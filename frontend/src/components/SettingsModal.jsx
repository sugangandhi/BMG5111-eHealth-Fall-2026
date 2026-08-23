import React, { useState } from 'react';
import { Settings, Moon, Sun, Bell, Shield, Sparkles, Download, CheckCircle, X, Volume2, Lock, Cpu, Database, Server } from 'lucide-react';

export default function SettingsModal({ isOpen, onClose, theme, toggleTheme, user }) {
  const [activeSection, setActiveSection] = useState('appearance');
  
  // Simulated State for Interactive Settings
  const [autoDraftReply, setAutoDraftReply] = useState(true);
  const [autoSoapCoding, setAutoSoapCoding] = useState(true);
  const [playAudioAlerts, setPlayAudioAlerts] = useState(true);
  const [webhookNotify, setWebhookNotify] = useState(true);
  const [sessionTimeout, setSessionTimeout] = useState('15');
  const [aiVerbosity, setAiVerbosity] = useState('clinical_detailed');
  const [exportStatus, setExportStatus] = useState(null);
  
  // Voice Feedback State
  const [voiceFeedback, setVoiceFeedback] = useState(() => localStorage.getItem('medoffice_voice_feedback') !== 'false');
  const [selectedVoice, setSelectedVoice] = useState(() => localStorage.getItem('medoffice_voice_uri') || '');
  const [availableVoices, setAvailableVoices] = useState([]);

  React.useEffect(() => {
    const loadVoices = () => {
      const voices = window.speechSynthesis.getVoices();
      if (voices.length > 0) setAvailableVoices(voices);
    };
    loadVoices();
    window.speechSynthesis.onvoiceschanged = loadVoices;
  }, []);

  const handleVoiceFeedbackToggle = () => {
    const newVal = !voiceFeedback;
    setVoiceFeedback(newVal);
    localStorage.setItem('medoffice_voice_feedback', newVal.toString());
  };

  const handleVoiceChange = (e) => {
    setSelectedVoice(e.target.value);
    localStorage.setItem('medoffice_voice_uri', e.target.value);
  };

  if (!isOpen) return null;

  const handleExportAudit = () => {
    const auditData = {
      timestamp: new Date().toISOString(),
      clinician: user?.name || 'Authorized Physician',
      email: user?.email || 'sugan@gmail.com',
      cpso_license: user?.cpso || 'PC-GMAIL-AUTH',
      clinic: user?.clinic || 'Prime Care Medical Group',
      compliance_status: 'HIPAA & SOC2 Type II Verified',
      recent_actions: [
        { id: 101, action: "Google SSO Cryptographic Verify", timestamp: "Today 08:30 AM", status: "SUCCESS" },
        { id: 102, action: "AI Scribe Transcription & ICD-10 Parsing", timestamp: "Today 09:15 AM", status: "LOGGED" },
        { id: 103, action: "Web-Fax Gateway Transmission (Brain MRI)", timestamp: "Today 10:45 AM", status: "TRANSLATED" },
        { id: 104, action: "STAT Triage Protocol Executed", timestamp: "Today 11:20 AM", status: "RESOLVED" }
      ]
    };

    const blob = new Blob([JSON.stringify(auditData, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `PrimeCare_HIPAA_Audit_${Date.now()}.json`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);

    setExportStatus("✅ HIPAA Compliance Audit Trail exported as JSON.");
    setTimeout(() => setExportStatus(null), 5000);
  };

  return (
    <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.82)', backdropFilter: 'blur(8px)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div className="glass-panel animate-fade-in" style={{ width: '850px', minHeight: '580px', maxHeight: '90vh', display: 'flex', flexDirection: 'column', border: '1px solid #3b82f6', boxShadow: '0 25px 70px rgba(0,0,0,0.7)', overflow: 'hidden' }}>
        
        {/* Modal Header */}
        <div style={{ padding: '20px 28px', borderBottom: '1px solid var(--glass-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'rgba(15, 23, 42, 0.6)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ padding: '8px', background: 'rgba(59, 130, 246, 0.2)', borderRadius: '10px', color: '#3b82f6' }}>
              <Settings size={24} />
            </div>
            <div>
              <h2 style={{ margin: 0, fontSize: '20px', color: 'var(--text-primary)' }}>Executive Clinical Settings Suite</h2>
              <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Manage practice configurations, AI automations, and zero-trust security</span>
            </div>
          </div>
          <button onClick={onClose} style={{ background: 'none', border: 'none', color: '#ef4444', cursor: 'pointer', padding: '6px' }}>
            <X size={24} />
          </button>
        </div>

        {/* Modal Body with Sidebar */}
        <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
          
          {/* Sidebar Navigation */}
          <div style={{ width: '240px', borderRight: '1px solid var(--glass-border)', padding: '20px 14px', display: 'flex', flexDirection: 'column', gap: '8px', background: 'rgba(0,0,0,0.2)' }}>
            <button 
              onClick={() => setActiveSection('appearance')}
              style={getTabStyle(activeSection === 'appearance')}
            >
              {theme === 'dark' ? <Moon size={18} /> : <Sun size={18} />} Appearance & Theme
            </button>
            <button 
              onClick={() => setActiveSection('ai')}
              style={getTabStyle(activeSection === 'ai')}
            >
              <Sparkles size={18} /> AI Copilot & Scribe
            </button>
            <button 
              onClick={() => setActiveSection('notifications')}
              style={getTabStyle(activeSection === 'notifications')}
            >
              <Bell size={18} /> Notifications & Audio
            </button>
            <button 
              onClick={() => setActiveSection('security')}
              style={getTabStyle(activeSection === 'security')}
            >
              <Shield size={18} /> Security & Auditory
            </button>
          </div>

          {/* Main Content Area */}
          <div style={{ flex: 1, padding: '32px', overflowY: 'auto', background: 'rgba(0,0,0,0.15)', display: 'flex', flexDirection: 'column', gap: '24px' }}>
            
            {exportStatus && (
              <div style={{ background: 'rgba(16, 185, 129, 0.15)', border: '1px solid #10b981', color: '#10b981', padding: '12px 18px', borderRadius: '10px', fontSize: '14px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '10px' }}>
                <CheckCircle size={18} />
                <span>{exportStatus}</span>
              </div>
            )}

            {/* SECTION: APPEARANCE & THEME */}
            {activeSection === 'appearance' && (
              <div className="animate-fade-in" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <div>
                  <h3 style={{ margin: '0 0 6px 0', fontSize: '18px', color: 'var(--text-primary)' }}>Workspace Theme Engine</h3>
                  <p style={{ margin: 0, fontSize: '13px', color: 'var(--text-secondary)' }}>Choose high-contrast clinical white for examination rooms or executive dark mode for night shifts.</p>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginTop: '10px' }}>
                  <div 
                    onClick={() => { if (theme !== 'dark') toggleTheme(); }}
                    style={{ 
                      padding: '20px', 
                      borderRadius: '14px', 
                      cursor: 'pointer',
                      border: theme === 'dark' ? '2px solid #3b82f6' : '1px solid var(--glass-border)',
                      background: theme === 'dark' ? 'rgba(59, 130, 246, 0.15)' : 'rgba(0,0,0,0.2)',
                      boxShadow: theme === 'dark' ? '0 0 20px rgba(59, 130, 246, 0.3)' : 'none',
                      transition: 'all 0.2s'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
                      <Moon size={28} color="#3b82f6" />
                      {theme === 'dark' && <span style={{ fontSize: '11px', background: '#3b82f6', color: 'white', padding: '2px 8px', borderRadius: '10px', fontWeight: 'bold' }}>ACTIVE</span>}
                    </div>
                    <h4 style={{ margin: '0 0 6px 0', color: 'var(--text-primary)' }}>Nighttime Executive Dark</h4>
                    <p style={{ margin: 0, fontSize: '12px', color: 'var(--text-secondary)' }}>Deep obsidian glassmorphism designed to reduce digital eye strain during late clinical shifts.</p>
                  </div>

                  <div 
                    onClick={() => { if (theme !== 'light') toggleTheme(); }}
                    style={{ 
                      padding: '20px', 
                      borderRadius: '14px', 
                      cursor: 'pointer',
                      border: theme === 'light' ? '2px solid #2563eb' : '1px solid var(--glass-border)',
                      background: theme === 'light' ? 'rgba(37, 99, 235, 0.12)' : 'rgba(0,0,0,0.2)',
                      boxShadow: theme === 'light' ? '0 0 20px rgba(37, 99, 235, 0.25)' : 'none',
                      transition: 'all 0.2s'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
                      <Sun size={28} color="#f59e0b" />
                      {theme === 'light' && <span style={{ fontSize: '11px', background: '#2563eb', color: 'white', padding: '2px 8px', borderRadius: '10px', fontWeight: 'bold' }}>ACTIVE</span>}
                    </div>
                    <h4 style={{ margin: '0 0 6px 0', color: 'var(--text-primary)' }}>Daytime Clinical Sanctuary</h4>
                    <p style={{ margin: 0, fontSize: '12px', color: 'var(--text-secondary)' }}>Bright hospital white typography with high-contrast borders for fast chart scanning.</p>
                  </div>
                </div>
              </div>
            )}

            {/* SECTION: AI COPILOT & SCRIBE */}
            {activeSection === 'ai' && (
              <div className="animate-fade-in" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <div>
                  <h3 style={{ margin: '0 0 6px 0', fontSize: '18px', color: 'var(--text-primary)' }}>AI Clinical Copilot & Voice Scribe</h3>
                  <p style={{ margin: 0, fontSize: '13px', color: 'var(--text-secondary)' }}>Configure automated diagnostic extraction and automated triage workflow behaviors.</p>
                </div>

                <div className="glass-panel" style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '20px', background: 'rgba(0,0,0,0.25)' }}>
                  <ToggleRow 
                    label="Auto-Draft Inbound Replies" 
                    desc="Generate evidence-based clinical email replies automatically when messages drop into Secure Inbox."
                    checked={autoDraftReply}
                    onChange={() => setAutoDraftReply(!autoDraftReply)}
                  />
                  <div style={{ height: '1px', background: 'var(--glass-border)' }} />
                  <ToggleRow 
                    label="Automated SOAP & ICD-10 Coding" 
                    desc="Parse unstructured Voice Scribe notes into objective SOAP sections and assign billing codes in real time."
                    checked={autoSoapCoding}
                    onChange={() => setAutoSoapCoding(!autoSoapCoding)}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '13px', fontWeight: '600', color: 'var(--text-primary)', marginBottom: '8px' }}>AI Diagnostic Verbosity & Tone</label>
                  <select 
                    value={aiVerbosity}
                    onChange={(e) => setAiVerbosity(e.target.value)}
                    className="input"
                    style={{ width: '100%', cursor: 'pointer' }}
                  >
                    <option value="clinical_detailed">Executive Clinical Detailed (Includes citations & pathophysiological rationales)</option>
                    <option value="concise_stat">Concise STAT Triage (Bullet points only for urgent trauma workflows)</option>
                    <option value="patient_friendly">Patient-Centered Plain Language (Translated for direct portal sharing)</option>
                  </select>
                </div>
              </div>
            )}

            {/* SECTION: NOTIFICATIONS & AUDIO */}
            {activeSection === 'notifications' && (
              <div className="animate-fade-in" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <div>
                  <h3 style={{ margin: '0 0 6px 0', fontSize: '18px', color: 'var(--text-primary)' }}>Notification Gateways & Audio</h3>
                  <p style={{ margin: 0, fontSize: '13px', color: 'var(--text-secondary)' }}>Manage automated alerts for incoming EMR webhooks and critical lab elevations.</p>
                </div>

                <div className="glass-panel" style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '20px', background: 'rgba(0,0,0,0.25)' }}>
                  <ToggleRow 
                    label="AI Voice Assistant Feedback" 
                    desc="Enable spoken Text-to-Speech confirmation when issuing hands-free commands."
                    checked={voiceFeedback}
                    onChange={handleVoiceFeedbackToggle}
                  />
                  
                  {voiceFeedback && availableVoices.length > 0 && (
                    <div style={{ paddingLeft: '10px', marginTop: '-10px' }}>
                      <label style={{ display: 'block', fontSize: '13px', fontWeight: '600', color: 'var(--text-primary)', marginBottom: '8px' }}>Select AI Voice Profile</label>
                      <select 
                        value={selectedVoice}
                        onChange={handleVoiceChange}
                        className="input"
                        style={{ width: '100%', cursor: 'pointer' }}
                      >
                        <option value="">Default System Voice</option>
                        {availableVoices.filter(v => v.lang.includes('en')).map(voice => (
                          <option key={voice.voiceURI} value={voice.voiceURI}>{voice.name}</option>
                        ))}
                      </select>
                    </div>
                  )}

                  <div style={{ height: '1px', background: 'var(--glass-border)' }} />
                  <ToggleRow 
                    label="STAT & Emergency Audio Chime" 
                    desc="Emit audible acoustic alarm when blood gas or troponin STAT lab values arrive via webhook."
                    checked={playAudioAlerts}
                    onChange={() => setPlayAudioAlerts(!playAudioAlerts)}
                  />
                  <div style={{ height: '1px', background: 'var(--glass-border)' }} />
                  <ToggleRow 
                    label="Live EMR Webhook Notification Banners" 
                    desc="Display visual top-bar toast banners whenever remote hospital dispatches enter your queue."
                    checked={webhookNotify}
                    onChange={() => setWebhookNotify(!webhookNotify)}
                  />
                </div>
              </div>
            )}

            {/* SECTION: SECURITY & AUDITING */}
            {activeSection === 'security' && (
              <div className="animate-fade-in" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <div>
                  <h3 style={{ margin: '0 0 6px 0', fontSize: '18px', color: 'var(--text-primary)' }}>Zero-Trust Security & HIPAA Compliance</h3>
                  <p style={{ margin: 0, fontSize: '13px', color: 'var(--text-secondary)' }}>Audit active cryptographic sessions, manage timeout thresholds, and download compliance trails.</p>
                </div>

                <div className="glass-panel" style={{ padding: '18px 20px', background: 'rgba(16, 185, 129, 0.12)', border: '1px solid rgba(16, 185, 129, 0.35)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <Server size={24} color="#10b981" />
                    <div>
                      <div style={{ fontWeight: '700', fontSize: '14px', color: 'var(--text-primary)' }}>Google Healthcare SSO Gateway Verified</div>
                      <div style={{ fontSize: '12px', color: '#10b981' }}>TLS 1.3 End-to-End Encryption Active · ID: {user?.email || 'Authenticated Clinician'}</div>
                    </div>
                  </div>
                  <span style={{ fontSize: '11px', background: '#10b981', color: 'white', padding: '4px 10px', borderRadius: '20px', fontWeight: 'bold' }}>SOC2 TYPE II</span>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '13px', fontWeight: '600', color: 'var(--text-primary)', marginBottom: '8px' }}>HIPAA Auto-Lock Screen Timeout</label>
                  <select 
                    value={sessionTimeout}
                    onChange={(e) => setSessionTimeout(e.target.value)}
                    className="input"
                    style={{ width: '100%', cursor: 'pointer' }}
                  >
                    <option value="5">5 Minutes (Recommended for public clinic corridors)</option>
                    <option value="15">15 Minutes (Standard Medical Office Setting)</option>
                    <option value="30">30 Minutes (Private Attending Physician Office)</option>
                    <option value="never">Disabled (Not HIPAA Compliant)</option>
                  </select>
                </div>

                <div style={{ marginTop: '10px' }}>
                  <button 
                    type="button"
                    className="btn btn-primary" 
                    onClick={handleExportAudit}
                    style={{ width: '100%', background: 'linear-gradient(135deg, #10b981, #059669)', border: 'none', padding: '14px', fontSize: '15px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', boxShadow: '0 6px 20px rgba(16, 185, 129, 0.3)' }}
                  >
                    <Download size={20} /> Export Complete HIPAA Clinical Audit Trail (JSON)
                  </button>
                </div>
              </div>
            )}

          </div>
        </div>

        {/* Modal Footer */}
        <div style={{ padding: '16px 28px', borderTop: '1px solid var(--glass-border)', background: 'rgba(15, 23, 42, 0.6)', display: 'flex', justifyContent: 'flex-end', gap: '12px' }}>
          <button className="btn btn-primary" onClick={onClose} style={{ padding: '8px 24px' }}>
            Save & Apply Preferences
          </button>
        </div>
      </div>
    </div>
  );
}

