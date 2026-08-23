import React, { useState, useEffect, useRef } from 'react';
import { UploadCloud, FileText, CheckCircle, Loader2, Download, AlertTriangle, ArrowRight, ShieldCheck, Database, Syringe, Pill, Activity, UserPlus, Mic } from 'lucide-react';

// Simulated Demo Data
const DEMO_SCANNED_TEXT = `
CONFIDENTIAL CLINICAL FAX
Date: 2026-08-06
From: North York General Hospital - Records Dept.
To: Prime Care Specialists

PATIENT HISTORY TRANSFER
Patient: Michael Scott (DOB: 03/15/1965)
OHIP: 1234-567-890-AB

PAST MEDICAL HISTORY:
- Hypertension (diagnosed 2018)
- Type 2 Diabetes Mellitus
- Hyperlipidemia

CURRENT MEDICATIONS:
- Lisinopril 20mg PO daily
- Metformin 1000mg PO BID
- Atorvastatin 40mg PO at bedtime

KNOWN ALLERGIES:
- Penicillin (Hives/Anaphylaxis)
- Sulfa drugs (Mild rash)

SURGICAL HISTORY:
- Appendectomy (2002)
- Right Inguinal Hernia Repair (2015)
`;

export default function FormFiller({ triggerNotification }) {
  const [isUploading, setIsUploading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [extractedData, setExtractedData] = useState(null);
  const [syncing, setSyncing] = useState(false);
  const [synced, setSynced] = useState(false);
  
  // Voice Note State
  const [voiceNote, setVoiceNote] = useState('');
  const [isListening, setIsListening] = useState(false);
  
  const fileInputRef = useRef(null);
  const recognitionRef = useRef(null);

  useEffect(() => {
    // Initialize Web Speech API
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (SpeechRecognition) {
      const recognition = new SpeechRecognition();
      recognition.continuous = true;
      recognition.interimResults = true;
      
      recognition.onresult = (event) => {
        let currentTranscript = '';
        for (let i = event.resultIndex; i < event.results.length; i++) {
          currentTranscript += event.results[i][0].transcript;
        }
        setVoiceNote(prev => prev + ' ' + currentTranscript.trim());
      };

      recognition.onerror = (event) => {
        console.error("Speech recognition error", event.error);
        setIsListening(false);
      };
      
      recognition.onend = () => {
        setIsListening(false);
      };

      recognitionRef.current = recognition;
    }
    
    return () => {
      if (recognitionRef.current) {
        recognitionRef.current.stop();
      }
    };
  }, []);

  const toggleListening = () => {
    if (isListening) {
      recognitionRef.current?.stop();
      setIsListening(false);
    } else {
      if (!recognitionRef.current) {
        alert("Your browser does not support Speech Recognition. Try Google Chrome.");
        return;
      }
      setVoiceNote(prev => prev ? prev + ' ' : '');
      recognitionRef.current.start();
      setIsListening(true);
    }
  };

  const handleFileChange = (e) => {
    if (e.target.files && e.target.files.length > 0) {
      processDocument();
    }
  };

  const handleDemoLoad = () => {
    processDocument();
  };

  const processDocument = () => {
    setIsUploading(true);
    setSuccess(false);
    setExtractedData(null);
    setSynced(false);
    
    // Simulate complex AI OCR & NLP Extraction process
    setTimeout(() => {
      setExtractedData({
        patient: { name: "Michael Scott", dob: "03/15/1965", id: "1234-567-890-AB" },
        allergies: [
          { allergen: "Penicillin", reaction: "Hives/Anaphylaxis", severity: "High" },
          { allergen: "Sulfa drugs", reaction: "Mild rash", severity: "Low" }
        ],
        medications: [
          { drug: "Lisinopril", dose: "20mg", route: "PO", frequency: "Daily" },
          { drug: "Metformin", dose: "1000mg", route: "PO", frequency: "BID" },
          { drug: "Atorvastatin", dose: "40mg", route: "PO", frequency: "At bedtime" }
        ],
        history: [
          { condition: "Hypertension", date: "2018" },
          { condition: "Type 2 Diabetes Mellitus", date: "Unknown" },
          { condition: "Appendectomy (Surgical)", date: "2002" },
          { condition: "Right Inguinal Hernia Repair (Surgical)", date: "2015" }
        ]
      });
      setSuccess(true);
      setIsUploading(false);
    }, 2500);
  };

  const handleSyncToEMR = () => {
    setSyncing(true);
    setTimeout(() => {
      setSyncing(false);
      setSynced(true);
      
      // Log to activity feed if backend is running
      try {
        const token = localStorage.getItem('medoffice_token') || 'demo-token';
        fetch('http://localhost:8000/api/activity/log', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
          body: JSON.stringify({
            action: "emr_intake_synced",
            description: "Automated OCR intake synced to patient chart",
            patient_name: "Michael Scott",
            detail: `Synced 2 allergies, 3 medications, and 4 history items from unstructured fax.`,
            color: "blue"
          })
        }).then(() => {
          if (triggerNotification) triggerNotification('dashboard');
        }).catch(() => {});
      } catch(e) {}
    }, 2000);
  };

  return (
    <div className="animate-fade-in" style={{ padding: '32px', maxWidth: '1500px', margin: '0 auto', height: '100%', display: 'flex', flexDirection: 'column' }}>
      
      {/* Header */}
      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: '800', color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '12px', margin: '0 0 8px 0' }}>
          <FileText size={32} color="#0ea5e9" /> Patient Intake OCR Engine
        </h1>
        <p style={{ fontSize: '15px', color: 'var(--text-secondary)', margin: 0, maxWidth: '900px', lineHeight: '1.6' }}>
          Instantly convert messy, unstructured hospital faxes and scanned PDFs into clean, structured data perfectly mapped to your EMR fields. Zero manual data entry required.
        </p>
      </div>

      {!success && !isUploading && (
        <div className="glass-panel" style={{ padding: '60px 40px', textAlign: 'center', border: '2px dashed rgba(14, 165, 233, 0.4)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flex: 1 }}>
          <div style={{ width: '80px', height: '80px', borderRadius: '50%', background: 'rgba(14, 165, 233, 0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '24px' }}>
            <UploadCloud size={40} color="#38bdf8" />
          </div>
          <h3 style={{ fontSize: '22px', color: 'var(--text-primary)', margin: '0 0 12px 0' }}>Drag & Drop Scanned Clinical Fax</h3>
          <p style={{ color: 'var(--text-secondary)', fontSize: '15px', maxWidth: '500px', margin: '0 0 32px 0' }}>
            Supports PDF, JPG, and PNG files up to 50MB.
          </p>
          
          <div style={{ display: 'flex', gap: '16px' }}>
            <input type="file" ref={fileInputRef} onChange={handleFileChange} style={{ display: 'none' }} accept=".pdf,image/*" />
            <button 
              className="btn btn-primary" 
              style={{ padding: '14px 28px', fontSize: '15px', fontWeight: '700', background: 'linear-gradient(135deg, #0ea5e9, #2563eb)', border: 'none', display: 'flex', alignItems: 'center', gap: '8px' }}
              onClick={() => fileInputRef.current?.click()}
            >
              Browse Files
            </button>
            <button 
              className="btn" 
              style={{ padding: '14px 28px', fontSize: '15px', fontWeight: '700', background: 'rgba(14, 165, 233, 0.1)', border: '1px solid #38bdf8', color: '#bae6fd', display: 'flex', alignItems: 'center', gap: '8px' }}
              onClick={handleDemoLoad}
            >
              <FileText size={18} /> Load Demo Fax
            </button>
          </div>
        </div>
      )}

      {isUploading && (
        <div style={{ flex: 1, display: 'flex', gap: '24px', minHeight: 0 }}>
          {/* Laser Scanner View */}
          <div className="glass-panel" style={{ flex: 1, padding: 0, display: 'flex', flexDirection: 'column', overflow: 'hidden', position: 'relative' }}>
            <div style={{ padding: '16px 20px', background: 'rgba(0,0,0,0.4)', borderBottom: '1px solid rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <FileText size={18} color="var(--text-secondary)" />
                <span style={{ fontSize: '14px', fontWeight: '700', color: 'var(--text-primary)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Scanning Source Document...</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#38bdf8' }}>
                <Loader2 size={16} className="animate-spin" />
                <span style={{ fontSize: '12px', fontWeight: '700', letterSpacing: '1px' }}>OCR ACTIVE</span>
              </div>
            </div>
            <div style={{ flex: 1, padding: '24px', overflowY: 'hidden', background: 'var(--bg-secondary)', position: 'relative' }}>
              <div style={{ color: 'var(--text-secondary)', fontFamily: 'monospace', fontSize: '14px', lineHeight: '1.8', whiteSpace: 'pre-wrap', opacity: 0.5 }}>
                {DEMO_SCANNED_TEXT}
              </div>
              
              {/* Laser Line */}
              <div style={{
                position: 'absolute', top: 0, left: 0, right: 0, height: '4px',
                background: '#38bdf8', boxShadow: '0 0 20px 4px #38bdf8',
                animation: 'scan 2s cubic-bezier(0.4, 0, 0.2, 1) infinite'
              }} />
              
              <style>{`
                @keyframes scan {
                  0% { top: 0%; opacity: 0; }
                  10% { opacity: 1; }
                  90% { opacity: 1; }
                  100% { top: 100%; opacity: 0; }
                }
              `}</style>
            </div>
          </div>
        </div>
      )}

      {success && extractedData && (
        <div style={{ flex: 1, display: 'grid', gridTemplateColumns: '1fr 1.5fr', gap: '24px', minHeight: 0 }}>
          
          {/* Left Column: Raw Document Viewer */}
          <div className="glass-panel" style={{ padding: 0, display: 'flex', flexDirection: 'column', overflow: 'hidden', borderTop: '4px solid #64748b' }}>
            <div style={{ padding: '16px 20px', background: 'rgba(0,0,0,0.4)', borderBottom: '1px solid rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', gap: '10px' }}>
              <FileText size={18} color="var(--text-secondary)" />
              <span style={{ fontSize: '14px', fontWeight: '700', color: 'var(--text-primary)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Raw Source Document</span>
            </div>
            <div style={{ flex: 1, padding: '24px', overflowY: 'auto', background: '#f8fafc' }}>
              <div style={{ background: 'var(--bg-secondary)', padding: '32px', boxShadow: '0 4px 15px rgba(0,0,0,0.1)', minHeight: '100%', color: 'var(--text-primary)', fontFamily: 'monospace', fontSize: '14px', lineHeight: '1.8', whiteSpace: 'pre-wrap' }}>
                {DEMO_SCANNED_TEXT}
              </div>
            </div>
          </div>

          {/* Right Column: Structured EMR Data Grid */}
          <div className="glass-panel" style={{ padding: '0', display: 'flex', flexDirection: 'column', overflow: 'hidden', borderTop: '4px solid #0ea5e9' }}>
            <div style={{ padding: '20px 24px', background: 'rgba(14, 165, 233, 0.1)', borderBottom: '1px solid rgba(14, 165, 233, 0.3)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <ShieldCheck size={24} color="#0ea5e9" />
                <div>
                  <h3 style={{ margin: 0, fontSize: '18px', color: 'var(--text-primary)', fontWeight: '800' }}>AI Structured Intake Record</h3>
                  <span style={{ fontSize: '13px', color: '#7dd3fc', fontWeight: '600' }}>Ready for EMR Sync</span>
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', background: 'rgba(0,0,0,0.4)', padding: '6px 12px', borderRadius: '20px', border: '1px solid rgba(255,255,255,0.1)' }}>
                <UserPlus size={14} color="var(--text-secondary)" />
                <span style={{ fontSize: '13px', color: 'var(--text-primary)', fontWeight: '600' }}>{extractedData.patient.name} ({extractedData.patient.dob})</span>
              </div>
            </div>

            <div style={{ flex: 1, overflowY: 'auto', padding: '24px', display: 'flex', flexDirection: 'column', gap: '24px' }}>
              
              {/* Allergies Block */}
              <div>
                <h4 style={{ margin: '0 0 12px 0', fontSize: '13px', color: '#ef4444', textTransform: 'uppercase', letterSpacing: '1px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <AlertTriangle size={16} /> Allergies & Adverse Reactions
                </h4>
                <div style={{ background: 'rgba(0,0,0,0.2)', border: '1px solid rgba(255,255,255,0.05)', borderRadius: '8px', overflow: 'hidden' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '14px' }}>
                    <thead>
                      <tr style={{ background: 'rgba(0,0,0,0.4)' }}>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '600' }}>Allergen</th>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '600' }}>Reaction</th>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '600' }}>Severity</th>
                      </tr>
                    </thead>
                    <tbody>
                      {extractedData.allergies.map((a, i) => (
                        <tr key={i} style={{ borderTop: '1px solid rgba(255,255,255,0.05)' }}>
                          <td style={{ padding: '12px 16px', color: 'var(--text-primary)', fontWeight: '600' }}>{a.allergen}</td>
                          <td style={{ padding: '12px 16px', color: 'var(--text-secondary)' }}>{a.reaction}</td>
                          <td style={{ padding: '12px 16px', color: a.severity === 'High' ? '#ef4444' : '#f59e0b', fontWeight: '700' }}>{a.severity}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              {/* Medications Block */}
              <div>
                <h4 style={{ margin: '0 0 12px 0', fontSize: '13px', color: '#3b82f6', textTransform: 'uppercase', letterSpacing: '1px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Pill size={16} /> Current Medications
                </h4>
                <div style={{ background: 'rgba(0,0,0,0.2)', border: '1px solid rgba(255,255,255,0.05)', borderRadius: '8px', overflow: 'hidden' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '14px' }}>
                    <thead>
                      <tr style={{ background: 'rgba(0,0,0,0.4)' }}>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '600' }}>Drug Name</th>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '600' }}>Dose</th>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '600' }}>Route</th>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '600' }}>Frequency</th>
                      </tr>
                    </thead>
                    <tbody>
                      {extractedData.medications.map((m, i) => (
                        <tr key={i} style={{ borderTop: '1px solid rgba(255,255,255,0.05)' }}>
                          <td style={{ padding: '12px 16px', color: 'var(--text-primary)', fontWeight: '600' }}>{m.drug}</td>
                          <td style={{ padding: '12px 16px', color: '#93c5fd' }}>{m.dose}</td>
                          <td style={{ padding: '12px 16px', color: 'var(--text-secondary)' }}>{m.route}</td>
                          <td style={{ padding: '12px 16px', color: 'var(--text-secondary)' }}>{m.frequency}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              {/* Medical/Surgical History */}
              <div>
                <h4 style={{ margin: '0 0 12px 0', fontSize: '13px', color: '#10b981', textTransform: 'uppercase', letterSpacing: '1px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Activity size={16} /> Past Medical & Surgical History
                </h4>
                <div style={{ background: 'rgba(0,0,0,0.2)', border: '1px solid rgba(255,255,255,0.05)', borderRadius: '8px', overflow: 'hidden' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '14px' }}>
                    <thead>
                      <tr style={{ background: 'rgba(0,0,0,0.4)' }}>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '600' }}>Condition / Procedure</th>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '600' }}>Date Recorded</th>
                      </tr>
                    </thead>
                    <tbody>
                      {extractedData.history.map((h, i) => (
                        <tr key={i} style={{ borderTop: '1px solid rgba(255,255,255,0.05)' }}>
                          <td style={{ padding: '12px 16px', color: 'var(--text-primary)', fontWeight: '600' }}>{h.condition}</td>
                          <td style={{ padding: '12px 16px', color: 'var(--text-secondary)' }}>{h.date}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

            </div>
            
            {/* Voice Dictation Note */}
            <div style={{ padding: '24px', borderTop: '1px solid rgba(255,255,255,0.1)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                <label style={{ fontSize: '13px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '1px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Mic size={16} color={isListening ? '#ef4444' : '#64748b'} className={isListening ? 'animate-pulse' : ''} /> 
                  Physician Voice Notes (Optional)
                </label>
                <button 
                  onClick={toggleListening}
                  style={{ background: isListening ? 'rgba(239, 68, 68, 0.2)' : 'rgba(255,255,255,0.05)', border: isListening ? '1px solid #ef4444' : '1px solid rgba(255,255,255,0.1)', color: isListening ? '#fca5a5' : 'var(--text-secondary)', padding: '6px 12px', borderRadius: '8px', cursor: 'pointer', fontSize: '12px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '6px', transition: 'all 0.3s' }}
                >
                  {isListening ? 'Stop Listening...' : 'Start Dictation'}
                </button>
              </div>
              <textarea 
                value={voiceNote} 
                onChange={(e) => setVoiceNote(e.target.value)}
                placeholder="Click 'Start Dictation' and speak to append clinical notes to this OCR intake..." 
                style={{ width: '100%', height: '80px', background: 'rgba(0,0,0,0.3)', border: isListening ? '1px solid #ef4444' : '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: 'var(--text-primary)', padding: '12px', fontSize: '14px', resize: 'none', transition: 'all 0.3s', boxShadow: isListening ? 'inset 0 0 10px rgba(239, 68, 68, 0.2)' : 'none' }}
              />
            </div>

            {/* Action Footer */}
            <div style={{ padding: '24px', background: 'rgba(0,0,0,0.3)', borderTop: '1px solid rgba(255,255,255,0.1)' }}>
              {synced ? (
                <div className="animate-fade-in" style={{ background: 'rgba(16, 185, 129, 0.2)', color: '#10b981', padding: '18px', borderRadius: '12px', textAlign: 'center', fontWeight: '800', fontSize: '16px', border: '2px solid #10b981', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px' }}>
                  <CheckCircle size={24} /> Data Successfully Synced to EMR Database!
                </div>
              ) : (
                <button 
                  className="btn btn-primary" 
                  style={{ width: '100%', padding: '18px', fontSize: '16px', fontWeight: '800', background: 'linear-gradient(135deg, #0ea5e9, #0284c7)', border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', boxShadow: '0 10px 30px rgba(14, 165, 233, 0.4)', transition: 'all 0.3s' }}
                  onClick={handleSyncToEMR}
                  disabled={syncing}
                >
                  {syncing ? <Loader2 size={24} className="animate-spin" /> : <Database size={24} />}
                  {syncing ? 'Syncing to Enterprise Database...' : 'Approve & Sync All Data to EMR'}
                </button>
              )}
            </div>

          </div>
        </div>
      )}

    </div>
  );
}
