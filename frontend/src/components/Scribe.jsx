import React, { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import { 
  Mic, X, Sparkles, Volume2, VolumeX, Send, Calendar, Clock, 
  Phone, User, Bot, AlertCircle, Compass, CheckCircle2, ArrowRight,
  ExternalLink, MessageSquare, Activity, FileText, DollarSign, Inbox, LayoutDashboard
} from 'lucide-react';

window.utterances = [];
window.isSpeaking = false;

const speakAction = (text) => {
  if (localStorage.getItem('medoffice_voice_feedback') === 'false') return;
  if ('speechSynthesis' in window) {
    setTimeout(() => {
      const msg = new SpeechSynthesisUtterance(text);
      msg.rate = 1.05;
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

export default function Scribe() {
  const [isOpen, setIsOpen] = useState(false);
  const [inputMessage, setInputMessage] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [interimTranscript, setInterimTranscript] = useState('');
  const [audioLevel, setAudioLevel] = useState(0);
  const [audioFreqData, setAudioFreqData] = useState(new Array(16).fill(4));
  const [speechError, setSpeechError] = useState(null);
  const [ttsEnabled, setTtsEnabled] = useState(true);

  // Chat message stream designed for hospital staff
  const [messages, setMessages] = useState([
    {
      id: 1,
      sender: 'assistant',
      text: "👋 **Hello! I am your e-Hospital Staff AI Assistant.**\n\nI can carry out instructions across the app, manage patient communication, and check schedules.\n\n**Speak or tap any instruction below:**",
      time: "Just now"
    }
  ]);

  const chatEndRef = useRef(null);

  // Speech Recognition & Web Audio Refs
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
  }, [messages, isProcessing, interimTranscript]);

  // Listen for open event
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

  // Cleanup on close
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

  const startRecording = async () => {
    setSpeechError(null);
    window.isSpeaking = false;
    window.dispatchEvent(new CustomEvent('pause-voice-nav'));

    setInterimTranscript('');
    interimRef.current = '';

    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      setSpeechError("Speech recognition is not supported in this browser. Please use Google Chrome, Edge, or Safari.");
      return;
    }

    // 1. Web Audio API for real microphone visualizer
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
          analyser.smoothingTimeConstant = 0.6;
          analyserRef.current = analyser;

          const source = audioCtx.createMediaStreamSource(stream);
          source.connect(analyser);

          const dataArray = new Uint8Array(analyser.frequencyBinCount);
          const updateAudioVisuals = () => {
            if (!isRecordingRef.current) return;
            analyser.getByteFrequencyData(dataArray);

            let sum = 0;
            const barCount = 16;
            const bars = [];
            const step = Math.max(1, Math.floor(dataArray.length / barCount));

            for (let i = 0; i < barCount; i++) {
              const val = dataArray[i * step] || 0;
              sum += val;
              const height = Math.max(4, Math.min(28, Math.round((val / 255) * 28)));
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
      console.warn("Microphone stream note:", micErr);
      if (micErr.name === 'NotAllowedError' || micErr.name === 'PermissionDeniedError') {
        setSpeechError("Microphone permission was denied. Please allow microphone access in your address bar.");
        return;
      }
    }

    // 2. Web Speech API Recognition
    try {
      const recognition = new SpeechRecognition();
      recognition.continuous = true;
      recognition.interimResults = true;
      recognition.lang = 'en-US';
      recognitionRef.current = recognition;

      recognition.onresult = (event) => {
        window.isSpeaking = false;

        let finalTranscript = '';
        let interimTranscriptText = '';

        for (let i = event.resultIndex; i < event.results.length; i++) {
          const piece = event.results[i][0].transcript;
          if (event.results[i].isFinal) {
            finalTranscript += piece + ' ';
          } else {
            interimTranscriptText += piece;
          }
        }

        if (interimTranscriptText) {
          setInterimTranscript(interimTranscriptText);
          interimRef.current = interimTranscriptText;
        }

        if (finalTranscript) {
          setInputMessage(prev => (prev ? prev.trim() + ' ' + finalTranscript.trim() : finalTranscript.trim()));
          setInterimTranscript('');
          interimRef.current = '';
        }
      };

      recognition.onerror = (event) => {
        if (event.error === 'no-speech' || event.error === 'aborted') {
          return;
        }
        if (event.error === 'not-allowed') {
          setSpeechError("Microphone access was blocked. Please enable it in browser settings.");
          stopRecording();
          return;
        }
        if (event.error === 'network') {
          setSpeechError("Speech network issue. Chrome requires internet access for speech recognition.");
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
      console.error("Speech recognition error:", e);
      setSpeechError(`Could not start microphone: ${e.message}`);
      stopRecording();
    }
  };

  const stopRecording = () => {
    setIsRecording(false);
    isRecordingRef.current = false;

    if (interimRef.current) {
      const remaining = interimRef.current.trim();
      setInputMessage(prev => (prev ? prev + ' ' + remaining : remaining));
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
    setAudioFreqData(new Array(16).fill(4));
  };

  const toggleRecording = () => {
    if (isRecordingRef.current) {
      stopRecording();
    } else {
      startRecording();
    }
  };

  // Execute instruction through Hospital Copilot
  const handleSendMessage = async (customText) => {
    const query = (customText || inputMessage || interimTranscript).trim();
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
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };

      setMessages(prev => [...prev, botMsg]);

      // Handle App Navigation instruction
      if (data.action_type === 'navigate' && data.action_data?.tab) {
        window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab: data.action_data.tab } }));
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
      // Graceful local instruction execution fallback
      const qLower = query.toLowerCase();
      let fallbackReply = "I received your instruction.";
      let actType = "general_reply";
      let actData = null;

      if (qLower.includes("inbox") || qLower.includes("message")) {
        fallbackReply = "🧭 Navigating to **Secure Inbox**.";
        actType = "navigate";
        actData = { tab: "inbox", label: "Secure Inbox" };
        window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab: 'inbox' } }));
      } else if (qLower.includes("dashboard") || qLower.includes("home")) {
        fallbackReply = "🧭 Navigating to **Dashboard**.";
        actType = "navigate";
        actData = { tab: "dashboard", label: "Dashboard" };
        window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab: 'dashboard' } }));
      } else if (qLower.includes("billing")) {
        fallbackReply = "🧭 Navigating to **Billing Dashboard**.";
        actType = "navigate";
        actData = { tab: "billing", label: "Billing Dashboard" };
        window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab: 'billing' } }));
      } else if (qLower.includes("twin")) {
        fallbackReply = "🧭 Navigating to **3D Digital Twin**.";
        actType = "navigate";
        actData = { tab: "twin", label: "3D Digital Twin" };
        window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab: 'twin' } }));
      } else if (qLower.includes("calendar")) {
        fallbackReply = "🧭 Navigating to **Smart Calendar**.";
        actType = "navigate";
        actData = { tab: "calendar", label: "Smart Calendar" };
        window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab: 'calendar' } }));
      }

      const botMsg = {
        id: Date.now() + 1,
        sender: 'assistant',
        text: fallbackReply,
        action_type: actType,
        action_data: actData,
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

  const handleNavigateToTab = (tab) => {
    window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab } }));
    setIsOpen(false);
  };

  // 1. Floating Launch Button (when closed)
  if (!isOpen) {
    return (
      <button 
        className="desktop-only"
        style={{
          position: 'fixed', bottom: '28px', right: '28px',
          width: '64px', height: '64px', borderRadius: '50%',
          background: 'linear-gradient(135deg, #10b981, #059669)', 
          color: 'white', border: '3px solid rgba(255,255,255,0.3)',
          boxShadow: '0 10px 35px rgba(16, 185, 129, 0.55)', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 9999,
          transition: 'transform 0.25s cubic-bezier(0.175, 0.885, 0.32, 1.275)',
        }}
        onMouseEnter={(e) => e.currentTarget.style.transform = 'scale(1.08)'}
        onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}
        onClick={() => setIsOpen(true)}
        title="Open Hospital Staff AI Chatbot"
      >
        <Mic size={28} color="white" className="animate-pulse" />
      </button>
    );
  }

  // 2. REAL MOBILE VERSION CHATBOT (Sheet / Screen)
  return (
    <div style={{ 
      position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, 
      background: 'rgba(2, 6, 23, 0.75)', backdropFilter: 'blur(10px)', 
      display: 'flex', alignItems: 'flex-end', justifyContent: 'center', zIndex: 99999 
    }}>
      <div 
        className="animate-fade-in" 
        style={{ 
          width: '100%', maxWidth: '480px', height: '94vh', 
          background: 'rgba(15, 23, 42, 0.98)', 
          borderTopLeftRadius: '24px', borderTopRightRadius: '24px',
          border: '1px solid rgba(16, 185, 129, 0.35)', borderBottom: 'none',
          boxShadow: '0 -15px 50px rgba(0,0,0,0.8), inset 0 1px 0 rgba(255,255,255,0.1)', 
          display: 'flex', flexDirection: 'column', overflow: 'hidden'
        }}
      >
        
        {/* Mobile Pull Indicator */}
        <div style={{ width: '40px', height: '4px', background: 'rgba(255,255,255,0.2)', borderRadius: '2px', margin: '8px auto 0 auto' }} />

        {/* Mobile Chatbot Header */}
        <div style={{ 
          display: 'flex', justifyContent: 'space-between', alignItems: 'center', 
          padding: '12px 18px', borderBottom: '1px solid rgba(255,255,255,0.08)',
          background: 'rgba(15, 23, 42, 0.7)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ 
              width: '40px', height: '40px', borderRadius: '12px', 
              background: 'linear-gradient(135deg, #10b981, #059669)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: '0 4px 14px rgba(16, 185, 129, 0.4)'
            }}>
              <Sparkles size={20} color="#ffffff" />
            </div>
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <h3 style={{ margin: 0, fontSize: '16px', color: '#f8fafc', fontWeight: '800' }}>Hospital AI Assistant</h3>
                <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#34d399', display: 'inline-block' }} />
              </div>
              <span style={{ fontSize: '11px', color: '#94a3b8' }}>Live Speech • Navigation • Actions</span>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            {/* Audio Voice Response Toggle */}
            <button 
              onClick={() => setTtsEnabled(!ttsEnabled)} 
              title={ttsEnabled ? "Voice replies enabled" : "Voice replies muted"}
              style={{ background: 'rgba(255,255,255,0.06)', border: 'none', color: ttsEnabled ? '#34d399' : '#64748b', padding: '8px', borderRadius: '50%', cursor: 'pointer' }}
            >
              {ttsEnabled ? <Volume2 size={16} /> : <VolumeX size={16} />}
            </button>
            {/* Close Button */}
            <button 
              onClick={() => { setIsOpen(false); stopRecording(); }} 
              style={{ background: 'rgba(239, 68, 68, 0.12)', border: 'none', color: '#fca5a5', width: '32px', height: '32px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}
            >
              <X size={16} />
            </button>
          </div>
        </div>

        {/* Chat Message Stream */}
        <div style={{ 
          flex: 1, padding: '16px 14px', overflowY: 'auto', 
          display: 'flex', flexDirection: 'column', gap: '14px',
          background: 'linear-gradient(180deg, rgba(15,23,42,0.6) 0%, rgba(2,6,23,0.8) 100%)'
        }}>
          {messages.map((msg) => (
            <div 
              key={msg.id} 
              style={{ 
                display: 'flex', 
                flexDirection: 'column',
                alignItems: msg.sender === 'user' ? 'flex-end' : 'flex-start'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '3px', fontSize: '10px', color: '#64748b' }}>
                {msg.sender === 'user' ? (
                  <><span>Hospital Staff</span> <User size={10} /></>
                ) : (
                  <><Bot size={10} color="#34d399" /> <span style={{ color: '#34d399', fontWeight: '700' }}>e-Hospital AI</span></>
                )}
                <span>• {msg.time}</span>
              </div>

              <div style={{ 
                maxWidth: '88%', 
                padding: '12px 16px', 
                borderRadius: msg.sender === 'user' ? '18px 18px 4px 18px' : '18px 18px 18px 4px',
                background: msg.sender === 'user' ? 'linear-gradient(135deg, #2563eb, #1d4ed8)' : 'rgba(30, 41, 59, 0.9)',
                border: msg.sender === 'user' ? '1px solid rgba(96, 165, 250, 0.3)' : '1px solid rgba(255, 255, 255, 0.08)',
                color: '#f8fafc',
                fontSize: '14px',
                lineHeight: '1.5',
                boxShadow: '0 4px 16px rgba(0,0,0,0.2)'
              }}>
                <div style={{ whiteSpace: 'pre-wrap' }}>
                  {msg.text}
                </div>

                {/* ACTION CARD: App Navigation */}
                {msg.action_type === 'navigate' && msg.action_data && (
                  <div style={{ marginTop: '10px', padding: '10px 12px', background: 'rgba(59, 130, 246, 0.15)', border: '1px solid rgba(59, 130, 246, 0.4)', borderRadius: '10px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <span style={{ color: '#93c5fd', fontWeight: '700', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <Compass size={14} /> Screen Switched
                      </span>
                      <button 
                        onClick={() => handleNavigateToTab(msg.action_data.tab)}
                        style={{ padding: '4px 10px', background: '#2563eb', border: 'none', borderRadius: '6px', color: '#fff', fontSize: '11px', fontWeight: '700', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}
                      >
                        View Screen <ExternalLink size={11} />
                      </button>
                    </div>
                  </div>
                )}

                {/* ACTION CARD: WhatsApp Dispatched */}
                {msg.action_type === 'whatsapp_sent' && msg.action_data && (
                  <div style={{ marginTop: '10px', padding: '10px 12px', background: 'rgba(16, 185, 129, 0.15)', border: '1px solid rgba(16, 185, 129, 0.4)', borderRadius: '10px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#34d399', fontWeight: '700', fontSize: '12px', marginBottom: '4px' }}>
                      <Phone size={14} /> Outbound WhatsApp Dispatched
                    </div>
                    <div style={{ fontSize: '12px', color: '#cbd5e1' }}>
                      <div><strong>To:</strong> {msg.action_data.patient_name} ({msg.action_data.phone})</div>
                      <div style={{ marginTop: '4px', fontStyle: 'italic', background: 'rgba(0,0,0,0.25)', padding: '6px 8px', borderRadius: '6px' }}>
                        "{msg.action_data.message}"
                      </div>
                    </div>
                  </div>
                )}

                {/* ACTION CARD: Appointment Booked */}
                {msg.action_type === 'appointment_booked' && msg.action_data && (
                  <div style={{ marginTop: '10px', padding: '10px 12px', background: 'rgba(20, 184, 166, 0.15)', border: '1px solid rgba(20, 184, 166, 0.4)', borderRadius: '10px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#2dd4bf', fontWeight: '700', fontSize: '12px', marginBottom: '4px' }}>
                      <CheckCircle2 size={14} /> Clinic Appointment Confirmed
                    </div>
                    <div style={{ fontSize: '12px', color: '#cbd5e1' }}>
                      <div><strong>Patient:</strong> {msg.action_data.patient_name}</div>
                      <div><strong>Schedule:</strong> {msg.action_data.date} at {msg.action_data.time}</div>
                      <div><strong>Type:</strong> {msg.action_data.type}</div>
                    </div>
                  </div>
                )}

              </div>
            </div>
          ))}

          {isProcessing && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#34d399', fontSize: '13px', fontStyle: 'italic' }}>
              <Sparkles size={14} className="animate-spin" /> Hospital AI is processing instruction...
            </div>
          )}
          <div ref={chatEndRef} />
        </div>

        {/* Horizontal Quick Action Chips */}
        <div style={{ 
          padding: '8px 12px', display: 'flex', gap: '6px', overflowX: 'auto', 
          background: 'rgba(15, 23, 42, 0.95)', borderTop: '1px solid rgba(255,255,255,0.06)',
          whiteSpace: 'nowrap', WebkitOverflowScrolling: 'touch'
        }}>
          <button 
            onClick={() => handleSendMessage("Go to Inbox")}
            style={{ padding: '6px 12px', background: 'rgba(59, 130, 246, 0.15)', border: '1px solid rgba(59, 130, 246, 0.35)', borderRadius: '16px', color: '#93c5fd', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}
          >
            <Inbox size={12} /> Go to Inbox
          </button>
          <button 
            onClick={() => handleSendMessage("What appointments do I have today?")}
            style={{ padding: '6px 12px', background: 'rgba(16, 185, 129, 0.15)', border: '1px solid rgba(16, 185, 129, 0.35)', borderRadius: '16px', color: '#6ee7b7', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}
          >
            <Clock size={12} /> Today's Schedule
          </button>
          <button 
            onClick={() => handleSendMessage("Send a WhatsApp message to Sarah Khan saying your blood pressure checkup is scheduled for Friday")}
            style={{ padding: '6px 12px', background: 'rgba(34, 197, 94, 0.15)', border: '1px solid rgba(34, 197, 94, 0.35)', borderRadius: '16px', color: '#86efac', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}
          >
            <Phone size={12} /> WhatsApp Sarah Khan
          </button>
          <button 
            onClick={() => handleSendMessage("Book an appointment for Sarah Khan tomorrow at 3 PM for diabetes review")}
            style={{ padding: '6px 12px', background: 'rgba(20, 184, 166, 0.15)', border: '1px solid rgba(20, 184, 166, 0.35)', borderRadius: '16px', color: '#5eead4', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}
          >
            <Calendar size={12} /> Book Tomorrow at 3 PM
          </button>
          <button 
            onClick={() => handleSendMessage("Go to Billing")}
            style={{ padding: '6px 12px', background: 'rgba(245, 158, 11, 0.15)', border: '1px solid rgba(245, 158, 11, 0.35)', borderRadius: '16px', color: '#fcd34d', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}
          >
            <DollarSign size={12} /> Go to Billing
          </button>
          <button 
            onClick={() => handleSendMessage("Go to 3D Twin")}
            style={{ padding: '6px 12px', background: 'rgba(168, 85, 247, 0.15)', border: '1px solid rgba(168, 85, 247, 0.35)', borderRadius: '16px', color: '#d8b4fe', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}
          >
            <Activity size={12} /> Go to 3D Twin
          </button>
          <button 
            onClick={() => handleSendMessage("What medications is Sarah Khan currently taking?")}
            style={{ padding: '6px 12px', background: 'rgba(236, 72, 153, 0.15)', border: '1px solid rgba(236, 72, 153, 0.35)', borderRadius: '16px', color: '#f472b6', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px' }}
          >
            <User size={12} /> Sarah Khan Meds
          </button>
        </div>

        {/* Mobile Sticky Voice & Input Bar */}
        <div style={{ 
          padding: '12px 14px 18px 14px', 
          background: 'rgba(15, 23, 42, 0.98)', 
          borderTop: '1px solid rgba(255,255,255,0.08)'
        }}>
          
          {/* Real Audio Waveform when Mic is Active */}
          {isRecording && (
            <div style={{ 
              display: 'flex', alignItems: 'center', justifyContent: 'space-between', 
              marginBottom: '10px', background: 'rgba(0,0,0,0.5)', padding: '6px 12px', 
              borderRadius: '10px', border: '1px solid rgba(16, 185, 129, 0.3)' 
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
                {audioFreqData.map((height, i) => (
                  <div 
                    key={i} 
                    style={{ 
                      width: '3px', height: `${height}px`,
                      background: audioLevel > 15 ? '#10b981' : '#ef4444',
                      borderRadius: '3px',
                      transition: 'height 0.05s ease'
                    }} 
                  />
                ))}
                <span style={{ marginLeft: '8px', fontSize: '11px', fontWeight: '700', color: audioLevel > 15 ? '#34d399' : '#ef4444' }}>
                  {audioLevel > 15 ? 'VOICE HEARD' : 'LISTENING...'}
                </span>
              </div>

              {interimTranscript && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', maxWidth: '65%' }}>
                  <div style={{ fontSize: '12px', color: '#93c5fd', fontStyle: 'italic', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    "{interimTranscript}"
                  </div>
                  <button
                    onClick={() => handleSendMessage(interimTranscript)}
                    style={{ padding: '3px 8px', background: '#10b981', border: 'none', borderRadius: '6px', color: '#fff', fontSize: '10px', fontWeight: '700', cursor: 'pointer', flexShrink: 0 }}
                  >
                    Run ↵
                  </button>
                </div>
              )}
            </div>
          )}

          {speechError && (
            <div style={{ marginBottom: '8px', padding: '6px 10px', background: 'rgba(239, 68, 68, 0.15)', border: '1px solid #ef4444', borderRadius: '6px', color: '#fca5a5', fontSize: '11px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span>{speechError}</span>
              <button onClick={() => setSpeechError(null)} style={{ background: 'transparent', border: 'none', color: '#fca5a5' }}><X size={12} /></button>
            </div>
          )}

          {/* Action Input Bar */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            {/* Quick Tap-to-Speak Mic Button */}
            <button 
              onClick={toggleRecording}
              style={{
                width: '46px', height: '46px', borderRadius: '50%',
                background: isRecording ? 'rgba(239, 68, 68, 0.3)' : 'linear-gradient(135deg, #10b981, #059669)',
                border: isRecording ? '2px solid #ef4444' : 'none',
                color: isRecording ? '#fca5a5' : '#ffffff',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: isRecording ? '0 0 16px rgba(239, 68, 68, 0.4)' : '0 4px 14px rgba(16, 185, 129, 0.4)',
                cursor: 'pointer', flexShrink: 0, transition: 'all 0.2s'
              }}
              title={isRecording ? "Stop listening" : "Tap to speak instruction"}
            >
              <Mic size={20} className={isRecording ? "animate-pulse" : ""} />
            </button>

            {/* Instruction Text Field */}
            <input 
              type="text"
              value={inputMessage}
              onChange={(e) => setInputMessage(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={isRecording ? "Listening to your voice..." : "Ask or command (e.g. 'Go to inbox')..."}
              style={{
                flex: 1, padding: '12px 16px', borderRadius: '24px',
                background: 'rgba(0,0,0,0.4)', border: '1px solid rgba(255,255,255,0.12)',
                color: '#ffffff', fontSize: '14px', outline: 'none'
              }}
            />

            {/* Send Instruction Button */}
            <button 
              onClick={() => handleSendMessage()}
              disabled={!inputMessage.trim() && !interimTranscript.trim() || isProcessing}
              style={{
                width: '42px', height: '42px', borderRadius: '50%',
                background: (inputMessage.trim() || interimTranscript.trim()) && !isProcessing ? 'linear-gradient(135deg, #3b82f6, #2563eb)' : 'rgba(255,255,255,0.08)',
                border: 'none', color: '#ffffff',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                cursor: (inputMessage.trim() || interimTranscript.trim()) && !isProcessing ? 'pointer' : 'not-allowed',
                flexShrink: 0
              }}
            >
              <Send size={16} />
            </button>
          </div>

        </div>

      </div>
    </div>
  );
}
