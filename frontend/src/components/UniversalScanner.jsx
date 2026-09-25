import React, { useState, useRef, useEffect } from 'react';
import { Camera, FileText, CheckCircle, XCircle, Loader, UploadCloud, X, ArrowRight, ShieldAlert, CreditCard } from 'lucide-react';
import axios from 'axios';
import { motion, AnimatePresence } from 'framer-motion';

export default function UniversalScanner({ isOpen, onClose }) {
  const [isScanning, setIsScanning] = useState(false);
  const [scanResult, setScanResult] = useState(null);
  const [error, setError] = useState(null);
  const fileInputRef = useRef(null);

  useEffect(() => {
    if (!isOpen) {
      // Reset state when closed
      setScanResult(null);
      setError(null);
      setIsScanning(false);
    }
  }, [isOpen]);

  const handleFileUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    setIsScanning(true);
    setError(null);
    setScanResult(null);

    const formData = new FormData();
    formData.append('file', file);

    try {
      const response = await axios.post('/api/scanner/triage', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      setScanResult(response.data);
    } catch (err) {
      setError("Failed to process document. Please try again.");
    } finally {
      setIsScanning(false);
      // reset file input
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  if (!isOpen) return null;

  return (
    <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(4px)', zIndex: 9999, display: 'flex', justifyContent: 'center', alignItems: 'center' }} onClick={onClose}>
      <motion.div 
        initial={{ opacity: 0, scale: 0.95, y: 20 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.95, y: 20 }}
        onClick={e => e.stopPropagation()}
        style={{ width: '600px', background: 'rgba(15, 23, 42, 0.95)', border: '1px solid #3b82f6', borderRadius: '16px', overflow: 'hidden', boxShadow: '0 25px 50px -12px rgba(0,0,0,0.7)', display: 'flex', flexDirection: 'column' }}
      >
        <div style={{ padding: '20px', borderBottom: '1px solid rgba(255,255,255,0.1)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ background: 'rgba(59, 130, 246, 0.2)', padding: '8px', borderRadius: '8px', color: '#60a5fa' }}>
              <Camera size={20} />
            </div>
            <h2 style={{ margin: 0, fontSize: '18px', color: 'white', fontWeight: '700' }}>Universal Document Triage</h2>
          </div>
          <button onClick={onClose} style={{ background: 'transparent', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer' }}>
            <X size={20} />
          </button>
        </div>

        <div style={{ padding: '24px', flex: 1 }}>
          {!scanResult && !isScanning && (
            <div 
              onClick={() => fileInputRef.current.click()}
              style={{ 
                border: '2px dashed rgba(59, 130, 246, 0.4)', 
                borderRadius: '12px', 
                padding: '48px 24px', 
                textAlign: 'center',
                cursor: 'pointer',
                background: 'rgba(59, 130, 246, 0.05)',
                transition: 'all 0.2s',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: '16px'
              }}
              onMouseOver={(e) => e.currentTarget.style.background = 'rgba(59, 130, 246, 0.1)'}
              onMouseOut={(e) => e.currentTarget.style.background = 'rgba(59, 130, 246, 0.05)'}
            >
              <UploadCloud size={48} color="#60a5fa" />
              <div>
                <div style={{ fontWeight: '600', color: 'white', fontSize: '18px' }}>Drag & Drop or Click to Upload</div>
                <div style={{ fontSize: '14px', color: 'var(--text-secondary)', marginTop: '8px', maxWidth: '300px', margin: '8px auto 0' }}>
                  Upload any health card, lab result, referral letter, or intake form. AI will automatically classify and extract it.
                </div>
              </div>
            </div>
          )}

          {isScanning && (
            <div style={{ padding: '48px 24px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '20px', color: '#60a5fa' }}>
              <Loader className="animate-spin" size={48} />
              <div style={{ fontWeight: '600', fontSize: '16px', color: 'white' }}>AI Vision Processing Document...</div>
              <div style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Extracting clinical data streams...</div>
            </div>
          )}

          {error && (
            <div style={{ color: '#ef4444', display: 'flex', alignItems: 'center', gap: '8px', padding: '16px', background: 'rgba(239, 68, 68, 0.1)', borderRadius: '8px' }}>
              <XCircle size={20} /> {error}
            </div>
          )}

          {scanResult && !isScanning && (
            <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '20px' }}>
                <CheckCircle size={24} color="#10b981" />
                <div>
                  <div style={{ fontWeight: '700', color: 'white', fontSize: '16px' }}>{scanResult.title} Detected</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Confidence: {(scanResult.confidence * 100).toFixed(1)}%</div>
                </div>
              </div>

              <div style={{ background: 'rgba(0,0,0,0.3)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '12px', padding: '16px', marginBottom: '24px' }}>
                {scanResult.type === 'health_card' && (
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                    <div><div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Patient Name</div><div style={{ color: 'white', fontWeight: '600' }}>{scanResult.data.patient_name}</div></div>
                    <div><div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>DOB</div><div style={{ color: 'white', fontWeight: '600' }}>{scanResult.data.dob}</div></div>
                    <div><div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>OHIP Number</div><div style={{ color: '#60a5fa', fontWeight: '700', letterSpacing: '1px' }}>{scanResult.data.health_card_number}</div></div>
                    <div><div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Version Code</div><div style={{ color: '#60a5fa', fontWeight: '700' }}>{scanResult.data.version_code}</div></div>
                  </div>
                )}

                {scanResult.type === 'referral' && (
                  <div style={{ display: 'grid', gap: '16px' }}>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr' }}>
                      <div><div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Patient Name</div><div style={{ color: 'white', fontWeight: '600' }}>{scanResult.data.patient_name}</div></div>
                      <div><div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Urgency</div><div style={{ color: '#ef4444', fontWeight: '700' }}>{scanResult.data.urgency}</div></div>
                    </div>
                    <div><div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Referred To</div><div style={{ color: 'white', fontWeight: '600' }}>{scanResult.data.referred_to}</div></div>
                    <div><div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Reason</div><div style={{ color: 'white', fontSize: '14px' }}>{scanResult.data.reason}</div></div>
                  </div>
                )}

                {scanResult.type === 'lab_result' && (
                  <div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '16px' }}>
                      <div><div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Patient Name</div><div style={{ color: 'white', fontWeight: '600' }}>{scanResult.data.patient_name}</div></div>
                      <div><div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Collection Date</div><div style={{ color: 'white', fontWeight: '600' }}>{scanResult.data.collection_date}</div></div>
                    </div>
                    <div style={{ fontSize: '12px', fontWeight: '700', color: '#ef4444', display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '8px' }}>
                      <ShieldAlert size={14} /> {scanResult.data.abnormal_flags} ABNORMAL FLAGS DETECTED
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                      {scanResult.data.findings.map((f, i) => (
                        <div key={i} style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.2)', padding: '10px', borderRadius: '8px', display: 'flex', justifyContent: 'space-between' }}>
                          <span style={{ color: 'white', fontWeight: '500', fontSize: '14px' }}>{f.test}</span>
                          <span style={{ color: '#fca5a5', fontWeight: '700', fontSize: '14px' }}>{f.value} <span style={{ fontSize: '11px', fontWeight: 'normal' }}>(ref: {f.reference})</span></span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {scanResult.type === 'general_document' && (
                  <div>
                    <div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Filename</div>
                    <div style={{ color: 'white', fontWeight: '600', marginBottom: '12px' }}>{scanResult.data.filename}</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>AI Summary</div>
                    <div style={{ color: 'white', fontSize: '14px' }}>{scanResult.data.summary}</div>
                  </div>
                )}
              </div>

              <div style={{ display: 'flex', gap: '12px' }}>
                <button 
                  onClick={() => {
                    // In a real app, this would route to specific tabs or trigger a save.
                    alert(`Action executed: ${scanResult.action_type}`);
                    onClose();
                  }}
                  style={{ flex: 1, padding: '12px', background: 'linear-gradient(to right, #3b82f6, #2563eb)', color: 'white', border: 'none', borderRadius: '8px', fontWeight: '600', fontSize: '15px', cursor: 'pointer', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '8px' }}
                >
                  {scanResult.suggested_action} <ArrowRight size={18} />
                </button>
                <button onClick={() => setScanResult(null)} style={{ padding: '12px 24px', background: 'rgba(255,255,255,0.1)', color: 'white', border: 'none', borderRadius: '8px', fontWeight: '600', cursor: 'pointer' }}>
                  Scan Another
                </button>
              </div>
            </motion.div>
          )}

          <input 
            type="file" 
            ref={fileInputRef} 
            style={{ display: 'none' }} 
            onChange={handleFileUpload}
          />
        </div>
      </motion.div>
    </div>
  );
}
