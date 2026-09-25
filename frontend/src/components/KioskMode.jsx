import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Lock, ScanFace, CheckCircle2, FileText, ChevronRight, UploadCloud, Loader2, RefreshCw } from 'lucide-react';
import axios from 'axios';

export default function KioskMode({ onExit }) {
  const [step, setStep] = useState(1);
  const [showUnlock, setShowUnlock] = useState(false);
  const [pin, setPin] = useState('');
  
  // Patient Data
  const [isScanning, setIsScanning] = useState(false);
  const [patientData, setPatientData] = useState({
    name: 'John Doe',
    dob: '1985-06-15',
    phone: '',
    agreed: false,
    signature: ''
  });

  const handleUnlock = (e) => {
    e.preventDefault();
    if (pin === '1234') {
      onExit();
    } else {
      alert("Incorrect PIN");
      setPin('');
    }
  };

  const simulateScan = () => {
    setIsScanning(true);
    setTimeout(() => {
      setIsScanning(false);
      setStep(3); // Go to info review
    }, 2500);
  };

  const submitCheckIn = async (e) => {
    e.preventDefault();
    setStep(5); // Success screen
    
    // Log to backend activity feed
    try {
      await axios.post('/api/activity/log', {
        action: 'kiosk_check_in',
        description: 'Patient checked in via Waiting Room Kiosk',
        patient_name: patientData.name,
        patient_id: 'KIOSK-123',
        detail: 'Consent signed electronically.',
        color: 'emerald'
      });
    } catch(err) {
      console.error(err);
    }
  };

  useEffect(() => {
    if (step === 5) {
      const timer = setTimeout(() => {
        setStep(1); // Reset back to welcome screen after 5 seconds
        setPatientData({ name: 'John Doe', dob: '1985-06-15', phone: '', agreed: false, signature: '' });
      }, 5000);
      return () => clearTimeout(timer);
    }
  }, [step]);

  return (
    <div style={{ position: 'fixed', inset: 0, background: 'var(--bg-primary)', zIndex: 99999, display: 'flex', flexDirection: 'column', color: 'var(--text-primary)' }}>
      
      {/* Hidden Unlock Button */}
      <div 
        onClick={() => setShowUnlock(true)}
        style={{ position: 'absolute', top: '20px', right: '20px', width: '60px', height: '60px', cursor: 'pointer', zIndex: 100, display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: 0.2 }}
      >
        <Lock size={20} />
      </div>

      <AnimatePresence mode="wait">
        
        {/* STEP 1: WELCOME */}
        {step === 1 && (
          <motion.div 
            key="step1"
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            onClick={() => setStep(2)}
            style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', background: 'linear-gradient(135deg, var(--bg-primary), var(--bg-secondary))' }}
          >
            <div style={{ width: '120px', height: '120px', background: 'var(--primary)', borderRadius: '30px', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '40px', boxShadow: '0 20px 40px rgba(47, 129, 247, 0.3)' }}>
              <CheckCircle2 size={64} color="white" />
            </div>
            <h1 style={{ fontSize: '48px', fontWeight: '800', marginBottom: '16px' }}>Welcome to Prime Care</h1>
            <p style={{ fontSize: '24px', color: 'var(--text-secondary)', marginBottom: '60px' }}>Tap anywhere on the screen to check in</p>
            <div className="animate-pulse" style={{ background: 'var(--primary)', color: 'white', padding: '16px 48px', borderRadius: '40px', fontSize: '20px', fontWeight: '700', boxShadow: '0 10px 25px rgba(47, 129, 247, 0.4)' }}>
              Start Check-In
            </div>
          </motion.div>
        )}

        {/* STEP 2: SCAN ID */}
        {step === 2 && (
          <motion.div 
            key="step2"
            initial={{ opacity: 0, x: 100 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -100 }}
            style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '40px' }}
          >
            <h2 style={{ fontSize: '36px', fontWeight: '800', marginBottom: '16px' }}>Verify Your Identity</h2>
            <p style={{ fontSize: '20px', color: 'var(--text-secondary)', marginBottom: '40px', textAlign: 'center', maxWidth: '600px' }}>
              Please hold your Health Card or Driver's License up to the camera, or tap the button to scan.
            </p>
            
            <div 
              onClick={!isScanning ? simulateScan : undefined}
              style={{ width: '400px', height: '250px', background: 'var(--bg-tertiary)', border: '2px dashed var(--primary)', borderRadius: '24px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', cursor: isScanning ? 'default' : 'pointer', transition: 'all 0.3s', position: 'relative', overflow: 'hidden' }}
            >
              {isScanning ? (
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', color: 'var(--primary)' }}>
                  <ScanFace size={64} className="animate-pulse" style={{ marginBottom: '16px' }} />
                  <div style={{ fontSize: '18px', fontWeight: '600' }}>Extracting details using AI...</div>
                </div>
              ) : (
                <>
                  <UploadCloud size={64} color="var(--primary)" style={{ marginBottom: '16px' }} />
                  <div style={{ fontSize: '20px', fontWeight: '700', color: 'var(--text-primary)' }}>Tap to Scan Card</div>
                </>
              )}
            </div>
            
            <button onClick={() => setStep(3)} style={{ marginTop: '40px', background: 'transparent', border: 'none', color: 'var(--text-secondary)', fontSize: '16px', fontWeight: '600', cursor: 'pointer', textDecoration: 'underline' }}>
              Enter Manually Instead
            </button>
          </motion.div>
        )}

        {/* STEP 3: REVIEW & FORMS */}
        {step === 3 && (
          <motion.div 
            key="step3"
            initial={{ opacity: 0, x: 100 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -100 }}
            style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '40px' }}
          >
            <h2 style={{ fontSize: '36px', fontWeight: '800', marginBottom: '16px' }}>Review Your Details</h2>
            <p style={{ fontSize: '20px', color: 'var(--text-secondary)', marginBottom: '40px' }}>Please confirm your information and sign the consent form.</p>
            
            <form onSubmit={submitCheckIn} style={{ width: '100%', maxWidth: '600px', background: 'var(--bg-secondary)', padding: '40px', borderRadius: '24px', border: '1px solid var(--border)', boxShadow: '0 20px 40px rgba(0,0,0,0.1)' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', marginBottom: '24px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '14px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '8px' }}>Full Name</label>
                  <input type="text" value={patientData.name} onChange={e => setPatientData({...patientData, name: e.target.value})} required style={{ width: '100%', padding: '16px', borderRadius: '12px', border: '1px solid var(--border)', background: 'var(--bg-primary)', color: 'var(--text-primary)', fontSize: '18px' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '14px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '8px' }}>Date of Birth</label>
                  <input type="date" value={patientData.dob} onChange={e => setPatientData({...patientData, dob: e.target.value})} required style={{ width: '100%', padding: '16px', borderRadius: '12px', border: '1px solid var(--border)', background: 'var(--bg-primary)', color: 'var(--text-primary)', fontSize: '18px' }} />
                </div>
              </div>

              <div style={{ marginBottom: '32px' }}>
                <label style={{ display: 'block', fontSize: '14px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '8px' }}>Mobile Phone Number</label>
                <input type="tel" value={patientData.phone} onChange={e => setPatientData({...patientData, phone: e.target.value})} placeholder="(555) 555-5555" required style={{ width: '100%', padding: '16px', borderRadius: '12px', border: '1px solid var(--border)', background: 'var(--bg-primary)', color: 'var(--text-primary)', fontSize: '18px' }} />
              </div>

              <div style={{ background: 'var(--bg-primary)', padding: '24px', borderRadius: '16px', border: '1px solid var(--border)', marginBottom: '32px' }}>
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '16px' }}>
                  <input type="checkbox" id="consent" checked={patientData.agreed} onChange={e => setPatientData({...patientData, agreed: e.target.checked})} required style={{ width: '24px', height: '24px', marginTop: '4px' }} />
                  <label htmlFor="consent" style={{ fontSize: '16px', lineHeight: '1.5' }}>
                    I consent to medical treatment and authorize Prime Care to release any information necessary to process my insurance claims.
                  </label>
                </div>
                
                {patientData.agreed && (
                  <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: 'auto' }} style={{ marginTop: '20px' }}>
                    <label style={{ display: 'block', fontSize: '14px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '8px' }}>Type your full name to sign electronically:</label>
                    <input type="text" value={patientData.signature} onChange={e => setPatientData({...patientData, signature: e.target.value})} placeholder="Electronic Signature" required style={{ width: '100%', padding: '16px', borderRadius: '12px', border: '1px solid var(--border)', background: 'var(--bg-tertiary)', color: 'var(--text-primary)', fontSize: '20px', fontFamily: 'cursive' }} />
                  </motion.div>
                )}
              </div>

              <div style={{ display: 'flex', gap: '16px' }}>
                <button type="button" onClick={() => setStep(1)} style={{ padding: '20px 32px', borderRadius: '16px', border: '1px solid var(--border)', background: 'transparent', color: 'var(--text-primary)', fontSize: '20px', fontWeight: '600', cursor: 'pointer' }}>Cancel</button>
                <button type="submit" disabled={!patientData.agreed || !patientData.signature} style={{ flex: 1, padding: '20px', borderRadius: '16px', border: 'none', background: patientData.agreed && patientData.signature ? 'var(--primary)' : 'var(--bg-tertiary)', color: patientData.agreed && patientData.signature ? 'white' : 'var(--text-secondary)', fontSize: '20px', fontWeight: '700', cursor: patientData.agreed && patientData.signature ? 'pointer' : 'not-allowed', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '12px', transition: 'all 0.2s' }}>
                  Complete Check-In <ChevronRight size={24} />
                </button>
              </div>
            </form>
          </motion.div>
        )}

        {/* STEP 5: SUCCESS */}
        {step === 5 && (
          <motion.div 
            key="step5"
            initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0 }}
            style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}
          >
            <div style={{ width: '160px', height: '160px', background: 'var(--accent)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '40px', boxShadow: '0 20px 40px rgba(35, 134, 54, 0.3)' }}>
              <CheckCircle2 size={80} color="white" />
            </div>
            <h1 style={{ fontSize: '48px', fontWeight: '800', marginBottom: '16px', color: 'var(--accent)' }}>You're Checked In!</h1>
            <p style={{ fontSize: '24px', color: 'var(--text-secondary)' }}>Please have a seat in the waiting area.</p>
            <div style={{ marginTop: '60px', display: 'flex', alignItems: 'center', gap: '12px', color: 'var(--text-secondary)' }}>
              <RefreshCw size={20} className="animate-spin" /> Returning to welcome screen...
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* UNLOCK MODAL */}
      <AnimatePresence>
        {showUnlock && (
          <motion.div 
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.8)', backdropFilter: 'blur(10px)', zIndex: 999999, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
          >
            <div style={{ background: 'var(--bg-secondary)', padding: '40px', borderRadius: '24px', width: '400px', textAlign: 'center' }}>
              <h3 style={{ fontSize: '24px', fontWeight: '700', marginBottom: '24px' }}>Exit Kiosk Mode</h3>
              <form onSubmit={handleUnlock}>
                <input 
                  type="password" 
                  value={pin} 
                  onChange={e => setPin(e.target.value)} 
                  placeholder="Enter 4-Digit PIN" 
                  autoFocus
                  style={{ width: '100%', padding: '20px', fontSize: '24px', textAlign: 'center', letterSpacing: '8px', borderRadius: '12px', border: '1px solid var(--border)', background: 'var(--bg-primary)', color: 'var(--text-primary)', marginBottom: '24px' }} 
                />
                <div style={{ display: 'flex', gap: '12px' }}>
                  <button type="button" onClick={() => setShowUnlock(false)} style={{ flex: 1, padding: '16px', borderRadius: '12px', border: '1px solid var(--border)', background: 'transparent', color: 'var(--text-primary)', fontSize: '18px', fontWeight: '600', cursor: 'pointer' }}>Cancel</button>
                  <button type="submit" style={{ flex: 1, padding: '16px', borderRadius: '12px', border: 'none', background: 'var(--error)', color: 'white', fontSize: '18px', fontWeight: '700', cursor: 'pointer' }}>Unlock</button>
                </div>
              </form>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

    </div>
  );
}
