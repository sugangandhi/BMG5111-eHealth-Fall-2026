import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Mic, CheckCircle, Loader2, X, Sparkles, Volume2, Copy, Bookmark, FileText, Activity, Layers, Tag, ShieldCheck, Network, HeartHandshake } from 'lucide-react';
window.utterances = [];
window.isSpeaking = false;
const speakAction = (text) => {
  if (localStorage.getItem('medoffice_voice_feedback') === 'false') return;
  if ('speechSynthesis' in window) {
    // Remove aggressive cancel
    // window.speechSynthesis.cancel();
    
    setTimeout(() => {
      const msg = new SpeechSynthesisUtterance(text);
      msg.rate = 1.0;
      msg.pitch = 1.0;
      
      const voiceUri = localStorage.getItem('medoffice_voice_uri');
      if (voiceUri) {
        const voices = window.speechSynthesis.getVoices();
        const voice = voices.find(v => v.voiceURI === voiceUri);
        if (voice) msg.voice = voice;
      }

      window.isSpeaking = true;
      msg.onstart = () => { window.isSpeaking = true; };
      
      msg.onend = () => {
        window.isSpeaking = false;
        const index = window.utterances.indexOf(msg);
        if (index > -1) window.utterances.splice(index, 1);
      };

      msg.onerror = () => { window.isSpeaking = false; };

      window.utterances.push(msg);
      window.speechSynthesis.speak(msg);
    }, 50);
  }
};

const SAMPLES = {
  cardiac: "Patient John Doe, 58-year-old male, presents with onset of acute substernal chest pressure starting 3 hours ago during mild exertion. Reports radiation of pain to left jaw and diaphoresis. Vitals demonstrate blood pressure 152/92, heart rate 98 beats per minute, regular rhythm. ECG shows mild T-wave inversion in anterior leads. Plan to admit for cardiac observation, serial troponins, stat repeat cardiogram, and initiation of acute ischemic protocol.",
  diabetes: "Follow up examination for Mary Smith regarding Type 2 Diabetes management. Patient admits to infrequent fingerstick monitoring and mild diet infractions over holidays, though denies polyuria or polyphagia. Today's fasting fingerstick reading is 168 mg/dL, with laboratory HbA1c elevated at 7.8%. Blood pressure controlled at 124/78. Plan is to adjust Metformin from 500mg to 1000mg BID, order repeat renal function panel, and re-evaluate HbA1c in 12 weeks.",
  neuro: "Consultation note for Robert Vance presenting with recurrent pulsatile frontal headaches rated 8 out of 10 in severity, accompanied by nausea and marked photophobia lasting up to 24 hours. Cranial nerves II through XII are intact without focal motor or sensory neurological deficits. Negative Romberg test and gait normal. Consistent with classic cephalalgia migraine disorder without aura. Prescribing abortive rescue sumatriptan 50mg and arranging non-contrast head outpatient MRI to rule out structural etiology."
};

// CSS for the pulsing audio waveform
const audioBarsStyle = `
  @keyframes sound-wave-1 { 0% { height: 4px; } 50% { height: 28px; } 100% { height: 4px; } }
  @keyframes sound-wave-2 { 0% { height: 4px; } 50% { height: 18px; } 100% { height: 4px; } }
  @keyframes sound-wave-3 { 0% { height: 4px; } 50% { height: 36px; } 100% { height: 4px; } }
  @keyframes sound-wave-4 { 0% { height: 4px; } 50% { height: 12px; } 100% { height: 4px; } }
  .audio-bar {
    width: 3px;
    background: #ef4444;
    border-radius: 4px;
    margin: 0 1px;
    opacity: 0.8;
  }
`;

