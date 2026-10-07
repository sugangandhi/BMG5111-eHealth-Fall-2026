import React, { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import { 
  Mic, MicOff, Send, Sparkles, Volume2, VolumeX, Copy, Bookmark, 
  FileText, Activity, Layers, Tag, ShieldCheck, CheckCircle2, 
  RefreshCw, X, Calendar, Clock, User, ChevronRight, MessageCircle, ExternalLink, Bot
} from 'lucide-react';

export default function Scribe() {
  const [isOpen, setIsOpen] = useState(false);
  const [inputQuery, setInputQuery] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [voiceFeedback, setVoiceFeedback] = useState(false);
  const [copiedId, setCopiedId] = useState(null);
  const [aiEngine, setAiEngine] = useState('EHR Integrated');

  useEffect(() => {
    axios.get('/api/ai/status')
      .then(res => {
        if (res.data?.display_name) setAiEngine(res.data.display_name);
      })
      .catch(() => {});
  }, []);

  // Chat message thread
  const [messages, setMessages] = useState([
    {
      id: 1,
      role: 'assistant',
      text: "Hello Doctor, I'm your Clinical Assistant. You can ask me about today's schedule, look up patient vitals, check inbox triage, or dictate an encounter note.",
      timestamp: 'Just now',
      suggested_prompts: [
        "Tell me the appointments today",
        "What are Sarah Khan's vitals?",
        "Check urgent triage inbox",
        "Take a note for patient with chest pain"
      ]
    }
  ]);

  const messagesEndRef = useRef(null);
  const recognitionRef = useRef(null);
  const inputRef = useRef(null);
  const baseQueryRef = useRef('');

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    if (isOpen) {
      scrollToBottom();
      setTimeout(() => inputRef.current?.focus(), 150);
    }
  }, [messages, isOpen]);

  // Global listeners for opening scribe
  useEffect(() => {
    const handleOpen = () => setIsOpen(true);
    const handleStart = () => {
      setIsOpen(true);
      if (!isRecording) startSpeechRecognition();
    };
    window.addEventListener('open-scribe', handleOpen);
    window.addEventListener('start-scribe', handleStart);
    return () => {
      window.removeEventListener('open-scribe', handleOpen);
      window.removeEventListener('start-scribe', handleStart);
    };
  }, [isRecording]);

  // Web Speech Recognition — Accurate single-stream accumulator (prevents repeated words)
  const startSpeechRecognition = () => {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      alert("Speech recognition is not supported in this browser. Please use Chrome or Edge.");
      return;
    }

    try {
      const recognition = new SpeechRecognition();
      recognition.continuous = true;
      recognition.interimResults = true;
      recognition.lang = 'en-US';

      // Store any text typed before recording was initiated
      baseQueryRef.current = inputRef.current?.value?.trim() || '';

      recognition.onstart = () => {
        setIsRecording(true);
      };

      recognition.onresult = (event) => {
        // Build the cumulative speech stream from session start to eliminate repetition
        let cumulativeTranscript = '';
        for (let i = 0; i < event.results.length; ++i) {
          cumulativeTranscript += event.results[i][0].transcript;
        }
        const spoken = cumulativeTranscript.trim();
        const base = baseQueryRef.current;
        if (base && spoken) {
          setInputQuery(`${base} ${spoken}`);
        } else if (spoken) {
          setInputQuery(spoken);
        }
      };

      recognition.onerror = (e) => {
        console.warn("Speech recognition error:", e);
        setIsRecording(false);
      };

      recognition.onend = () => {
        setIsRecording(false);
      };

      recognitionRef.current = recognition;
      recognition.start();
    } catch (e) {
      console.error("Speech init error:", e);
      setIsRecording(false);
    }
  };

  const stopSpeechRecognition = () => {
    if (recognitionRef.current) {
      try {
        recognitionRef.current.stop();
      } catch (e) {}
    }
    setIsRecording(false);
  };

  const toggleRecording = () => {
    if (isRecording) {
      stopSpeechRecognition();
    } else {
      startSpeechRecognition();
    }
  };

  const speakText = (text) => {
    if (!voiceFeedback || !('speechSynthesis' in window)) return;
    try {
      window.speechSynthesis.cancel();
      const clean = text.replace(/[*#`_]/g, '');
      const utterance = new SpeechSynthesisUtterance(clean);
      utterance.rate = 1.05;
      window.speechSynthesis.speak(utterance);
    } catch (e) {
      console.warn("Speech synthesis note:", e);
    }
  };

  const handleSendQuery = async (queryToSend = null) => {
    const text = (queryToSend || inputQuery).trim();
    if (!text || isProcessing) return;

    if (isRecording) {
      stopSpeechRecognition();
    }

    const userMsg = {
      id: Date.now(),
      role: 'doctor',
      text: text,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    };

    setMessages(prev => [...prev, userMsg]);
    setInputQuery('');
    setIsProcessing(true);

    try {
      const activePatient = JSON.parse(localStorage.getItem('active_patient_context') || 'null');
      const res = await axios.post('/api/assistant/chat', {
        query: text,
        active_patient: activePatient
      });

      const data = res.data;
      const botMsg = {
        id: Date.now() + 1,
        role: 'assistant',
        text: data.reply || "Clinical request processed.",
        intent: data.intent,
        appointments: data.appointments || null,
        soap_note: data.soap_note || null,
        vitals: data.vitals || null,
        suggested_prompts: data.suggested_prompts || [],
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };

      setMessages(prev => [...prev, botMsg]);

      if (voiceFeedback && data.reply) {
        speakText(data.reply);
      }
    } catch (err) {
      console.error("Assistant chat error:", err);
      setMessages(prev => [
        ...prev,
        {
          id: Date.now() + 1,
          role: 'assistant',
          text: "I encountered an issue connecting to the clinical backend. Please verify that the server is running.",
          timestamp: 'Just now'
        }
      ]);
    } finally {
      setIsProcessing(false);
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  };

  const handleCopyText = (text, id) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const handleSelectPatientChart = (appt) => {
    setIsOpen(false);
    window.dispatchEvent(new CustomEvent('switch-tab', { detail: 'patients' }));
  };

  // Helper to render formatted text cleanly without raw asterisks
  const renderFormattedContent = (content) => {
    if (!content) return null;
    const parts = content.split(/(\*\*.*?\*\*)/g);
    return parts.map((part, index) => {
      if (part.startsWith('**') && part.endsWith('**')) {
        return (
          <strong key={index} style={{ color: '#0f172a', fontWeight: '700' }}>
            {part.slice(2, -2)}
          </strong>
        );
      }
      return part;
    });
  };

  if (!isOpen) return null;

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      background: 'rgba(15, 23, 42, 0.45)',
      backdropFilter: 'blur(4px)',
      zIndex: 100000,
      display: 'flex',
      justifyContent: 'flex-end'
    }}>
      <div 
        className="clinical-white-copilot"
        style={{
          width: '520px',
          maxWidth: '100vw',
          height: '100%',
          background: '#ffffff',
          borderLeft: '1px solid #e2e8f0',
          display: 'flex',
          flexDirection: 'column',
          boxShadow: '-10px 0 35px rgba(0, 0, 0, 0.1)',
          animation: 'slideInRight 0.2s ease-out',
          color: '#0f172a',
          fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif'
        }}
      >
        {/* Professional Header */}
        <div style={{
          padding: '16px 20px',
          borderBottom: '1px solid #e2e8f0',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          background: '#ffffff',
          flexShrink: 0
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{
              width: '38px',
              height: '38px',
              borderRadius: '10px',
              background: '#0f172a',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#ffffff',
              boxShadow: '0 2px 8px rgba(15, 23, 42, 0.25)'
            }}>
              <Bot size={22} />
            </div>
            <div>
              <h2 style={{ margin: 0, fontSize: '15px', fontWeight: '700', color: '#0f172a', display: 'flex', alignItems: 'center', gap: '8px' }}>
                Prime Care AI • Clinical Assistant
              </h2>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: '#16a34a', marginTop: '2px', fontWeight: '600' }}>
                <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#16a34a' }} />
                Online • {aiEngine}
              </div>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <button
              onClick={() => setVoiceFeedback(prev => !prev)}
              style={{
                background: voiceFeedback ? '#f1f5f9' : '#f8fafc',
                border: '1px solid #cbd5e1',
                color: '#0f172a',
                padding: '6px 12px',
                borderRadius: '8px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                fontSize: '12px',
                fontWeight: '600',
                transition: 'all 0.15s'
              }}
              title={voiceFeedback ? "Audio feedback enabled" : "Audio muted"}
            >
              {voiceFeedback ? <Volume2 size={15} /> : <VolumeX size={15} />}
              <span>{voiceFeedback ? "Audio ON" : "Muted"}</span>
            </button>

            <button
              onClick={() => {
                if (isRecording) stopSpeechRecognition();
                setIsOpen(false);
              }}
              style={{
                background: '#f1f5f9',
                border: 'none',
                color: '#64748b',
                width: '34px',
                height: '34px',
                borderRadius: '8px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                transition: 'background 0.15s'
              }}
              title="Close Assistant"
            >
              <X size={18} />
            </button>
          </div>
        </div>

        {/* Chat Feed */}
        <div style={{
          flex: 1,
          overflowY: 'auto',
          padding: '20px 18px',
          background: '#f8fafc',
          display: 'flex',
          flexDirection: 'column',
          gap: '16px'
        }}>
          {messages.map((msg) => {
            const isDoctor = msg.role === 'doctor';
            return (
              <div
                key={msg.id}
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: isDoctor ? 'flex-end' : 'flex-start',
                  maxWidth: '100%'
                }}
              >
                {/* Header label */}
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                  marginBottom: '4px',
                  fontSize: '11.5px',
                  color: '#64748b'
                }}>
                  {isDoctor ? (
                    <>
                      <span>{msg.timestamp}</span>
                      <span style={{ fontWeight: '700', color: '#0f172a' }}>You</span>
                    </>
                  ) : (
                    <>
                      <Bot size={13} color="#0f172a" />
                      <span style={{ fontWeight: '700', color: '#0f172a' }}>Clinical Assistant</span>
                      <span>• {msg.timestamp}</span>
                    </>
                  )}
                </div>

                {/* Bubble Body — Clean White and Black (No blue backgrounds) */}
                <div
                  style={{
                    maxWidth: '88%',
                    padding: '14px 16px',
                    borderRadius: isDoctor ? '16px 16px 4px 16px' : '16px 16px 16px 4px',
                    background: '#ffffff',
                    border: isDoctor ? '1.5px solid #cbd5e1' : '1px solid #e2e8f0',
                    color: '#0f172a',
                    fontSize: '14px',
                    lineHeight: '1.55',
                    boxShadow: '0 1px 3px rgba(0,0,0,0.04)'
                  }}
                >
                  <div style={{ whiteSpace: 'pre-wrap' }}>{renderFormattedContent(msg.text)}</div>

                  {/* Clean Interactive Appointment Cards */}
                  {msg.appointments && msg.appointments.length > 0 && (
                    <div style={{ marginTop: '14px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                      <div style={{ fontSize: '11px', fontWeight: '800', color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                        Scheduled Appointments ({msg.appointments.length})
                      </div>
                      {msg.appointments.slice(0, 6).map((appt, i) => (
                        <div
                          key={i}
                          style={{
                            padding: '12px 14px',
                            borderRadius: '10px',
                            background: '#ffffff',
                            border: '1px solid #e2e8f0',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between',
                            gap: '12px',
                            boxShadow: '0 1px 3px rgba(0,0,0,0.04)'
                          }}
                        >
                          <div style={{ minWidth: 0 }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                              <Clock size={13} color="#0f172a" />
                              <span style={{ fontWeight: '800', color: '#0f172a', fontSize: '13px' }}>{appt.time}</span>
                              <span style={{ fontSize: '11px', color: '#64748b' }}>• {appt.source}</span>
                            </div>
                            <div style={{ fontWeight: '800', fontSize: '14.5px', marginTop: '3px', color: '#0f172a' }}>
                              {appt.patient_name}
                            </div>
                            <div style={{ fontSize: '12px', color: '#64748b', marginTop: '1px' }}>{appt.type}</div>
                          </div>

                          <button
                            onClick={() => handleSelectPatientChart(appt)}
                            style={{
                              background: '#ffffff',
                              border: '1px solid #cbd5e1',
                              color: '#0f172a',
                              padding: '6px 12px',
                              borderRadius: '8px',
                              fontSize: '12px',
                              fontWeight: '700',
                              cursor: 'pointer',
                              display: 'flex',
                              alignItems: 'center',
                              gap: '4px',
                              flexShrink: 0,
                              transition: 'all 0.15s'
                            }}
                          >
                            Open Chart <ChevronRight size={13} />
                          </button>
                        </div>
                      ))}
                    </div>
                  )}

                  {/* Structured SOAP Note Card */}
                  {msg.soap_note && (
                    <div style={{
                      marginTop: '14px',
                      padding: '14px',
                      borderRadius: '12px',
                      background: '#f0fdf4',
                      border: '1px solid #bbf7d0'
                    }}>
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
                        <span style={{ fontSize: '12.5px', fontWeight: '800', color: '#15803d', display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <CheckCircle2 size={16} /> Structured SOAP Note
                        </span>
                        <button
                          onClick={() => handleCopyText(JSON.stringify(msg.soap_note.soap, null, 2), msg.id)}
                          style={{
                            background: '#ffffff',
                            border: '1px solid #bbf7d0',
                            color: copiedId === msg.id ? '#15803d' : '#475569',
                            cursor: 'pointer',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '4px',
                            fontSize: '11px',
                            fontWeight: '700',
                            padding: '4px 8px',
                            borderRadius: '6px'
                          }}
                        >
                          <Copy size={12} /> {copiedId === msg.id ? 'Copied' : 'Copy'}
                        </button>
                      </div>

                      <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '13px', color: '#0f172a' }}>
                        <div>
                          <strong style={{ color: '#1e40af' }}>Subjective: </strong>
                          <span>{msg.soap_note.soap?.subjective}</span>
                        </div>
                        <div>
                          <strong style={{ color: '#047857' }}>Objective: </strong>
                          <span>{msg.soap_note.soap?.objective}</span>
                        </div>
                        <div>
                          <strong style={{ color: '#b45309' }}>Assessment: </strong>
                          <span>{msg.soap_note.soap?.assessment}</span>
                        </div>
                        <div>
                          <strong style={{ color: '#6d28d9' }}>Plan: </strong>
                          <span>{msg.soap_note.soap?.plan}</span>
                        </div>
                      </div>

                      {msg.soap_note.ohip_fee_codes && msg.soap_note.ohip_fee_codes.length > 0 && (
                        <div style={{ marginTop: '10px', paddingTop: '8px', borderTop: '1px solid #dcfce7', display: 'flex', gap: '6px', flexWrap: 'wrap', alignItems: 'center' }}>
                          <span style={{ fontSize: '11px', color: '#64748b', fontWeight: '700' }}>OHIP Billing:</span>
                          {msg.soap_note.ohip_fee_codes.map((c, idx) => (
                            <span key={idx} style={{ fontSize: '11px', padding: '2px 8px', borderRadius: '4px', background: '#eff6ff', color: '#1e40af', border: '1px solid #bfdbfe', fontWeight: '700' }}>
                              {c}
                            </span>
                          ))}
                        </div>
                      )}
                    </div>
                  )}

                  {/* Follow-up Prompt Pills */}
                  {msg.suggested_prompts && msg.suggested_prompts.length > 0 && (
                    <div style={{ marginTop: '14px', display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                      {msg.suggested_prompts.map((p, idx) => (
                        <button
                          key={idx}
                          onClick={() => handleSendQuery(p)}
                          style={{
                            padding: '6px 12px',
                            borderRadius: '16px',
                            background: '#ffffff',
                            border: '1px solid #cbd5e1',
                            color: '#0f172a',
                            fontSize: '12px',
                            fontWeight: '600',
                            cursor: 'pointer',
                            boxShadow: '0 1px 2px rgba(0,0,0,0.03)',
                            transition: 'all 0.15s'
                          }}
                        >
                          {p} →
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            );
          })}

          {isProcessing && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#0f172a', fontSize: '13px', padding: '8px 12px' }}>
              <RefreshCw size={15} className="animate-spin" />
              <span>Analyzing clinical database...</span>
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>

        {/* Input Bar — High Contrast, 100% Reliable Typing */}
        <div style={{
          padding: '14px 18px',
          paddingBottom: '20px',
          background: '#ffffff',
          borderTop: '1px solid #e2e8f0',
          display: 'flex',
          flexDirection: 'column',
          gap: '8px',
          flexShrink: 0
        }}>
          {isRecording && (
            <div style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              padding: '8px 14px',
              borderRadius: '8px',
              background: '#fef2f2',
              border: '1px solid #fecaca',
              color: '#dc2626',
              fontSize: '12.5px',
              fontWeight: '700'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#ef4444' }} className="animate-ping" />
                Listening... Speak clearly into your microphone
              </div>
              <button
                onClick={stopSpeechRecognition}
                style={{ background: 'transparent', border: 'none', color: '#dc2626', cursor: 'pointer', fontWeight: '800' }}
              >
                Done
              </button>
            </div>
          )}

          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            background: '#f8fafc',
            border: isRecording ? '1.5px solid #ef4444' : '1.5px solid #cbd5e1',
            borderRadius: '14px',
            padding: '6px 10px',
            boxShadow: '0 2px 6px rgba(0,0,0,0.03)'
          }}>
            {/* Mic Toggle Button */}
            <button
              onClick={toggleRecording}
              style={{
                width: '38px',
                height: '38px',
                borderRadius: '50%',
                background: isRecording ? '#ef4444' : '#ffffff',
                border: isRecording ? 'none' : '1px solid #cbd5e1',
                color: isRecording ? '#ffffff' : '#0f172a',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexShrink: 0,
                transition: 'all 0.15s'
              }}
              title={isRecording ? "Stop voice listening" : "Start voice speech input"}
            >
              {isRecording ? <MicOff size={18} /> : <Mic size={18} />}
            </button>

            {/* Reliable White Mode Input Field */}
            <input
              ref={inputRef}
              type="text"
              autoFocus
              placeholder="Ask a question or dictate clinical notes..."
              value={inputQuery}
              onChange={(e) => setInputQuery(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  handleSendQuery();
                }
              }}
              style={{
                flex: 1,
                background: 'transparent',
                border: 'none',
                color: '#0f172a',
                fontSize: '14.5px',
                outline: 'none',
                padding: '8px 6px',
                fontWeight: '500'
              }}
            />

            {/* Send Button */}
            <button
              onClick={() => handleSendQuery()}
              disabled={!inputQuery.trim() || isProcessing}
              style={{
                width: '38px',
                height: '38px',
                borderRadius: '10px',
                background: inputQuery.trim() && !isProcessing
                  ? '#0f172a'
                  : '#e2e8f0',
                border: 'none',
                color: inputQuery.trim() && !isProcessing ? '#ffffff' : '#94a3b8',
                cursor: inputQuery.trim() && !isProcessing ? 'pointer' : 'default',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexShrink: 0,
                transition: 'all 0.15s'
              }}
              title="Send to Clinical Assistant"
            >
              <Send size={17} />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
