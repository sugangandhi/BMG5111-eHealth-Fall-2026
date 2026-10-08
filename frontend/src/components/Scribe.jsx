import React, { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import { 
  Mic, MicOff, Send, Sparkles, Volume2, VolumeX, Copy, Bookmark, 
  FileText, Activity, Layers, Tag, ShieldCheck, CheckCircle2, 
  RefreshCw, X, Calendar, Clock, User, ChevronRight, ChevronDown, Check, Pin, MessageCircle, MessageSquare, ExternalLink, Bot,
  History, PlusCircle, Trash2, Archive, FileClock,
  Menu, PanelLeft, PanelLeftClose, Plus, Search
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

  // Dynamic active patient context
  const [currentPatient, setCurrentPatient] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('active_patient_context') || 'null');
    } catch (e) {
      return null;
    }
  });

  const [promptOffset, setPromptOffset] = useState(0);
  const [askedQueries, setAskedQueries] = useState([]);
  const [availablePatients, setAvailablePatients] = useState([]);

  useEffect(() => {
    axios.get('/api/patients')
      .then(res => {
        if (res.data?.patients) {
          setAvailablePatients(res.data.patients);
        }
      })
      .catch(e => console.log("Patients load note in Scribe:", e));
  }, []);

  const filterAndSlicePrompts = (pool, askedList, offset) => {
    const past = (askedList || []).map(q => q.toLowerCase().trim());
    const unasked = pool.filter(item => {
      const itemLow = item.toLowerCase();
      return !past.some(p => p.length > 5 && (p.includes(itemLow) || itemLow.includes(p)));
    });

    const activeList = unasked.length > 0 ? unasked : pool;
    const numToTake = Math.min(4, activeList.length);
    const startIdx = offset % activeList.length;
    const result = [];
    for (let i = 0; i < numToTake; i++) {
      const idx = (startIdx + i) % activeList.length;
      if (!result.includes(activeList[idx])) {
        result.push(activeList[idx]);
      }
    }
    return result;
  };

  const getPromptsForPatient = (patient, askedList = askedQueries, offset = promptOffset) => {
    if (!patient || !patient.name) {
      const generalPool = [
        "Tell me appointments today",
        "Check urgent triage inbox",
        "What are the OHIP billing rules for K030 and A007?",
        "Review David Murphy's CKD staging and labs",
        "Check Robert Chen's COPD inhaler regimen",
        "What are the clinical criteria for WSIB Form 8 completion?",
        "How do I document an encounter SOAP note in the EHR?",
        "Review upcoming clinic schedule for tomorrow"
      ];
      return filterAndSlicePrompts(generalPool, askedList, offset);
    }

    const name = patient.name;
    const conds = ((patient.conditions || []).map(c => typeof c === 'object' ? (c.display || c.name || '') : String(c)).join(' ') + ' ' + (patient.badge || '')).toLowerCase();

    let pool = [];

    if (conds.includes('diabet') || name.toLowerCase().includes('sarah')) {
      pool = [
        `What is ${name}'s latest HbA1c and glycemic trend?`,
        `Review blood pressure & Ramipril dosing for ${name}`,
        `Check lipid panel and Atorvastatin tolerability for ${name}`,
        `What is the OHIP fee code (K030) for ${name}'s diabetes consult?`,
        `Assess microalbuminuria and annual diabetic nephropathy screen for ${name}`,
        `Book next diabetes review appointment for ${name}`,
        `Take an encounter note for ${name}'s diabetes follow-up`,
        `Draft dietary carbohydrate counseling instructions for ${name}`
      ];
    } else if (conds.includes('copd') || conds.includes('lung') || name.toLowerCase().includes('robert')) {
      pool = [
        `Assess COPD exacerbation risk and GOLD staging for ${name}`,
        `Review current inhaler therapy (Tiotropium/Budesonide) for ${name}`,
        `Check baseline resting SpO2 and dyspnea grade for ${name}`,
        `Draft patient instructions for proper inhaler technique for ${name}`,
        `Assess coronary artery disease stability & cardiac symptoms for ${name}`,
        `Book follow-up pulmonary check for ${name}`,
        `Take an encounter note for ${name}'s respiratory consult`,
        `Review vaccination status (Pneumococcal & Influenza) for ${name}`
      ];
    } else if (conds.includes('ckd') || conds.includes('kidney') || conds.includes('renal') || name.toLowerCase().includes('david')) {
      pool = [
        `What are ${name}'s latest eGFR and serum creatinine levels?`,
        `Review renal-safe medications and ACE inhibitor titration for ${name}`,
        `Check serum electrolytes (potassium) & hyperkalemia risk for ${name}`,
        `Assess urine albumin-to-creatinine ratio (uACR) for ${name}`,
        `Schedule ${name}'s quarterly renal review appointment`,
        `Take a clinical progress note for ${name}'s nephrology follow-up`,
        `Review dietary restrictions (low potassium & phosphorus) for ${name}`,
        `Order renal ultrasound and repeat metabolic panel for ${name}`
      ];
    } else if (conds.includes('prenatal') || conds.includes('pregnan') || name.toLowerCase().includes('fatima')) {
      pool = [
        `Review ${name}'s 26-week gestational milestones and growth curve`,
        `Check 75g oral glucose tolerance test (OGTT) protocol for ${name}`,
        `Assess symphysis-fundal height and fetal heart tones for ${name}`,
        `Confirm blood group, Rh(D) status and antibody screen for ${name}`,
        `Take an obstetrical progress note for ${name}'s prenatal visit`,
        `Book 28-week prenatal check and repeat bloodwork for ${name}`,
        `Review fetal movement kick counts instructions with ${name}`,
        `What is the OHIP prenatal fee code (A007/P005) for ${name}?`
      ];
    } else if (conds.includes('wsib') || conds.includes('work') || conds.includes('injury') || conds.includes('wrist') || conds.includes('lumbar') || name.toLowerCase().includes('marcus')) {
      pool = [
        `Review ${name}'s WSIB Form 8 functional abilities & claim status`,
        `Document lumbar spine range of motion and tenderness for ${name}`,
        `Outline modified duties and lifting restrictions (under 10 lbs) for ${name}`,
        `Draft WSIB medical progress report & treatment plan for ${name}`,
        `Schedule physiotherapy reassessment appointment for ${name}`,
        `Take an occupational health encounter note for ${name}`,
        `Assess neuropathic symptoms and straight leg raise test for ${name}`,
        `Review NSAID analgesia and gastroprotection for ${name}`
      ];
    } else if (conds.includes('asthma') || conds.includes('pediatric') || name.toLowerCase().includes('james')) {
      pool = [
        `Review ${name}'s school asthma & EpiPen emergency action plan`,
        `Check pediatric Asthma Control Test (PACT) score for ${name}`,
        `Assess Flovent and Ventolin spacer adherence for ${name}`,
        `Review environmental allergen triggers and eczema topical therapy for ${name}`,
        `Take a pediatric encounter note for ${name}`,
        `Check inhaler refill and renew pharmacy prescription for ${name}`,
        `Book seasonal asthma follow-up for ${name}`,
        `Provide school administration medical authorization letter for ${name}`
      ];
    } else if (conds.includes('rheumatoid') || conds.includes('arthrit') || name.toLowerCase().includes('elena')) {
      pool = [
        `Check ${name}'s Methotrexate lab monitoring (CBC, LFTs, ESR/CRP)`,
        `Assess joint stiffness duration and 28-joint disease activity score (DAS28)`,
        `Confirm Folic acid 5mg supplementation timing for ${name}`,
        `Review DEXA bone mineral density scan & osteoporosis therapy for ${name}`,
        `Take a clinical note for ${name}'s rheumatology follow-up`,
        `Schedule ${name}'s next routine 12-week safety bloodwork`,
        `Assess criteria for biologic or JAK inhibitor step-up therapy for ${name}`,
        `Book next clinical assessment for ${name}`
      ];
    } else if (conds.includes('mental') || conds.includes('depress') || conds.includes('anxiety') || name.toLowerCase().includes('marie')) {
      pool = [
        `Review ${name}'s PHQ-9 depression and GAD-7 anxiety scores`,
        `Assess SSRI tolerability, emotional blunting, and sleep hygiene for ${name}`,
        `Review acute migraine abortive therapy (Triptan) frequency for ${name}`,
        `Take a confidential mental health progress note for ${name}`,
        `Discuss CBT and structured psychotherapy referrals for ${name}`,
        `Book ${name}'s 4-week mental health follow-up appointment`,
        `Screen for suicidal ideation, safety plan, and crisis resources for ${name}`,
        `What is the OHIP psychotherapy fee code (K197/K198) for ${name}?`
      ];
    } else if (conds.includes('oncol') || conds.includes('cancer') || conds.includes('breast') || name.toLowerCase().includes('louise')) {
      pool = [
        `Review ${name}'s post-treatment oncology surveillance interval`,
        `Check routine surveillance bloodwork (CBC, LFTs, Calcium) for ${name}`,
        `Review endocrine therapy (Tamoxifen/Aromatase inhibitor) adherence & side effects`,
        `Schedule annual bilateral surveillance mammogram for ${name}`,
        `Assess bone density DEXA scan and bisphosphonate compliance for ${name}`,
        `Take a clinical progress note for ${name}'s oncology follow-up`,
        `Book oncology liaison check for ${name}`,
        `Review lifestyle, lymphedema precautions, and cardiovascular health for ${name}`
      ];
    } else if (conds.includes('oat') || conds.includes('suboxone') || conds.includes('opioid') || name.toLowerCase().includes('michael')) {
      pool = [
        `Review ${name}'s Suboxone maintenance dosing and craving control`,
        `Check point-of-care urine drug screen status and compliance for ${name}`,
        `Review Hepatitis C viral load and direct-acting antiviral (DAA) staging`,
        `Confirm HIV viral load suppression and Antiretroviral (ART) compliance for ${name}`,
        `Take an encounter note for ${name}'s OAT monthly check-in`,
        `Authorize 30-day OAT pharmacy dispensation and carry doses for ${name}`,
        `Confirm naloxone kit availability and harm reduction counseling for ${name}`,
        `Book next addiction medicine review appointment for ${name}`
      ];
    } else {
      pool = [
        `What are ${name}'s recorded vitals and allergies?`,
        `Review active medications and clinical history for ${name}`,
        `Take a clinical encounter note for ${name}`,
        `Book an appointment for ${name}`,
        `Check recent lab results and diagnostic imaging for ${name}`,
        `Review immunizations and preventive care schedule for ${name}`,
        `What are the relevant OHIP assessment fee codes for ${name}?`,
        `Send WhatsApp follow-up reminder to ${name}`
      ];
    }

    return filterAndSlicePrompts(pool, askedList, offset);
  };

  const getInitialGreeting = (patient) => {
    if (patient && patient.name) {
      return {
        id: 1,
        role: 'assistant',
        text: `Active Patient in Focus: **${patient.name}** (${patient.badge || (patient.conditions || [])[0] || 'Clinic Record'}). How can I assist you with ${patient.name}'s care today?`,
        timestamp: 'Just now'
      };
    }
    return {
      id: 1,
      role: 'assistant',
      text: "Hello Doctor, I'm your Clinical Assistant. You can ask me about today's schedule, look up patient vitals, check inbox triage, or dictate an encounter note.",
      timestamp: 'Just now'
    };
  };

  // ── Antigravity Multi-Session Architecture & Patient Isolation ─────────────
  const SESSIONS_STORAGE_KEY = 'scribe_chat_sessions_v2';
  const ACTIVE_SESSION_KEY = 'scribe_active_session_id_v2';

  const getPatientKey = (patient) => {
    if (!patient) return 'general';
    if (patient.id) return String(patient.id);
    if (patient.name) return patient.name.toLowerCase().replace(/[^a-z0-9]/g, '_');
    return 'general';
  };

  const loadAllSessions = () => {
    try {
      const raw = localStorage.getItem(SESSIONS_STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed) && parsed.length > 0) return parsed;
      }
    } catch (e) {
      console.warn("Error reading sessions from storage:", e);
    }
    return [];
  };

  const saveAllSessions = (sessList) => {
    try {
      localStorage.setItem(SESSIONS_STORAGE_KEY, JSON.stringify(sessList));
    } catch (e) {
      console.warn("Error writing sessions to storage:", e);
    }
  };

  const createNewSessionObject = (patient, customTitle = null) => {
    const pKey = getPatientKey(patient);
    const now = new Date();
    const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    const dateStr = now.toLocaleDateString([], { month: 'short', day: 'numeric' });
    const defaultTitle = patient?.name
      ? `${patient.name} — New Encounter (${dateStr})`
      : `Clinic Session (${dateStr})`;

    return {
      id: `sess_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      patientKey: pKey,
      patientId: patient?.id || null,
      patientName: patient?.name || 'General Clinic',
      patientBadge: patient?.badge || (patient?.conditions && patient?.conditions[0]?.display) || '',
      title: customTitle || defaultTitle,
      createdAt: now.toISOString(),
      updatedAt: now.toISOString(),
      lastDoctorQuery: '',
      messages: [getInitialGreeting(patient)]
    };
  };

  // Sessions collection state
  const [sessions, setSessions] = useState(() => {
    const existing = loadAllSessions();
    if (existing.length > 0) return existing;
    const initialPatient = JSON.parse(localStorage.getItem('active_patient_context') || 'null');
    const firstSess = createNewSessionObject(initialPatient);
    saveAllSessions([firstSess]);
    return [firstSess];
  });

  // Active Session ID state
  const [activeSessionId, setActiveSessionId] = useState(() => {
    const existing = loadAllSessions();
    const storedActive = localStorage.getItem(ACTIVE_SESSION_KEY);
    if (storedActive && existing.some(s => s.id === storedActive)) {
      return storedActive;
    }
    const initialPatient = JSON.parse(localStorage.getItem('active_patient_context') || 'null');
    if (initialPatient && existing.length > 0) {
      const pKey = getPatientKey(initialPatient);
      const match = existing.find(s => s.patientKey === pKey);
      if (match) return match.id;
    }
    if (existing.length > 0) return existing[0].id;
    return null;
  });

  const [showSessionsDropdown, setShowSessionsDropdown] = useState(false);
  const [showHistoryModal, setShowHistoryModal] = useState(false);
  const [historySearch, setHistorySearch] = useState('');
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [sidebarSearch, setSidebarSearch] = useState('');

  // Active session and messages derived cleanly
  const activeSession = sessions.find(s => s.id === activeSessionId) || sessions[0] || null;
  const messages = activeSession ? activeSession.messages : [];

  // Count of total longitudinal entries for the active patient
  const getLongitudinalPatientHistory = (patient) => {
    const pKey = getPatientKey(patient);
    const patientSessions = sessions.filter(s => s.patientKey === pKey);
    const turns = [];
    for (const s of patientSessions) {
      for (const m of s.messages) {
        if (m && m.role && (m.role === 'doctor' || (m.role === 'assistant' && !m.text?.startsWith("Active Patient in Focus:") && !m.text?.startsWith("Hello Doctor")))) {
          turns.push({
            id: m.id,
            role: m.role,
            text: m.text,
            timestamp: m.timestamp,
            session_title: s.title
          });
        }
      }
    }
    return turns;
  };

  const longitudinalArchive = getLongitudinalPatientHistory(currentPatient);
  const archiveCount = longitudinalArchive.length;

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

  const handleShufflePrompts = () => {
    setPromptOffset(prev => prev + 2);
  };

  // Antigravity Session Switching & Clean Patient Isolation
  const handleSwitchPatient = (targetPatient) => {
    if (!targetPatient) {
      setCurrentPatient(null);
      try { localStorage.removeItem('active_patient_context'); } catch(e){}
      window.dispatchEvent(new CustomEvent('set-active-patient', { detail: null }));

      const generalSessions = sessions.filter(s => s.patientKey === 'general');
      if (generalSessions.length > 0) {
        setActiveSessionId(generalSessions[0].id);
        localStorage.setItem(ACTIVE_SESSION_KEY, generalSessions[0].id);
      } else {
        const newSess = createNewSessionObject(null);
        const nextList = [newSess, ...sessions];
        setSessions(nextList);
        setActiveSessionId(newSess.id);
        saveAllSessions(nextList);
        localStorage.setItem(ACTIVE_SESSION_KEY, newSess.id);
      }
      setPromptOffset(0);
      setAskedQueries([]);
      return;
    }

    const pKey = getPatientKey(targetPatient);
    setCurrentPatient(targetPatient);
    try { localStorage.setItem('active_patient_context', JSON.stringify(targetPatient)); } catch(e){}
    window.dispatchEvent(new CustomEvent('set-active-patient', { detail: targetPatient }));

    // Check if this patient already has existing sessions
    const patientSessions = sessions.filter(s => s.patientKey === pKey);
    if (patientSessions.length > 0) {
      // Switch to this patient's most recent session
      const targetSession = patientSessions[0];
      setActiveSessionId(targetSession.id);
      localStorage.setItem(ACTIVE_SESSION_KEY, targetSession.id);
    } else {
      // New patient => start a clean isolated new session for them!
      const newSess = createNewSessionObject(targetPatient);
      const nextList = [newSess, ...sessions];
      setSessions(nextList);
      setActiveSessionId(newSess.id);
      saveAllSessions(nextList);
      localStorage.setItem(ACTIVE_SESSION_KEY, newSess.id);
    }

    setPromptOffset(0);
    setAskedQueries([]);
  };

  // Create a brand new session for current patient or clinic
  const handleNewSession = () => {
    const newSess = createNewSessionObject(currentPatient);
    const nextList = [newSess, ...sessions];
    setSessions(nextList);
    setActiveSessionId(newSess.id);
    saveAllSessions(nextList);
    localStorage.setItem(ACTIVE_SESSION_KEY, newSess.id);
    setShowSessionsDropdown(false);
    setPromptOffset(0);
    setAskedQueries([]);
  };

  const handleDeleteSession = (sessionIdToDelete) => {
    if (sessions.length <= 1) {
      alert("You must keep at least one active session.");
      return;
    }
    const remaining = sessions.filter(s => s.id !== sessionIdToDelete);
    setSessions(remaining);
    saveAllSessions(remaining);
    if (activeSessionId === sessionIdToDelete) {
      const nextId = remaining[0].id;
      setActiveSessionId(nextId);
      localStorage.setItem(ACTIVE_SESSION_KEY, nextId);
    }
  };

  const handleSwitchPatientFromScribe = (patientId) => {
    if (!patientId) {
      handleSwitchPatient(null);
      return;
    }
    const target = availablePatients.find(p => p.id === patientId);
    if (target) {
      const pObj = {
        id: target.id,
        name: target.name,
        mrn: target.mrn || `MRN-${target.id}`,
        conditions: target.conditions || [],
        badge: target.badge || (target.conditions && target.conditions[0]?.display) || '',
        allergies: target.allergies || 'NKDA'
      };
      handleSwitchPatient(pObj);
    }
  };

  // Global listeners for opening scribe and patient context changes
  useEffect(() => {
    const handleOpen = (e) => {
      setIsOpen(true);
      let incoming = e?.detail?.patient;
      if (!incoming) {
        try {
          incoming = JSON.parse(localStorage.getItem('active_patient_context') || 'null');
        } catch (err) {}
      }

      if (incoming && incoming.name) {
        if (!currentPatient || currentPatient.name !== incoming.name || currentPatient.id !== incoming.id) {
          handleSwitchPatient(incoming);
        }
      }
    };

    const handlePatientContextChange = (e) => {
      const p = e?.detail;
      if (p && p.name) {
        if (!currentPatient || currentPatient.name !== p.name || currentPatient.id !== p.id) {
          handleSwitchPatient(p);
        }
      } else if (p === null) {
        handleSwitchPatient(null);
      }
    };

    const handleStart = (e) => {
      setIsOpen(true);
      if (e?.detail?.patient) {
        handleOpen(e);
      }
      if (!isRecording) startSpeechRecognition();
    };

    window.addEventListener('open-scribe', handleOpen);
    window.addEventListener('start-scribe', handleStart);
    window.addEventListener('set-active-patient', handlePatientContextChange);
    return () => {
      window.removeEventListener('open-scribe', handleOpen);
      window.removeEventListener('start-scribe', handleStart);
      window.removeEventListener('set-active-patient', handlePatientContextChange);
    };
  }, [isRecording, currentPatient, sessions, activeSessionId]);

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

    setAskedQueries(prev => [...prev, text]);
    setPromptOffset(prev => prev + 1);

    const userMsg = {
      id: Date.now(),
      role: 'doctor',
      text: text,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    };

    // Update active session immediately with userMsg and set lastDoctorQuery
    setSessions(prevSessions => {
      const updated = prevSessions.map(sess => {
        if (sess.id === activeSessionId) {
          const nextMsgs = [...sess.messages, userMsg];
          let title = sess.title;
          if (sess.title.includes('New Encounter') || sess.title.includes('Clinic Session')) {
            title = text.length > 34 ? text.slice(0, 34) + '...' : text;
          }
          return {
            ...sess,
            title,
            lastDoctorQuery: text,
            messages: nextMsgs,
            updatedAt: new Date().toISOString()
          };
        }
        return sess;
      });
      saveAllSessions(updated);
      return updated;
    });

    setInputQuery('');
    setIsProcessing(true);

    try {
      const activePatient = currentPatient || JSON.parse(localStorage.getItem('active_patient_context') || 'null');
      const patientHistory = getLongitudinalPatientHistory(activePatient);

      const res = await axios.post('/api/assistant/chat', {
        query: text,
        active_patient: activePatient,
        previous_queries: [...askedQueries, text],
        patient_history: patientHistory
      });

      const data = res.data;

      // Automatically sync active patient if discussion targeted another patient
      if (data.patient_name && (!activePatient || activePatient.name !== data.patient_name)) {
        const matched = availablePatients.find(p => p.name.toLowerCase() === data.patient_name.toLowerCase());
        const switched = matched || { name: data.patient_name, badge: 'Clinical Discussion' };
        window.dispatchEvent(new CustomEvent('set-active-patient', { detail: switched }));
        handleSwitchPatient(switched);
      }

      const botMsg = {
        id: Date.now() + 1,
        role: 'assistant',
        text: data.reply || "Clinical request processed.",
        intent: data.intent,
        appointments: data.appointments || null,
        soap_note: data.soap_note || null,
        vitals: data.vitals || null,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      };

      setSessions(prevSessions => {
        const updated = prevSessions.map(sess => {
          if (sess.id === activeSessionId) {
            return {
              ...sess,
              messages: [...sess.messages, botMsg],
              updatedAt: new Date().toISOString()
            };
          }
          return sess;
        });
        saveAllSessions(updated);
        return updated;
      });

      if (voiceFeedback && data.reply) {
        speakText(data.reply);
      }
    } catch (err) {
      console.error("Assistant chat error:", err);
      const errorMsg = {
        id: Date.now() + 1,
        role: 'assistant',
        text: "I encountered an issue connecting to the clinical backend. Please verify that the server is running.",
        timestamp: 'Just now'
      };
      setSessions(prevSessions => {
        const updated = prevSessions.map(sess => {
          if (sess.id === activeSessionId) {
            return {
              ...sess,
              messages: [...sess.messages, errorMsg],
              updatedAt: new Date().toISOString()
            };
          }
          return sess;
        });
        saveAllSessions(updated);
        return updated;
      });
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

  const handleClearPatientFocus = () => {
    handleSwitchPatient(null);
  };

  const handleSelectPatientChart = (appt) => {
    const matched = availablePatients.find(p => p.id === appt.patient_id || p.name === appt.patient_name);
    const pObj = matched || {
      id: appt.patient_id,
      name: appt.patient_name,
      badge: appt.type || 'Appointment'
    };
    handleSwitchPatient(pObj);
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

  const currentPatientKey = getPatientKey(currentPatient);
  const currentPatientSessions = sessions.filter(s => s.patientKey === currentPatientKey);
  const otherPatientSessions = sessions.filter(s => s.patientKey !== currentPatientKey);

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
          position: 'relative',
          overflow: 'hidden',
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
        <style>{`
          @keyframes slideInLeft {
            from { transform: translateX(-100%); }
            to { transform: translateX(0); }
          }
          @keyframes slideInRight {
            from { transform: translateX(100%); }
            to { transform: translateX(0); }
          }
          @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
          }
        `}</style>

        {/* Pull-out Tab Handle on Left Edge */}
        {!isSidebarOpen && (
          <button
            onClick={() => setIsSidebarOpen(true)}
            style={{
              position: 'absolute',
              left: 0,
              top: '120px',
              zIndex: 35,
              background: '#ffffff',
              border: '1px solid #cbd5e1',
              borderLeft: 'none',
              borderRadius: '0 8px 8px 0',
              padding: '8px 5px',
              cursor: 'pointer',
              boxShadow: '2px 1px 8px rgba(0,0,0,0.08)',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              gap: '4px',
              color: '#2563eb',
              transition: 'all 0.15s'
            }}
            title="Pull out conversations sidebar"
          >
            <PanelLeft size={14} />
            <span style={{ fontSize: '9px', fontWeight: '800', writingMode: 'vertical-rl', textOrientation: 'mixed', letterSpacing: '0.6px', color: '#475569' }}>
              CHATS
            </span>
          </button>
        )}

        {/* Slide-out Conversations Side Menu Drawer */}
        {isSidebarOpen && (
          <>
            {/* Backdrop */}
            <div
              onClick={() => setIsSidebarOpen(false)}
              style={{
                position: 'absolute',
                top: 0,
                bottom: 0,
                left: 0,
                right: 0,
                background: 'rgba(15, 23, 42, 0.35)',
                backdropFilter: 'blur(2px)',
                zIndex: 100,
                animation: 'fadeIn 0.15s ease-out'
              }}
            />

            {/* Sidebar Panel */}
            <div
              style={{
                position: 'absolute',
                top: 0,
                bottom: 0,
                left: 0,
                width: '320px',
                maxWidth: '85%',
                background: '#ffffff',
                borderRight: '1px solid #e2e8f0',
                zIndex: 110,
                display: 'flex',
                flexDirection: 'column',
                boxShadow: '4px 0 24px rgba(0, 0, 0, 0.15)',
                animation: 'slideInLeft 0.18s ease-out'
              }}
            >
              {/* Header */}
              <div style={{
                padding: '14px 16px',
                borderBottom: '1px solid #e2e8f0',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                background: '#f8fafc',
                flexShrink: 0
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <MessageSquare size={17} color="#2563eb" />
                  <span style={{ fontWeight: '800', fontSize: '14px', color: '#0f172a' }}>
                    Conversations
                  </span>
                  <span style={{
                    fontSize: '11px',
                    fontWeight: '700',
                    background: '#e0f2fe',
                    color: '#0369a1',
                    padding: '1px 6px',
                    borderRadius: '10px'
                  }}>
                    {sessions.length}
                  </span>
                </div>

                <button
                  onClick={() => setIsSidebarOpen(false)}
                  style={{
                    background: '#ffffff',
                    border: '1px solid #cbd5e1',
                    borderRadius: '6px',
                    color: '#64748b',
                    width: '28px',
                    height: '28px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: 'pointer'
                  }}
                  title="Close sidebar"
                >
                  <PanelLeftClose size={15} />
                </button>
              </div>

              {/* Start New Conversation Action Button */}
              <div style={{ padding: '12px 14px', borderBottom: '1px solid #f1f5f9', flexShrink: 0 }}>
                <button
                  onClick={() => {
                    handleNewSession();
                    setIsSidebarOpen(false);
                  }}
                  style={{
                    width: '100%',
                    background: '#2563eb',
                    border: 'none',
                    borderRadius: '8px',
                    color: '#ffffff',
                    padding: '9px 12px',
                    fontSize: '12.5px',
                    fontWeight: '700',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '6px',
                    boxShadow: '0 2px 6px rgba(37,99,235,0.25)',
                    transition: 'background 0.15s'
                  }}
                  onMouseEnter={(e) => e.currentTarget.style.background = '#1d4ed8'}
                  onMouseLeave={(e) => e.currentTarget.style.background = '#2563eb'}
                >
                  <Plus size={16} />
                  <span>Start New Conversation</span>
                </button>
              </div>

              {/* Search Filter */}
              <div style={{ padding: '8px 14px', borderBottom: '1px solid #f1f5f9', flexShrink: 0 }}>
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                  background: '#f8fafc',
                  border: '1px solid #cbd5e1',
                  borderRadius: '6px',
                  padding: '5px 8px'
                }}>
                  <Search size={13} color="#64748b" />
                  <input
                    type="text"
                    placeholder="Search conversations..."
                    value={sidebarSearch}
                    onChange={(e) => setSidebarSearch(e.target.value)}
                    style={{
                      border: 'none',
                      background: 'transparent',
                      fontSize: '12px',
                      color: '#0f172a',
                      outline: 'none',
                      width: '100%'
                    }}
                  />
                  {sidebarSearch && (
                    <button
                      onClick={() => setSidebarSearch('')}
                      style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', fontSize: '11px', padding: 0 }}
                    >
                      ✕
                    </button>
                  )}
                </div>
              </div>

              {/* Conversations List */}
              <div style={{
                flex: 1,
                overflowY: 'auto',
                padding: '10px 12px',
                display: 'flex',
                flexDirection: 'column',
                gap: '8px'
              }}>
                {(() => {
                  const query = sidebarSearch.toLowerCase().trim();
                  const filterSess = (list) => {
                    if (!query) return list;
                    return list.filter(s =>
                      s.title?.toLowerCase().includes(query) ||
                      s.patientName?.toLowerCase().includes(query) ||
                      s.lastDoctorQuery?.toLowerCase().includes(query)
                    );
                  };

                  const filteredCurrent = filterSess(currentPatientSessions);
                  const filteredOther = filterSess(otherPatientSessions);

                  if (filteredCurrent.length === 0 && filteredOther.length === 0) {
                    return (
                      <div style={{ textAlign: 'center', padding: '24px 10px', color: '#64748b', fontSize: '12.5px' }}>
                        No conversations found matching "{sidebarSearch}"
                      </div>
                    );
                  }

                  return (
                    <>
                      {/* Current Patient's Conversations Section */}
                      <div>
                        <div style={{
                          fontSize: '10.5px',
                          fontWeight: '800',
                          color: '#64748b',
                          textTransform: 'uppercase',
                          letterSpacing: '0.5px',
                          marginBottom: '6px',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'space-between'
                        }}>
                          <span>{currentPatient ? `${currentPatient.name}'s Chats` : 'General Clinic Chats'}</span>
                          <span>({filteredCurrent.length})</span>
                        </div>

                        <div style={{ display: 'flex', flexDirection: 'column', gap: '5px' }}>
                          {filteredCurrent.map((sess) => {
                            const isActive = sess.id === activeSessionId;
                            return (
                              <div
                                key={sess.id}
                                onClick={() => {
                                  setActiveSessionId(sess.id);
                                  localStorage.setItem(ACTIVE_SESSION_KEY, sess.id);
                                  setIsSidebarOpen(false);
                                }}
                                style={{
                                  padding: '9px 10px',
                                  borderRadius: '8px',
                                  background: isActive ? '#eff6ff' : '#ffffff',
                                  border: isActive ? '1.5px solid #60a5fa' : '1px solid #e2e8f0',
                                  boxShadow: isActive ? '0 2px 6px rgba(37,99,235,0.1)' : '0 1px 2px rgba(0,0,0,0.02)',
                                  cursor: 'pointer',
                                  display: 'flex',
                                  alignItems: 'flex-start',
                                  justifyContent: 'space-between',
                                  gap: '8px',
                                  transition: 'all 0.15s'
                                }}
                              >
                                <div style={{ minWidth: 0, flex: 1 }}>
                                  <div style={{
                                    fontSize: '12px',
                                    fontWeight: isActive ? '800' : '600',
                                    color: isActive ? '#1d4ed8' : '#0f172a',
                                    whiteSpace: 'nowrap',
                                    overflow: 'hidden',
                                    textOverflow: 'ellipsis'
                                  }}>
                                    {sess.title}
                                  </div>
                                  {sess.lastDoctorQuery && (
                                    <div style={{
                                      fontSize: '11px',
                                      color: '#64748b',
                                      whiteSpace: 'nowrap',
                                      overflow: 'hidden',
                                      textOverflow: 'ellipsis',
                                      marginTop: '2px'
                                    }}>
                                      "{sess.lastDoctorQuery}"
                                    </div>
                                  )}
                                  <div style={{
                                    fontSize: '10px',
                                    color: '#94a3b8',
                                    marginTop: '3px',
                                    display: 'flex',
                                    alignItems: 'center',
                                    gap: '6px'
                                  }}>
                                    <span>{sess.messages.length} {sess.messages.length === 1 ? 'msg' : 'msgs'}</span>
                                    <span>•</span>
                                    <span>{new Date(sess.updatedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                                  </div>
                                </div>

                                <div style={{ display: 'flex', alignItems: 'center', gap: '4px', flexShrink: 0 }}>
                                  {isActive && (
                                    <span style={{
                                      background: '#2563eb',
                                      color: '#ffffff',
                                      borderRadius: '50%',
                                      width: '16px',
                                      height: '16px',
                                      display: 'flex',
                                      alignItems: 'center',
                                      justifyContent: 'center',
                                      fontSize: '10px'
                                    }}>
                                      <Check size={10} />
                                    </span>
                                  )}
                                  {sessions.length > 1 && (
                                    <button
                                      onClick={(e) => {
                                        e.stopPropagation();
                                        handleDeleteSession(sess.id);
                                      }}
                                      style={{
                                        background: 'transparent',
                                        border: 'none',
                                        color: '#94a3b8',
                                        cursor: 'pointer',
                                        padding: '3px',
                                        display: 'flex',
                                        alignItems: 'center',
                                        borderRadius: '4px'
                                      }}
                                      onMouseEnter={(e) => e.currentTarget.style.color = '#ef4444'}
                                      onMouseLeave={(e) => e.currentTarget.style.color = '#94a3b8'}
                                      title="Delete conversation"
                                    >
                                      <Trash2 size={12} />
                                    </button>
                                  )}
                                </div>
                              </div>
                            );
                          })}
                        </div>
                      </div>

                      {/* Other Patients' Conversations Section */}
                      {filteredOther.length > 0 && (
                        <div style={{ marginTop: '10px', borderTop: '1px solid #f1f5f9', paddingTop: '10px' }}>
                          <div style={{
                            fontSize: '10.5px',
                            fontWeight: '800',
                            color: '#64748b',
                            textTransform: 'uppercase',
                            letterSpacing: '0.5px',
                            marginBottom: '6px',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between'
                          }}>
                            <span>Other Patients' Chats</span>
                            <span>({filteredOther.length})</span>
                          </div>

                          <div style={{ display: 'flex', flexDirection: 'column', gap: '5px' }}>
                            {filteredOther.map((sess) => (
                              <div
                                key={sess.id}
                                onClick={() => {
                                  const matchedPt = availablePatients.find(p => p.name === sess.patientName || p.id === sess.patientId);
                                  if (matchedPt) {
                                    setCurrentPatient(matchedPt);
                                    try { localStorage.setItem('active_patient_context', JSON.stringify(matchedPt)); } catch(e){}
                                    window.dispatchEvent(new CustomEvent('set-active-patient', { detail: matchedPt }));
                                  } else {
                                    const ptObj = { name: sess.patientName, id: sess.patientId, badge: sess.patientBadge };
                                    setCurrentPatient(ptObj);
                                    try { localStorage.setItem('active_patient_context', JSON.stringify(ptObj)); } catch(e){}
                                  }
                                  setActiveSessionId(sess.id);
                                  localStorage.setItem(ACTIVE_SESSION_KEY, sess.id);
                                  setIsSidebarOpen(false);
                                }}
                                style={{
                                  padding: '9px 10px',
                                  borderRadius: '8px',
                                  background: '#ffffff',
                                  border: '1px solid #e2e8f0',
                                  boxShadow: '0 1px 2px rgba(0,0,0,0.02)',
                                  cursor: 'pointer',
                                  display: 'flex',
                                  alignItems: 'flex-start',
                                  justifyContent: 'space-between',
                                  gap: '8px',
                                  transition: 'all 0.15s'
                                }}
                              >
                                <div style={{ minWidth: 0, flex: 1 }}>
                                  <div style={{ display: 'flex', alignItems: 'center', gap: '5px', marginBottom: '2px' }}>
                                    <span style={{
                                      fontSize: '10px',
                                      fontWeight: '800',
                                      background: '#e0f2fe',
                                      color: '#0369a1',
                                      padding: '1px 5px',
                                      borderRadius: '4px'
                                    }}>
                                      {sess.patientName}
                                    </span>
                                  </div>
                                  <div style={{
                                    fontSize: '12px',
                                    fontWeight: '600',
                                    color: '#0f172a',
                                    whiteSpace: 'nowrap',
                                    overflow: 'hidden',
                                    textOverflow: 'ellipsis'
                                  }}>
                                    {sess.title}
                                  </div>
                                  <div style={{
                                    fontSize: '10px',
                                    color: '#94a3b8',
                                    marginTop: '2px'
                                  }}>
                                    {sess.messages.length} msgs • {new Date(sess.updatedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                                  </div>
                                </div>

                                <div style={{ display: 'flex', alignItems: 'center', gap: '2px', flexShrink: 0 }}>
                                  <ChevronRight size={13} color="#94a3b8" />
                                </div>
                              </div>
                            ))}
                          </div>
                        </div>
                      )}
                    </>
                  );
                })()}
              </div>

              {/* Sidebar Footer */}
              <div style={{
                padding: '10px 14px',
                borderTop: '1px solid #e2e8f0',
                background: '#f8fafc',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                flexShrink: 0
              }}>
                <button
                  onClick={() => {
                    setIsSidebarOpen(false);
                    setShowHistoryModal(true);
                  }}
                  style={{
                    background: '#ffffff',
                    border: '1px solid #cbd5e1',
                    borderRadius: '6px',
                    color: '#0f172a',
                    fontSize: '11px',
                    fontWeight: '700',
                    padding: '5px 10px',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px'
                  }}
                >
                  <History size={12} color="#2563eb" />
                  <span>History ({archiveCount})</span>
                </button>

                <button
                  onClick={() => setIsSidebarOpen(false)}
                  style={{
                    background: 'transparent',
                    border: 'none',
                    color: '#64748b',
                    fontSize: '11.5px',
                    fontWeight: '600',
                    cursor: 'pointer'
                  }}
                >
                  Close
                </button>
              </div>
            </div>
          </>
        )}

        {/* Professional Header */}
        <div style={{
          padding: '14px 18px',
          borderBottom: '1px solid #e2e8f0',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          background: '#ffffff',
          flexShrink: 0,
          position: 'relative'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            {/* Sidebar Toggle Menu Button */}
            <button
              onClick={() => setIsSidebarOpen(prev => !prev)}
              style={{
                background: isSidebarOpen ? '#eff6ff' : '#f8fafc',
                border: isSidebarOpen ? '1px solid #93c5fd' : '1px solid #cbd5e1',
                color: isSidebarOpen ? '#2563eb' : '#0f172a',
                padding: '6px 9px',
                borderRadius: '8px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '5px',
                fontSize: '12px',
                fontWeight: '700',
                transition: 'all 0.15s',
                boxShadow: '0 1px 2px rgba(0,0,0,0.03)'
              }}
              title={isSidebarOpen ? "Close conversations sidebar" : "Open conversations sidebar (view all chats)"}
            >
              {isSidebarOpen ? <PanelLeftClose size={16} /> : <PanelLeft size={16} />}
              <span>Chats</span>
            </button>

            <div style={{
              width: '36px',
              height: '36px',
              borderRadius: '10px',
              background: '#2563eb',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#ffffff',
              boxShadow: '0 2px 6px rgba(37, 99, 235, 0.25)'
            }}>
              <Bot size={20} />
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

        {/* Active Patient Focus Banner & Fast Chart Switcher */}
        <div style={{
          padding: '10px 18px',
          background: '#f8fafc',
          borderBottom: '1px solid #e2e8f0',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: '10px',
          fontSize: '12px',
          flexShrink: 0
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', minWidth: 0, flex: 1 }}>
            <span style={{
              width: '8px',
              height: '8px',
              borderRadius: '50%',
              background: currentPatient ? '#16a34a' : '#64748b',
              flexShrink: 0
            }} />
            <span style={{ color: '#64748b', fontWeight: '600', flexShrink: 0 }}>
              {currentPatient ? 'Active Patient:' : 'Clinic Scope:'}
            </span>
            <strong style={{
              color: '#0f172a',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              maxWidth: '135px'
            }}>
              {currentPatient ? currentPatient.name : 'General Clinic'}
            </strong>
            {currentPatient?.badge && (
              <span style={{
                padding: '2px 8px',
                borderRadius: '12px',
                background: '#e0f2fe',
                color: '#0369a1',
                fontSize: '10.5px',
                fontWeight: '700',
                whiteSpace: 'nowrap',
                flexShrink: 0
              }}>
                {currentPatient.badge}
              </span>
            )}
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexShrink: 0 }}>
            {availablePatients.length > 0 && (
              <select
                value={currentPatient?.id || ''}
                onChange={(e) => handleSwitchPatientFromScribe(e.target.value)}
                style={{
                  background: '#ffffff',
                  border: '1px solid #cbd5e1',
                  borderRadius: '6px',
                  color: '#0f172a',
                  fontSize: '11px',
                  fontWeight: '600',
                  padding: '3px 6px',
                  cursor: 'pointer',
                  outline: 'none'
                }}
                title="Switch active patient chart"
              >
                <option value="">⇄ Switch Patient...</option>
                {availablePatients.map(p => (
                  <option key={p.id} value={p.id}>
                    {p.name}
                  </option>
                ))}
              </select>
            )}

            {currentPatient && (
              <button
                onClick={handleClearPatientFocus}
                style={{
                  background: 'transparent',
                  border: 'none',
                  color: '#64748b',
                  cursor: 'pointer',
                  fontSize: '11px',
                  fontWeight: '700',
                  textDecoration: 'underline',
                  padding: '2px 4px'
                }}
                title="Clear patient focus and return to general clinic mode"
              >
                Clear ✕
              </button>
            )}
          </div>
        </div>

        {/* Antigravity Session Bar */}
        <div style={{
          padding: '8px 16px',
          background: '#f8fafc',
          borderBottom: '1px solid #e2e8f0',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: '8px',
          fontSize: '12px',
          flexShrink: 0,
          position: 'relative'
        }}>
          {/* Active Session Dropdown Selector */}
          <div style={{ position: 'relative', minWidth: 0, flex: 1 }}>
            <button
              onClick={() => setIsSidebarOpen(true)}
              style={{
                background: '#ffffff',
                border: '1px solid #cbd5e1',
                borderRadius: '8px',
                color: '#0f172a',
                padding: '5px 10px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                maxWidth: '280px',
                width: '100%',
                boxShadow: '0 1px 2px rgba(0,0,0,0.03)',
                transition: 'all 0.15s'
              }}
              title="Click to view all conversations in side menu"
            >
              <PanelLeft size={13} color="#2563eb" style={{ flexShrink: 0 }} />
              <span style={{
                fontWeight: '700',
                fontSize: '11.5px',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
                textAlign: 'left',
                flex: 1
              }}>
                {activeSession?.title || 'Current Session'}
              </span>
              <ChevronDown size={13} color="#64748b" style={{ flexShrink: 0 }} />
            </button>

            {/* Antigravity Sessions Dropdown Menu */}
            {showSessionsDropdown && (
              <>
                <div
                  onClick={() => setShowSessionsDropdown(false)}
                  style={{
                    position: 'fixed',
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    zIndex: 100020
                  }}
                />
                <div style={{
                  position: 'absolute',
                  top: '100%',
                  left: 0,
                  marginTop: '6px',
                  width: '320px',
                  maxHeight: '400px',
                  background: '#ffffff',
                  border: '1px solid #cbd5e1',
                  borderRadius: '10px',
                  boxShadow: '0 10px 25px rgba(0,0,0,0.12)',
                  zIndex: 100025,
                  display: 'flex',
                  flexDirection: 'column',
                  overflow: 'hidden',
                  animation: 'fadeIn 0.1s ease-out'
                }}>
                  {/* Dropdown Header */}
                  <div style={{
                    padding: '10px 14px',
                    borderBottom: '1px solid #e2e8f0',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    background: '#f8fafc'
                  }}>
                    <span style={{ fontSize: '11.5px', fontWeight: '800', color: '#0f172a' }}>
                      Clinical Sessions ({sessions.length})
                    </span>
                    <button
                      onClick={handleNewSession}
                      style={{
                        background: '#0f172a',
                        border: 'none',
                        color: '#ffffff',
                        fontSize: '10.5px',
                        fontWeight: '700',
                        padding: '4px 8px',
                        borderRadius: '6px',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px'
                      }}
                    >
                      <PlusCircle size={11} /> New Session
                    </button>
                  </div>

                  {/* Sessions Scrollable List */}
                  <div style={{
                    flex: 1,
                    overflowY: 'auto',
                    padding: '6px',
                    display: 'flex',
                    flexDirection: 'column',
                    gap: '4px',
                    maxHeight: '300px'
                  }}>
                    {/* Current Patient's Sessions */}
                    <div style={{ fontSize: '10px', fontWeight: '800', color: '#64748b', padding: '4px 8px', textTransform: 'uppercase', letterSpacing: '0.4px' }}>
                      {currentPatient ? `${currentPatient.name}'s Sessions` : 'General Clinic Sessions'}
                    </div>

                    {currentPatientSessions.map((sess) => {
                      const isActive = sess.id === activeSessionId;
                      return (
                        <div
                          key={sess.id}
                          style={{
                            padding: '8px 10px',
                            borderRadius: '6px',
                            background: isActive ? '#f1f5f9' : '#ffffff',
                            border: isActive ? '1px solid #cbd5e1' : '1px solid transparent',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between',
                            cursor: 'pointer',
                            gap: '8px',
                            transition: 'all 0.1s'
                          }}
                          onClick={() => {
                            setActiveSessionId(sess.id);
                            localStorage.setItem(ACTIVE_SESSION_KEY, sess.id);
                            setShowSessionsDropdown(false);
                          }}
                        >
                          <div style={{ minWidth: 0, flex: 1 }}>
                            <div style={{
                              fontWeight: isActive ? '800' : '600',
                              fontSize: '12px',
                              color: '#0f172a',
                              overflow: 'hidden',
                              textOverflow: 'ellipsis',
                              whiteSpace: 'nowrap'
                            }}>
                              {sess.title}
                            </div>
                            <div style={{ fontSize: '10.5px', color: '#64748b', marginTop: '1px' }}>
                              {sess.messages.length} {sess.messages.length === 1 ? 'msg' : 'msgs'} • {new Date(sess.updatedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                            </div>
                          </div>

                          <div style={{ display: 'flex', alignItems: 'center', gap: '4px', flexShrink: 0 }}>
                            {isActive && <Check size={14} color="#16a34a" />}
                            {sessions.length > 1 && (
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  handleDeleteSession(sess.id);
                                }}
                                style={{
                                  background: 'transparent',
                                  border: 'none',
                                  color: '#94a3b8',
                                  cursor: 'pointer',
                                  padding: '2px',
                                  display: 'flex',
                                  alignItems: 'center'
                                }}
                                title="Delete session"
                              >
                                <Trash2 size={12} />
                              </button>
                            )}
                          </div>
                        </div>
                      );
                    })}

                    {/* Other Patients' Sessions */}
                    {otherPatientSessions.length > 0 && (
                      <>
                        <div style={{
                          fontSize: '10px',
                          fontWeight: '800',
                          color: '#64748b',
                          padding: '8px 8px 4px',
                          textTransform: 'uppercase',
                          letterSpacing: '0.4px',
                          borderTop: '1px solid #f1f5f9',
                          marginTop: '4px'
                        }}>
                          Other Patients' Sessions
                        </div>
                        {otherPatientSessions.map((sess) => (
                          <div
                            key={sess.id}
                            style={{
                              padding: '8px 10px',
                              borderRadius: '6px',
                              background: '#ffffff',
                              border: '1px solid #f1f5f9',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'space-between',
                              cursor: 'pointer',
                              gap: '8px'
                            }}
                            onClick={() => {
                              // Switch active patient and active session
                              const matchedPt = availablePatients.find(p => p.name === sess.patientName || p.id === sess.patientId);
                              if (matchedPt) {
                                setCurrentPatient(matchedPt);
                                try { localStorage.setItem('active_patient_context', JSON.stringify(matchedPt)); } catch(e){}
                                window.dispatchEvent(new CustomEvent('set-active-patient', { detail: matchedPt }));
                              } else {
                                const ptObj = { name: sess.patientName, id: sess.patientId, badge: sess.patientBadge };
                                setCurrentPatient(ptObj);
                                try { localStorage.setItem('active_patient_context', JSON.stringify(ptObj)); } catch(e){}
                              }
                              setActiveSessionId(sess.id);
                              localStorage.setItem(ACTIVE_SESSION_KEY, sess.id);
                              setShowSessionsDropdown(false);
                            }}
                          >
                            <div style={{ minWidth: 0, flex: 1 }}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                                <span style={{ fontSize: '10px', fontWeight: '800', background: '#e0f2fe', color: '#0369a1', padding: '1px 6px', borderRadius: '4px' }}>
                                  {sess.patientName}
                                </span>
                              </div>
                              <div style={{
                                fontWeight: '600',
                                fontSize: '11.5px',
                                color: '#0f172a',
                                overflow: 'hidden',
                                textOverflow: 'ellipsis',
                                whiteSpace: 'nowrap',
                                marginTop: '2px'
                              }}>
                                {sess.title}
                              </div>
                            </div>
                            <ChevronRight size={12} color="#94a3b8" />
                          </div>
                        ))}
                      </>
                    )}
                  </div>
                </div>
              </>
            )}
          </div>

          {/* Action Buttons Right Side */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexShrink: 0 }}>
            <button
              onClick={handleNewSession}
              style={{
                background: '#ffffff',
                border: '1px solid #cbd5e1',
                borderRadius: '8px',
                color: '#0f172a',
                fontSize: '11px',
                fontWeight: '700',
                padding: '5px 9px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '4px',
                boxShadow: '0 1px 2px rgba(0,0,0,0.03)',
                transition: 'all 0.15s'
              }}
              title="Start a new clean encounter session for this patient"
            >
              <PlusCircle size={12} color="#0f172a" />
              <span>New Session</span>
            </button>

            <button
              onClick={() => setShowHistoryModal(true)}
              style={{
                background: '#ffffff',
                border: '1px solid #cbd5e1',
                borderRadius: '8px',
                color: '#0f172a',
                fontSize: '11px',
                fontWeight: '700',
                padding: '5px 9px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '4px',
                boxShadow: '0 1px 2px rgba(0,0,0,0.03)',
                transition: 'all 0.15s'
              }}
              title="View permanent longitudinal patient history"
            >
              <History size={12} color="#0f172a" />
              <span>History ({archiveCount})</span>
            </button>
          </div>
        </div>

        {/* Longitudinal History Modal Overlay */}
        {showHistoryModal && (
          <div style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(15, 23, 42, 0.65)',
            backdropFilter: 'blur(3px)',
            zIndex: 100010,
            display: 'flex',
            flexDirection: 'column',
            animation: 'fadeIn 0.15s ease-out'
          }}>
            <div style={{
              background: '#ffffff',
              height: '100%',
              display: 'flex',
              flexDirection: 'column',
              boxShadow: '-4px 0 24px rgba(0,0,0,0.15)'
            }}>
              {/* Modal Header */}
              <div style={{
                padding: '16px 20px',
                borderBottom: '1px solid #e2e8f0',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                background: '#ffffff',
                flexShrink: 0
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <div style={{
                    width: '34px',
                    height: '34px',
                    borderRadius: '8px',
                    background: '#0f172a',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: '#ffffff'
                  }}>
                    <History size={18} />
                  </div>
                  <div>
                    <h3 style={{ margin: 0, fontSize: '15px', fontWeight: '800', color: '#0f172a' }}>
                      Longitudinal Clinical History
                    </h3>
                    <div style={{ fontSize: '12px', color: '#64748b', marginTop: '2px', fontWeight: '600' }}>
                      {currentPatient ? currentPatient.name : 'General Clinic Record'} • {loadArchive(currentPatient).length} logged entries
                    </div>
                  </div>
                </div>

                <button
                  onClick={() => setShowHistoryModal(false)}
                  style={{
                    background: '#f1f5f9',
                    border: 'none',
                    color: '#64748b',
                    width: '32px',
                    height: '32px',
                    borderRadius: '8px',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center'
                  }}
                  title="Close History View"
                >
                  <X size={18} />
                </button>
              </div>

              {/* Notice Banner */}
              <div style={{
                padding: '10px 18px',
                background: '#f8fafc',
                borderBottom: '1px solid #e2e8f0',
                fontSize: '11.5px',
                color: '#334155',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                flexShrink: 0
              }}>
                <Archive size={14} color="#0f172a" style={{ flexShrink: 0 }} />
                <span>
                  All past dialogues and clinical notes are permanently preserved locally and continuously fed to the AI reasoning engine for medication continuity and future predictions.
                </span>
              </div>

              {/* Search filter */}
              <div style={{
                padding: '10px 18px',
                borderBottom: '1px solid #e2e8f0',
                background: '#ffffff',
                flexShrink: 0
              }}>
                <input
                  type="text"
                  placeholder="Search past notes, medications, or dialogue..."
                  value={historySearch}
                  onChange={(e) => setHistorySearch(e.target.value)}
                  style={{
                    width: '100%',
                    boxSizing: 'border-box',
                    padding: '8px 12px',
                    borderRadius: '8px',
                    border: '1px solid #cbd5e1',
                    fontSize: '12.5px',
                    outline: 'none',
                    color: '#0f172a',
                    background: '#f8fafc'
                  }}
                />
              </div>

              {/* Archived entries feed */}
              <div style={{
                flex: 1,
                overflowY: 'auto',
                padding: '16px 18px',
                background: '#f8fafc',
                display: 'flex',
                flexDirection: 'column',
                gap: '12px'
              }}>
                {(() => {
                  const rawList = loadArchive(currentPatient);
                  const list = historySearch.trim()
                    ? rawList.filter(item => (item.text || '').toLowerCase().includes(historySearch.toLowerCase()))
                    : rawList;

                  if (list.length === 0) {
                    return (
                      <div style={{
                        textAlign: 'center',
                        padding: '40px 20px',
                        color: '#64748b',
                        fontSize: '13px'
                      }}>
                        <FileClock size={36} color="#94a3b8" style={{ margin: '0 auto 10px', display: 'block' }} />
                        <strong>No archived entries found</strong>
                        <p style={{ margin: '4px 0 0', fontSize: '12px' }}>
                          Conversations and notes for this patient will be preserved here across encounters.
                        </p>
                      </div>
                    );
                  }

                  return list.map((entry, idx) => {
                    const isDoc = entry.role === 'doctor' || entry.role === 'user';
                    return (
                      <div
                        key={entry.id || idx}
                        style={{
                          background: '#ffffff',
                          borderRadius: '10px',
                          border: '1px solid #e2e8f0',
                          padding: '12px 14px',
                          boxShadow: '0 1px 3px rgba(0,0,0,0.03)'
                        }}
                      >
                        <div style={{
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'space-between',
                          marginBottom: '6px',
                          fontSize: '11px',
                          color: '#64748b'
                        }}>
                          <span style={{
                            fontWeight: '800',
                            color: isDoc ? '#0f172a' : '#1e40af',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '5px'
                          }}>
                            {isDoc ? 'Physician Query' : 'Clinical AI Reasoning'}
                          </span>
                          <span>{entry.timestamp || 'Logged'}</span>
                        </div>
                        <div style={{
                          fontSize: '13px',
                          color: '#0f172a',
                          lineHeight: '1.5',
                          whiteSpace: 'pre-wrap'
                        }}>
                          {renderFormattedContent(entry.text)}
                        </div>
                      </div>
                    );
                  });
                })()}
              </div>

              {/* Modal Footer */}
              <div style={{
                padding: '12px 18px',
                borderTop: '1px solid #e2e8f0',
                background: '#ffffff',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                flexShrink: 0
              }}>
                <button
                  onClick={handleClearArchive}
                  style={{
                    background: 'transparent',
                    border: 'none',
                    color: '#ef4444',
                    cursor: 'pointer',
                    fontSize: '11.5px',
                    fontWeight: '700',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                    padding: '4px'
                  }}
                  title="Clear stored testing history for this patient"
                >
                  <Trash2 size={13} />
                  <span>Clear Archive</span>
                </button>

                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <button
                    onClick={() => {
                      setShowHistoryModal(false);
                      handleNewSession();
                    }}
                    style={{
                      background: '#ffffff',
                      border: '1px solid #cbd5e1',
                      color: '#0f172a',
                      borderRadius: '8px',
                      padding: '6px 12px',
                      fontSize: '12px',
                      fontWeight: '700',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px'
                    }}
                  >
                    <PlusCircle size={13} />
                    <span>New Session</span>
                  </button>

                  <button
                    onClick={() => setShowHistoryModal(false)}
                    style={{
                      background: '#0f172a',
                      border: 'none',
                      color: '#ffffff',
                      borderRadius: '8px',
                      padding: '6px 14px',
                      fontSize: '12px',
                      fontWeight: '700',
                      cursor: 'pointer'
                    }}
                  >
                    Close
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Chat Feed */}
        <div style={{
          flex: 1,
          overflowY: 'auto',
          background: '#f8fafc',
          display: 'flex',
          flexDirection: 'column',
          position: 'relative'
        }}>
          {/* Sticky Header with Last Doctor Inquiry (Antigravity Workflow) */}
          <div style={{
            position: 'sticky',
            top: 0,
            zIndex: 15,
            background: 'rgba(255, 255, 255, 0.96)',
            backdropFilter: 'blur(8px)',
            borderBottom: '1px solid #e2e8f0',
            padding: '8px 18px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '10px',
            fontSize: '12px',
            boxShadow: '0 1px 3px rgba(0, 0, 0, 0.04)'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', minWidth: 0, flex: 1 }}>
              <Pin size={12} color={activeSession?.lastDoctorQuery ? '#0f172a' : '#94a3b8'} style={{ flexShrink: 0, transform: 'rotate(45deg)' }} />
              <span style={{
                color: '#64748b',
                fontWeight: '700',
                fontSize: '10.5px',
                textTransform: 'uppercase',
                letterSpacing: '0.4px',
                flexShrink: 0
              }}>
                {activeSession?.lastDoctorQuery ? 'Active Inquiry:' : 'Session Focus:'}
              </span>
              <span style={{
                color: '#0f172a',
                fontWeight: '700',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap'
              }}>
                {activeSession?.lastDoctorQuery || (currentPatient ? `Encounter started for ${currentPatient.name}` : 'General Clinic Copilot')}
              </span>
            </div>
            {activeSession?.lastDoctorQuery && (
              <button
                onClick={() => handleCopyText(activeSession.lastDoctorQuery, 'sticky_query')}
                style={{
                  background: '#f8fafc',
                  border: '1px solid #cbd5e1',
                  borderRadius: '6px',
                  color: '#475569',
                  fontSize: '10.5px',
                  fontWeight: '600',
                  padding: '2px 8px',
                  cursor: 'pointer',
                  flexShrink: 0,
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px'
                }}
                title="Copy active inquiry"
              >
                <Copy size={11} />
                <span>{copiedId === 'sticky_query' ? 'Copied' : 'Copy'}</span>
              </button>
            )}
          </div>

          <div style={{
            padding: '16px 18px',
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
        </div>

        {/* Dynamic Suggested Inquiries Dock — Context-aware & Non-repeating */}
        {(() => {
          const currentPrompts = getPromptsForPatient(currentPatient, askedQueries, promptOffset);
          if (!currentPrompts || currentPrompts.length === 0) return null;
          return (
            <div style={{
              padding: '10px 18px',
              background: '#f8fafc',
              borderTop: '1px solid #e2e8f0',
              display: 'flex',
              flexDirection: 'column',
              gap: '6px',
              flexShrink: 0
            }}>
              <div style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                fontSize: '11px',
                color: '#64748b',
                fontWeight: '600'
              }}>
                <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <span>Suggested Inquiries</span>
                  <span style={{ fontWeight: '700', color: '#0f172a' }}>
                    ({currentPatient ? currentPatient.name : 'Clinic'}):
                  </span>
                </span>
                <button
                  onClick={handleShufflePrompts}
                  style={{
                    background: 'transparent',
                    border: 'none',
                    color: '#2563eb',
                    fontSize: '11px',
                    fontWeight: '700',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                    padding: '2px 4px'
                  }}
                  title="Shuffle to see more questions"
                >
                  <RefreshCw size={11} /> More suggestions ↻
                </button>
              </div>

              <div style={{
                display: 'flex',
                flexWrap: 'wrap',
                gap: '6px'
              }}>
                {currentPrompts.map((p, idx) => (
                  <button
                    key={idx}
                    onClick={() => handleSendQuery(p)}
                    style={{
                      padding: '6px 12px',
                      borderRadius: '16px',
                      background: '#ffffff',
                      border: '1px solid #cbd5e1',
                      color: '#0f172a',
                      fontSize: '11.5px',
                      fontWeight: '600',
                      cursor: 'pointer',
                      boxShadow: '0 1px 2px rgba(0,0,0,0.02)',
                      textAlign: 'left',
                      transition: 'all 0.15s',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '6px'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = '#eff6ff';
                      e.currentTarget.style.color = '#1d4ed8';
                      e.currentTarget.style.borderColor = '#93c5fd';
                      e.currentTarget.style.boxShadow = '0 2px 6px rgba(37,99,235,0.12)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = '#ffffff';
                      e.currentTarget.style.color = '#0f172a';
                      e.currentTarget.style.borderColor = '#cbd5e1';
                      e.currentTarget.style.boxShadow = '0 1px 2px rgba(0,0,0,0.02)';
                    }}
                  >
                    <span>{p}</span>
                    <span style={{ color: '#2563eb', fontWeight: '700' }}>→</span>
                  </button>
                ))}
              </div>
            </div>
          );
        })()}

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

            {/* Send Button — Standard Professional Medical Blue */}
            <button
              onClick={() => handleSendQuery()}
              disabled={!inputQuery.trim() || isProcessing}
              style={{
                width: '38px',
                height: '38px',
                borderRadius: '10px',
                background: inputQuery.trim() && !isProcessing
                  ? '#2563eb'
                  : '#f1f5f9',
                border: inputQuery.trim() && !isProcessing
                  ? '1px solid #1d4ed8'
                  : '1px solid #e2e8f0',
                color: inputQuery.trim() && !isProcessing ? '#ffffff' : '#94a3b8',
                cursor: inputQuery.trim() && !isProcessing ? 'pointer' : 'default',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexShrink: 0,
                boxShadow: inputQuery.trim() && !isProcessing ? '0 2px 6px rgba(37,99,235,0.25)' : 'none',
                transition: 'all 0.15s'
              }}
              onMouseEnter={(e) => {
                if (inputQuery.trim() && !isProcessing) {
                  e.currentTarget.style.background = '#1d4ed8';
                }
              }}
              onMouseLeave={(e) => {
                if (inputQuery.trim() && !isProcessing) {
                  e.currentTarget.style.background = '#2563eb';
                }
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