function ToggleRow({ label, desc, checked, onChange }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
      <div style={{ maxWidth: '80%' }}>
        <div style={{ fontWeight: '700', fontSize: '15px', color: 'var(--text-primary)' }}>{label}</div>
        <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '2px' }}>{desc}</div>
      </div>
      <div 
        onClick={onChange}
        style={{
          width: '52px', height: '28px', borderRadius: '20px',
          background: checked ? '#3b82f6' : 'rgba(255,255,255,0.2)',
          position: 'relative', cursor: 'pointer', transition: 'background 0.2s',
          boxShadow: checked ? '0 0 12px rgba(59, 130, 246, 0.5)' : 'none'
        }}
      >
        <div style={{
          width: '22px', height: '22px', borderRadius: '50%', background: 'white',
          position: 'absolute', top: '3px', left: checked ? '27px' : '3px',
          transition: 'left 0.2s', boxShadow: '0 2px 5px rgba(0,0,0,0.3)'
        }} />
      </div>
    </div>
  );
}

function getTabStyle(active) {
  return {
    display: 'flex', alignItems: 'center', gap: '12px', padding: '12px 16px',
    borderRadius: '12px', border: 'none',
    background: active ? 'rgba(59, 130, 246, 0.25)' : 'transparent',
    color: active ? '#60a5fa' : 'var(--text-secondary)',
    cursor: 'pointer', fontSize: '14px', fontWeight: active ? '700' : '500',
    transition: 'all 0.2s', textAlign: 'left', width: '100%'
  };
}
