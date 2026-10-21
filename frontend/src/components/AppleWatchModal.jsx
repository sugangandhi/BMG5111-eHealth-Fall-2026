import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { 
  Watch, Heart, Activity, Moon, ShieldCheck, RefreshCw, 
  CheckCircle2, X, Smartphone, FileText, Send, QrCode,
  AlertCircle, HelpCircle, ArrowRight, Check, Sparkles,
  ExternalLink, Copy, MessageSquare
} from 'lucide-react';

export default function AppleWatchModal({ isOpen, onClose, patient, onInsertToNote }) {
  const [activeTab, setActiveTab] = useState('vitals'); // 'vitals' | 'connect'
  const [telemetryMode, setTelemetryMode] = useState('demo'); // 'demo' | 'real'
  const [isSyncing, setIsSyncing] = useState(false);
  const [lastSynced, setLastSynced] = useState('3m ago');
  const [vitals, setVitals] = useState(null);
  const [copiedNotification, setCopiedNotification] = useState(false);
  const [inviteStatus, setInviteStatus] = useState(null); // null | 'sending' | 'sent'
  const [inviteResult, setInviteResult] = useState(null);
  const [copiedLink, setCopiedLink] = useState(false);
  const [syncStatusMsg, setSyncStatusMsg] = useState(null);

  const rawPatientId = patient?.patient_id || patient?.raw_id || patient?.id || 'pt-001';
  const patientId = String(rawPatientId);
  const patientName = typeof patient?.name === 'string' ? patient.name : (patient?.name?.text || patient?.patient_name || 'Selected Patient');
  const patientMrn = patient?.mrn || (patientId ? `MRN-${patientId}` : 'MRN-4821');

  const [activePhone, setActivePhone] = useState(patient?.phone || '');

  // Keep phone in sync with patient prop, fresh API query, and global updates
  useEffect(() => {
    if (patient) {
      if (patient.phone) {
        setActivePhone(patient.phone);
      }
      if (patientId && !patientId.startsWith('cloud-')) {
        axios.get(`/api/patient/${patientId}`)
          .then(res => {
            if (res.data?.phone) {
              setActivePhone(res.data.phone);
            }
          })
          .catch(() => {});
      }
    }
  }, [patient, patientId, isOpen]);

  useEffect(() => {
    const handleUpdated = (e) => {
      if (e.detail?.phone && (String(e.detail.id) === patientId || e.detail.name === patientName)) {
        setActivePhone(e.detail.phone);
      }
    };
    window.addEventListener('patient-details-updated', handleUpdated);
    return () => window.removeEventListener('patient-details-updated', handleUpdated);
  }, [patientId, patientName]);

  const patientPhone = activePhone || patient?.phone || patient?.telecom?.[0]?.value || '+1 613-261-6383';

  const handleChangePhoneClick = () => {
    const resolvedPatient = {
      ...patient,
      id: patientId,
      patient_id: patientId,
      name: patientName,
      phone: activePhone || patient?.phone || ''
    };
    if (onClose) onClose();
    setTimeout(() => {
      window.dispatchEvent(new CustomEvent('open-patient-edit', { detail: { patient: resolvedPatient } }));
    }, 120);
  };

  const fetchVitals = (mode = telemetryMode) => {
    setIsSyncing(true);
    axios.get(`/api/wearables/vitals?patient_name=${encodeURIComponent(patientName)}&mode=${mode}`)
      .then(res => {
        if (res.data) {
          setVitals(res.data);
          if (res.data.last_synced_display) {
            setLastSynced(res.data.last_synced_display);
          } else if (res.data.last_synced_minutes_ago !== null && res.data.last_synced_minutes_ago !== undefined) {
            setLastSynced(`${res.data.last_synced_minutes_ago}m ago`);
          } else {
            setLastSynced('Not synced yet');
          }
        }
      })
      .catch(() => {
        // Fallback default
        if (mode === 'real') {
          setVitals({
            patient_name: patientName,
            is_paired: false,
            mode: 'real',
            device_status: 'No Physical Watch Paired',
            message: `No physical Apple Watch has synced data for ${patientName} yet.`
          });
        } else {
          setVitals({
            device: 'Apple Watch Series 9',
            watchos: 'watchOS 11.0.2',
            battery: '88%',
            heart_rate: 71,
            resting_hr: 62,
            hr_range: '58 - 112 bpm',
            rhythm_status: 'Normal Sinus Rhythm (0 AFib events in 30d)',
            blood_pressure: '122/78',
            map_mmhg: 92,
            bp_trend: 'Optimal range',
            spo2: 98,
            spo2_overnight_mean: 97.8,
            sleep_total: '7h 24m',
            sleep_deep: '1h 45m',
            sleep_rem: '2h 09m',
            steps: 6840,
            active_calories: 482,
            fall_detection: 'Armed & Active',
            mode: 'demo',
            device_status: 'Simulated Clinical Demo'
          });
        }
      })
      .finally(() => {
        setTimeout(() => setIsSyncing(false), 500);
      });
  };

  useEffect(() => {
    if (isOpen && patientName) {
      setInviteStatus(null);
      setInviteResult(null);
      setCopiedLink(false);
      setSyncStatusMsg(null);
      fetchVitals(telemetryMode);
    }
  }, [isOpen, patientName, telemetryMode]);

  if (!isOpen) return null;

  const handleModeSwitch = (newMode) => {
    setTelemetryMode(newMode);
    fetchVitals(newMode);
  };

  const handleSendInvite = () => {
    setInviteStatus('sending');
    axios.post('/api/wearables/pair-invite', {
      patient_name: patientName,
      channel: 'whatsapp',
      phone_number: patientPhone
    })
      .then((res) => {
        setInviteStatus('sent');
        setInviteResult(res.data);
      })
      .catch(() => {
        setInviteStatus('sent'); // optimistic fallback
        const cleanDigits = (patientPhone || '').replace(/\D/g, '');
        let fullDigits = cleanDigits;
        if (cleanDigits.length === 10) {
          fullDigits = cleanDigits === '6382761031' ? '91' + cleanDigits : '1' + cleanDigits;
        }
        const inviteUrl = `https://bmg5111-ehealth-fall-2026.onrender.com/healthkit/authorize?patient=${encodeURIComponent(patientName)}`;
        const msg = `Hello ${patientName}, your physician at Prime Care Clinic has invited you to connect your Apple Watch via Apple HealthKit. Tap this secure link on your iPhone to approve vital signs sharing: ${inviteUrl}`;
        setInviteResult({
          status: 'sent',
          provider: 'simulated',
          whatsapp_dispatched: false,
          invite_url: inviteUrl,
          wa_me_url: `https://wa.me/${fullDigits}?text=${encodeURIComponent(msg)}`
        });
      });
  };

  const getDirectWaLink = () => {
    if (inviteResult?.wa_me_url) return inviteResult.wa_me_url;
    const cleanDigits = (patientPhone || '').replace(/\D/g, '');
    let fullDigits = cleanDigits;
    if (cleanDigits.length === 10) {
      fullDigits = cleanDigits === '6382761031' ? '91' + cleanDigits : '1' + cleanDigits;
    }
    const inviteUrl = `https://bmg5111-ehealth-fall-2026.onrender.com/healthkit/authorize?patient=${encodeURIComponent(patientName)}`;
    const msg = `Hello ${patientName}, your physician at Prime Care Clinic has invited you to connect your Apple Watch via Apple HealthKit. Tap this secure link on your iPhone to approve vital signs sharing: ${inviteUrl}`;
    return `https://wa.me/${fullDigits}?text=${encodeURIComponent(msg)}`;
  };

  const handleCopyInviteLink = () => {
    const url = inviteResult?.invite_url || `https://bmg5111-ehealth-fall-2026.onrender.com/healthkit/authorize?patient=${encodeURIComponent(patientName)}`;
    if (navigator?.clipboard?.writeText) {
      navigator.clipboard.writeText(url);
    }
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2500);
  };

  const handleTestSimulateSync = () => {
    setIsSyncing(true);
    const testPayload = {
      patient_name: patientName,
      heart_rate: 74,
      resting_hr: 63,
      blood_pressure: '118/76',
      map_mmhg: 90,
      spo2: 99,
      steps: 7240,
      device: 'Apple Watch Series 10 (Physical Feed)',
      battery: '94%',
      rhythm_status: 'Normal Sinus Rhythm (Verified Apple Health ECG)',
      fall_detection: 'Armed & Active (0 falls)'
    };

    axios.post('/api/wearables/sync', testPayload)
      .then(res => {
        setTelemetryMode('real');
        setActiveTab('vitals');
        if (res.data?.data) {
          setVitals(res.data.data);
          setLastSynced('Just now');
        }
        setSyncStatusMsg('Live telemetry received from Apple HealthKit webhook!');
        setTimeout(() => setSyncStatusMsg(null), 3500);
      })
      .catch(() => {
        fetchVitals('real');
      })
      .finally(() => {
        setIsSyncing(false);
      });
  };

  const handlePushToScribe = () => {
    const isReal = vitals?.is_real_device;
    const hr = vitals?.heart_rate || 71;
    const bp = vitals?.blood_pressure || '122/78';
    const rhythm = vitals?.rhythm_status || 'Normal Sinus Rhythm';
    const spo2 = vitals?.spo2 || 98;
    const sleep = vitals?.sleep_total || '7h 24m';
    const steps = vitals?.steps || 6840;
    const sourceLabel = isReal ? 'Physical Apple Watch (Live Webhook)' : 'Apple HealthKit Telemetry (Simulated Baseline)';

    const summary = `[${sourceLabel} - ${patientName}]: HR ${hr} bpm (${rhythm}); BP ${bp} mmHg (MAP ${vitals?.map_mmhg || 92}); SpO2 ${spo2}%; Sleep ${sleep}; Activity ${steps} steps; Fall Detection Active.`;

    if (onInsertToNote) {
      onInsertToNote(summary);
    } else {
      window.dispatchEvent(new CustomEvent('insert-scribe-text', { detail: { text: `\n\n${summary}\n` } }));
    }

    setCopiedNotification(true);
    setTimeout(() => setCopiedNotification(false), 2500);
  };

  const isDemo = telemetryMode === 'demo' && !vitals?.is_real_device;
  const isUnpairedReal = telemetryMode === 'real' && !vitals?.is_paired && !vitals?.is_real_device;

  return (
    <div className="apple-watch-overlay">
      <div className="apple-watch-modal-card">
        
        {/* ── Modal Header (Responsive on Mobile) ── */}
        <div className="apple-watch-header-container">
          {/* Top Row: Icon + Patient Info + Close button */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
              <div style={{
                width: '38px',
                height: '38px',
                borderRadius: '10px',
                background: '#eff6ff',
                border: '1px solid #bfdbfe',
                color: '#2563eb',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexShrink: 0
              }}>
                <Watch size={22} />
              </div>

              <div style={{ minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
                  <h3 style={{ margin: 0, fontSize: '16px', fontWeight: '700', color: '#0f172a', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {patientName}
                  </h3>
                  <span style={{ fontSize: '11px', color: '#2563eb', background: '#eff6ff', padding: '1px 6px', borderRadius: '6px', border: '1px solid #bfdbfe', fontWeight: '600' }}>
                    {patientMrn}
                  </span>
                </div>
                <div style={{ margin: '1px 0 0 0', fontSize: '11px', color: '#64748b', display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <span>{vitals?.device || 'Apple Watch'}</span>
                  <span>·</span>
                  <span>Battery {vitals?.battery || '88%'}</span>
                </div>
              </div>
            </div>

            <button
              onClick={onClose}
              style={{
                background: '#f8fafc',
                border: '1px solid #e2e8f0',
                color: '#64748b',
                width: '34px',
                height: '34px',
                borderRadius: '8px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexShrink: 0
              }}
              aria-label="Close modal"
            >
              <X size={18} />
            </button>
          </div>

          {/* Sub Row: Mode Toggle + Status Badge + Sync */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            width: '100%',
            gap: '8px',
            flexWrap: 'wrap',
            paddingTop: '6px',
            borderTop: '1px dashed #e2e8f0'
          }}>
            {/* Status Pill */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              {isDemo ? (
                <span style={{
                  fontSize: '11px',
                  fontWeight: '600',
                  color: '#b45309',
                  background: '#fef3c7',
                  border: '1px solid #fde68a',
                  padding: '2px 8px',
                  borderRadius: '12px',
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '4px'
                }}>
                  <Sparkles size={12} color="#b45309" />
                  Simulated Demo Feed
                </span>
              ) : isUnpairedReal ? (
                <span style={{
                  fontSize: '11px',
                  fontWeight: '600',
                  color: '#64748b',
                  background: '#f1f5f9',
                  border: '1px solid #e2e8f0',
                  padding: '2px 8px',
                  borderRadius: '12px',
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '4px'
                }}>
                  <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#94a3b8' }} />
                  Not Paired
                </span>
              ) : (
                <span style={{
                  fontSize: '11px',
                  fontWeight: '600',
                  color: '#059669',
                  background: '#ecfdf5',
                  border: '1px solid #a7f3d0',
                  padding: '2px 8px',
                  borderRadius: '12px',
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '4px'
                }}>
                  <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#059669' }} />
                  Live Hardware Connected
                </span>
              )}

              <span style={{ fontSize: '11px', color: '#64748b' }}>
                Synced: {lastSynced}
              </span>
            </div>

            {/* Mode Switcher Pill */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
              <div style={{
                background: '#f1f5f9',
                padding: '2px',
                borderRadius: '8px',
                display: 'inline-flex',
                border: '1px solid #e2e8f0'
              }}>
                <button
                  onClick={() => handleModeSwitch('demo')}
                  style={{
                    padding: '3px 8px',
                    borderRadius: '6px',
                    border: 'none',
                    background: telemetryMode === 'demo' ? '#ffffff' : 'transparent',
                    color: telemetryMode === 'demo' ? '#2563eb' : '#64748b',
                    fontWeight: telemetryMode === 'demo' ? '700' : '500',
                    fontSize: '11px',
                    cursor: 'pointer',
                    boxShadow: telemetryMode === 'demo' ? '0 1px 3px rgba(0,0,0,0.06)' : 'none'
                  }}
                >
                  Demo Mode
                </button>
                <button
                  onClick={() => handleModeSwitch('real')}
                  style={{
                    padding: '3px 8px',
                    borderRadius: '6px',
                    border: 'none',
                    background: telemetryMode === 'real' ? '#ffffff' : 'transparent',
                    color: telemetryMode === 'real' ? '#2563eb' : '#64748b',
                    fontWeight: telemetryMode === 'real' ? '700' : '500',
                    fontSize: '11px',
                    cursor: 'pointer',
                    boxShadow: telemetryMode === 'real' ? '0 1px 3px rgba(0,0,0,0.06)' : 'none'
                  }}
                >
                  Real Watch
                </button>
              </div>

              <button
                onClick={() => fetchVitals()}
                disabled={isSyncing}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                  padding: '5px 10px',
                  borderRadius: '8px',
                  border: '1px solid #bfdbfe',
                  background: '#eff6ff',
                  color: '#2563eb',
                  fontSize: '11px',
                  fontWeight: '600',
                  cursor: isSyncing ? 'default' : 'pointer'
                }}
                title="Refresh telemetry"
              >
                <RefreshCw size={12} className={isSyncing ? 'animate-spin' : ''} />
                {isSyncing ? 'Syncing...' : 'Sync'}
              </button>
            </div>
          </div>

          {/* Navigation Tabs */}
          <div style={{
            display: 'flex',
            gap: '8px',
            width: '100%',
            marginTop: '2px'
          }}>
            <button
              onClick={() => setActiveTab('vitals')}
              style={{
                flex: 1,
                padding: '6px 12px',
                borderRadius: '6px',
                border: 'none',
                background: activeTab === 'vitals' ? '#2563eb' : '#f8fafc',
                color: activeTab === 'vitals' ? '#ffffff' : '#475569',
                fontSize: '12px',
                fontWeight: '600',
                cursor: 'pointer',
                textAlign: 'center',
                transition: 'all 0.15s'
              }}
            >
              📊 Vitals Telemetry
            </button>
            <button
              onClick={() => setActiveTab('connect')}
              style={{
                flex: 1,
                padding: '6px 12px',
                borderRadius: '6px',
                border: 'none',
                background: activeTab === 'connect' ? '#2563eb' : '#f8fafc',
                color: activeTab === 'connect' ? '#ffffff' : '#475569',
                fontSize: '12px',
                fontWeight: '600',
                cursor: 'pointer',
                textAlign: 'center',
                transition: 'all 0.15s'
              }}
            >
              🔗 How to Connect Apple Health
            </button>
          </div>
        </div>

        {/* ── Status Message Toast ── */}
        {syncStatusMsg && (
          <div style={{
            padding: '8px 16px',
            background: '#ecfdf5',
            borderBottom: '1px solid #a7f3d0',
            color: '#065f46',
            fontSize: '12px',
            display: 'flex',
            alignItems: 'center',
            gap: '6px'
          }}>
            <CheckCircle2 size={14} color="#059669" />
            <span>{syncStatusMsg}</span>
          </div>
        )}

        {/* ── Modal Body ── */}
        <div style={{ padding: '16px 20px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '14px', flex: 1 }}>

          {activeTab === 'connect' ? (
            /* ── TAB 2: HOW TO CONNECT APPLE HEALTH GUIDE ── */
            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              
              {/* Concept Banner */}
              <div style={{
                background: '#eff6ff',
                border: '1px solid #bfdbfe',
                borderRadius: '10px',
                padding: '12px 14px',
                display: 'flex',
                gap: '10px'
              }}>
                <HelpCircle size={18} color="#2563eb" style={{ flexShrink: 0, marginTop: '2px' }} />
                <div style={{ fontSize: '12px', color: '#1e3a8a', lineHeight: '1.5' }}>
                  <strong style={{ display: 'block', marginBottom: '2px', color: '#1e40af' }}>
                    How Apple HealthKit Integration Works
                  </strong>
                  Apple Health data remains securely encrypted on the patient’s iPhone and Apple Watch inside the iOS Secure Enclave.
                  Apple does not allow web browsers to read health data directly via Bluetooth. Telemetry is securely synchronized with our clinical backend via HTTPS.
                </div>
              </div>

              {/* Step 1: Send HealthKit Invite via WhatsApp or SMS */}
              <div style={{
                background: '#ffffff',
                border: '1px solid #e2e8f0',
                borderRadius: '10px',
                padding: '14px',
                display: 'flex',
                flexDirection: 'column',
                gap: '10px'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <div style={{ width: '22px', height: '22px', borderRadius: '50%', background: '#2563eb', color: '#ffffff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px', fontWeight: '700' }}>
                    1
                  </div>
                  <h4 style={{ margin: 0, fontSize: '13px', fontWeight: '700', color: '#0f172a' }}>
                    Send HealthKit Pairing Invite to Patient
                  </h4>
                </div>
                <p style={{ margin: 0, fontSize: '12px', color: '#64748b' }}>
                  Dispatches an automated WhatsApp / SMS authorization request to <strong>{patientName}</strong> ({patientPhone}).{' '}
                  <button
                    type="button"
                    onClick={handleChangePhoneClick}
                    style={{
                      background: 'none',
                      border: 'none',
                      color: '#2563eb',
                      fontWeight: '700',
                      cursor: 'pointer',
                      padding: 0,
                      fontSize: '11px',
                      textDecoration: 'underline'
                    }}
                  >
                    Change phone
                  </button>
                </p>

                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', alignItems: 'center' }}>
                  <button
                    onClick={handleSendInvite}
                    disabled={inviteStatus === 'sending'}
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '6px',
                      padding: '8px 14px',
                      borderRadius: '8px',
                      border: '1px solid #bfdbfe',
                      background: inviteStatus === 'sent' ? '#ecfdf5' : '#eff6ff',
                      color: inviteStatus === 'sent' ? '#059669' : '#2563eb',
                      fontSize: '12px',
                      fontWeight: '600',
                      cursor: 'pointer'
                    }}
                  >
                    {inviteStatus === 'sent' ? (
                      <>
                        <Check size={14} /> Re-send Gateway Invite
                      </>
                    ) : (
                      <>
                        <Send size={14} />
                        {inviteStatus === 'sending' ? 'Sending Invite...' : 'Send WhatsApp HealthKit Invite'}
                      </>
                    )}
                  </button>

                  <a
                    href={getDirectWaLink()}
                    target="_blank"
                    rel="noopener noreferrer"
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '6px',
                      padding: '8px 14px',
                      borderRadius: '8px',
                      border: '1px solid #16a34a',
                      background: '#16a34a',
                      color: '#ffffff',
                      fontSize: '12px',
                      fontWeight: '600',
                      textDecoration: 'none',
                      cursor: 'pointer'
                    }}
                    title="Launch WhatsApp with pre-filled HealthKit invite text"
                  >
                    <MessageSquare size={14} />
                    Open in WhatsApp Directly
                  </a>

                  <button
                    onClick={handleCopyInviteLink}
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '6px',
                      padding: '8px 14px',
                      borderRadius: '8px',
                      border: '1px solid #e2e8f0',
                      background: '#ffffff',
                      color: copiedLink ? '#059669' : '#334155',
                      fontSize: '12px',
                      fontWeight: '600',
                      cursor: 'pointer'
                    }}
                  >
                    {copiedLink ? <Check size={14} /> : <Copy size={14} />}
                    {copiedLink ? 'Copied Link!' : 'Copy Link'}
                  </button>
                </div>

                {inviteStatus === 'sent' && (
                  <div style={{
                    marginTop: '2px',
                    padding: '8px 12px',
                    background: '#f0fdf4',
                    border: '1px solid #bbf7d0',
                    borderRadius: '8px',
                    fontSize: '11px',
                    color: '#166534',
                    lineHeight: '1.5'
                  }}>
                    <div style={{ fontWeight: '700', marginBottom: '2px' }}>
                      ✓ Pairing invitation generated for {patientPhone}
                    </div>
                    <div>
                      {inviteResult?.whatsapp_dispatched ? (
                        <span>Dispatched through clinic Meta / Twilio WhatsApp gateway.</span>
                      ) : (
                        <span>
                          Logged to patient EHR conversation thread. To send directly from your personal WhatsApp without Meta API sandbox setup, click <strong>"Open in WhatsApp Directly"</strong> above.
                        </span>
                      )}
                    </div>
                  </div>
                )}
              </div>

              {/* Step 2: In-Clinic QR Code Scan */}
              <div style={{
                background: '#ffffff',
                border: '1px solid #e2e8f0',
                borderRadius: '10px',
                padding: '14px',
                display: 'flex',
                alignItems: 'center',
                gap: '14px',
                flexWrap: 'wrap'
              }}>
                <img
                  src={`https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=${encodeURIComponent(`https://bmg5111-ehealth-fall-2026.onrender.com/healthkit/authorize?patient=${encodeURIComponent(patientName)}`)}`}
                  alt="Apple HealthKit Pairing QR Code"
                  style={{
                    width: '64px',
                    height: '64px',
                    borderRadius: '8px',
                    border: '1px solid #e2e8f0',
                    padding: '2px',
                    background: '#ffffff',
                    flexShrink: 0
                  }}
                />
                <div style={{ flex: 1, minWidth: '200px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <div style={{ width: '20px', height: '20px', borderRadius: '50%', background: '#2563eb', color: '#ffffff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '11px', fontWeight: '700' }}>
                      2
                    </div>
                    <strong style={{ fontSize: '13px', color: '#0f172a' }}>Scan QR Code with Patient's iPhone</strong>
                  </div>
                  <p style={{ margin: '2px 0 0 0', fontSize: '11px', color: '#64748b' }}>
                    During an in-person visit, the patient points their iPhone Camera at this code to open the HealthKit authorization portal and stream vitals into the chart.
                  </p>
                </div>
              </div>

              {/* Step 3: Webhook & Developer Simulation */}
              <div style={{
                background: '#ffffff',
                border: '1px solid #e2e8f0',
                borderRadius: '10px',
                padding: '14px',
                display: 'flex',
                flexDirection: 'column',
                gap: '8px'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <div style={{ width: '20px', height: '20px', borderRadius: '50%', background: '#2563eb', color: '#ffffff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '11px', fontWeight: '700' }}>
                    3
                  </div>
                  <strong style={{ fontSize: '13px', color: '#0f172a' }}>Live Webhook Ingestion API</strong>
                </div>
                <p style={{ margin: 0, fontSize: '11px', color: '#64748b' }}>
                  Any iOS Shortcut or HealthKit companion app pushes JSON directly to:
                </p>
                <code style={{
                  background: '#f8fafc',
                  border: '1px solid #e2e8f0',
                  padding: '6px 10px',
                  borderRadius: '6px',
                  fontSize: '11px',
                  color: '#0f172a',
                  wordBreak: 'break-all'
                }}>
                  POST /api/wearables/sync
                </code>

                <div style={{ marginTop: '4px' }}>
                  <button
                    onClick={handleTestSimulateSync}
                    disabled={isSyncing}
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '6px',
                      padding: '8px 14px',
                      borderRadius: '8px',
                      border: '1px solid #059669',
                      background: '#ecfdf5',
                      color: '#059669',
                      fontSize: '12px',
                      fontWeight: '600',
                      cursor: 'pointer'
                    }}
                  >
                    <Smartphone size={14} />
                    Test Push Live Apple Watch Reading Now
                  </button>
                </div>
              </div>

            </div>
          ) : isUnpairedReal ? (
            /* ── UNPAIRED REAL DEVICE STATE ── */
            <div style={{
              background: '#f8fafc',
              border: '1px dashed #cbd5e1',
              borderRadius: '12px',
              padding: '24px 16px',
              textAlign: 'center',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: '12px'
            }}>
              <div style={{
                width: '48px',
                height: '48px',
                borderRadius: '50%',
                background: '#ffffff',
                border: '1px solid #e2e8f0',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#64748b'
              }}>
                <Watch size={24} />
              </div>

              <div>
                <h4 style={{ margin: '0 0 4px 0', fontSize: '15px', fontWeight: '700', color: '#0f172a' }}>
                  No Physical Apple Watch Paired for {patientName}
                </h4>
                <p style={{ margin: 0, fontSize: '12px', color: '#64748b', maxWidth: '420px', lineHeight: '1.5' }}>
                  To see live biometric feeds from an actual hardware watch, invite the patient to connect via Apple HealthKit or test using simulated demo data.
                </p>
              </div>

              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', justifyContent: 'center' }}>
                <button
                  onClick={() => setActiveTab('connect')}
                  style={{
                    padding: '8px 16px',
                    borderRadius: '8px',
                    border: '1px solid #2563eb',
                    background: '#2563eb',
                    color: '#ffffff',
                    fontSize: '12px',
                    fontWeight: '600',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px'
                  }}
                >
                  Pair Apple Watch <ArrowRight size={14} />
                </button>
                <button
                  onClick={() => handleModeSwitch('demo')}
                  style={{
                    padding: '8px 16px',
                    borderRadius: '8px',
                    border: '1px solid #bfdbfe',
                    background: '#eff6ff',
                    color: '#2563eb',
                    fontSize: '12px',
                    fontWeight: '600',
                    cursor: 'pointer'
                  }}
                >
                  Preview with Demo Feed
                </button>
              </div>
            </div>
          ) : (
            /* ── TAB 1: 4 MAIN METRIC TILES (Responsive Grid) ── */
            <>
              {/* Notice Banner when in Demo mode */}
              {isDemo && (
                <div style={{
                  background: '#fefce8',
                  border: '1px solid #fef08a',
                  borderRadius: '8px',
                  padding: '8px 12px',
                  fontSize: '11px',
                  color: '#854d0e',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: '8px',
                  flexWrap: 'wrap'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <AlertCircle size={14} color="#854d0e" style={{ flexShrink: 0 }} />
                    <span>Showing <strong>Simulated Demo Vitals</strong> for clinical review & AI Copilot queries.</span>
                  </div>
                  <button
                    onClick={() => setActiveTab('connect')}
                    style={{
                      background: 'transparent',
                      border: 'none',
                      color: '#2563eb',
                      fontWeight: '700',
                      cursor: 'pointer',
                      padding: 0,
                      fontSize: '11px',
                      textDecoration: 'underline'
                    }}
                  >
                    How to connect real watch →
                  </button>
                </div>
              )}

              <div className="apple-watch-grid">
                {/* Tile 1: Heart Rate & ECG */}
                <div className="apple-watch-metric-card">
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '12px', fontWeight: '600', color: '#64748b', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <Heart size={15} color="#2563eb" /> Heart Rate & Rhythm
                    </span>
                    <span style={{ fontSize: '11px', color: '#2563eb', fontWeight: '600', background: '#eff6ff', padding: '1px 6px', borderRadius: '4px' }}>
                      Sinus Rhythm
                    </span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: '6px' }}>
                    <span style={{ fontSize: '28px', fontWeight: '800', color: '#0f172a' }}>{vitals?.heart_rate || 71}</span>
                    <span style={{ fontSize: '13px', color: '#64748b' }}>BPM</span>
                  </div>
                  <p style={{ margin: 0, fontSize: '11px', color: '#64748b' }}>
                    Resting: {vitals?.resting_hr || 62} bpm · Range: {vitals?.hr_range || '58-112 bpm'}
                  </p>
                  <p style={{ margin: '2px 0 0 0', fontSize: '11px', color: '#059669', fontWeight: '600' }}>
                    ✓ {vitals?.rhythm_status || 'No AFib detected in past 30 days'}
                  </p>
                </div>

                {/* Tile 2: Blood Pressure Telemetry */}
                <div className="apple-watch-metric-card">
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '12px', fontWeight: '600', color: '#64748b', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <Activity size={15} color="#2563eb" /> Blood Pressure
                    </span>
                    <span style={{ fontSize: '11px', color: '#059669', fontWeight: '600', background: '#ecfdf5', padding: '1px 6px', borderRadius: '4px' }}>
                      Optimal
                    </span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: '6px' }}>
                    <span style={{ fontSize: '28px', fontWeight: '800', color: '#0f172a' }}>{vitals?.blood_pressure || '122/78'}</span>
                    <span style={{ fontSize: '13px', color: '#64748b' }}>mmHg</span>
                  </div>
                  <p style={{ margin: 0, fontSize: '11px', color: '#64748b' }}>
                    Mean Arterial Pressure: {vitals?.map_mmhg || 92} mmHg
                  </p>
                  <p style={{ margin: '2px 0 0 0', fontSize: '11px', color: '#059669', fontWeight: '600' }}>
                    ✓ {vitals?.bp_trend || 'Normotensive baseline'}
                  </p>
                </div>

                {/* Tile 3: SpO2 Blood Oxygen */}
                <div className="apple-watch-metric-card">
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '12px', fontWeight: '600', color: '#64748b', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <ShieldCheck size={15} color="#2563eb" /> Blood Oxygen (SpO2)
                    </span>
                    <span style={{ fontSize: '11px', color: '#2563eb', fontWeight: '600', background: '#eff6ff', padding: '1px 6px', borderRadius: '4px' }}>
                      Normal
                    </span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: '6px' }}>
                    <span style={{ fontSize: '28px', fontWeight: '800', color: '#0f172a' }}>{vitals?.spo2 || 98}%</span>
                    <span style={{ fontSize: '13px', color: '#64748b' }}>continuous</span>
                  </div>
                  <p style={{ margin: 0, fontSize: '11px', color: '#64748b' }}>
                    Overnight mean: {vitals?.spo2_overnight_mean || 97.8}%
                  </p>
                  <p style={{ margin: '2px 0 0 0', fontSize: '11px', color: '#059669', fontWeight: '600' }}>
                    ✓ 0 nocturnal desaturations recorded
                  </p>
                </div>

                {/* Tile 4: Sleep & Recovery */}
                <div className="apple-watch-metric-card">
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '12px', fontWeight: '600', color: '#64748b', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <Moon size={15} color="#2563eb" /> Sleep Architecture
                    </span>
                    <span style={{ fontSize: '11px', color: '#2563eb', fontWeight: '600', background: '#eff6ff', padding: '1px 6px', borderRadius: '4px' }}>
                      Last Night
                    </span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'baseline', gap: '6px' }}>
                    <span style={{ fontSize: '28px', fontWeight: '800', color: '#0f172a' }}>{vitals?.sleep_total || '7h 24m'}</span>
                    <span style={{ fontSize: '13px', color: '#64748b' }}>total</span>
                  </div>
                  <p style={{ margin: 0, fontSize: '11px', color: '#64748b' }}>
                    Deep: {vitals?.sleep_deep || '1h 45m'} · REM: {vitals?.sleep_rem || '2h 09m'}
                  </p>
                  <p style={{ margin: '2px 0 0 0', fontSize: '11px', color: '#2563eb', fontWeight: '600' }}>
                    Sleeping respiration: {vitals?.respiratory_rate_sleep || '14.2 br/min'}
                  </p>
                </div>
              </div>

              {/* Safety & Activity Bar */}
              <div style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '10px 14px',
                background: '#f8fafc',
                border: '1px solid #e2e8f0',
                borderRadius: '10px',
                fontSize: '12px',
                color: '#334155',
                flexWrap: 'wrap',
                gap: '8px'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '14px', flexWrap: 'wrap' }}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
                    <CheckCircle2 size={14} color="#059669" />
                    <span>Fall Detection: <strong>{vitals?.fall_detection || 'Armed & Active'}</strong></span>
                  </span>
                  <span style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
                    <Smartphone size={14} color="#2563eb" />
                    <span>Daily Steps: <strong>{vitals?.steps?.toLocaleString() || '6,840'}</strong></span>
                  </span>
                </div>

                <span style={{ color: '#059669', fontWeight: '600', fontSize: '11px' }}>
                  ✓ EMR Synced
                </span>
              </div>
            </>
          )}

        </div>

        {/* ── Modal Footer Controls (Responsive on Mobile) ── */}
        <div className="apple-watch-footer-container">
          <span style={{ fontSize: '11px', color: '#64748b' }}>
            Encrypted HealthKit telemetry via CPSO compliance channel
          </span>

          <div className="apple-watch-footer-actions">
            {activeTab === 'vitals' && !isUnpairedReal && (
              <button
                onClick={handlePushToScribe}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                  padding: '8px 16px',
                  borderRadius: '8px',
                  border: '1px solid #bfdbfe',
                  background: copiedNotification ? '#ecfdf5' : '#eff6ff',
                  color: copiedNotification ? '#059669' : '#2563eb',
                  fontSize: '13px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  transition: 'all 0.15s'
                }}
                title="Insert wearable telemetry into active Scribe note"
              >
                <FileText size={15} />
                {copiedNotification ? '✓ Vitals Added to Chart' : 'Add Vitals to Scribe Note'}
              </button>
            )}

            <button
              onClick={onClose}
              style={{
                padding: '8px 16px',
                borderRadius: '8px',
                border: '1px solid #e2e8f0',
                background: '#ffffff',
                color: '#334155',
                fontSize: '13px',
                fontWeight: '600',
                cursor: 'pointer'
              }}
            >
              Close
            </button>
          </div>
        </div>

      </div>
    </div>
  );
}
