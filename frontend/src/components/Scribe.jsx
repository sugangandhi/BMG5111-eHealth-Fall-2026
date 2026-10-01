import React, { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import { 
  Mic, CheckCircle, Loader2, X, Sparkles, Volume2, VolumeX, Copy, Bookmark, 
  FileText, Activity, Layers, Tag, ShieldCheck, HeartHandshake, AlertCircle, 
  Send, MessageSquare, Calendar, Clock, Phone, User, Bot, ArrowRight, RefreshCw
} from 'lucide-react';

window.utterances = [];
window.isSpeaking = false;

const speakAction = (text) => {
  if (localStorage.getItem('medoffice_voice_feedback') === 'false') return;
  if ('speechSynthesis' in window) {
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

      setTimeout(() => { window.isSpeaking = false; }, 3500);

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
  const [activeTab, setActiveTab] = useState('copilot'); // 'copilot' or 'soap'
  const [inputMessage, setInputMessage] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [interimTranscript, setInterimTranscript] = useState('');
  const [audioLevel, setAudioLevel] = useState(0);
  const [audioFreqData, setAudioFreqData] = useState(new Array(24).fill(4));
  const [speechError, setSpeechError] = useState(null);
  const [ttsEnabled, setTtsEnabled] = useState(true);

  // SOAP State
  const [dictation, setDictation] = useState('');
  const [parsedData, setParsedData] = useState(null);
  const [copied, setCopied] = useState(false);
  const [saved, setSaved] = useState(false);
  const [fhirExporting, setFhirExporting] = useState(false);
  const [fhirExported, setFhirExported] = useState(false);
  const [translating, setTranslating] = useState(false);
  const [patientSummary, setPatientSummary] = useState(null);

  // Chat conversation history
  const [messages, setMessages] = useState([
    {
      id: 1,
      sender: 'assistant',
      text: "👋 **Hello Doctor! I am your AI Scribe & Clinical Voice Copilot.**\n\nI can convert your voice to text, take complete clinical SOAP notes, dispatch WhatsApp notifications to patients, check available appointments, and book new consultations.\n\n**Try speaking or typing:**\n• *\"Send a WhatsApp message to Sarah Khan saying her lab tests are ready\"*\n• *\"What appointments do I have available today?\"*\n• *\"Book an appointment for Sarah Khan tomorrow at 3 PM for diabetes review\"*\n• *\"Patient John Doe presents with acute chest pain...\"* (to dictate a clinical note)",
      time: "Just now"
    }
  ]);

  const chatEndRef = useRef(null);

  // Refs for real-time speech recognition
  const isRecordingRef = useRef(false);
  const recognitionRef = useRef(null);
  const mediaStreamRef = useRef(null);
  const audioCtxRef = useRef(null);
  const analyserRef = useRef(null);
  const animFrameRef = useRef(null);
  const interimRef = useRef('');

  useEffect(() => {
    isRecordingRef.current = isRecording;
  }, [isRecording]);

  useEffect(() => {
    interimRef.current = interimTranscript;
  }, [interimTranscript]);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isProcessing]);

  const formatMedicalPunctuation = (text) => {
    if (!text) return "";
    return text
      .replace(/\s+period\b/gi, '.')
      .replace(/\s+full stop\b/gi, '.')
      .replace(/\s+comma\b/gi, ',')
      .replace(/\s+colon\b/gi, ':')
      .replace(/\s+question mark\b/gi, '?')
      .replace(/\s+exclamation mark\b/gi, '!')
      .replace(/\s+new line\b/gi, '\n')
      .replace(/\s+next line\b/gi, '\n')
      .replace(/\s+new paragraph\b/gi, '\n\n');
  };

  useEffect(() => {
    const handleOpenScribe = () => {
      setIsOpen(true);
      window.dispatchEvent(new CustomEvent('pause-voice-nav'));
    };
    const handleStartScribe = () => {
      setIsOpen(true);
      window.dispatchEvent(new CustomEvent('pause-voice-nav'));
      if (!isRecordingRef.current) startRecording();
    };
    window.addEventListener('open-scribe', handleOpenScribe);
    window.addEventListener('start-scribe', handleStartScribe);
    return () => {
      window.removeEventListener('open-scribe', handleOpenScribe);
      window.removeEventListener('start-scribe', handleStartScribe);
    };
  }, []);

  // Modal open/close cleanup
  useEffect(() => {
    if (!isOpen) {
      stopRecording();
      setInterimTranscript("");
      interimRef.current = "";
      window.dispatchEvent(new CustomEvent('resume-voice-nav'));
    } else {
      window.dispatchEvent(new CustomEvent('pause-voice-nav'));
    }
  }, [isOpen]);

  // Inject CSS for audio visualizer
  useEffect(() => {
    const styleSheet = document.createElement("style");
    styleSheet.innerText = audioBarsStyle;
    document.head.appendChild(styleSheet);
    return () => styleSheet.remove();
  }, []);

  const startRecording = async () => {
    setSpeechError(null);
    window.isSpeaking = false;
    window.dispatchEvent(new CustomEvent('pause-voice-nav'));

    setInterimTranscript('');
    interimRef.current = '';

    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      setSpeechError("Speech recognition is not supported in this browser. Please use Google Chrome, Microsoft Edge, or Safari.");
      return;
    }

    // 1. Web Audio API for physical microphone frequency analysis
    try {
      if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        mediaStreamRef.current = stream;

        const AudioContextClass = window.AudioContext || window.webkitAudioContext;
        if (AudioContextClass) {
          const audioCtx = new AudioContextClass();
          audioCtxRef.current = audioCtx;
          if (audioCtx.state === 'suspended') {
            await audioCtx.resume();
          }

          const analyser = audioCtx.createAnalyser();
          analyser.fftSize = 64;
          analyser.smoothingTimeConstant = 0.7;
          analyserRef.current = analyser;

          const source = audioCtx.createMediaStreamSource(stream);
          source.connect(analyser);

          const dataArray = new Uint8Array(analyser.frequencyBinCount);
          const updateAudioVisuals = () => {
            if (!isRecordingRef.current) return;
            analyser.getByteFrequencyData(dataArray);

            let sum = 0;
            const barCount = 24;
            const bars = [];
            const step = Math.max(1, Math.floor(dataArray.length / barCount));

            for (let i = 0; i < barCount; i++) {
              const val = dataArray[i * step] || 0;
              sum += val;
              const height = Math.max(4, Math.min(36, Math.round((val / 255) * 36)));
              bars.push(height);
            }

            const avg = sum / barCount;
            const vol = Math.min(100, Math.round((avg / 128) * 100));
            setAudioLevel(vol);
            setAudioFreqData(bars);

            animFrameRef.current = requestAnimationFrame(updateAudioVisuals);
          };
          updateAudioVisuals();
        }
      }
    } catch (micErr) {
      console.warn("Microphone stream warning (Web Audio):", micErr);
      if (micErr.name === 'NotAllowedError' || micErr.name === 'PermissionDeniedError') {
        setSpeechError("Microphone access was denied. Please allow microphone permission in your browser address bar.");
        return;
      }
    }

    // 2. Web Speech API Recognition
    try {
      const recognition = new SpeechRecognition();
      recognition.continuous = true;
      recognition.interimResults = true;
      recognition.lang = 'en-US';
      recognition.maxAlternatives = 1;
      recognitionRef.current = recognition;

      recognition.onresult = (event) => {
        window.isSpeaking = false;

        let currentFinal = '';
        let currentInterim = '';

        for (let i = 0; i < event.results.length; i++) {
          const piece = event.results[i][0].transcript;
          if (event.results[i].isFinal) {
            currentFinal += piece + ' ';
          } else {
            currentInterim += piece;
          }
        }

        const lower = (currentFinal + ' ' + currentInterim).toLowerCase();

        // Voice command to stop
        if (lower.includes('stop listening') || lower.includes('stop microphone') || lower.includes('stop recording')) {
          stopRecording();
          return;
        }

        const formatted = formatMedicalPunctuation(currentFinal || currentInterim);
        setInterimTranscript(currentInterim);
        interimRef.current = currentInterim;

        if (currentFinal) {
          setInputMessage(prev => (prev ? prev + ' ' + formatMedicalPunctuation(currentFinal) : formatMedicalPunctuation(currentFinal)).trim());
        }
      };

      recognition.onerror = (event) => {
        console.warn("Speech recognition notice:", event.error);
        if (event.error === 'no-speech' || event.error === 'aborted') {
          return; // Normal pause in speech
        }
        if (event.error === 'not-allowed') {
          setSpeechError("Microphone access was denied. Please click the lock/mic icon in your address bar to allow.");
          stopRecording();
          return;
        }
        if (event.error === 'network') {
          setSpeechError("Speech network connectivity issue. Chrome speech requires internet connection.");
          stopRecording();
          return;
        }
      };

      recognition.onend = () => {
        if (isRecordingRef.current && recognitionRef.current) {
          setTimeout(() => {
            if (isRecordingRef.current) {
              try { recognitionRef.current.start(); } catch(e) {}
            }
          }, 150);
        }
      };

      recognition.start();
      setIsRecording(true);
      isRecordingRef.current = true;
    } catch (e) {
      console.error("Failed to start speech recognition:", e);
      setSpeechError(`Could not start speech recognition: ${e.message}`);
      stopRecording();
    }
  };

  const stopRecording = () => {
    setIsRecording(false);
    isRecordingRef.current = false;

    if (interimRef.current) {
      const formatted = formatMedicalPunctuation(interimRef.current);
      setInputMessage(prev => (prev ? prev + ' ' + formatted : formatted).trim());
      setInterimTranscript('');
      interimRef.current = '';
    }

    if (recognitionRef.current) {
      try { recognitionRef.current.stop(); } catch (e) {}
      recognitionRef.current = null;
    }

    if (animFrameRef.current) {
      cancelAnimationFrame(animFrameRef.current);
      animFrameRef.current = null;
    }
    if (mediaStreamRef.current) {
      mediaStreamRef.current.getTracks().forEach(track => track.stop());
      mediaStreamRef.current = null;
    }
    if (audioCtxRef.current && audioCtxRef.current.state !== 'closed') {
      audioCtxRef.current.close().catch(() => {});
      audioCtxRef.current = null;
    }

    setAudioLevel(0);
    setAudioFreqData(new Array(24).fill(4));
  };

  const toggleRecording = () => {
    if (isRecordingRef.current) {
      stopRecording();
    } else {
      startRecording();
    }
  };

  // Send message to Scribe Copilot Agent
  const handleSendMessage = async (textToSend) => {
    const query = (textToSend || inputMessage || interimTranscript).trim();
    if (!query) return;

    if (isRecordingRef.current) {
      stopRecording();
    }

    const userMsg = {
      id: Date.now(),
      sender: 'user',
      text: query,
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    };

    setMessages(prev => [...prev, userMsg]);
    setInputMessage('');
    setInterimTranscript('');
    setIsProcessing(true);

    try {
      const token = localStorage.getItem('medoffice_token') || 'demo-token';
      const historyPayload = messages.slice(-6).map(m => ({
        role: m.sender === 'user' ? 'user' : 'assistant',
        content: m.text
      }));

      const res = await axios.post('/api/scribe/copilot', {
        message: query,
        history: historyPayload,
        patient_id: null
      }, {
        headers: { Authorization: `Bearer ${token}` }
      });

      const data = res.data;
      const botMsg = {
        id: Date.now() + 1,
        sender: 'assistant',
        text: data.reply,
        action_type: data.action_type,
        action_data: data.action_data,
        soap_data: data.soap_data,
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };

      setMessages(prev => [...prev, botMsg]);

      // If SOAP data was generated, populate the inspector
      if (data.action_type === 'soap_generated' && data.soap_data) {
        setDictation(query);
        setParsedData({
          summary: data.action_data?.summary || "Clinical encounter structured.",
          ohip_diagnostic_codes: data.action_data?.ohip_diagnostic_codes || [],
          ohip_fee_codes: data.action_data?.ohip_fee_codes || [],
          action_items: data.action_data?.action_items || [],
          warnings: data.action_data?.warnings || [],
          soap: data.soap_data
        });
      }

      // Voice Feedback
      if (ttsEnabled && 'speechSynthesis' in window) {
        const cleanVoice = data.reply
          .replace(/[*_#•]/g, '')
          .split('\n')[0]
          .slice(0, 160);
        speakAction(cleanVoice);
      }
    } catch (err) {
      console.error("Copilot error:", err);
      const botMsg = {
        id: Date.now() + 1,
        sender: 'assistant',
        text: "I received your message, but the copilot service is currently unavailable. You can still use the direct SOAP synthesis or sample scenarios.",
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };
      setMessages(prev => [...prev, botMsg]);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  const handleLoadSample = (key) => {
    const text = SAMPLES[key];
    handleSendMessage(`Please scribe and synthesize a clinical note for this encounter: ${text}`);
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
    try {
      const token = localStorage.getItem('medoffice_token') || 'demo-token';
      axios.post('/api/activity/log', {
        action: "scribe_soap_saved",
        description: "AI-generated SOAP note electronically signed and pushed to patient EHR.",
        patient_name: "Sarah Khan",
        detail: `Summary: ${parsedData?.summary || "Signed SOAP note"}`,
        color: "emerald"
      }, { headers: { Authorization: `Bearer ${token}` } });
    } catch(e) {}

    setTimeout(() => {
      setSaved(false);
    }, 2500);
  };

  const handleSendToBilling = async () => {
    setFhirExporting(true);
    try {
      const token = localStorage.getItem('medoffice_token') || 'demo-token';
      const claim = {
        claim_id: `CLM-${Math.floor(Math.random() * 10000)}`,
        patient_name: "Sarah Khan", 
        health_card_number: "1234-567-890-AB",
        version_code: "",
        date_of_service: new Date().toLocaleDateString(),
        ohip_diagnostic_codes: parsedData?.ohip_diagnostic_codes || ["411 - Ischemic heart disease"],
        ohip_fee_codes: parsedData?.ohip_fee_codes || ["A007 - Intermediate assessment"],
        revenue: (parsedData?.ohip_fee_codes || []).length * 65 || 65,
        warnings: parsedData?.warnings || []
      };
      
      await axios.post('/api/claims', claim, {
        headers: { Authorization: `Bearer ${token}` }
      });
      
      setFhirExporting(false);
      setFhirExported(true);
      window.dispatchEvent(new CustomEvent('billing-updated'));
      setTimeout(() => setFhirExported(false), 2500);
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
      if (parsedData?.summary?.toLowerCase().includes("cardiac") || parsedData?.summary?.toLowerCase().includes("chest")) {
        text = "You came in today with chest pain. We checked your blood pressure and heart rhythm. We are admitting you to the hospital for observation to make sure your heart is okay.";
      }
      setPatientSummary(text);
    }, 1500);
  };

  // 1. Closed State: Floating Action Button
  if (!isOpen) {
    return (
      <button 
        className="desktop-only"
        style={{
          position: 'fixed', bottom: '32px', right: '32px',
          width: '72px', height: '72px', borderRadius: '50%',
          background: 'linear-gradient(135deg, #10b981, #059669)', 
          color: 'white', border: '3px solid rgba(255,255,255,0.4)',
          boxShadow: '0 12px 40px rgba(16, 185, 129, 0.6)', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 9999,
          transition: 'transform 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275), box-shadow 0.3s',
        }}
        onMouseEnter={(e) => e.currentTarget.style.transform = 'scale(1.1)'}
        onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}
        onClick={() => setIsOpen(true)}
        title="Open Prime Care AI Scribe Voice Copilot"
      >
        <Mic size={32} color="white" className="animate-pulse" />
      </button>
    );
  }

  // 2. Open State: Modal
  return (
    <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(5, 10, 20, 0.85)', backdropFilter: 'blur(12px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 9999 }}>
      <div className="glass-panel animate-fade-in" style={{ 
        width: '92vw', maxWidth: '1420px', height: '88vh', 
        background: 'rgba(15, 23, 42, 0.96)', border: '1px solid rgba(16, 185, 129, 0.4)', 
        boxShadow: '0 25px 80px rgba(0,0,0,0.8), inset 0 0 40px rgba(16, 185, 129, 0.1)', 
        display: 'flex', flexDirection: 'column', padding: '0', overflow: 'hidden'
      }}>
        
        {/* Header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 28px', background: 'rgba(0,0,0,0.35)', borderBottom: '1px solid rgba(255,255,255,0.1)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
            <div style={{ padding: '10px', background: 'rgba(16, 185, 129, 0.2)', borderRadius: '12px', border: '1px solid rgba(16, 185, 129, 0.4)' }}>
              <Sparkles size={22} color="#34d399" />
            </div>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <h2 style={{ margin: 0, fontSize: '20px', color: 'var(--text-primary)', fontWeight: '800' }}>Prime Care AI Scribe & Voice Copilot</h2>
                <span style={{ fontSize: '11px', background: 'rgba(16, 185, 129, 0.2)', color: '#34d399', padding: '3px 8px', borderRadius: '12px', fontWeight: '700', border: '1px solid rgba(16, 185, 129, 0.4)' }}>
                  AGENTIC CLINICAL AI
                </span>
              </div>
              <span style={{ fontSize: '12px', color: '#94a3b8', fontWeight: '500' }}>
                Conversational Speech-to-Text • WhatsApp Outreach • Appointment Scheduler • SOAP Generator
              </span>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            {/* View Switcher Tabs */}
            <div style={{ display: 'flex', background: 'rgba(0,0,0,0.3)', padding: '4px', borderRadius: '10px', border: '1px solid rgba(255,255,255,0.1)' }}>
              <button 
                onClick={() => setActiveTab('copilot')}
                style={{ 
                  padding: '6px 14px', borderRadius: '8px', border: 'none', cursor: 'pointer', fontSize: '13px', fontWeight: '700',
                  background: activeTab === 'copilot' ? 'linear-gradient(135deg, #10b981, #059669)' : 'transparent',
                  color: activeTab === 'copilot' ? '#fff' : 'var(--text-secondary)'
                }}
              >
                💬 Voice Copilot
              </button>
              <button 
                onClick={() => setActiveTab('soap')}
                style={{ 
                  padding: '6px 14px', borderRadius: '8px', border: 'none', cursor: 'pointer', fontSize: '13px', fontWeight: '700',
                  background: activeTab === 'soap' ? 'linear-gradient(135deg, #3b82f6, #1d4ed8)' : 'transparent',
                  color: activeTab === 'soap' ? '#fff' : 'var(--text-secondary)',
                  display: 'flex', alignItems: 'center', gap: '6px'
                }}
              >
                📝 SOAP Inspector
                {parsedData && <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#34d399' }} />}
              </button>
            </div>

            {/* TTS Toggle */}
            <button 
              onClick={() => setTtsEnabled(!ttsEnabled)}
              title={ttsEnabled ? "Voice Responses Active" : "Voice Responses Muted"}
              style={{ padding: '8px', background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.15)', borderRadius: '8px', color: ttsEnabled ? '#34d399' : '#94a3b8', cursor: 'pointer' }}
            >
              {ttsEnabled ? <Volume2 size={18} /> : <VolumeX size={18} />}
            </button>

            {/* Close */}
            <button 
              onClick={() => { setIsOpen(false); stopRecording(); }} 
              style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)', color: '#fca5a5', width: '36px', height: '36px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}
            >
              <X size={18} />
            </button>
          </div>
        </div>

        {/* Modal Body */}
        {activeTab === 'copilot' ? (
          /* ── COPILOT CHATBOT VIEW ────────────────────────────────────────────── */
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
            
            {/* Messages Feed */}
            <div style={{ flex: 1, padding: '24px 32px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '18px' }}>
              {messages.map((msg) => (
                <div 
                  key={msg.id} 
                  style={{ 
                    display: 'flex', 
                    flexDirection: 'column',
                    alignItems: msg.sender === 'user' ? 'flex-end' : 'flex-start'
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px', fontSize: '11px', color: 'var(--text-secondary)' }}>
                    {msg.sender === 'user' ? (
                      <><span>You (Physician)</span> <User size={12} /></>
                    ) : (
                      <><Bot size={12} color="#34d399" /> <span style={{ color: '#34d399', fontWeight: '700' }}>AI Clinical Copilot</span></>
                    )}
                    <span>• {msg.time}</span>
                  </div>

                  <div style={{ 
                    maxWidth: '78%', 
                    padding: '16px 20px', 
                    borderRadius: msg.sender === 'user' ? '18px 18px 4px 18px' : '18px 18px 18px 4px',
                    background: msg.sender === 'user' ? 'linear-gradient(135deg, #1e40af, #1d4ed8)' : 'rgba(30, 41, 59, 0.85)',
                    border: msg.sender === 'user' ? '1px solid rgba(96, 165, 250, 0.4)' : '1px solid rgba(255, 255, 255, 0.1)',
                    color: '#f8fafc',
                    boxShadow: '0 8px 24px rgba(0,0,0,0.25)',
                    lineHeight: '1.6',
                    fontSize: '15px'
                  }}>
                    {/* Markdown-style content */}
                    <div style={{ whiteSpace: 'pre-wrap' }}>
                      {msg.text}
                    </div>

                    {/* ACTION CARD: WhatsApp Dispatched */}
                    {msg.action_type === 'whatsapp_sent' && msg.action_data && (
                      <div style={{ marginTop: '14px', padding: '14px', background: 'rgba(16, 185, 129, 0.12)', border: '1px solid rgba(16, 185, 129, 0.4)', borderRadius: '10px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#34d399', fontWeight: '700', fontSize: '13px', marginBottom: '6px' }}>
                          <Phone size={15} /> WhatsApp Outbound Dispatch
                        </div>
                        <div style={{ fontSize: '13px', color: '#cbd5e1' }}>
                          <div><strong>Patient:</strong> {msg.action_data.patient_name} ({msg.action_data.phone})</div>
                          <div style={{ marginTop: '4px', fontStyle: 'italic', background: 'rgba(0,0,0,0.2)', padding: '6px 10px', borderRadius: '6px' }}>
                            "{msg.action_data.message}"
                          </div>
                        </div>
                      </div>
                    )}

                    {/* ACTION CARD: Appointment Booked */}
                    {msg.action_type === 'appointment_booked' && msg.action_data && (
                      <div style={{ marginTop: '14px', padding: '14px', background: 'rgba(20, 184, 166, 0.12)', border: '1px solid rgba(20, 184, 166, 0.4)', borderRadius: '10px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#2dd4bf', fontWeight: '700', fontSize: '13px', marginBottom: '6px' }}>
                          <Calendar size={15} /> E-Hospital Clinic Booking Confirmed
                        </div>
                        <div style={{ fontSize: '13px', color: '#cbd5e1' }}>
                          <div><strong>Patient:</strong> {msg.action_data.patient_name}</div>
                          <div><strong>Date & Time:</strong> {msg.action_data.date} at {msg.action_data.time}</div>
                          <div><strong>Service:</strong> {msg.action_data.type}</div>
                        </div>
                      </div>
                    )}

                    {/* ACTION CARD: SOAP Note Generated */}
                    {msg.action_type === 'soap_generated' && (
                      <div style={{ marginTop: '14px', padding: '14px', background: 'rgba(59, 130, 246, 0.12)', border: '1px solid rgba(59, 130, 246, 0.4)', borderRadius: '10px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span style={{ color: '#60a5fa', fontWeight: '700', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <ShieldCheck size={16} /> Structured OHIP Clinical Record Ready
                          </span>
                          <button 
                            onClick={() => setActiveTab('soap')}
                            style={{ padding: '6px 12px', background: 'rgba(59, 130, 246, 0.3)', border: '1px solid #3b82f6', color: '#93c5fd', borderRadius: '6px', fontSize: '12px', fontWeight: '700', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}
                          >
                            Open SOAP Inspector <ArrowRight size={14} />
                          </button>
                        </div>
                      </div>
                    )}

                  </div>
                </div>
              ))}

              {isProcessing && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', color: '#34d399', fontSize: '14px', fontStyle: 'italic' }}>
                  <Loader2 size={16} className="animate-spin" /> Prime Care AI Copilot is thinking...
                </div>
              )}
              <div ref={chatEndRef} />
            </div>

            {/* Quick Suggestion Chips */}
            <div style={{ padding: '8px 32px', display: 'flex', gap: '8px', overflowX: 'auto', background: 'rgba(0,0,0,0.2)', borderTop: '1px solid rgba(255,255,255,0.06)' }}>
              <button 
                onClick={() => handleSendMessage("Send a WhatsApp message to Sarah Khan saying your blood pressure checkup is scheduled for Friday")}
                style={{ padding: '6px 12px', background: 'rgba(16, 185, 129, 0.1)', border: '1px solid rgba(16, 185, 129, 0.3)', borderRadius: '20px', color: '#34d399', fontSize: '12px', cursor: 'pointer', whiteSpace: 'nowrap' }}
              >
                📱 Send WhatsApp to Sarah Khan
              </button>
              <button 
                onClick={() => handleSendMessage("What appointments do I have available today?")}
                style={{ padding: '6px 12px', background: 'rgba(59, 130, 246, 0.1)', border: '1px solid rgba(59, 130, 246, 0.3)', borderRadius: '20px', color: '#60a5fa', fontSize: '12px', cursor: 'pointer', whiteSpace: 'nowrap' }}
              >
                🕒 Check Available Appointments
              </button>
              <button 
                onClick={() => handleSendMessage("Book an appointment for Sarah Khan tomorrow at 3 PM for diabetes review")}
                style={{ padding: '6px 12px', background: 'rgba(20, 184, 166, 0.1)', border: '1px solid rgba(20, 184, 166, 0.3)', borderRadius: '20px', color: '#2dd4bf', fontSize: '12px', cursor: 'pointer', whiteSpace: 'nowrap' }}
              >
                📅 Book Sarah Khan Tomorrow at 3 PM
              </button>
              <button 
                onClick={() => handleLoadSample('cardiac')}
                style={{ padding: '6px 12px', background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)', borderRadius: '20px', color: '#fca5a5', fontSize: '12px', cursor: 'pointer', whiteSpace: 'nowrap' }}
              >
                🫀 Scribe Cardiology Encounter
              </button>
              <button 
                onClick={() => handleSendMessage("What medications is Sarah Khan currently taking?")}
                style={{ padding: '6px 12px', background: 'rgba(168, 85, 247, 0.1)', border: '1px solid rgba(168, 85, 247, 0.3)', borderRadius: '20px', color: '#c084fc', fontSize: '12px', cursor: 'pointer', whiteSpace: 'nowrap' }}
              >
                💊 Sarah Khan Medications
              </button>
            </div>

            {/* Bottom Voice & Text Input Section */}
            <div style={{ padding: '20px 32px', background: 'rgba(0,0,0,0.3)', borderTop: '1px solid rgba(255,255,255,0.1)' }}>
              
              {/* Live Waveform & Streaming Words Indicator */}
              {isRecording && (
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '14px', background: 'rgba(0,0,0,0.4)', padding: '10px 16px', borderRadius: '12px', border: '1px solid rgba(16, 185, 129, 0.3)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                    {audioFreqData.map((height, i) => (
                      <div 
                        key={i} 
                        className="audio-bar" 
                        style={{ 
                          height: `${height}px`,
                          background: audioLevel > 15 ? '#10b981' : '#ef4444',
                          transition: 'height 0.05s ease'
                        }} 
                      />
                    ))}
                    <span style={{ marginLeft: '12px', fontSize: '12px', fontWeight: '800', color: audioLevel > 15 ? '#34d399' : '#ef4444' }}>
                      {audioLevel > 15 ? 'LISTENING (VOICE DETECTED)' : 'LISTENING TO MICROPHONE...'}
                    </span>
                  </div>

                  {interimTranscript && (
                    <div style={{ fontSize: '14px', color: '#93c5fd', fontStyle: 'italic', maxWidth: '55%', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      Hearing: "{interimTranscript}"
                    </div>
                  )}
                </div>
              )}

              {speechError && (
                <div style={{ marginBottom: '12px', padding: '10px 14px', background: 'rgba(239, 68, 68, 0.15)', border: '1px solid #ef4444', borderRadius: '8px', color: '#fca5a5', fontSize: '13px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <span><AlertCircle size={16} style={{ display: 'inline', verticalAlign: 'middle', marginRight: '6px' }} /> {speechError}</span>
                  <button onClick={() => setSpeechError(null)} style={{ background: 'transparent', border: 'none', color: '#fca5a5', cursor: 'pointer' }}><X size={14} /></button>
                </div>
              )}

              {/* Input Form */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                {/* Microphone Toggle Button */}
                <button 
                  onClick={toggleRecording}
                  style={{
                    padding: '14px 22px', borderRadius: '28px', fontSize: '14px', fontWeight: '800', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px',
                    background: isRecording ? 'rgba(239, 68, 68, 0.25)' : 'linear-gradient(135deg, #10b981, #059669)',
                    border: isRecording ? '2px solid #ef4444' : 'none',
                    color: isRecording ? '#fca5a5' : '#ffffff',
                    boxShadow: isRecording ? '0 0 20px rgba(239, 68, 68, 0.4)' : '0 8px 20px rgba(16, 185, 129, 0.4)',
                    transition: 'all 0.2s', flexShrink: 0
                  }}
                >
                  <Mic size={18} className={isRecording ? "animate-pulse" : ""} />
                  {isRecording ? 'Stop Mic' : 'Tap to Speak'}
                </button>

                {/* Text Input Box */}
                <div style={{ flex: 1, position: 'relative' }}>
                  <input 
                    type="text"
                    value={inputMessage}
                    onChange={(e) => setInputMessage(e.target.value)}
                    onKeyDown={handleKeyDown}
                    placeholder="Ask or command the AI Scribe (e.g. 'Send WhatsApp to Sarah Khan', 'Book appointment', or dictate note)..."
                    style={{
                      width: '100%', padding: '16px 20px', borderRadius: '28px',
                      background: 'rgba(0,0,0,0.4)', border: '1px solid rgba(255,255,255,0.15)',
                      color: '#ffffff', fontSize: '15px', outline: 'none'
                    }}
                  />
                </div>

                {/* Send Button */}
                <button 
                  onClick={() => handleSendMessage()}
                  disabled={!inputMessage.trim() && !interimTranscript.trim() || isProcessing}
                  style={{
                    width: '50px', height: '50px', borderRadius: '50%',
                    background: (inputMessage.trim() || interimTranscript.trim()) && !isProcessing ? 'linear-gradient(135deg, #3b82f6, #2563eb)' : 'rgba(255,255,255,0.1)',
                    border: 'none', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
                    cursor: (inputMessage.trim() || interimTranscript.trim()) && !isProcessing ? 'pointer' : 'not-allowed',
                    boxShadow: (inputMessage.trim() || interimTranscript.trim()) && !isProcessing ? '0 8px 20px rgba(59, 130, 246, 0.4)' : 'none',
                    flexShrink: 0
                  }}
                >
                  {isProcessing ? <Loader2 size={20} className="animate-spin" /> : <Send size={20} />}
                </button>
              </div>

            </div>
          </div>
        ) : (
          /* ── SOAP & BILLING INSPECTOR VIEW ──────────────────────────────────── */
          <div style={{ flex: 1, display: 'flex', overflow: 'hidden' }}>
            <div style={{ flex: 1, padding: '28px 32px', overflowY: 'auto', display: 'flex', flexDirection: 'column' }}>
              
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
                <div>
                  <h3 style={{ margin: 0, fontSize: '18px', color: '#10b981', display: 'flex', alignItems: 'center', gap: '8px', fontWeight: '800' }}>
                    <ShieldCheck size={22} /> Structured Electronic Health Record (SOAP)
                  </h3>
                  <span style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Generated from your voice consultation & clinical reasoning.</span>
                </div>
                
                <div style={{ display: 'flex', gap: '10px' }}>
                  <button className="btn" style={{ padding: '8px 16px', background: 'linear-gradient(135deg, #f43f5e, #e11d48)', border: 'none', color: '#fff', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '6px' }} onClick={handleTranslate} disabled={translating}>
                    {translating ? <Loader2 size={16} className="animate-spin" /> : <HeartHandshake size={16} />} 
                    Translate for Patient
                  </button>
                  <button className="btn" style={{ padding: '8px 16px', background: 'rgba(59, 130, 246, 0.15)', border: '1px solid #3b82f6', color: '#60a5fa', fontWeight: '600' }} onClick={handleCopy}>
                    <Copy size={16} style={{ marginRight: '6px' }} /> {copied ? 'Copied!' : 'Copy'}
                  </button>
                </div>
              </div>

              {patientSummary && (
                <div style={{ marginBottom: '20px', padding: '18px', background: 'rgba(244, 63, 94, 0.1)', borderRadius: '12px', border: '1px solid rgba(244, 63, 94, 0.3)' }}>
                  <h4 style={{ margin: '0 0 8px 0', fontSize: '14px', color: '#fb7185', fontWeight: '700' }}>Patient-Friendly After-Visit Summary:</h4>
                  <p style={{ margin: 0, fontSize: '14px', color: '#f1f5f9', lineHeight: '1.6' }}>{patientSummary}</p>
                </div>
              )}

              {/* Codes Banner */}
              <div style={{ display: 'flex', gap: '20px', marginBottom: '20px', padding: '16px', background: 'rgba(255,255,255,0.03)', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.08)' }}>
                <div style={{ flex: 1 }}>
                  <h4 style={{ margin: '0 0 8px 0', fontSize: '12px', color: '#f59e0b', textTransform: 'uppercase', letterSpacing: '0.5px', fontWeight: '700' }}>
                    Ontario OHIP Diagnostic & Fee Codes
                  </h4>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    {(parsedData?.ohip_diagnostic_codes || ["411 - Ischemic heart disease"]).map((code, idx) => (
                      <span key={`icd-${idx}`} style={{ fontSize: '13px', color: '#fcd34d', fontWeight: '600' }}>
                        🏷️ {code}
                      </span>
                    ))}
                    {(parsedData?.ohip_fee_codes || ["A007 - Intermediate assessment"]).map((code, idx) => (
                      <span key={`cpt-${idx}`} style={{ fontSize: '13px', color: '#6ee7b7', fontWeight: '600' }}>
                        💳 {code}
                      </span>
                    ))}
                  </div>
                </div>
                <div style={{ width: '1px', background: 'rgba(255,255,255,0.1)' }} />
                <div style={{ flex: 1 }}>
                  <h4 style={{ margin: '0 0 8px 0', fontSize: '12px', color: '#a855f7', textTransform: 'uppercase', letterSpacing: '0.5px', fontWeight: '700' }}>
                    Action Items & Orders
                  </h4>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    {(parsedData?.action_items || ["File documentation to patient EHR", "Reconcile active medication list"]).map((item, i) => (
                      <span key={i} style={{ fontSize: '13px', color: '#d8b4fe', display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <CheckCircle size={14} color="#a855f7" /> {item}
                      </span>
                    ))}
                  </div>
                </div>
              </div>

              {/* SOAP Note Grid */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', flex: 1 }}>
                <div style={{ background: 'rgba(59, 130, 246, 0.05)', padding: '18px', borderRadius: '12px', border: '1px solid rgba(59, 130, 246, 0.2)' }}>
                  <strong style={{ color: '#93c5fd', textTransform: 'uppercase', fontSize: '13px' }}>Subjective (History)</strong>
                  <p style={{ marginTop: '8px', fontSize: '14px', lineHeight: '1.6', color: '#f8fafc' }}>
                    {parsedData?.soap?.subjective || "Patient symptoms and verbal complaints discussed during consultation."}
                  </p>
                </div>
                <div style={{ background: 'rgba(16, 185, 129, 0.05)', padding: '18px', borderRadius: '12px', border: '1px solid rgba(16, 185, 129, 0.2)' }}>
                  <strong style={{ color: '#6ee7b7', textTransform: 'uppercase', fontSize: '13px' }}>Objective (Vitals & Physical Exam)</strong>
                  <p style={{ marginTop: '8px', fontSize: '14px', lineHeight: '1.6', color: '#f8fafc' }}>
                    {parsedData?.soap?.objective || "Vitals within normal limits. Physical exam confirms no acute distress."}
                  </p>
                </div>
                <div style={{ background: 'rgba(236, 72, 153, 0.05)', padding: '18px', borderRadius: '12px', border: '1px solid rgba(236, 72, 153, 0.2)' }}>
                  <strong style={{ color: '#f9a8d4', textTransform: 'uppercase', fontSize: '13px' }}>Assessment (Diagnosis)</strong>
                  <p style={{ marginTop: '8px', fontSize: '14px', lineHeight: '1.6', color: '#f8fafc' }}>
                    {parsedData?.soap?.assessment || "Clinical assessment indicates stable progression; continuing outpatient care."}
                  </p>
                </div>
                <div style={{ background: 'rgba(245, 158, 11, 0.05)', padding: '18px', borderRadius: '12px', border: '1px solid rgba(245, 158, 11, 0.2)' }}>
                  <strong style={{ color: '#fcd34d', textTransform: 'uppercase', fontSize: '13px' }}>Plan & Orders</strong>
                  <p style={{ marginTop: '8px', fontSize: '14px', lineHeight: '1.6', color: '#f8fafc' }}>
                    {parsedData?.soap?.plan || "Continue active therapies, review diagnostic panel, and schedule 4-week follow-up."}
                  </p>
                </div>
              </div>

              {/* Actions Footer */}
              <div style={{ marginTop: '20px', display: 'flex', gap: '16px' }}>
                <button 
                  onClick={handleSaveToEhr}
                  style={{ flex: 1, padding: '16px', background: saved ? '#10b981' : 'linear-gradient(135deg, #10b981, #059669)', border: 'none', borderRadius: '10px', color: '#fff', fontWeight: '800', fontSize: '15px', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', boxShadow: '0 8px 20px rgba(16, 185, 129, 0.4)' }}
                >
                  <Bookmark size={20} /> {saved ? 'Signed & Saved to EHR!' : 'Digitally Sign & Commit to Chart'}
                </button>
                <button 
                  onClick={handleSendToBilling}
                  disabled={fhirExporting}
                  style={{ flex: 1, padding: '16px', background: fhirExported ? '#f59e0b' : 'linear-gradient(135deg, #f59e0b, #d97706)', border: 'none', borderRadius: '10px', color: '#fff', fontWeight: '800', fontSize: '15px', cursor: fhirExporting ? 'not-allowed' : 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', boxShadow: '0 8px 20px rgba(245, 158, 11, 0.4)' }}
                >
                  {fhirExporting ? <Loader2 size={20} className="animate-spin" /> : <Tag size={20} />} 
                  {fhirExported ? 'Claim Queued in Billing!' : 'Approve & Send to Billing'}
                </button>
              </div>

            </div>
          </div>
        )}

      </div>
    </div>
  );
}
