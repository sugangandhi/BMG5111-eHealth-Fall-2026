import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { 
  MessageCircle, X, Send, CheckCircle2, AlertCircle, 
  ExternalLink, Sparkles, Activity, ShieldCheck, Copy, Check, Info, Phone, Cloud, Database
} from 'lucide-react';

export default function WhatsAppModal({ isOpen, onClose, activePatient, onActivityLogged }) {
  const [activeSubTab, setActiveSubTab] = useState('direct'); // 'direct' | 'simulate' | 'config'
  const [patients, setPatients] = useState([]);
  const [selectedPatientId, setSelectedPatientId] = useState(activePatient?.id || '');
  
  // Direct Chat Tab State
  const [targetPhone, setTargetPhone] = useState('1234567890');
  const [directMessage, setDirectMessage] = useState('');
  
  // Simulation Tab State
  const [simPhone, setSimPhone] = useState('613-555-0192');
  const [simMessage, setSimMessage] = useState('Hi Doctor, this is Sarah Khan. My blood pressure this morning is 138/88 and my heart rate is 78.');
  const [isSimulating, setIsSimulating] = useState(false);
  const [simulationResult, setSimulationResult] = useState(null);

  // Config Tab State
  const [configStatus, setConfigStatus] = useState(null);
  const [copiedKey, setCopiedKey] = useState(null);

  // Load patients and config status on open
  useEffect(() => {
    if (!isOpen) return;

    axios.get('/api/patients')
      .then(res => {
        if (res.data && res.data.patients) {
          setPatients(res.data.patients);
        }
      })
      .catch(err => console.error("Error loading patients:", err));

    axios.get('/api/whatsapp/status')
      .then(res => setConfigStatus(res.data))
      .catch(err => console.error("Error checking WhatsApp status:", err));
  }, [isOpen]);

  // Sync with activePatient or selected patient
  useEffect(() => {
    if (activePatient) {
      setSelectedPatientId(activePatient.id);
      const phone = activePatient.phone ? activePatient.phone.replace(/\D/g, '') : '1234567890';
      setTargetPhone(phone || '1234567890');
      setDirectMessage(`Hello Dr. Patel, this is ${activePatient.name?.text || activePatient.name}. My DOB is ${activePatient.birthDate || 'YYYY-MM-DD'}. I am submitting an update.`);
      setSimPhone(activePatient.phone || '613-555-0192');
      setSimMessage(`Hello Doctor, this is ${activePatient.name?.text || activePatient.name}. Today's blood pressure is 136/84 and my heart rate is 74.`);
    } else {
      setDirectMessage('Hello Dr. Patel, I am a patient reaching out to update my records. My name is [Your Name] and my DOB is [YYYY-MM-DD].');
    }
  }, [activePatient]);

  const handlePatientSelect = (pId) => {
    setSelectedPatientId(pId);
    const p = patients.find(item => item.id === pId);
    if (p) {
      axios.get(`/api/patient/${pId}`).then(res => {
        const fullPatient = res.data;
        const phone = fullPatient.phone ? fullPatient.phone.replace(/\D/g, '') : '6135550192';
        setTargetPhone(phone);
        setSimPhone(fullPatient.phone || '613-555-0192');
        setDirectMessage(`Hello Dr. Patel, this is ${fullPatient.name?.text || fullPatient.name}. My DOB is ${fullPatient.birthDate}. Submitting my health update.`);
        setSimMessage(`Hi Dr. Patel, this is ${fullPatient.name?.text || fullPatient.name}. My BP today is 135/85 and glucose is 6.5.`);
      }).catch(() => {
        setDirectMessage(`Hello Dr. Patel, this is ${p.name}. My DOB is ${p.birthDate}.`);
      });
    }
  };

  const handleOpenWhatsApp = () => {
    const digitsOnly = targetPhone.replace(/\D/g, '');
    const cleanNumber = digitsOnly.length === 10 ? `1${digitsOnly}` : digitsOnly;
    const url = `https://wa.me/${cleanNumber}?text=${encodeURIComponent(directMessage)}`;
    window.open(url, '_blank');
  };

  const handleRunSimulation = async () => {
    setIsSimulating(true);
    setSimulationResult(null);
    try {
      const res = await axios.post('/api/whatsapp/simulate', {
        phone: simPhone,
        message: simMessage
      });
      setSimulationResult(res.data);
      if (onActivityLogged) {
        onActivityLogged();
      }
    } catch (err) {
      setSimulationResult({
        status: 'error',
        detail: err.response?.data?.detail || err.message
      });
    } finally {
      setIsSimulating(false);
    }
  };

  const copyToClipboard = (text, keyName) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(keyName);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  if (!isOpen) return null;

  return (
    <div 
      className="modal-backdrop animate-fade-in"
      style={{
        position: 'fixed',
        inset: 0,
        zIndex: 1100,
        background: 'rgba(0, 0, 0, 0.7)',
        backdropFilter: 'blur(8px)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '16px'
      }}
      onClick={onClose}
    >
      <div 
        className="glass-panel"
        style={{
          width: '100%',
          maxWidth: '560px',
          maxHeight: '90vh',
          display: 'flex',
          flexDirection: 'column',
          borderRadius: '20px',
          border: '1px solid rgba(37, 211, 102, 0.3)',
          background: 'var(--bg-primary)',
          boxShadow: '0 20px 50px rgba(0, 0, 0, 0.4), 0 0 25px rgba(37, 211, 102, 0.15)',
          overflow: 'hidden'
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div style={{
          padding: '16px 20px',
          borderBottom: '1px solid var(--glass-border)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          background: 'linear-gradient(135deg, rgba(37, 211, 102, 0.12), transparent)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{
              width: '40px',
              height: '40px',
              borderRadius: '12px',
              background: 'linear-gradient(135deg, #25D366, #128C7E)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#ffffff',
              boxShadow: '0 4px 12px rgba(37, 211, 102, 0.35)'
            }}>
              <MessageCircle size={22} />
            </div>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <h3 style={{ margin: 0, fontSize: '17px', fontWeight: '700', color: 'var(--text-primary)' }}>
                  WhatsApp Patient Portal
                </h3>
                <span style={{
                  fontSize: '10px',
                  fontWeight: '700',
                  padding: '2px 8px',
                  borderRadius: '10px',
                  background: configStatus?.configured ? 'rgba(37, 211, 102, 0.2)' : 'rgba(59, 130, 246, 0.2)',
                  color: configStatus?.configured ? '#25d366' : '#60a5fa',
                  textTransform: 'uppercase',
                  letterSpacing: '0.05em'
                }}>
                  {configStatus?.configured ? 'Cloud API Active' : 'Simulation Mode'}
                </span>
              </div>
              <p style={{ margin: 0, fontSize: '12px', color: 'var(--text-secondary)' }}>
                Automated EHR vitals capture & two-way clinical messaging
              </p>
            </div>
          </div>
          <button 
            onClick={onClose}
            style={{
              background: 'transparent',
              border: 'none',
              color: 'var(--text-secondary)',
              cursor: 'pointer',
              padding: '6px',
              borderRadius: '8px'
            }}
          >
            <X size={20} />
          </button>
        </div>

        {/* Tab Navigation */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(3, 1fr)',
          padding: '6px',
          background: 'var(--bg-secondary)',
          borderBottom: '1px solid var(--glass-border)'
        }}>
          <button
            onClick={() => setActiveSubTab('direct')}
            style={{
              padding: '10px 6px',
              borderRadius: '10px',
              border: 'none',
              background: activeSubTab === 'direct' ? '#25D366' : 'transparent',
              color: activeSubTab === 'direct' ? '#ffffff' : 'var(--text-secondary)',
              fontWeight: activeSubTab === 'direct' ? '700' : '500',
              fontSize: '12px',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              transition: 'all 0.2s'
            }}
          >
            <ExternalLink size={14} /> Open WhatsApp
          </button>

          <button
            onClick={() => setActiveSubTab('simulate')}
            style={{
              padding: '10px 6px',
              borderRadius: '10px',
              border: 'none',
              background: activeSubTab === 'simulate' ? '#25D366' : 'transparent',
              color: activeSubTab === 'simulate' ? '#ffffff' : 'var(--text-secondary)',
              fontWeight: activeSubTab === 'simulate' ? '700' : '500',
              fontSize: '12px',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              transition: 'all 0.2s'
            }}
          >
            <Sparkles size={14} /> Live Bot Simulator
          </button>

          <button
            onClick={() => setActiveSubTab('config')}
            style={{
              padding: '10px 6px',
              borderRadius: '10px',
              border: 'none',
              background: activeSubTab === 'config' ? '#25D366' : 'transparent',
              color: activeSubTab === 'config' ? '#ffffff' : 'var(--text-secondary)',
              fontWeight: activeSubTab === 'config' ? '700' : '500',
              fontSize: '12px',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              transition: 'all 0.2s'
            }}
          >
            <Cloud size={14} /> Central EMR Cloud
          </button>
        </div>

        {/* Content Body */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '18px', display: 'flex', flexDirection: 'column', gap: '16px' }}>

          {/* TAB 1: DIRECT CHAT LAUNCHER */}
          {activeSubTab === 'direct' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', display: 'block', marginBottom: '6px' }}>
                  Select Registered Patient
                </label>
                <select
                  value={selectedPatientId}
                  onChange={(e) => handlePatientSelect(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '10px 12px',
                    borderRadius: '10px',
                    background: 'var(--bg-secondary)',
                    border: '1px solid var(--glass-border)',
                    color: 'var(--text-primary)',
                    fontSize: '13px',
                    outline: 'none'
                  }}
                >
                  <option value="">-- Manual Number / Patient --</option>
                  {patients.map(p => (
                    <option key={p.id} value={p.id}>{p.name} (DOB: {p.birthDate})</option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', display: 'block', marginBottom: '6px' }}>
                  Patient Mobile / WhatsApp Number
                </label>
                <div style={{ position: 'relative' }}>
                  <input
                    type="text"
                    value={targetPhone}
                    onChange={(e) => setTargetPhone(e.target.value)}
                    placeholder="e.g. 6135550192 or 1234567890"
                    style={{
                      width: '100%',
                      padding: '10px 12px 10px 38px',
                      borderRadius: '10px',
                      background: 'var(--bg-secondary)',
                      border: '1px solid var(--glass-border)',
                      color: 'var(--text-primary)',
                      fontSize: '14px',
                      boxSizing: 'border-box'
                    }}
                  />
                  <Phone size={16} color="var(--text-secondary)" style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)' }} />
                </div>
              </div>

              <div>
                <label style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', display: 'block', marginBottom: '6px' }}>
                  Pre-filled WhatsApp Message
                </label>
                <textarea
                  rows={4}
                  value={directMessage}
                  onChange={(e) => setDirectMessage(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '10px 12px',
                    borderRadius: '10px',
                    background: 'var(--bg-secondary)',
                    border: '1px solid var(--glass-border)',
                    color: 'var(--text-primary)',
                    fontSize: '13px',
                    lineHeight: '1.4',
                    resize: 'none',
                    boxSizing: 'border-box'
                  }}
                />
              </div>

              {/* Quick Append Chips */}
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                <button
                  type="button"
                  onClick={() => setDirectMessage(prev => prev + " BP reading: 138/86.")}
                  style={{ fontSize: '11px', padding: '4px 10px', borderRadius: '15px', background: 'rgba(59, 130, 246, 0.15)', border: '1px solid rgba(59, 130, 246, 0.3)', color: '#60a5fa', cursor: 'pointer' }}
                >
                  + Add BP (138/86)
                </button>
                <button
                  type="button"
                  onClick={() => setDirectMessage(prev => prev + " Pulse: 78 bpm.")}
                  style={{ fontSize: '11px', padding: '4px 10px', borderRadius: '15px', background: 'rgba(16, 185, 129, 0.15)', border: '1px solid rgba(16, 185, 129, 0.3)', color: '#34d399', cursor: 'pointer' }}
                >
                  + Add Pulse (78)
                </button>
                <button
                  type="button"
                  onClick={() => setDirectMessage(prev => prev + " Fasting sugar: 6.8.")}
                  style={{ fontSize: '11px', padding: '4px 10px', borderRadius: '15px', background: 'rgba(245, 158, 11, 0.15)', border: '1px solid rgba(245, 158, 11, 0.3)', color: '#fbbf24', cursor: 'pointer' }}
                >
                  + Add Glucose (6.8)
                </button>
              </div>

              {/* Launch Button */}
              <button
                type="button"
                onClick={handleOpenWhatsApp}
                style={{
                  marginTop: '8px',
                  padding: '13px',
                  borderRadius: '12px',
                  border: 'none',
                  background: 'linear-gradient(135deg, #25D366, #128C7E)',
                  color: '#ffffff',
                  fontWeight: '700',
                  fontSize: '14px',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '8px',
                  boxShadow: '0 4px 15px rgba(37, 211, 102, 0.4)'
                }}
              >
                <MessageCircle size={18} /> Open in WhatsApp App / Web
              </button>

              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '8px 12px', background: 'rgba(37, 211, 102, 0.08)', borderRadius: '10px', border: '1px solid rgba(37, 211, 102, 0.2)' }}>
                <Info size={15} color="#25D366" style={{ flexShrink: 0 }} />
                <span style={{ fontSize: '11px', color: 'var(--text-secondary)', lineHeight: '1.4' }}>
                  On mobile phones, this opens the native WhatsApp app directly to chat with the e-Hospital bot.
                </span>
              </div>
            </div>
          )}

          {/* TAB 2: LIVE BOT & EHR SIMULATOR */}
          {activeSubTab === 'simulate' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div style={{ padding: '10px 14px', background: 'rgba(59, 130, 246, 0.08)', borderRadius: '12px', border: '1px solid rgba(59, 130, 246, 0.2)' }}>
                <span style={{ fontSize: '12px', color: 'var(--text-primary)', lineHeight: '1.4', display: 'block' }}>
                  🧪 <strong>Interactive Test Console:</strong> Simulates an incoming patient message to e-Hospital. Automatically tests regex/NLP vital extraction, updates local EHR, and live syncs to the Central EMR MySQL database on AWS.
                </span>
              </div>

              {/* Scenario Presets */}
              <div>
                <label style={{ fontSize: '11px', fontWeight: '700', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.05em', display: 'block', marginBottom: '6px' }}>
                  Quick Clinical Presets:
                </label>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                  <button
                    type="button"
                    onClick={() => {
                      setSimPhone('613-555-0192');
                      setSimMessage('Hi Doctor Patel, this is Sarah Khan. My morning blood pressure is 138/88 and pulse is 78.');
                    }}
                    style={{ fontSize: '11px', padding: '5px 10px', borderRadius: '8px', background: 'var(--bg-secondary)', border: '1px solid var(--glass-border)', color: 'var(--text-primary)', cursor: 'pointer' }}
                  >
                    🩺 Sarah Khan (BP + HR)
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setSimPhone('613-555-0374');
                      setSimMessage('Good morning clinic, Marcus Tremblay here. Fasting glucose today is 7.2 mmol/L.');
                    }}
                    style={{ fontSize: '11px', padding: '5px 10px', borderRadius: '8px', background: 'var(--bg-secondary)', border: '1px solid var(--glass-border)', color: 'var(--text-primary)', cursor: 'pointer' }}
                  >
                    🩸 Marcus (Glucose)
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setSimPhone('416-555-9999');
                      setSimMessage('Hello, I am a new patient inquiring about an appointment.');
                    }}
                    style={{ fontSize: '11px', padding: '5px 10px', borderRadius: '8px', background: 'var(--bg-secondary)', border: '1px solid var(--glass-border)', color: 'var(--text-primary)', cursor: 'pointer' }}
                  >
                    ❓ Unregistered Sender
                  </button>
                </div>
              </div>

              <div>
                <label style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', display: 'block', marginBottom: '6px' }}>
                  Sender Phone Number
                </label>
                <input
                  type="text"
                  value={simPhone}
                  onChange={(e) => setSimPhone(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '9px 12px',
                    borderRadius: '10px',
                    background: 'var(--bg-secondary)',
                    border: '1px solid var(--glass-border)',
                    color: 'var(--text-primary)',
                    fontSize: '13px',
                    boxSizing: 'border-box'
                  }}
                />
              </div>

              <div>
                <label style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', display: 'block', marginBottom: '6px' }}>
                  Incoming Message Body
                </label>
                <textarea
                  rows={3}
                  value={simMessage}
                  onChange={(e) => setSimMessage(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '9px 12px',
                    borderRadius: '10px',
                    background: 'var(--bg-secondary)',
                    border: '1px solid var(--glass-border)',
                    color: 'var(--text-primary)',
                    fontSize: '13px',
                    lineHeight: '1.4',
                    resize: 'none',
                    boxSizing: 'border-box'
                  }}
                />
              </div>

              <button
                type="button"
                disabled={isSimulating}
                onClick={handleRunSimulation}
                style={{
                  padding: '12px',
                  borderRadius: '12px',
                  border: 'none',
                  background: isSimulating ? 'var(--bg-secondary)' : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                  color: '#ffffff',
                  fontWeight: '700',
                  fontSize: '13px',
                  cursor: isSimulating ? 'not-allowed' : 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '8px',
                  boxShadow: '0 4px 15px rgba(59, 130, 246, 0.35)'
                }}
              >
                {isSimulating ? (
                  <>
                    <Activity size={16} className="animate-spin" /> Processing Clinical Message...
                  </>
                ) : (
                  <>
                    <Send size={16} /> Send Simulated Inbound Message
                  </>
                )}
              </button>

              {/* Simulation Result Box */}
              {simulationResult && (
                <div style={{
                  padding: '14px',
                  borderRadius: '14px',
                  background: simulationResult.status === 'success' ? 'rgba(16, 185, 129, 0.08)' : 'rgba(245, 158, 11, 0.08)',
                  border: `1px solid ${simulationResult.status === 'success' ? 'rgba(16, 185, 129, 0.3)' : 'rgba(245, 158, 11, 0.3)'}`,
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '10px'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      {simulationResult.status === 'success' ? (
                        <CheckCircle2 size={18} color="#10b981" />
                      ) : (
                        <AlertCircle size={18} color="#f59e0b" />
                      )}
                      <span style={{ fontSize: '13px', fontWeight: '700', color: 'var(--text-primary)' }}>
                        {simulationResult.matched ? `Matched: ${simulationResult.patient_name}` : 'Unmatched Contact (Logged)'}
                      </span>
                    </div>
                    {simulationResult.patient_id && (
                      <span style={{ fontSize: '11px', color: 'var(--text-secondary)', background: 'var(--bg-secondary)', padding: '2px 8px', borderRadius: '6px' }}>
                        {simulationResult.patient_id}
                      </span>
                    )}
                  </div>

                  {/* Extracted Vitals */}
                  {simulationResult.vitals_extracted && Object.keys(simulationResult.vitals_extracted).length > 0 && (
                    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                      {Object.entries(simulationResult.vitals_extracted).map(([k, v]) => (
                        <span key={k} style={{ fontSize: '11px', fontWeight: '700', padding: '3px 8px', borderRadius: '6px', background: 'rgba(16, 185, 129, 0.2)', color: '#34d399' }}>
                          {k.toUpperCase()}: {v}
                        </span>
                      ))}
                    </div>
                  )}

                  {/* Central EMR Cloud Live Sync Confirmation */}
                  {simulationResult.central_emr_sync?.synced && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '6px 12px', background: 'rgba(56, 189, 248, 0.12)', borderRadius: '8px', border: '1px solid rgba(56, 189, 248, 0.3)' }}>
                      <Cloud size={14} color="#38bdf8" />
                      <span style={{ fontSize: '11px', fontWeight: '600', color: '#38bdf8' }}>
                        Live Synced to Central EMR Cloud Database (Vital ID: #{simulationResult.central_emr_sync.vital_id})
                      </span>
                    </div>
                  )}

                  {/* Automated Bot Reply */}
                  <div style={{ background: 'var(--bg-secondary)', padding: '10px 12px', borderRadius: '10px', borderLeft: '3px solid #25D366' }}>
                    <div style={{ fontSize: '11px', fontWeight: '700', color: '#25D366', marginBottom: '4px' }}>
                      Automated WhatsApp Bot Reply:
                    </div>
                    <div style={{ fontSize: '12px', color: 'var(--text-primary)', lineHeight: '1.4' }}>
                      "{simulationResult.reply_text}"
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* TAB 3: CENTRAL CLINICAL EMR CLOUD NETWORK */}
          {activeSubTab === 'config' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div style={{ padding: '12px 14px', background: 'rgba(56, 189, 248, 0.08)', borderRadius: '12px', border: '1px solid rgba(56, 189, 248, 0.25)', display: 'flex', alignItems: 'center', gap: '10px' }}>
                <Cloud size={20} color="#38bdf8" style={{ flexShrink: 0 }} />
                <div>
                  <div style={{ fontSize: '13px', fontWeight: '700', color: 'var(--text-primary)' }}>
                    Central Clinical EMR Cloud Network
                  </div>
                  <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                    Connected to AWS App Runner MySQL Database (77 Introspected Tables)
                  </div>
                </div>
              </div>

              {/* Central EMR Cloud Status Card */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <div style={{ fontSize: '11px', fontWeight: '700', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                  1. Live Cloud Database Connection
                </div>
                
                <div style={{ background: 'var(--bg-secondary)', padding: '12px', borderRadius: '10px', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Central Endpoint:</span>
                    <span style={{ fontSize: '11px', fontWeight: '600', color: '#38bdf8', fontFamily: 'monospace' }}>
                      https://aetab8pjmb.us-east-1.awsapprunner.com
                    </span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Active Tables:</span>
                    <span style={{ fontSize: '11px', fontWeight: '700', color: '#10b981' }}>77 Tables (MySQL Sequelize)</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Active Sync Tables:</span>
                    <span style={{ fontSize: '11px', fontWeight: '500', color: 'var(--text-primary)' }}>vitals_history, patients_registration, appointments</span>
                  </div>
                </div>
              </div>

              {/* Render Webhook Settings */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <div style={{ fontSize: '11px', fontWeight: '700', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                  2. Meta Webhook Configuration
                </div>
                
                <div style={{ background: 'var(--bg-secondary)', padding: '10px 12px', borderRadius: '10px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Callback Webhook URL:</div>
                    <div style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text-primary)', fontFamily: 'monospace' }}>
                      {window.location.origin}/api/whatsapp/webhook
                    </div>
                  </div>
                  <button 
                    onClick={() => copyToClipboard(`${window.location.origin}/api/whatsapp/webhook`, 'url')}
                    style={{ background: 'transparent', border: 'none', color: '#60a5fa', cursor: 'pointer', padding: '4px' }}
                  >
                    {copiedKey === 'url' ? <Check size={16} color="#10b981" /> : <Copy size={16} />}
                  </button>
                </div>

                <div style={{ background: 'var(--bg-secondary)', padding: '10px 12px', borderRadius: '10px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Verify Token:</div>
                    <div style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text-primary)', fontFamily: 'monospace' }}>
                      ehospital_verified_2026
                    </div>
                  </div>
                  <button 
                    onClick={() => copyToClipboard('ehospital_verified_2026', 'verify')}
                    style={{ background: 'transparent', border: 'none', color: '#60a5fa', cursor: 'pointer', padding: '4px' }}
                  >
                    {copiedKey === 'verify' ? <Check size={16} color="#10b981" /> : <Copy size={16} />}
                  </button>
                </div>
              </div>

              {/* Environment Variables */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <div style={{ fontSize: '11px', fontWeight: '700', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                  3. Cloud Environment Variables
                </div>

                <div style={{ background: 'var(--bg-secondary)', padding: '12px', borderRadius: '10px', fontSize: '12px', lineHeight: '1.6', fontFamily: 'monospace', color: 'var(--text-primary)' }}>
                  <div><span style={{ color: '#38bdf8' }}>CENTRAL_CLINICAL_API_URL</span>=https://aetab8pjmb...</div>
                  <div><span style={{ color: '#25D366' }}>WHATSAPP_TOKEN</span>=EAA...</div>
                  <div><span style={{ color: '#25D366' }}>WHATSAPP_PHONE_NUMBER_ID</span>=105492...</div>
                  <div><span style={{ color: '#25D366' }}>WHATSAPP_VERIFY_TOKEN</span>=ehospital_verified_2026</div>
                </div>
              </div>
            </div>
          )}

        </div>
      </div>
    </div>
  );
}
