import React, { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import { 
  Mic, Bot, Sparkles, Volume2, VolumeX, Send, Calendar, Clock, 
  Phone, User, Compass, CheckCircle2, ArrowRight, ExternalLink, 
  RotateCcw, Activity, DollarSign, Inbox, MessageSquare, ChevronRight,
  AlertCircle
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

export default function Scribe({ onNavigateTab }) {
  const [inputMessage, setInputMessage] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [interimTranscript, setInterimTranscript] = useState('');
  const [audioLevel, setAudioLevel] = useState(0);
  const [audioFreqData, setAudioFreqData] = useState(new Array(16).fill(4));
  const [speechError, setSpeechError] = useState(null);
  const [ttsEnabled, setTtsEnabled] = useState(true);

  // Pre-loaded realistic chatbot greeting for hospital staff
  const initialMessages = [
    {
      id: 1,
      sender: 'assistant',
      text: "👋 **Hello Dr. Patel & Clinical Team!**\n\nI am your **e-Hospital Staff AI Copilot**. You can speak or type instructions to work around the app, message patients, manage appointments, and check charts.",
      time: "Just now",
      suggestions: [
        "What appointments do I have today?",
        "Send a WhatsApp message to Sarah Khan saying your blood test results are ready",
        "Book an appointment for Sarah Khan tomorrow at 3 PM",
        "Go to Inbox",
        "Go to Billing",
        "What medications is Sarah Khan taking?"
      ]
    }
  ];

  const [messages, setMessages] = useState(() => {
    try {
      const saved = sessionStorage.getItem('hospital_chatbot_history');
      return saved ? JSON.parse(saved) : initialMessages;
    } catch {
      return initialMessages;
    }
  });

  const chatEndRef = useRef(null);
  const inputRef = useRef(null);

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
    try {
      sessionStorage.setItem('hospital_chatbot_history', JSON.stringify(messages));
    } catch {}
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isProcessing, interimTranscript]);

  // Clean up recording on unmount
  useEffect(() => {
    return () => {
      stopRecording();
    };
  }, []);

  const handleClearChat = () => {
    setMessages(initialMessages);
    try {
      sessionStorage.removeItem('hospital_chatbot_history');
    } catch {}
    setInputMessage('');
    setInterimTranscript('');
  };

  const startRecording = async () => {
    setSpeechError(null);
    window.isSpeaking = false;
    window.dispatchEvent(new CustomEvent('pause-voice-nav'));

    setInterimTranscript('');
    interimRef.current = '';

    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      setSpeechError("Speech recognition is not supported in this browser. Please use Chrome, Safari, or Edge.");
      return;
    }

    // 1. Web Audio API for animated frequency waveform
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
        setSpeechError("Microphone permission was denied. Please allow microphone access in your browser settings.");
        return;
      }
    }

    // 2. Web Speech API Recognition with resultIndex to prevent duplicated text
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
          setInputMessage(prev => {
            const next = prev ? prev.trim() + ' ' + finalTranscript.trim() : finalTranscript.trim();
            return next;
          });
          setInterimTranscript('');
          interimRef.current = '';
        }
      };

      recognition.onerror = (event) => {
        if (event.error === 'no-speech' || event.error === 'aborted') {
          return;
        }
        if (event.error === 'not-allowed') {
          setSpeechError("Microphone access was blocked. Please enable microphone permission.");
          stopRecording();
          return;
        }
        if (event.error === 'network') {
          setSpeechError("Speech recognition requires active internet connectivity.");
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
      setInputMessage(prev => (prev ? prev.trim() + ' ' + remaining : remaining));
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
    window.dispatchEvent(new CustomEvent('resume-voice-nav'));
  };

  const toggleRecording = () => {
    if (isRecordingRef.current) {
      stopRecording();
    } else {
      startRecording();
    }
  };

  // Execute instruction through Hospital Copilot Backend
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

      // If user commanded tab navigation, execute it
      if (data.action_type === 'navigate' && data.action_data?.tab) {
        if (onNavigateTab) {
          onNavigateTab(data.action_data.tab);
        } else {
          window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab: data.action_data.tab } }));
        }
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
      // Client-side fallback handler
      const qLower = query.toLowerCase();
      let fallbackReply = "I received your instruction.";
      let actType = "general_reply";
      let actData = null;

      if (qLower.includes("inbox") || qLower.includes("message")) {
        fallbackReply = "🧭 Navigating to **Secure Inbox**.";
        actType = "navigate";
        actData = { tab: "inbox", label: "Secure Inbox" };
        if (onNavigateTab) onNavigateTab('inbox');
        else window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab: 'inbox' } }));
      } else if (qLower.includes("dashboard") || qLower.includes("home")) {
        fallbackReply = "🧭 Navigating to **Dashboard**.";
        actType = "navigate";
        actData = { tab: "dashboard", label: "Dashboard" };
        if (onNavigateTab) onNavigateTab('dashboard');
        else window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab: 'dashboard' } }));
      } else if (qLower.includes("billing")) {
        fallbackReply = "🧭 Navigating to **Billing Dashboard**.";
        actType = "navigate";
        actData = { tab: "billing", label: "Billing Dashboard" };
        if (onNavigateTab) onNavigateTab('billing');
        else window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab: 'billing' } }));
      } else if (qLower.includes("twin")) {
        fallbackReply = "🧭 Navigating to **3D Digital Twin**.";
        actType = "navigate";
        actData = { tab: "twin", label: "3D Digital Twin" };
        if (onNavigateTab) onNavigateTab('twin');
        else window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab: 'twin' } }));
      } else if (qLower.includes("calendar")) {
        fallbackReply = "🧭 Navigating to **Smart Calendar**.";
        actType = "navigate";
        actData = { tab: "calendar", label: "Smart Calendar" };
        if (onNavigateTab) onNavigateTab('calendar');
        else window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab: 'calendar' } }));
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

  const handleTabJump = (tab) => {
    if (onNavigateTab) {
      onNavigateTab(tab);
    } else {
      window.dispatchEvent(new CustomEvent('navigate-tab', { detail: { tab } }));
    }
  };

  return (
    <div style={{
      width: '100%',
      maxWidth: '900px',
      height: '100%',
      margin: '0 auto',
      display: 'flex',
      flexDirection: 'column',
      background: 'rgba(15, 23, 42, 0.95)',
      borderRadius: '20px',
      border: '1px solid rgba(255, 255, 255, 0.08)',
      boxShadow: '0 12px 40px rgba(0, 0, 0, 0.5)',
      overflow: 'hidden',
      position: 'relative'
    }}>
      
      {/* ── CHATBOT TOP HEADER ────────────────────────────────────────── */}
      <div style={{
        padding: '14px 20px',
        borderBottom: '1px solid rgba(255, 255, 255, 0.08)',
        background: 'rgba(15, 23, 42, 0.85)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexShrink: 0
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{
            width: '42px',
            height: '42px',
            borderRadius: '12px',
            background: 'linear-gradient(135deg, #10b981, #059669)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: '0 4px 14px rgba(16, 185, 129, 0.4)',
            position: 'relative'
          }}>
            <Bot size={22} color="#ffffff" />
            <span style={{
              position: 'absolute',
              bottom: '-2px',
              right: '-2px',
              width: '10px',
              height: '10px',
              borderRadius: '50%',
              background: '#34d399',
              border: '2px solid #0f172a'
            }} />
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <h2 style={{ margin: 0, fontSize: '16px', fontWeight: '800', color: '#f8fafc', letterSpacing: '-0.2px' }}>
                e-Hospital AI Copilot
              </h2>
              <span style={{
                background: 'rgba(16, 185, 129, 0.15)',
                color: '#34d399',
                fontSize: '10px',
                fontWeight: '700',
                padding: '2px 8px',
                borderRadius: '10px',
                border: '1px solid rgba(16, 185, 129, 0.3)'
              }}>
                STAFF ASSISTANT
              </span>
            </div>
            <p style={{ margin: '2px 0 0 0', fontSize: '11px', color: '#94a3b8' }}>
              Real-time Voice Recognition • Actions • Clinical Support
            </p>
          </div>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          {/* TTS Audio Response Toggle */}
          <button 
            onClick={() => setTtsEnabled(!ttsEnabled)} 
            title={ttsEnabled ? "Voice responses active" : "Voice responses muted"}
            style={{
              background: 'rgba(255, 255, 255, 0.06)',
              border: '1px solid rgba(255, 255, 255, 0.08)',
              color: ttsEnabled ? '#34d399' : '#64748b',
              padding: '8px',
              borderRadius: '50%',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}
          >
            {ttsEnabled ? <Volume2 size={16} /> : <VolumeX size={16} />}
          </button>

          {/* Clear / Reset Chat */}
          <button 
            onClick={handleClearChat}
            title="Start new conversation"
            style={{
              background: 'rgba(255, 255, 255, 0.06)',
              border: '1px solid rgba(255, 255, 255, 0.08)',
              color: '#94a3b8',
              padding: '8px',
              borderRadius: '50%',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}
          >
            <RotateCcw size={16} />
          </button>
        </div>
      </div>

      {/* ── CHAT MESSAGES BODY ─────────────────────────────────────────── */}
      <div style={{
        flex: 1,
        padding: '20px 16px',
        overflowY: 'auto',
        display: 'flex',
        flexDirection: 'column',
        gap: '16px',
        background: 'linear-gradient(180deg, rgba(15, 23, 42, 0.5) 0%, rgba(2, 6, 23, 0.8) 100%)'
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
            {/* Sender metadata label */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px', fontSize: '11px', color: '#64748b' }}>
              {msg.sender === 'user' ? (
                <><span>Hospital Staff</span> <User size={11} /></>
              ) : (
                <><Bot size={12} color="#34d399" /> <span style={{ color: '#34d399', fontWeight: '700' }}>e-Hospital AI</span></>
              )}
              <span>• {msg.time}</span>
            </div>

            {/* Message Bubble */}
            <div style={{ 
              maxWidth: '85%', 
              padding: '14px 18px', 
              borderRadius: msg.sender === 'user' ? '20px 20px 4px 20px' : '20px 20px 20px 4px',
              background: msg.sender === 'user' ? 'linear-gradient(135deg, #2563eb, #1d4ed8)' : 'rgba(30, 41, 59, 0.85)',
              border: msg.sender === 'user' ? '1px solid rgba(96, 165, 250, 0.3)' : '1px solid rgba(255, 255, 255, 0.09)',
              color: '#f8fafc',
              fontSize: '14px',
              lineHeight: '1.6',
              boxShadow: '0 4px 20px rgba(0, 0, 0, 0.25)'
            }}>
              <div style={{ whiteSpace: 'pre-wrap' }}>
                {msg.text}
              </div>

              {/* ACTION CARD: App Navigation */}
              {msg.action_type === 'navigate' && msg.action_data && (
                <div style={{
                  marginTop: '12px',
                  padding: '12px 14px',
                  background: 'rgba(59, 130, 246, 0.15)',
                  border: '1px solid rgba(59, 130, 246, 0.4)',
                  borderRadius: '12px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: '12px'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Compass size={16} color="#60a5fa" />
                    <div>
                      <div style={{ color: '#93c5fd', fontWeight: '700', fontSize: '13px' }}>
                        Screen Switched to {msg.action_data.label}
                      </div>
                      <div style={{ fontSize: '11px', color: '#cbd5e1' }}>
                        Ready in application viewport
                      </div>
                    </div>
                  </div>
                  <button 
                    onClick={() => handleTabJump(msg.action_data.tab)}
                    style={{
                      padding: '6px 12px',
                      background: '#2563eb',
                      border: 'none',
                      borderRadius: '8px',
                      color: '#ffffff',
                      fontSize: '12px',
                      fontWeight: '700',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px',
                      flexShrink: 0
                    }}
                  >
                    Open Screen <ChevronRight size={14} />
                  </button>
                </div>
              )}

              {/* ACTION CARD: Outbound WhatsApp Dispatched */}
              {msg.action_type === 'whatsapp_sent' && msg.action_data && (
                <div style={{
                  marginTop: '12px',
                  padding: '12px 14px',
                  background: 'rgba(16, 185, 129, 0.15)',
                  border: '1px solid rgba(16, 185, 129, 0.4)',
                  borderRadius: '12px'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#34d399', fontWeight: '700', fontSize: '13px', marginBottom: '6px' }}>
                    <Phone size={15} /> WhatsApp Message Dispatched
                  </div>
                  <div style={{ fontSize: '12px', color: '#cbd5e1' }}>
                    <div><strong>Recipient:</strong> {msg.action_data.patient_name} ({msg.action_data.phone})</div>
                    <div style={{ marginTop: '6px', fontStyle: 'italic', background: 'rgba(0,0,0,0.3)', padding: '8px 10px', borderRadius: '8px', borderLeft: '3px solid #10b981' }}>
                      "{msg.action_data.message}"
                    </div>
                  </div>
                </div>
              )}

              {/* ACTION CARD: Appointment Confirmed */}
              {msg.action_type === 'appointment_booked' && msg.action_data && (
                <div style={{
                  marginTop: '12px',
                  padding: '12px 14px',
                  background: 'rgba(20, 184, 166, 0.15)',
                  border: '1px solid rgba(20, 184, 166, 0.4)',
                  borderRadius: '12px'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#2dd4bf', fontWeight: '700', fontSize: '13px', marginBottom: '6px' }}>
                    <CheckCircle2 size={15} /> Clinic Appointment Confirmed
                  </div>
                  <div style={{ fontSize: '12px', color: '#cbd5e1', lineHeight: '1.5' }}>
                    <div><strong>Patient:</strong> {msg.action_data.patient_name}</div>
                    <div><strong>Date & Time:</strong> {msg.action_data.date} at {msg.action_data.time}</div>
                    <div><strong>Service:</strong> {msg.action_data.type}</div>
                  </div>
                </div>
              )}

              {/* Suggestions Chips inside greeting bubble */}
              {msg.suggestions && (
                <div style={{ marginTop: '14px', display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                  {msg.suggestions.map((sug, idx) => (
                    <button
                      key={idx}
                      onClick={() => handleSendMessage(sug)}
                      style={{
                        padding: '6px 12px',
                        background: 'rgba(255, 255, 255, 0.06)',
                        border: '1px solid rgba(255, 255, 255, 0.12)',
                        borderRadius: '16px',
                        color: '#93c5fd',
                        fontSize: '11px',
                        fontWeight: '600',
                        cursor: 'pointer',
                        textAlign: 'left',
                        transition: 'all 0.2s'
                      }}
                      onMouseEnter={(e) => { e.currentTarget.style.background = 'rgba(59, 130, 246, 0.2)'; e.currentTarget.style.borderColor = '#3b82f6'; }}
                      onMouseLeave={(e) => { e.currentTarget.style.background = 'rgba(255, 255, 255, 0.06)'; e.currentTarget.style.borderColor = 'rgba(255, 255, 255, 0.12)'; }}
                    >
                      {sug}
                    </button>
                  ))}
                </div>
              )}

            </div>
          </div>
        ))}

        {/* Processing Indicator */}
        {isProcessing && (
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#34d399', fontSize: '13px', fontStyle: 'italic', padding: '6px 0' }}>
            <Sparkles size={16} className="animate-spin" /> Hospital AI is executing instruction...
          </div>
        )}
        <div ref={chatEndRef} />
      </div>

      {/* ── QUICK SUGGESTION ACTIONS BAR ─────────────────────────────────── */}
      <div style={{
        padding: '8px 14px',
        display: 'flex',
        gap: '6px',
        overflowX: 'auto',
        background: 'rgba(15, 23, 42, 0.9)',
        borderTop: '1px solid rgba(255, 255, 255, 0.06)',
        whiteSpace: 'nowrap',
        WebkitOverflowScrolling: 'touch',
        flexShrink: 0
      }}>
        <button 
          onClick={() => handleSendMessage("What appointments do I have today?")}
          style={{ padding: '6px 12px', background: 'rgba(16, 185, 129, 0.15)', border: '1px solid rgba(16, 185, 129, 0.35)', borderRadius: '16px', color: '#6ee7b7', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '5px' }}
        >
          <Clock size={12} /> Today's Schedule
        </button>
        <button 
          onClick={() => handleSendMessage("Send a WhatsApp message to Sarah Khan saying your blood pressure checkup is scheduled for Friday")}
          style={{ padding: '6px 12px', background: 'rgba(34, 197, 94, 0.15)', border: '1px solid rgba(34, 197, 94, 0.35)', borderRadius: '16px', color: '#86efac', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '5px' }}
        >
          <Phone size={12} /> WhatsApp Sarah Khan
        </button>
        <button 
          onClick={() => handleSendMessage("Book an appointment for Sarah Khan tomorrow at 3 PM for diabetes review")}
          style={{ padding: '6px 12px', background: 'rgba(20, 184, 166, 0.15)', border: '1px solid rgba(20, 184, 166, 0.35)', borderRadius: '16px', color: '#5eead4', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '5px' }}
        >
          <Calendar size={12} /> Book Tomorrow 3 PM
        </button>
        <button 
          onClick={() => handleSendMessage("Go to Inbox")}
          style={{ padding: '6px 12px', background: 'rgba(59, 130, 246, 0.15)', border: '1px solid rgba(59, 130, 246, 0.35)', borderRadius: '16px', color: '#93c5fd', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '5px' }}
        >
          <Inbox size={12} /> Go to Inbox
        </button>
        <button 
          onClick={() => handleSendMessage("Go to Billing")}
          style={{ padding: '6px 12px', background: 'rgba(245, 158, 11, 0.15)', border: '1px solid rgba(245, 158, 11, 0.35)', borderRadius: '16px', color: '#fcd34d', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '5px' }}
        >
          <DollarSign size={12} /> Go to Billing
        </button>
        <button 
          onClick={() => handleSendMessage("Go to 3D Twin")}
          style={{ padding: '6px 12px', background: 'rgba(168, 85, 247, 0.15)', border: '1px solid rgba(168, 85, 247, 0.35)', borderRadius: '16px', color: '#d8b4fe', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '5px' }}
        >
          <Activity size={12} /> Go to 3D Twin
        </button>
        <button 
          onClick={() => handleSendMessage("What medications is Sarah Khan currently taking?")}
          style={{ padding: '6px 12px', background: 'rgba(236, 72, 153, 0.15)', border: '1px solid rgba(236, 72, 153, 0.35)', borderRadius: '16px', color: '#f472b6', fontSize: '11px', fontWeight: '600', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '5px' }}
        >
          <User size={12} /> Sarah Khan Meds
        </button>
      </div>

      {/* ── STICKY VOICE & TEXT INPUT DOCK ───────────────────────────────── */}
      <div style={{
        padding: '12px 16px 16px 16px',
        background: 'rgba(15, 23, 42, 0.98)',
        borderTop: '1px solid rgba(255, 255, 255, 0.08)',
        flexShrink: 0
      }}>

        {/* Real Audio Waveform Visualizer Bar */}
        {isRecording && (
          <div style={{ 
            display: 'flex', alignItems: 'center', justifyContent: 'space-between', 
            marginBottom: '10px', background: 'rgba(0,0,0,0.55)', padding: '8px 14px', 
            borderRadius: '12px', border: '1px solid rgba(16, 185, 129, 0.4)' 
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
              <span style={{ marginLeft: '10px', fontSize: '11px', fontWeight: '700', color: audioLevel > 15 ? '#34d399' : '#ef4444' }}>
                {audioLevel > 15 ? 'VOICE DETECTED' : 'LISTENING...'}
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
          <div style={{ marginBottom: '8px', padding: '6px 12px', background: 'rgba(239, 68, 68, 0.15)', border: '1px solid #ef4444', borderRadius: '8px', color: '#fca5a5', fontSize: '11px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <span>{speechError}</span>
            <button onClick={() => setSpeechError(null)} style={{ background: 'transparent', border: 'none', color: '#fca5a5', cursor: 'pointer' }}>✕</button>
          </div>
        )}

        {/* Input Bar */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          
          {/* Dedicated Microphone Button */}
          <button 
            onClick={toggleRecording}
            style={{
              width: '46px',
              height: '46px',
              borderRadius: '50%',
              background: isRecording ? 'rgba(239, 68, 68, 0.35)' : 'linear-gradient(135deg, #10b981, #059669)',
              border: isRecording ? '2px solid #ef4444' : 'none',
              color: isRecording ? '#fca5a5' : '#ffffff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: isRecording ? '0 0 20px rgba(239, 68, 68, 0.5)' : '0 4px 14px rgba(16, 185, 129, 0.4)',
              cursor: 'pointer',
              flexShrink: 0,
              transition: 'all 0.2s'
            }}
            title={isRecording ? "Stop listening" : "Tap to speak instruction"}
          >
            <Mic size={20} className={isRecording ? "animate-pulse" : ""} />
          </button>

          {/* Chat Message Input Field */}
          <input 
            ref={inputRef}
            type="text"
            value={inputMessage}
            onChange={(e) => setInputMessage(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={isRecording ? "Listening... (speech converts to text live)" : "Ask a question or speak a command (e.g. 'Go to inbox')..."}
            style={{
              flex: 1,
              padding: '13px 18px',
              borderRadius: '26px',
              background: 'rgba(0, 0, 0, 0.45)',
              border: '1px solid rgba(255, 255, 255, 0.14)',
              color: '#ffffff',
              fontSize: '14px',
              outline: 'none',
              transition: 'border-color 0.2s'
            }}
            onFocus={(e) => e.target.style.borderColor = '#3b82f6'}
            onBlur={(e) => e.target.style.borderColor = 'rgba(255, 255, 255, 0.14)'}
          />

          {/* Send Button */}
          <button 
            onClick={() => handleSendMessage()}
            disabled={!inputMessage.trim() && !interimTranscript.trim() || isProcessing}
            style={{
              width: '44px',
              height: '44px',
              borderRadius: '50%',
              background: (inputMessage.trim() || interimTranscript.trim()) && !isProcessing ? 'linear-gradient(135deg, #3b82f6, #2563eb)' : 'rgba(255, 255, 255, 0.08)',
              border: 'none',
              color: '#ffffff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: (inputMessage.trim() || interimTranscript.trim()) && !isProcessing ? 'pointer' : 'not-allowed',
              flexShrink: 0,
              boxShadow: (inputMessage.trim() || interimTranscript.trim()) && !isProcessing ? '0 4px 14px rgba(59, 130, 246, 0.4)' : 'none',
              transition: 'all 0.2s'
            }}
            title="Send instruction"
          >
            <Send size={18} />
          </button>
        </div>

      </div>

    </div>
  );
}
