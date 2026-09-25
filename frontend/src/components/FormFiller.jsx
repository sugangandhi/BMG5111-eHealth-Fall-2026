import React, { useState, useEffect, useRef } from 'react';
import { UploadCloud, FileText, CheckCircle, Loader2, Download, AlertTriangle, ArrowRight, ShieldCheck, Database, Syringe, Pill, Activity, UserPlus, Mic, Zap, Lock, Scan, Check, Server, FileDigit } from 'lucide-react';

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
        fetch('/api/activity/log', {
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
      <div style={{ marginBottom: '24px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: '700', color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '12px', margin: '0 0 8px 0' }}>
            <FileText size={32} color="var(--primary)" /> Patient Intake OCR Engine
          </h1>
          <p style={{ fontSize: '15px', color: 'var(--text-secondary)', margin: 0, maxWidth: '900px', lineHeight: '1.6' }}>
            Enterprise-grade Natural Language Processing to convert unstructured clinical faxes and PDF forms into structured EMR data.
          </p>
        </div>
        
        {!success && !isUploading && (
          <button 
            className="btn btn-primary"
            onClick={() => {
              // Programmatically trigger Universal Scanner by simulating a click on its header button
              // In a real app we'd use Context, but this is a quick demo hook
              const scannerBtn = document.querySelector('button[title="Universal AI Document Scanner"]');
              if (scannerBtn) scannerBtn.click();
            }}
            style={{ padding: '10px 20px', display: 'flex', alignItems: 'center', gap: '8px', fontSize: '15px' }}
          >
            <Scan size={18} /> Launch Universal Scanner
          </button>
        )}
      </div>

      {!success && !isUploading && (
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '24px' }}>
          
          {/* Main Product Overview Grid */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px' }}>
            
            {/* Left Col: Features & Value Prop */}
            <div className="glass-panel" style={{ padding: '32px', display: 'flex', flexDirection: 'column', gap: '24px' }}>
              <div>
                <h2 style={{ fontSize: '20px', fontWeight: '600', color: 'var(--text-primary)', marginBottom: '8px' }}>
                  Eliminate Manual Data Entry
                </h2>
                <p style={{ color: 'var(--text-secondary)', fontSize: '14px', lineHeight: '1.6' }}>
                  The Prime Care Intake Engine automatically processes messy, unstructured 50-page faxes and seamlessly maps demographics, medications, and allergies directly into your FHIR-compliant database.
                </p>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {[
                  { icon: <Zap size={18} color="var(--primary)" />, title: "Sub-Second Processing", desc: "Extracts key clinical entities in under 1.2 seconds per page." },
                  { icon: <ShieldCheck size={18} color="var(--accent)" />, title: "Medical Terminology Recognition", desc: "Built-in SNOMED-CT and RxNorm ontology mapping." },
                  { icon: <Lock size={18} color="var(--error)" />, title: "Enterprise Security", desc: "SOC2 Type II, HIPAA compliant, and AES-256 encrypted at rest." }
                ].map((item, i) => (
                  <div key={i} style={{ display: 'flex', gap: '16px', alignItems: 'flex-start' }}>
                    <div style={{ padding: '10px', background: 'var(--bg-tertiary)', borderRadius: '8px', border: '1px solid var(--border)' }}>
                      {item.icon}
                    </div>
                    <div>
                      <h4 style={{ margin: '0 0 4px 0', fontSize: '14px', color: 'var(--text-primary)' }}>{item.title}</h4>
                      <p style={{ margin: 0, fontSize: '13px', color: 'var(--text-secondary)' }}>{item.desc}</p>
                    </div>
                  </div>
                ))}
              </div>

              <div style={{ marginTop: 'auto', paddingTop: '24px', borderTop: '1px solid var(--border)', display: 'flex', alignItems: 'center', gap: '24px' }}>
                <div>
                  <div style={{ fontSize: '24px', fontWeight: '700', color: 'var(--text-primary)' }}>99.8%</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Extraction Accuracy</div>
                </div>
                <div style={{ width: '1px', height: '30px', background: 'var(--border)' }} />
                <div>
                  <div style={{ fontSize: '24px', fontWeight: '700', color: 'var(--text-primary)' }}>1.2M+</div>
                  <div style={{ fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Pages Processed / Mo</div>
                </div>
              </div>
            </div>

            {/* Right Col: Architecture Diagram (CSS Built) */}
            <div className="glass-panel" style={{ padding: '40px', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-tertiary)' }}>
              
              <div style={{ display: 'flex', alignItems: 'center', gap: '16px', width: '100%', justifyContent: 'center' }}>
                
                {/* PDF Node */}
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
                  <div style={{ width: '70px', height: '70px', background: 'var(--bg-secondary)', border: '1px solid var(--border)', borderRadius: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 6px rgba(0,0,0,0.05)' }}>
                    <FileDigit size={32} color="var(--text-secondary)" />
                  </div>
                  <span style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)' }}>Raw Fax PDF</span>
                </div>

                {/* Arrow */}
                <ArrowRight size={24} color="var(--primary)" />

                {/* AI Node */}
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
                  <div style={{ width: '90px', height: '90px', background: 'var(--primary)', border: '1px solid var(--primary-hover)', borderRadius: '16px', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 8px 15px rgba(47, 129, 247, 0.2)' }}>
                    <Zap size={40} color="white" />
                  </div>
                  <span style={{ fontSize: '13px', fontWeight: '700', color: 'var(--primary)' }}>NLP Engine</span>
                </div>

                {/* Arrow */}
                <ArrowRight size={24} color="var(--primary)" />

                {/* EMR Node */}
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
                  <div style={{ width: '70px', height: '70px', background: 'var(--bg-secondary)', border: '1px solid var(--accent)', borderRadius: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 6px rgba(0,0,0,0.05)' }}>
                    <Server size={32} color="var(--accent)" />
                  </div>
                  <span style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)' }}>FHIR Database</span>
                </div>

              </div>

              <div style={{ marginTop: '48px', width: '100%' }}>
                <h4 style={{ fontSize: '12px', textTransform: 'uppercase', color: 'var(--text-secondary)', marginBottom: '12px', textAlign: 'center', letterSpacing: '1px' }}>Supported Standard Formats</h4>
                <div style={{ display: 'flex', justifyContent: 'center', gap: '12px', flexWrap: 'wrap' }}>
                  {['HL7 v2', 'FHIR R4', 'DICOM', 'CCDA', 'X12 837'].map(tag => (
                    <span key={tag} style={{ padding: '4px 12px', background: 'var(--bg-secondary)', border: '1px solid var(--border)', borderRadius: '20px', fontSize: '12px', color: 'var(--text-primary)', fontWeight: '500' }}>
                      {tag}
                    </span>
                  ))}
                </div>
              </div>

            </div>
          </div>

          {/* Bottom Bar: Developer / Testing Action */}
          <div className="glass-panel" style={{ padding: '24px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3 style={{ fontSize: '15px', fontWeight: '600', color: 'var(--text-primary)', margin: '0 0 4px 0' }}>Developer Demo Mode</h3>
              <p style={{ margin: 0, fontSize: '13px', color: 'var(--text-secondary)' }}>Bypass the Universal Scanner and inject a mock parsed document directly into the intake workflow.</p>
            </div>
            <button 
              className="btn btn-secondary" 
              onClick={handleDemoLoad}
            >
              <FileText size={16} /> Load Demo Fax Injection
            </button>
          </div>

        </div>
      )}

      {/* --- Existing OCR Processing UI --- */}
      {isUploading && (
        <div style={{ flex: 1, display: 'flex', gap: '24px', minHeight: 0 }}>
          {/* Laser Scanner View */}
          <div className="glass-panel" style={{ flex: 1, padding: 0, display: 'flex', flexDirection: 'column', overflow: 'hidden', position: 'relative' }}>
            <div style={{ padding: '16px 20px', background: 'var(--bg-tertiary)', borderBottom: '1px solid var(--border)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <FileText size={18} color="var(--text-secondary)" />
                <span style={{ fontSize: '14px', fontWeight: '600', color: 'var(--text-primary)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Scanning Source Document...</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--primary)' }}>
                <Loader2 size={16} className="animate-spin" />
                <span style={{ fontSize: '12px', fontWeight: '600', letterSpacing: '1px' }}>OCR ACTIVE</span>
              </div>
            </div>
            <div style={{ flex: 1, padding: '24px', overflowY: 'hidden', background: 'var(--bg-secondary)', position: 'relative' }}>
              <div style={{ color: 'var(--text-secondary)', fontFamily: 'monospace', fontSize: '14px', lineHeight: '1.8', whiteSpace: 'pre-wrap', opacity: 0.5 }}>
                {DEMO_SCANNED_TEXT}
              </div>
              
              {/* Laser Line */}
              <div style={{
                position: 'absolute', top: 0, left: 0, right: 0, height: '4px',
                background: 'var(--primary)', boxShadow: '0 0 20px 4px rgba(47, 129, 247, 0.5)',
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

      {/* --- Existing Structured Data Verification UI --- */}
      {success && extractedData && (
        <div style={{ flex: 1, display: 'grid', gridTemplateColumns: '1fr 1.5fr', gap: '24px', minHeight: 0 }}>
          
          {/* Left Column: Raw Document Viewer */}
          <div className="glass-panel" style={{ padding: 0, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
            <div style={{ padding: '16px 20px', background: 'var(--bg-tertiary)', borderBottom: '1px solid var(--border)', display: 'flex', alignItems: 'center', gap: '10px' }}>
              <FileText size={18} color="var(--text-secondary)" />
              <span style={{ fontSize: '14px', fontWeight: '600', color: 'var(--text-primary)', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Raw Source Document</span>
            </div>
            <div style={{ flex: 1, padding: '24px', overflowY: 'auto', background: 'var(--bg-primary)' }}>
              <div style={{ background: 'var(--bg-secondary)', padding: '32px', border: '1px solid var(--border)', minHeight: '100%', color: 'var(--text-primary)', fontFamily: 'monospace', fontSize: '14px', lineHeight: '1.8', whiteSpace: 'pre-wrap' }}>
                {DEMO_SCANNED_TEXT}
              </div>
            </div>
          </div>

          {/* Right Column: Structured EMR Data Grid */}
          <div className="glass-panel" style={{ padding: '0', display: 'flex', flexDirection: 'column', overflow: 'hidden', borderTop: '4px solid var(--primary)' }}>
            <div style={{ padding: '20px 24px', background: 'var(--bg-secondary)', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <ShieldCheck size={24} color="var(--primary)" />
                <div>
                  <h3 style={{ margin: 0, fontSize: '16px', color: 'var(--text-primary)', fontWeight: '600' }}>AI Structured Intake Record</h3>
                  <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Ready for FHIR Sync</span>
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', background: 'var(--bg-tertiary)', padding: '6px 12px', borderRadius: '6px', border: '1px solid var(--border)' }}>
                <UserPlus size={14} color="var(--text-secondary)" />
                <span style={{ fontSize: '13px', color: 'var(--text-primary)', fontWeight: '500' }}>{extractedData.patient.name} ({extractedData.patient.dob})</span>
              </div>
            </div>

            <div style={{ flex: 1, overflowY: 'auto', padding: '24px', display: 'flex', flexDirection: 'column', gap: '24px' }}>
              
              {/* Allergies Block */}
              <div>
                <h4 style={{ margin: '0 0 12px 0', fontSize: '13px', color: 'var(--error)', textTransform: 'uppercase', letterSpacing: '0.5px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <AlertTriangle size={16} /> Allergies & Adverse Reactions
                </h4>
                <div style={{ background: 'var(--bg-secondary)', border: '1px solid var(--border)', borderRadius: '6px', overflow: 'hidden' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '14px' }}>
                    <thead>
                      <tr style={{ background: 'var(--bg-tertiary)' }}>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '500', borderBottom: '1px solid var(--border)' }}>Allergen</th>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '500', borderBottom: '1px solid var(--border)' }}>Reaction</th>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '500', borderBottom: '1px solid var(--border)' }}>Severity</th>
                      </tr>
                    </thead>
                    <tbody>
                      {extractedData.allergies.map((a, i) => (
                        <tr key={i} style={{ borderBottom: '1px solid var(--border)' }}>
                          <td style={{ padding: '12px 16px', color: 'var(--text-primary)', fontWeight: '500' }}>{a.allergen}</td>
                          <td style={{ padding: '12px 16px', color: 'var(--text-secondary)' }}>{a.reaction}</td>
                          <td style={{ padding: '12px 16px', color: a.severity === 'High' ? 'var(--error)' : '#f59e0b', fontWeight: '600' }}>{a.severity}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              {/* Medications Block */}
              <div>
                <h4 style={{ margin: '0 0 12px 0', fontSize: '13px', color: 'var(--primary)', textTransform: 'uppercase', letterSpacing: '0.5px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Pill size={16} /> Current Medications
                </h4>
                <div style={{ background: 'var(--bg-secondary)', border: '1px solid var(--border)', borderRadius: '6px', overflow: 'hidden' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '14px' }}>
                    <thead>
                      <tr style={{ background: 'var(--bg-tertiary)' }}>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '500', borderBottom: '1px solid var(--border)' }}>Drug Name</th>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '500', borderBottom: '1px solid var(--border)' }}>Dose</th>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '500', borderBottom: '1px solid var(--border)' }}>Route</th>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '500', borderBottom: '1px solid var(--border)' }}>Frequency</th>
                      </tr>
                    </thead>
                    <tbody>
                      {extractedData.medications.map((m, i) => (
                        <tr key={i} style={{ borderBottom: '1px solid var(--border)' }}>
                          <td style={{ padding: '12px 16px', color: 'var(--text-primary)', fontWeight: '500' }}>{m.drug}</td>
                          <td style={{ padding: '12px 16px', color: 'var(--primary)' }}>{m.dose}</td>
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
                <h4 style={{ margin: '0 0 12px 0', fontSize: '13px', color: 'var(--accent)', textTransform: 'uppercase', letterSpacing: '0.5px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Activity size={16} /> Past Medical & Surgical History
                </h4>
                <div style={{ background: 'var(--bg-secondary)', border: '1px solid var(--border)', borderRadius: '6px', overflow: 'hidden' }}>
                  <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '14px' }}>
                    <thead>
                      <tr style={{ background: 'var(--bg-tertiary)' }}>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '500', borderBottom: '1px solid var(--border)' }}>Condition / Procedure</th>
                        <th style={{ padding: '12px 16px', color: 'var(--text-secondary)', fontWeight: '500', borderBottom: '1px solid var(--border)' }}>Date Recorded</th>
                      </tr>
                    </thead>
                    <tbody>
                      {extractedData.history.map((h, i) => (
                        <tr key={i} style={{ borderBottom: '1px solid var(--border)' }}>
                          <td style={{ padding: '12px 16px', color: 'var(--text-primary)', fontWeight: '500' }}>{h.condition}</td>
                          <td style={{ padding: '12px 16px', color: 'var(--text-secondary)' }}>{h.date}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

            </div>
            
            {/* Voice Dictation Note */}
            <div style={{ padding: '24px', borderTop: '1px solid var(--border)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                <label style={{ fontSize: '13px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.5px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Mic size={16} color={isListening ? 'var(--error)' : 'var(--text-secondary)'} className={isListening ? 'animate-pulse' : ''} /> 
                  Physician Voice Notes (Optional)
                </label>
                <button 
                  onClick={toggleListening}
                  className="btn btn-secondary"
                  style={{ padding: '6px 12px', fontSize: '12px', color: isListening ? 'var(--error)' : 'var(--text-primary)', borderColor: isListening ? 'var(--error)' : 'var(--border)' }}
                >
                  {isListening ? 'Stop Listening...' : 'Start Dictation'}
                </button>
              </div>
              <textarea 
                value={voiceNote} 
                onChange={(e) => setVoiceNote(e.target.value)}
                placeholder="Click 'Start Dictation' and speak to append clinical notes to this OCR intake..." 
                className="input"
                style={{ height: '80px', resize: 'none', borderColor: isListening ? 'var(--error)' : 'var(--border)' }}
              />
            </div>

            {/* Action Footer */}
            <div style={{ padding: '24px', background: 'var(--bg-tertiary)', borderTop: '1px solid var(--border)' }}>
              {synced ? (
                <div className="animate-fade-in" style={{ background: 'var(--bg-secondary)', color: 'var(--accent)', padding: '16px', borderRadius: '6px', textAlign: 'center', fontWeight: '600', fontSize: '14px', border: '1px solid var(--accent)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
                  <CheckCircle size={18} /> Data Successfully Synced to EMR Database!
                </div>
              ) : (
                <button 
                  className="btn btn-primary" 
                  style={{ width: '100%', padding: '14px', fontSize: '14px' }}
                  onClick={handleSyncToEMR}
                  disabled={syncing}
                >
                  {syncing ? <Loader2 size={18} className="animate-spin" /> : <Database size={18} />}
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