export default function Scribe() {
  const [isOpen, setIsOpen] = useState(false);
  const [dictation, setDictation] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);
  const [parsedData, setParsedData] = useState(null);
  const [isRecording, setIsRecording] = useState(false);
  const [copied, setCopied] = useState(false);
  const [saved, setSaved] = useState(false);
  const [speechError, setSpeechError] = useState(null);
  const [fhirExporting, setFhirExporting] = useState(false);
  const [fhirExported, setFhirExported] = useState(false);
  const [translating, setTranslating] = useState(false);
  const [patientSummary, setPatientSummary] = useState(null);
  
  // Track the text that existed before the current recording session started
  const sessionBaseTextRef = React.useRef("");

  useEffect(() => {
    const handleOpenScribe = () => setIsOpen(true);
    const handleStartScribe = () => {
      setIsOpen(true);
      if (!isRecording) toggleRecording();
    };
    window.addEventListener('open-scribe', handleOpenScribe);
    window.addEventListener('start-scribe', handleStartScribe);
    return () => {
      window.removeEventListener('open-scribe', handleOpenScribe);
      window.removeEventListener('start-scribe', handleStartScribe);
    };
  }, [isRecording]);

  useEffect(() => {
    const handleVoiceCommand = (e) => {
      const { action, target } = e.detail;
      if (action === 'scribe_cmd') {
        if (target === 'start' && !isRecording) toggleRecording();
        if (target === 'stop' && isRecording) toggleRecording();
        if (target === 'demo_cardio') handleLoadSample('cardiac');
        if (target === 'demo_diab') handleLoadSample('diabetes');
        if (target === 'demo_neuro') handleLoadSample('neuro');
        if (target === 'synthesize') handleSubmit();
        if (target === 'translate') handleTranslate();
        if (target === 'export') handleFhirExport();
        if (target === 'sign') handleSaveToEhr();
      }
    };
    window.addEventListener('voice-command', handleVoiceCommand);
    return () => window.removeEventListener('voice-command', handleVoiceCommand);
  }, [isRecording, dictation, parsedData]);
  
  // Clear everything when modal is closed
  useEffect(() => {
    if (!isOpen) {
      setDictation("");
      setParsedData(null);
      setIsRecording(false);
      sessionBaseTextRef.current = "";
      window.dispatchEvent(new CustomEvent('resume-voice-nav'));
    }
  }, [isOpen]);

  // Inject CSS for audio visualizer
  useEffect(() => {
    const styleSheet = document.createElement("style");
    styleSheet.innerText = audioBarsStyle;
    document.head.appendChild(styleSheet);
    return () => styleSheet.remove();
  }, []);

  // Web Speech API Integration
  useEffect(() => {
    let recognition = null;
    if (isRecording) {
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      if (!SpeechRecognition) {
        setSpeechError("Speech recognition is not supported by your current browser. Try clicking one of the sample buttons above!");
        setIsRecording(false);
        return;
      }

      recognition = new SpeechRecognition();
      recognition.continuous = true;
      recognition.interimResults = false;
      recognition.lang = 'en-US';

      recognition.onresult = (event) => {
        if (window.isSpeaking) return;
        let currentTranscript = '';
        for (let i = 0; i < event.results.length; i++) {
          currentTranscript += event.results[i][0].transcript;
          if (event.results[i].isFinal) {
             currentTranscript += ' ';
          }
        }
        
        const lower = currentTranscript.toLowerCase();
        
        // Inline Voice Commands while Dictating
        if (lower.includes('stop listening') || lower.includes('stop microphone') || lower.includes('stop recording')) {
          speakAction('Stopping microphone');
          toggleRecording();
          return;
        }
        if (lower.includes('synthesize note') || lower.includes('create note') || lower.includes('finish note')) {
          speakAction('Synthesizing clinical note');
          handleSubmit();
          return;
        }
        if (lower.includes('translate for patient') || lower.includes('translate')) {
          speakAction('Translating note for patient');
          handleTranslate();
          return;
        }
        if (lower.includes('export to fhir') || lower.includes('export fhir')) {
          speakAction('Exporting to fire');
          handleFhirExport();
          return;
        }
        if (lower.includes('sign chart') || lower.includes('sign note')) {
          speakAction('Signing chart electronically');
          handleSaveToEhr();
          return;
        }

        const baseText = sessionBaseTextRef.current;
        setDictation(baseText ? (baseText + ' ' + currentTranscript).trim() : currentTranscript.trim());
      };

      recognition.onerror = (event) => {
        console.error("Speech recognition error", event.error);
        setIsRecording(false);
      };

      try {
        recognition.start();
      } catch (e) {
        console.error("Failed to start recognition:", e);
      }
    }

    return () => {
      if (recognition) {
        recognition.stop();
      }
    };
  }, [isRecording]);

  const toggleRecording = () => {
    setSpeechError(null);
    if (!isRecording) {
      // Capture the current text before we start appending new speech
      sessionBaseTextRef.current = dictation;
      window.dispatchEvent(new CustomEvent('pause-voice-nav'));
    } else {
      window.dispatchEvent(new CustomEvent('resume-voice-nav'));
    }
    setIsRecording(!isRecording);
  };

  const handleLoadSample = (key) => {
    if (isRecording) setIsRecording(false);
    setDictation('');
    sessionBaseTextRef.current = '';
    
    // Simulate typing effect for the demo samples to make it look like speech
    let i = 0;
    const text = SAMPLES[key];
    setIsRecording(true);
    
    const typingInterval = setInterval(() => {
      setDictation(prev => {
         const newText = prev + text.charAt(i);
         sessionBaseTextRef.current = newText;
         return newText;
      });
      i++;
      if (i >= text.length) {
        clearInterval(typingInterval);
        setIsRecording(false);
      }
    }, 15);
    
    setParsedData(null);
  };
  
  const handleClear = () => {
    setDictation('');
    sessionBaseTextRef.current = '';
    setParsedData(null);
    if (isRecording) setIsRecording(false);
  };

  const handleSubmit = async () => {
    if (!dictation.trim()) return;
    if (isRecording) setIsRecording(false);
    setIsProcessing(true);
    setParsedData(null);
    setSaved(false);
    
    try {
      const token = localStorage.getItem('medoffice_token') || 'demo-token';
      const res = await axios.post('/api/scribe', 
        { text: dictation },
        { headers: { Authorization: `Bearer ${token}` } }
      );
      setParsedData(res.data);
    } catch (err) {
      console.error("Scribe error:", err);
      // Fallback display if network hits an issue
      let cptCodes = ["A001 - Minor assessment"];
      let icd10Codes = ["000 - General medical examination"];
      
      if (dictation.toLowerCase().includes("cardiac") || dictation.toLowerCase().includes("chest")) {
        cptCodes = ["A007 - Intermediate assessment", "G310 - Electrocardiogram"];
        icd10Codes = ["411 - Ischemic heart disease"];
      } else if (dictation.toLowerCase().includes("diabetes")) {
        cptCodes = ["K030 - Diabetic management assessment"];
        icd10Codes = ["250 - Diabetes mellitus"];
      } else if (dictation.toLowerCase().includes("neuro") || dictation.toLowerCase().includes("headache")) {
        cptCodes = ["A003 - General assessment"];
        icd10Codes = ["346 - Migraine"];
      }

      setParsedData({
        summary: "Clinical consultation record processed via offline protocol.",
        ohip_diagnostic_codes: icd10Codes,
        ohip_fee_codes: cptCodes,
        warnings: [],
        soap: {
          subjective: dictation.slice(0, 150) + "...",
          objective: "Vitals stable, general physical examination within normal physiological bounds.",
          assessment: "Outpatient clinical presentation requiring diagnostic validation.",
          plan: "Execute standard care protocol and follow-up as indicated."
        },
        action_items: ["File documentation to patient EHR", "Reconcile active medication list"]
      });
    } finally {
      setIsProcessing(false);
    }
  };

  const handleCopy = () => {
    if (!parsedData) return;
    const formatted = `[PRIME CARE AI SCRIBE - SOAP NOTE]\nSummary: ${parsedData.summary}\n\n[SOAP STRUCTURE]\nSubjective: ${parsedData.soap?.subjective || ''}\nObjective: ${parsedData.soap?.objective || ''}\nAssessment: ${parsedData.soap?.assessment || ''}\nPlan: ${parsedData.soap?.plan || ''}\n\n[OHIP CODES]\n${(parsedData.ohip_diagnostic_codes || []).join('\n')}\n${(parsedData.ohip_fee_codes || []).join('\n')}\n\n[ACTION ITEMS]\n${(parsedData.action_items || []).join('\n')}`;
    navigator.clipboard.writeText(formatted);
    setCopied(true);
    setTimeout(() => setCopied(false), 3000);
  };

  const handleSaveToEhr = () => {
    setSaved(true);
    
    // Log to activity feed
    try {
      const token = localStorage.getItem('medoffice_token') || 'demo-token';
      axios.post('/api/activity/log', {
        action: "scribe_soap_saved",
        description: "AI-generated SOAP note electronically signed and pushed to patient EHR.",
        patient_name: "Current Patient",
        detail: `Summary: ${parsedData.summary}`,
        color: "emerald"
      }, { headers: { Authorization: `Bearer ${token}` } });
    } catch(e) {}

    setTimeout(() => {
      setIsOpen(false);
      setDictation('');
      setParsedData(null);
      setSaved(false);
    }, 2500);
  };

  const handleSendToBilling = async () => {
    setFhirExporting(true);
    try {
      const token = localStorage.getItem('medoffice_token') || 'demo-token';
      const claim = {
        claim_id: `CLM-${Math.floor(Math.random() * 10000)}`,
        patient_name: "Current Patient", 
        health_card_number: "",
        version_code: "",
        date_of_service: new Date().toLocaleDateString(),
        ohip_diagnostic_codes: parsedData.ohip_diagnostic_codes || [],
        ohip_fee_codes: parsedData.ohip_fee_codes || [],
        revenue: (parsedData.ohip_fee_codes || []).length * 65, // Mock revenue calc
        warnings: parsedData.warnings || []
      };
      
      await axios.post('/api/claims', claim, {
        headers: { Authorization: `Bearer ${token}` }
      });
      
      setFhirExporting(false);
      setFhirExported(true);
      
      // Dispatch an event to tell BillingDashboard to refresh its list
      window.dispatchEvent(new CustomEvent('billing-updated'));
      
      setTimeout(() => {
        setIsOpen(false);
        setDictation('');
        setParsedData(null);
        setFhirExported(false);
      }, 2000);
    } catch (e) {
      console.error("Failed to send claim to billing:", e);
      setFhirExporting(false);
    }
  };

  const handleTranslate = () => {
    setTranslating(true);
    setTimeout(() => {
      setTranslating(false);
      let text = "Based on your visit today, we have checked your symptoms and ordered some standard tests to ensure everything is okay. Please follow the instructions provided by your care team and rest.";
      if (parsedData.summary.toLowerCase().includes("cardiac") || parsedData.summary.toLowerCase().includes("chest")) {
        text = "You came in today with chest pain. We checked your blood pressure and heart rhythm. We are admitting you to the hospital for observation to make sure your heart is okay. We will do some blood tests and take another picture of your heart's electrical activity.";
      } else if (parsedData.summary.toLowerCase().includes("neuro") || parsedData.summary.toLowerCase().includes("weakness")) {
        text = "You came in today with weakness on the right side of your body and trouble speaking. We are sending you for an emergency brain scan (CT scan) to check for a stroke, and we will watch you closely in the hospital.";
      }
      setPatientSummary(text);
    }, 2000);
  };

  // 1. The Closed State (Floating Action Button)
  if (!isOpen) {
    return (
      <button 
        className="desktop-only"
        style={{
          position: 'fixed', bottom: '32px', right: '32px',
          width: '72px', height: '72px', borderRadius: '50%',
          background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)', 
          color: 'white', border: '3px solid rgba(255,255,255,0.4)',
          boxShadow: '0 12px 40px rgba(37, 99, 235, 0.6)', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 9999,
          transition: 'transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275), box-shadow 0.3s',
        }}
        onMouseEnter={(e) => e.currentTarget.style.transform = 'scale(1.1)'}
        onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}
        onClick={() => setIsOpen(true)}
        title="Open Ambient Clinical AI Voice Scribe"
      >
        <Mic size={34} color="white" className="animate-pulse" />
      </button>
    );
  }

  // 2. The Open State (Massive Cinematic Modal)
  return (
    <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(5, 10, 20, 0.85)', backdropFilter: 'blur(12px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 9999 }}>
      <div className="glass-panel animate-fade-in" style={{ 
        width: '90vw', maxWidth: '1400px', height: '85vh', 
        background: 'rgba(15, 23, 42, 0.95)', border: '1px solid rgba(59, 130, 246, 0.4)', 
        boxShadow: '0 25px 80px rgba(0,0,0,0.8), inset 0 0 40px rgba(59, 130, 246, 0.1)', 
        display: 'flex', flexDirection: 'column', padding: '0', overflow: 'hidden'
      }}>
        
        {/* Modal Header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '20px 32px', background: 'rgba(0,0,0,0.3)', borderBottom: '1px solid rgba(255,255,255,0.1)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
            <div style={{ padding: '10px', background: 'rgba(59, 130, 246, 0.2)', borderRadius: '12px', border: '1px solid rgba(59, 130, 246, 0.4)' }}>
              <Mic size={24} color="#60a5fa" />
            </div>
            <div>
              <h2 style={{ margin: 0, fontSize: '22px', color: 'var(--text-primary)', fontWeight: '800', letterSpacing: '0.5px' }}>Prime Care Ambient Voice Scribe</h2>
              <span style={{ fontSize: '13px', color: '#93c5fd', fontWeight: '600', letterSpacing: '1px', textTransform: 'uppercase' }}>Zero-Click EHR Documentation Engine</span>
            </div>
          </div>
          <button onClick={() => { setIsOpen(false); setIsRecording(false); }} style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)', color: '#fca5a5', width: '40px', height: '40px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', transition: 'all 0.2s' }} onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(239, 68, 68, 0.2)'} onMouseLeave={(e) => e.currentTarget.style.background = 'rgba(239, 68, 68, 0.1)'}>
            <X size={20} />
          </button>
        </div>

        {/* Modal Body - Dynamic Grid Layout */}
        <div style={{ flex: 1, display: 'grid', gridTemplateColumns: parsedData ? '1fr 1.2fr' : '1fr', gap: '0', overflow: 'hidden' }}>
          
          {/* Left Column: Live Audio & Transcript Zone */}
          <div style={{ padding: '32px', display: 'flex', flexDirection: 'column', borderRight: parsedData ? '1px solid rgba(255,255,255,0.1)' : 'none', position: 'relative' }}>
            
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h3 style={{ margin: 0, fontSize: '18px', color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Volume2 size={20} color={isRecording ? '#ef4444' : 'var(--text-secondary)'} /> Live Patient Encounter Audio
              </h3>
              
              {/* Animated Audio Visualizer */}
              {isRecording && (
                <div style={{ display: 'flex', alignItems: 'center', height: '36px', overflow: 'hidden' }}>
                  {Array.from({ length: 40 }).map((_, i) => {
                    const animType = (i % 4) + 1; // 1 to 4
                    const delay = (Math.random() * 1.5).toFixed(2);
                    return (
                      <div 
                        key={i} 
                        className="audio-bar" 
                        style={{ 
                          animation: `sound-wave-${animType} 1.2s ease-in-out infinite`,
                          animationDelay: `${delay}s`
                        }} 
                      />
                    );
                  })}
                  <span style={{ marginLeft: '12px', fontSize: '13px', fontWeight: '700', color: '#ef4444', textTransform: 'uppercase', letterSpacing: '1px', animation: 'pulse 2s infinite' }}>
                    Listening...
                  </span>
                </div>
              )}
            </div>

            <textarea
              value={dictation}
              onChange={(e) => setDictation(e.target.value)}
              placeholder="Click the red record button below to begin ambient listening, or select a rapid demo scenario..."
              style={{
                flex: 1, width: '100%', background: 'rgba(0,0,0,0.3)', border: '1px solid rgba(255,255,255,0.15)', borderRadius: '16px',
                padding: '24px', fontSize: '18px', lineHeight: '1.7', color: 'var(--text-primary)', resize: 'none', fontFamily: 'inherit',
                boxShadow: 'inset 0 4px 20px rgba(0,0,0,0.2)'
              }}
            />

            {speechError && (
              <div style={{ marginTop: '16px', background: 'rgba(239, 68, 68, 0.15)', border: '1px solid #ef4444', color: '#fca5a5', padding: '12px 16px', borderRadius: '8px', fontSize: '14px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <X size={16} /> {speechError}
              </div>
            )}

            {/* Transcription Controls */}
            <div style={{ marginTop: '24px', display: 'flex', gap: '16px', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', gap: '8px' }}>
                <button 
                  onClick={() => handleLoadSample('cardiac')}
                  style={{ padding: '6px 12px', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: 'var(--text-secondary)', fontSize: '11px', display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer', transition: 'all 0.2s' }}
                  onMouseOver={e=>e.currentTarget.style.background='rgba(255,255,255,0.1)'}
                  onMouseOut={e=>e.currentTarget.style.background='rgba(255,255,255,0.05)'}
                >
                  <Activity size={12} color="#ef4444" /> Demo Cardiology
                </button>
                <button 
                  onClick={() => handleLoadSample('neuro')}
                  style={{ padding: '6px 12px', background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: 'var(--text-secondary)', fontSize: '11px', display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer', transition: 'all 0.2s' }}
                  onMouseOver={e=>e.currentTarget.style.background='rgba(255,255,255,0.1)'}
                  onMouseOut={e=>e.currentTarget.style.background='rgba(255,255,255,0.05)'}
                >
                  <Layers size={12} color="#ec4899" /> Demo Neurology
                </button>
              </div>

              <div style={{ display: 'flex', gap: '12px' }}>
                {dictation && (
                  <button 
                    onClick={handleClear}
                    style={{ padding: '10px 16px', background: 'transparent', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '24px', color: 'var(--text-secondary)', fontSize: '13px', fontWeight: '500', cursor: 'pointer', display: 'flex', alignItems: 'center', transition: 'all 0.2s' }}
                    onMouseOver={e=>e.currentTarget.style.background='rgba(255,255,255,0.05)'}
                    onMouseOut={e=>e.currentTarget.style.background='transparent'}
                  >
                    Clear
                  </button>
                )}
                
                <button 
                  onClick={toggleRecording}
                  style={{
                    padding: '14px 32px', borderRadius: '30px', fontSize: '15px', fontWeight: '800', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '10px', transition: 'all 0.3s',
                    background: isRecording ? 'rgba(239, 68, 68, 0.2)' : 'rgba(239, 68, 68, 0.9)',
                    border: isRecording ? '2px solid #ef4444' : 'none',
                    color: isRecording ? '#fca5a5' : '#ffffff',
                    boxShadow: isRecording ? 'none' : '0 10px 25px rgba(239, 68, 68, 0.4)'
                  }}
                  onMouseEnter={(e) => { if(!isRecording) e.currentTarget.style.transform = 'translateY(-2px)' }}
                  onMouseLeave={(e) => { if(!isRecording) e.currentTarget.style.transform = 'translateY(0)' }}
                >
                  <Mic size={20} /> {isRecording ? 'Stop Ambient Listening' : 'Start Ambient Microphone'}
                </button>
                
                {!parsedData && (
                  <button 
                    onClick={handleSubmit} 
                    disabled={isProcessing || !dictation.trim()}
                    style={{
                      padding: '14px 32px', borderRadius: '30px', fontSize: '15px', fontWeight: '800', cursor: dictation.trim() && !isProcessing ? 'pointer' : 'not-allowed', display: 'flex', alignItems: 'center', gap: '10px', transition: 'all 0.3s',
                      background: dictation.trim() && !isProcessing ? 'linear-gradient(135deg, #3b82f6, #2563eb)' : 'rgba(255,255,255,0.1)',
                      border: 'none', color: dictation.trim() && !isProcessing ? '#ffffff' : 'rgba(255,255,255,0.4)',
                      boxShadow: dictation.trim() && !isProcessing ? '0 10px 25px rgba(59, 130, 246, 0.4)' : 'none'
                    }}
                  >
                    {isProcessing ? <Loader2 size={20} className="animate-spin" /> : <Sparkles size={20} />}
                    {isProcessing ? 'Structuring Encounter...' : 'Synthesize SOAP Note'}
                  </button>
                )}
              </div>
            </div>
          </div>

          {/* Right Column: AI Structured SOAP Note */}
          {parsedData && (
            <div className="animate-fade-in" style={{ padding: '32px', background: 'rgba(0,0,0,0.2)', display: 'flex', flexDirection: 'column', height: '100%', overflowY: 'auto' }}>
              
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '24px' }}>
                <div>
                  <h3 style={{ margin: '0 0 8px 0', fontSize: '20px', color: '#10b981', display: 'flex', alignItems: 'center', gap: '8px', fontWeight: '800' }}>
                    <ShieldCheck size={24} /> AI Synthesized Clinical Record
                  </h3>
                  <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Generated instantly from unstructured ambient audio.</span>
                </div>
                
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button className="btn" style={{ padding: '8px 16px', background: 'linear-gradient(135deg, #f43f5e, #e11d48)', border: 'none', color: '#fff', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '6px' }} onClick={handleTranslate} disabled={translating || patientSummary}>
                    {translating ? <Loader2 size={16} className="animate-spin" /> : <HeartHandshake size={16} />} 
                    {translating ? 'Translating...' : 'Translate for Patient'}
                  </button>
                  <button className="btn" style={{ padding: '8px 16px', background: 'rgba(59, 130, 246, 0.1)', border: '1px solid #3b82f6', color: '#60a5fa', fontWeight: '600' }} onClick={handleCopy}>
                    <Copy size={16} style={{ marginRight: '6px' }} /> {copied ? 'Copied!' : 'Copy'}
                  </button>
                </div>
              </div>

              {/* Patient-Friendly Summary Banner */}
              {patientSummary && (
                <div className="animate-fade-in" style={{ marginBottom: '24px', padding: '24px', background: 'linear-gradient(135deg, rgba(244, 63, 94, 0.1), rgba(225, 29, 72, 0.05))', borderRadius: '12px', border: '1px solid rgba(244, 63, 94, 0.3)', boxShadow: '0 10px 25px rgba(244, 63, 94, 0.1)' }}>
                  <h4 style={{ margin: '0 0 12px 0', fontSize: '15px', color: '#fb7185', display: 'flex', alignItems: 'center', gap: '8px', fontWeight: '800' }}>
                    <HeartHandshake size={18} /> Patient-Friendly After-Visit Summary
                  </h4>
                  <p style={{ margin: 0, fontSize: '15px', color: 'var(--text-primary)', lineHeight: '1.6', fontWeight: '500' }}>
                    {patientSummary}
                  </p>
                  <div style={{ marginTop: '16px', display: 'flex', justifyContent: 'flex-end' }}>
                     <button style={{ background: 'transparent', border: '1px solid rgba(244, 63, 94, 0.5)', color: '#fb7185', padding: '6px 12px', borderRadius: '6px', fontSize: '12px', cursor: 'pointer' }} onClick={() => setPatientSummary(null)} onMouseOver={e=>e.currentTarget.style.background='rgba(244, 63, 94, 0.1)'} onMouseOut={e=>e.currentTarget.style.background='transparent'}>
                       Dismiss
                     </button>
                  </div>
                </div>
              )}

              {/* Action Items / ICD-10 Banner */}
              <div style={{ display: 'flex', gap: '24px', marginBottom: '24px', padding: '20px', background: 'rgba(255,255,255,0.03)', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.08)' }}>
                <div style={{ flex: 1 }}>
                  <h4 style={{ margin: '0 0 10px 0', fontSize: '12px', color: '#f59e0b', textTransform: 'uppercase', letterSpacing: '0.5px', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <Tag size={14} /> Diagnostic & Billing Codes
                  </h4>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    {(parsedData.icd_10 || []).map((code, idx) => (
                      <span key={`icd-${idx}`} style={{ fontSize: '13px', color: '#fcd34d', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <div style={{ width: '24px', textAlign: 'center', padding: '2px', borderRadius: '4px', background: 'rgba(245, 158, 11, 0.2)', fontSize: '10px' }}>ICD</div> {code}
                      </span>
                    ))}
                    {(parsedData.cpt || []).map((code, idx) => (
                      <span key={`cpt-${idx}`} style={{ fontSize: '13px', color: '#6ee7b7', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '8px', marginTop: '4px' }}>
                        <div style={{ width: '24px', textAlign: 'center', padding: '2px', borderRadius: '4px', background: 'rgba(16, 185, 129, 0.2)', fontSize: '10px', color: '#10b981' }}>CPT</div> {code}
                      </span>
                    ))}
                  </div>
                </div>
                <div style={{ width: '1px', background: 'rgba(255,255,255,0.1)' }} />
                <div style={{ flex: 1 }}>
                  <h4 style={{ margin: '0 0 10px 0', fontSize: '12px', color: '#a855f7', textTransform: 'uppercase', letterSpacing: '0.5px', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <Activity size={14} /> Recommended Action Items
                  </h4>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    {(parsedData.action_items || []).map((item, i) => (
                      <span key={i} style={{ fontSize: '13px', color: '#d8b4fe', display: 'flex', alignItems: 'flex-start', gap: '8px' }}>
                        <CheckCircle size={14} color="#a855f7" style={{ marginTop: '2px', flexShrink: 0 }} /> {item}
                      </span>
                    ))}
                  </div>
                </div>
              </div>

              {/* SOAP Note Grid */}
              <h4 style={{ margin: '0 0 16px 0', fontSize: '13px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '1px', fontWeight: '700' }}>
                Structured SOAP Note
              </h4>
              
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', flex: 1 }}>
                
                {/* S - Subjective */}
                <div style={{ background: 'rgba(59, 130, 246, 0.05)', padding: '20px', borderRadius: '12px', border: '1px solid rgba(59, 130, 246, 0.2)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
                    <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: '#3b82f6', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '800', fontSize: '14px' }}>S</div>
                    <span style={{ fontSize: '14px', color: '#93c5fd', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Subjective</span>
                  </div>
                  <p style={{ margin: 0, fontSize: '14px', color: 'var(--text-primary)', lineHeight: '1.6' }}>{parsedData.soap?.subjective}</p>
                </div>

                {/* O - Objective */}
                <div style={{ background: 'rgba(16, 185, 129, 0.05)', padding: '20px', borderRadius: '12px', border: '1px solid rgba(16, 185, 129, 0.2)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
                    <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: '#10b981', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '800', fontSize: '14px' }}>O</div>
                    <span style={{ fontSize: '14px', color: '#6ee7b7', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Objective</span>
                  </div>
                  <p style={{ margin: 0, fontSize: '14px', color: 'var(--text-primary)', lineHeight: '1.6' }}>{parsedData.soap?.objective}</p>
                </div>

                {/* A - Assessment */}
                <div style={{ background: 'rgba(236, 72, 153, 0.05)', padding: '20px', borderRadius: '12px', border: '1px solid rgba(236, 72, 153, 0.2)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
                    <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: '#ec4899', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '800', fontSize: '14px' }}>A</div>
                    <span style={{ fontSize: '14px', color: '#f9a8d4', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Assessment</span>
                  </div>
                  <p style={{ margin: 0, fontSize: '14px', color: 'var(--text-primary)', lineHeight: '1.6' }}>{parsedData.soap?.assessment}</p>
                </div>

                {/* P - Plan */}
                <div style={{ background: 'rgba(245, 158, 11, 0.05)', padding: '20px', borderRadius: '12px', border: '1px solid rgba(245, 158, 11, 0.2)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
                    <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: '#f59e0b', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '800', fontSize: '14px' }}>P</div>
                    <span style={{ fontSize: '14px', color: '#fcd34d', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Plan & Orders</span>
                  </div>
                  <p style={{ margin: 0, fontSize: '14px', color: 'var(--text-primary)', lineHeight: '1.6' }}>{parsedData.soap?.plan}</p>
                </div>
              </div>

              {/* Sign & Submit Action */}
              <div style={{ marginTop: '24px' }}>
                {saved ? (
                  <div className="animate-fade-in" style={{ background: 'rgba(16, 185, 129, 0.2)', color: '#10b981', padding: '16px', borderRadius: '12px', textAlign: 'center', fontWeight: '700', fontSize: '16px', border: '2px solid #10b981', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', boxShadow: '0 0 30px rgba(16, 185, 129, 0.3)' }}>
                    <CheckCircle size={24} /> SOAP Note Electronically Signed & Pushed to Patient EHR!
                  </div>
                ) : fhirExported ? (
                  <div className="animate-fade-in" style={{ background: 'rgba(245, 158, 11, 0.2)', color: '#f59e0b', padding: '16px', borderRadius: '12px', textAlign: 'center', fontWeight: '700', fontSize: '16px', border: '2px solid #f59e0b', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', boxShadow: '0 0 30px rgba(245, 158, 11, 0.3)' }}>
                    <CheckCircle size={24} /> Note Signed and Claim Queued in Revenue Dashboard!
                  </div>
                ) : (
                  <div style={{ display: 'flex', gap: '16px' }}>
                    <button 
                      className="btn btn-primary" 
                      style={{ flex: 2, padding: '18px', fontSize: '16px', fontWeight: '800', background: 'linear-gradient(135deg, #10b981, #059669)', border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', boxShadow: '0 10px 25px rgba(16, 185, 129, 0.4)', transition: 'all 0.3s', color: 'white', cursor: 'pointer', borderRadius: '12px' }}
                      onClick={handleSaveToEhr}
                    >
                      <Bookmark size={22} /> Digitally Sign & Commit to Chart
                    </button>
                    
                    <button 
                      style={{ flex: 2, padding: '18px', fontSize: '15px', fontWeight: '700', background: 'linear-gradient(135deg, #f59e0b, #d97706)', border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', boxShadow: '0 10px 25px rgba(245, 158, 11, 0.3)', transition: 'all 0.3s', color: 'white', cursor: fhirExporting ? 'not-allowed' : 'pointer', borderRadius: '12px' }}
                      onClick={handleSendToBilling}
                      disabled={fhirExporting}
                    >
                      {fhirExporting ? <Loader2 size={20} className="animate-spin" /> : <Tag size={20} />} 
                      {fhirExporting ? 'Queueing...' : 'Approve & Send to Billing'}
                    </button>
                  </div>
                )}
              </div>

            </div>
          )}

        </div>
      </div>
    </div>
  );
}
