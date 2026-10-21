import { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import { LayoutDashboard, FileText, Send, MessageSquare, LogOut, Inbox, Sun, Moon, Settings, ChevronDown, Shield, User, Users, Plus, Bell, X, Activity, Mic, Search, Calendar, DollarSign, Scan, ScanFace, MessageCircle, ExternalLink, Phone, Sparkles } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import './index.css';

// We will create these components next
import Dashboard from './components/Dashboard';
import PatientDirectory from './components/PatientDirectory';
import FormFiller from './components/FormFiller';
import ReferralChecker from './components/ReferralChecker';
import InboundSummary from './components/InboundSummary';
import SecureInbox from './components/SecureInbox';
import Login from './components/Login';
import Scribe from './components/Scribe';
import SettingsModal from './components/SettingsModal';
import SmartCalendar from './components/SmartCalendar';
import BillingDashboard from './components/BillingDashboard';
import UniversalScanner from './components/UniversalScanner';
import KioskMode from './components/KioskMode';
import DigitalTwin from './components/DigitalTwin';
import WhatsAppModal from './components/WhatsAppModal';
window.utterances = [];
window.isSpeaking = false;
const speakAction = (text) => {
  if (localStorage.getItem('medoffice_voice_feedback') === 'false') return;
  if ('speechSynthesis' in window) {
    console.log("TTS Triggered:", text);
    // Remove aggressive cancel as it can cause Chrome to drop the next speak() call instantly
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

      msg.onerror = (e) => { 
        console.error("TTS Error:", e);
        window.isSpeaking = false; 
      };

      window.utterances.push(msg);
      window.speechSynthesis.speak(msg);
    }, 50);
  }
};

function App() {
  const [token, setToken] = useState(localStorage.getItem('medoffice_token'));
  const [user, setUser] = useState(JSON.parse(localStorage.getItem('medoffice_user')));
  const [activeTab, setActiveTab] = useState('dashboard');
  const [badges, setBadges] = useState({ dashboard: 0, inbox: 0 });
  const [theme, setTheme] = useState(localStorage.getItem('medoffice_theme') || 'light');
  
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isMoreToolsOpen, setIsMoreToolsOpen] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isVoiceNavActive, setIsVoiceNavActive] = useState(false);
  const [voiceNavStatus, setVoiceNavStatus] = useState('');
  const [isKioskMode, setIsKioskMode] = useState(false);
  
  const [searchQuery, setSearchQuery] = useState('');
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [isScannerOpen, setIsScannerOpen] = useState(false);
  const [isWhatsAppOpen, setIsWhatsAppOpen] = useState(false);
  const [searchSelectedIndex, setSearchSelectedIndex] = useState(0);
  const [activePatient, setActivePatient] = useState(null);
  const searchInputRef = useRef(null);


  const mockSearchResults = [
    { id: 'p1', type: 'Patient', title: 'John Doe', desc: 'DOB: 04/12/1985 • Hypertension', action: 'dashboard', icon: <User size={14} color="#3b82f6" /> },
    { id: 'p2', type: 'Patient', title: 'Sarah Jenkins', desc: 'DOB: 11/23/1992 • MRI Referral', action: 'dashboard', icon: <User size={14} color="#3b82f6" /> },
    { id: 'p3', type: 'Directory', title: 'Central Cloud Patient Directory', desc: '60 Unified Patients (50 Cloud + 10 Clinic)', action: 'patients', icon: <Users size={14} color="#3b82f6" /> },
    { id: 's1', type: 'Setting', title: 'Voice Profile', desc: 'Change AI Assistant Voice', action: 'settings', icon: <Mic size={14} color="#10b981" /> },
    { id: 'i1', type: 'Message', title: 'Cardiology Dept', desc: 'STAT ECG Review needed', action: 'inbox', icon: <Inbox size={14} color="#a855f7" /> }
  ];

  const filteredSearch = searchQuery.length > 0 ? mockSearchResults.filter(r => r.title.toLowerCase().includes(searchQuery.toLowerCase()) || r.type.toLowerCase().includes(searchQuery.toLowerCase()) || r.desc.toLowerCase().includes(searchQuery.toLowerCase())) : [];
  
  const [isNotificationsOpen, setIsNotificationsOpen] = useState(false);
  const [globalNotifications, setGlobalNotifications] = useState([
    { id: 1, title: 'AI OCR Engine', message: 'Extracted 12 data points from New Patient Intake Form', time: '10 mins ago', color: '#10b981' },
    { id: 2, title: 'AI Chart Review', message: 'Flagged High Tropnin levels in John Doe discharge summary', time: '1 hour ago', color: '#ef4444' },
    { id: 3, title: 'Prior Auth Triage', message: 'Automatically approved MRI referral for Sarah Jenkins', time: '3 hours ago', color: '#8b5cf6' }
  ]);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('medoffice_theme', theme);
  }, [theme]);

  // Global Keyboard Shortcuts (Cmd+K)
  useEffect(() => {
    const handleKeyDown = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        setIsSearchOpen(true);
      }
      if (e.key === 'Escape') {
        setIsSearchOpen(false);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const [isEditingPatientPhone, setIsEditingPatientPhone] = useState(false);
  const [tempPhone, setTempPhone] = useState('');
  const [allPatients, setAllPatients] = useState([]);

  // Initial patient loader so activePatient has real connected data
  useEffect(() => {
    axios.get('/api/patients').then(res => {
      if (res.data?.patients && res.data.patients.length > 0) {
        setAllPatients(res.data.patients);
        let stored = null;
        try {
          stored = JSON.parse(localStorage.getItem('active_patient_context') || 'null');
        } catch (e) {}

        if (!activePatient) {
          const matched = stored?.name 
            ? (res.data.patients.find(p => p.name === stored.name || p.id === stored.id) || stored)
            : res.data.patients[0];
          
          const pObj = {
            id: matched.id,
            name: matched.name,
            initials: (matched.name || 'PT').split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase(),
            dob: matched.birthDate || matched.dob || '1981-04-14',
            phone: matched.phone || '613-555-0192',
            mrn: matched.mrn || `MRN-${matched.id}`,
            allergies: matched.allergies || 'NKDA',
            codeStatus: 'Full Code',
            conditions: matched.conditions || [],
            badge: matched.badge || (matched.conditions && matched.conditions[0]?.display) || ''
          };
          setActivePatient(pObj);
          try {
            localStorage.setItem('active_patient_context', JSON.stringify(pObj));
          } catch (e) {}
        }
      }
    }).catch(err => console.log("Initial patient load note:", err));
  }, []);

  const handleSelectPatientById = (patientId) => {
    const target = allPatients.find(p => p.id === patientId);
    if (target) {
      const pObj = {
        id: target.id,
        name: target.name,
        initials: (target.name || 'PT').split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase(),
        dob: target.birthDate,
        phone: target.phone || '613-555-0192',
        mrn: target.mrn || `MRN-${target.id}`,
        allergies: target.allergies || 'NKDA',
        codeStatus: 'Full Code',
        conditions: target.conditions || [],
        badge: target.badge || (target.conditions && target.conditions[0]?.display) || ''
      };
      setActivePatient(pObj);
      setIsEditingPatientPhone(false);
      try {
        localStorage.setItem('active_patient_context', JSON.stringify(pObj));
      } catch (e) {}
      window.dispatchEvent(new CustomEvent('set-active-patient', { detail: pObj }));
    }
  };

  const handleSelectPatientFromDirectory = (p) => {
    const pObj = {
      id: p.id,
      name: p.name,
      initials: p.initials || (p.name || 'PT').split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase(),
      dob: p.birthDate || p.dob || '1985-05-12',
      phone: p.phone || p.contact || '613-555-0192',
      mrn: p.mrn || `MRN-${p.id}`,
      allergies: p.allergies || 'NKDA',
      codeStatus: 'Full Code',
      source: p.source || 'central_cloud',
      conditions: p.conditions || [p.badge || ''],
      badge: p.badge || ''
    };
    setActivePatient(pObj);
    setIsEditingPatientPhone(false);
    try {
      localStorage.setItem('active_patient_context', JSON.stringify(pObj));
    } catch (e) {}
    window.dispatchEvent(new CustomEvent('set-active-patient', { detail: pObj }));
  };

  // Save patient phone change (connect personal test phone directly to chart)
  const handleSavePatientPhone = async () => {
    if (!activePatient || !tempPhone.trim()) return;
    const clean = tempPhone.trim();
    const updated = { ...activePatient, phone: clean };
    setActivePatient(updated);
    setAllPatients(prev => prev.map(p => p.id === activePatient.id ? { ...p, phone: clean } : p));
    setIsEditingPatientPhone(false);
    localStorage.setItem('test_whatsapp_phone', clean);

    try {
      if (activePatient.id) {
        await axios.put(`/api/patient/${activePatient.id}/phone`, { phone: clean });
      }
    } catch (e) {
      console.log("Phone save note:", e);
    }
  };

  // Direct Automatic 1-Tap WhatsApp Launcher (Zero Popups)
  const launchDirectWhatsApp = (patient = null, customMessage = null) => {
    const target = patient || activePatient;
    const pName = target?.name?.text || target?.name || (target ? 'Patient' : 'Patient');
    const rawPhone = target?.phone || localStorage.getItem('test_whatsapp_phone') || '613-555-0192';
    const digits = rawPhone.replace(/\D/g, '') || '16135550192';
    const cleanNumber = digits.length === 10 ? `1${digits}` : digits;

    let text = customMessage;
    if (!text) {
      const docName = user?.name || 'your attending physician';
      text = target 
        ? `Hello ${pName}, this is ${docName} following up on your medical chart from Prime Care Medical Clinic.`
        : `Hello, this is ${docName} following up on patient clinical care with Prime Care Clinic.`;
    }

    const waUrl = `https://wa.me/${cleanNumber}?text=${encodeURIComponent(text)}`;
    window.open(waUrl, '_blank');
  };

  // Handle global events from other components
  useEffect(() => {
    const handleSetActivePatient = (e) => {
      setActivePatient(e.detail);
    };
    const handleSwitchTab = (e) => {
      if (e.detail) handleTabClick(e.detail);
    };
    const handleOpenScanner = () => {
      setIsScannerOpen(true);
    };
    const handleOpenWhatsApp = (e) => {
      const patient = e?.detail?.patient || activePatient;
      const customMsg = e?.detail?.message || null;
      launchDirectWhatsApp(patient, customMsg);
    };
    window.addEventListener('set-active-patient', handleSetActivePatient);
    window.addEventListener('switch-tab', handleSwitchTab);
    window.addEventListener('open-scanner', handleOpenScanner);
    window.addEventListener('open-whatsapp', handleOpenWhatsApp);
    return () => {
      window.removeEventListener('set-active-patient', handleSetActivePatient);
      window.removeEventListener('switch-tab', handleSwitchTab);
      window.removeEventListener('open-scanner', handleOpenScanner);
      window.removeEventListener('open-whatsapp', handleOpenWhatsApp);
    };
  }, [activePatient]);

  const toggleTheme = () => {
    setTheme(prev => prev === 'dark' ? 'light' : 'dark');
  };

  const handleTabClick = (tab) => {
    setActiveTab(tab);
    if (badges[tab]) {
      setBadges(prev => {
        const next = { ...prev, [tab]: 0 };
        const total = Object.values(next).reduce((a, b) => a + b, 0);
        document.title = total > 0 ? `(${total}) Prime Care AI` : 'Prime Care AI';
        return next;
      });
    }
  };

  const wasGlobalNavActiveRef = useRef(false);

  useEffect(() => {
    const handlePause = () => {
      setIsVoiceNavActive(prev => {
        if (prev) wasGlobalNavActiveRef.current = true;
        return false;
      });
    };
    const handleResume = () => {
      if (wasGlobalNavActiveRef.current) {
        setIsVoiceNavActive(true);
      }
    };
    window.addEventListener('pause-voice-nav', handlePause);
    window.addEventListener('resume-voice-nav', handleResume);
    return () => {
      window.removeEventListener('pause-voice-nav', handlePause);
      window.removeEventListener('resume-voice-nav', handleResume);
    };
  }, []);

  useEffect(() => {
    let recognition = null;
    let isActive = isVoiceNavActive;
    
    if (isVoiceNavActive) {
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      if (SpeechRecognition) {
        recognition = new SpeechRecognition();
        recognition.continuous = true;
        recognition.interimResults = false;
        recognition.lang = 'en-US';

        recognition.onresult = (event) => {
          if (window.isSpeaking) {
             console.log("Muting microphone: AI is currently speaking.");
             return; 
          }
          const last = event.results.length - 1;
          const transcript = event.results[last][0].transcript.toLowerCase();
          
          let navAction = null;
          let otherActions = [];

          if (transcript.includes('dashboard')) navAction = 'dashboard';
          if (transcript.includes('inbox') || transcript.includes('message')) navAction = 'inbox';
          if (transcript.includes('referral') || transcript.includes('triage')) navAction = 'referral';
          if (transcript.includes('intake') || transcript.includes('form') || transcript.includes('ocr')) navAction = 'formFiller';
          if (transcript.includes('summary') || transcript.includes('chat')) navAction = 'inbound';
          if (transcript.includes('billing') || transcript.includes('revenue')) navAction = 'billing';

          let spokenFeedback = "";

          if (transcript.includes('scroll down')) { otherActions.push({ action: 'scroll', target: 'down' }); spokenFeedback = "Scrolling down"; }
          if (transcript.includes('scroll up')) { otherActions.push({ action: 'scroll', target: 'up' }); spokenFeedback = "Scrolling up"; }
          
          if (transcript.includes('oncology')) { otherActions.push({ action: 'click_case', target: 'oncology' }); spokenFeedback = "Opening Oncology case"; }
          if (transcript.includes('cardiology')) { otherActions.push({ action: 'click_case', target: 'cardiology' }); spokenFeedback = "Opening Cardiology case"; }
          if (transcript.includes('orthopaedics')) { otherActions.push({ action: 'click_case', target: 'orthopaedics' }); spokenFeedback = "Opening Orthopaedics case"; }

          // Global App Controls
          if (transcript.includes('settings') || transcript.includes('console')) { otherActions.push({ action: 'open_settings' }); spokenFeedback = "Opening settings console"; }
          if (transcript.includes('notification') || transcript.includes('activity')) { otherActions.push({ action: 'open_notifications' }); spokenFeedback = "Opening notifications"; }
          if (transcript.includes('theme') || transcript.includes('night mode') || transcript.includes('day mode') || transcript.includes('dark mode')) { otherActions.push({ action: 'toggle_theme' }); spokenFeedback = "Toggling appearance mode"; }
          if (transcript.includes('sign out') || transcript.includes('log out')) { otherActions.push({ action: 'logout' }); spokenFeedback = "Signing out"; }

          // Scribe commands that can be issued globally when scribe is open but not recording
          if (transcript.includes('synthesize note') || transcript.includes('create note') || transcript.includes('finish note')) {
             otherActions.push({ action: 'scribe_cmd', target: 'synthesize' }); spokenFeedback = "Synthesizing clinical note";
          }
          if (transcript.includes('translate for patient') || transcript.includes('translate')) {
             otherActions.push({ action: 'scribe_cmd', target: 'translate' }); spokenFeedback = "Translating note for patient";
          }
          if (transcript.includes('export to fhir') || transcript.includes('export fhir')) {
             otherActions.push({ action: 'scribe_cmd', target: 'export' }); spokenFeedback = "Exporting to fire";
          }
          if (transcript.includes('sign chart') || transcript.includes('sign note')) {
             otherActions.push({ action: 'scribe_cmd', target: 'sign' }); spokenFeedback = "Signing chart electronically";
          }
          if (transcript.includes('stop listening') || transcript.includes('stop microphone') || transcript.includes('stop recording')) {
             otherActions.push({ action: 'scribe_cmd', target: 'stop' }); spokenFeedback = "Stopping microphone";
          }
          
          // Secure Inbox Tabs
          if (transcript.includes('unread messages') || transcript.includes('unread emails') || transcript.includes('show unread')) { 
             navAction = 'inbox'; 
             otherActions.push({ action: 'inbox_folder', target: 'unread' }); 
             spokenFeedback = "Opening unread messages"; 
          }
          if (transcript.includes('starred') || transcript.includes('important messages')) { 
             navAction = 'inbox'; 
             otherActions.push({ action: 'inbox_folder', target: 'starred' }); 
             spokenFeedback = "Opening starred messages"; 
          }
          if (transcript.includes('resolved messages') || transcript.includes('archive')) { 
             navAction = 'inbox'; 
             otherActions.push({ action: 'inbox_folder', target: 'resolved' }); 
             spokenFeedback = "Opening resolved messages"; 
          }

          const wantsToTakeNote = transcript.includes('take a note') || transcript.includes('open scribe');
          const wantsToStartMic = transcript.includes('start') && (transcript.includes('listen') || transcript.includes('mic') || transcript.includes('record'));
          
          if (wantsToTakeNote && !wantsToStartMic) spokenFeedback = "Opening AI Scribe";
          if (wantsToStartMic) spokenFeedback = "Starting AI Scribe dictation";

          if (navAction) {
            spokenFeedback = `Navigating to ${navAction.replace(/([A-Z])/g, ' $1').toLowerCase()}`;
            setVoiceNavStatus(`Navigating...`);
            handleTabClick(navAction);
          }

          if (spokenFeedback) {
             speakAction(spokenFeedback);
          }

          if (otherActions.length > 0 || wantsToTakeNote || wantsToStartMic) {
             setVoiceNavStatus('Executing command...');
             setTimeout(() => {
                otherActions.forEach(act => {
                   if (act.action === 'scroll') {
                     const mainScroll = document.getElementById('main-scroll-area');
                     if (mainScroll) {
                       if (act.target === 'down') mainScroll.scrollBy({ top: 600, behavior: 'smooth' });
                       if (act.target === 'up') mainScroll.scrollBy({ top: -600, behavior: 'smooth' });
                     }
                   } else if (act.action === 'open_settings') {
                     setIsSettingsOpen(true);
                   } else if (act.action === 'open_notifications') {
                     setIsNotificationsOpen(true);
                   } else if (act.action === 'toggle_theme') {
                     toggleTheme();
                   } else if (act.action === 'logout') {
                     handleLogout();
                   } else {
                     window.dispatchEvent(new CustomEvent('voice-command', { detail: act }));
                   }
                });

                if (wantsToStartMic) {
                   // MIC HANDOFF PROTOCOL
                   setIsVoiceNavActive(prev => {
                     if (prev) wasGlobalNavActiveRef.current = true;
                     return false;
                   });
                   window.dispatchEvent(new CustomEvent('open-scribe'));
                   setTimeout(() => {
                       window.dispatchEvent(new CustomEvent('start-scribe'));
                   }, 300); // Give Scribe time to mount
                } else if (wantsToTakeNote) {
                   window.dispatchEvent(new CustomEvent('open-scribe'));
                }
             }, navAction ? 400 : 0);
          }

          if (!navAction && otherActions.length === 0 && !wantsToTakeNote && !wantsToStartMic) {
             // Just listening, no action found
          } else {
             setTimeout(() => setVoiceNavStatus(''), 3000);
          }
        };

        recognition.onerror = (e) => {
          console.error("Voice Nav Error:", e);
          if (e.error === 'not-allowed') {
            setIsVoiceNavActive(false);
            isActive = false;
          }
        };

        recognition.onend = () => {
          if (isActive) {
            try { recognition.start(); } catch(e) {}
          }
        };

        try { recognition.start(); } catch(e) {}
      }
    }
    return () => {
      isActive = false;
      if (recognition) {
        try { recognition.stop(); } catch(e) {}
      }
    };
  }, [isVoiceNavActive]);

  const triggerNotification = (tab) => {
    setBadges(prev => {
      const next = { ...prev, [tab]: (prev[tab] || 0) + 1 };
      const total = Object.values(next).reduce((a, b) => a + b, 0);
      document.title = total > 0 ? `(${total}) Prime Care AI` : 'Prime Care AI';
      return next;
    });
  };

  const handleLogin = (data) => {
    setToken(data.token);
    setUser(data.user);
    localStorage.setItem('medoffice_token', data.token);
    localStorage.setItem('medoffice_user', JSON.stringify(data.user));
    setActiveTab('dashboard');
  };

  const handleLogout = () => {
    setIsMenuOpen(false);
    setToken(null);
    setUser(null);
    localStorage.removeItem('medoffice_token');
    localStorage.removeItem('medoffice_user');
  };

  if (!token) {
    return <Login onLogin={handleLogin} />;
  }

  if (isKioskMode) {
    return <KioskMode onExit={() => setIsKioskMode(false)} />;
  }

  return (
    <div className="app-shell" style={{ display: 'flex', flexDirection: 'column', height: '100vh', position: 'relative', background: 'var(--bg-primary)' }}>
      <header style={{ display: 'flex', justifyContent: 'space-between', padding: '12px 20px', margin: '12px 16px', background: '#ffffff', border: '1px solid #e2e8f0', borderRadius: '14px', alignItems: 'center', position: 'relative', zIndex: 100, boxShadow: '0 1px 3px rgba(15, 23, 42, 0.04)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', minWidth: 0 }}>
          {user?.picture ? (
            <img src={user.picture} alt={user?.name || 'User'} style={{ width: '38px', height: '38px', borderRadius: '50%', border: '1px solid var(--border)', flexShrink: 0 }} />
          ) : (
            <div style={{ width: '38px', height: '38px', borderRadius: '8px', background: '#2563eb', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '700', fontSize: '15px', color: 'white', flexShrink: 0 }}>
              {user?.initials || 'MD'}
            </div>
          )}
          <div style={{ minWidth: 0 }}>
            {/* Desktop header text */}
            <div className="desktop-only">
              <h2 style={{ margin: 0, fontSize: '16px', fontWeight: '700', color: '#0f172a', display: 'flex', alignItems: 'center' }}>
                Prime Care App 
                <span style={{ fontSize: '10px', background: '#eff6ff', color: '#2563eb', padding: '2px 8px', borderRadius: '4px', marginLeft: '8px', border: '1px solid #bfdbfe', fontWeight: '700' }}>
                  CLINICAL EHR
                </span>
              </h2>
              <p style={{ margin: '2px 0 0 0', fontSize: '12px', color: '#64748b', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <span>{user?.clinic || 'Prime Care Medical Group'} · </span>
                <strong style={{ color: '#0f172a', fontWeight: '600' }}>{user?.name}</strong>
                {user?.email && ` (${user.email})`}
                <button
                  type="button"
                  onClick={handleLogout}
                  style={{
                    background: '#fef2f2',
                    border: '1px solid #fecaca',
                    color: '#dc2626',
                    borderRadius: '6px',
                    padding: '2px 8px',
                    fontSize: '11px',
                    fontWeight: '700',
                    cursor: 'pointer',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '4px',
                    marginLeft: '6px'
                  }}
                  title="Sign out to switch doctor accounts or create a new profile"
                >
                  <LogOut size={11} /> Switch Doctor
                </button>
              </p>
            </div>

            {/* Mobile header text - consolidated doctor info & duty status */}
            <div className="mobile-only" style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', minWidth: 0 }}>
                <strong style={{ fontSize: '14px', fontWeight: '700', color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: '125px' }}>
                  {user?.name || 'Attending Physician'}
                </strong>
                <button
                  type="button"
                  onClick={handleLogout}
                  style={{
                    background: 'rgba(239, 68, 68, 0.12)',
                    border: '1px solid rgba(239, 68, 68, 0.3)',
                    color: '#ef4444',
                    borderRadius: '5px',
                    padding: '1px 6px',
                    fontSize: '10px',
                    fontWeight: '700',
                    cursor: 'pointer',
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '3px',
                    flexShrink: 0
                  }}
                  title="Switch doctor account"
                >
                  <LogOut size={10} /> Switch
                </button>
              </div>
              <p style={{ margin: '1px 0 0 0', fontSize: '10px', color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: '5px' }}>
                <span style={{ color: '#16a34a', fontWeight: '600', display: 'inline-flex', alignItems: 'center', gap: '3px' }}>
                  <span style={{ width: '5px', height: '5px', borderRadius: '50%', background: '#16a34a', display: 'inline-block' }} /> Live
                </span>
                <span>·</span>
                <span>{new Date().toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' })}</span>
              </p>
            </div>
          </div>
        </div>

        {/* Header Right Actions */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', position: 'relative', flexShrink: 0 }}>
          
          {/* Spotlight Search Trigger (Desktop) */}
          <button 
            className="desktop-only"
            onClick={() => setIsSearchOpen(true)}
            style={{ 
              background: 'var(--bg-secondary)', 
              border: '1px solid var(--border)', 
              borderRadius: '6px', 
              padding: '6px 12px', 
              display: 'flex', 
              alignItems: 'center', 
              gap: '8px',
              color: 'var(--text-secondary)', 
              cursor: 'pointer',
              boxShadow: '0 1px 2px rgba(0,0,0,0.04)'
            }}
          >
            <Search size={16} />
            <span style={{ fontSize: '13px', marginRight: '32px' }}>Search e-Hospital...</span>
            <div style={{ display: 'flex', alignItems: 'center', gap: '2px', background: 'var(--bg-tertiary)', padding: '2px 4px', borderRadius: '4px', fontSize: '10px', fontWeight: '500', color: 'var(--text-secondary)' }}>
              <span>⌘</span><span>K</span>
            </div>
          </button>

          {/* Search Icon Trigger (Mobile Only) */}
          <button
            className="mobile-only"
            onClick={() => setIsSearchOpen(true)}
            style={{
              background: 'var(--bg-secondary)',
              border: '1px solid var(--border)',
              borderRadius: '6px', width: '32px', height: '32px',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: 'var(--text-secondary)', cursor: 'pointer', flexShrink: 0
            }}
          >
            <Search size={16} />
          </button>

          {/* Hands-Free Navigation Toggle (Desktop Only) */}
          <button 
            className="desktop-only"
            onClick={() => setIsVoiceNavActive(!isVoiceNavActive)}
            style={{ 
              background: isVoiceNavActive ? 'rgba(35, 134, 54, 0.1)' : 'var(--bg-secondary)', 
              border: isVoiceNavActive ? '1px solid var(--accent)' : '1px solid var(--border)', 
              borderRadius: '6px', padding: '6px 12px', display: 'flex', alignItems: 'center', gap: '8px',
              color: isVoiceNavActive ? 'var(--accent)' : 'var(--text-secondary)', cursor: 'pointer',
              fontWeight: '500', fontSize: '13px',
              boxShadow: '0 1px 2px rgba(0,0,0,0.04)'
            }}
          >
            <Mic size={16} />
            {isVoiceNavActive ? 'Listening...' : 'Hands-Free Nav'}
          </button>

          <button 
            onClick={() => setIsNotificationsOpen(!isNotificationsOpen)}
            style={{ 
              background: 'var(--bg-secondary)', border: '1px solid var(--border)', 
              borderRadius: '6px', width: '32px', height: '32px', display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: 'var(--text-secondary)', cursor: 'pointer', position: 'relative', flexShrink: 0,
              boxShadow: '0 1px 2px rgba(0,0,0,0.04)'
            }}
          >
            <Bell size={16} />
            <div style={{ position: 'absolute', top: '-3px', right: '-3px', background: 'var(--error)', width: '8px', height: '8px', borderRadius: '50%', border: '2px solid var(--bg-primary)' }} />
          </button>

          <button 
            className="desktop-only"
            onClick={() => setIsScannerOpen(true)}
            style={{ 
              background: 'var(--bg-secondary)', 
              border: '1px solid var(--border)', 
              borderRadius: '6px', width: '34px', height: '34px', display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: 'var(--primary)', cursor: 'pointer', position: 'relative',
              boxShadow: '0 1px 2px rgba(0,0,0,0.04)'
            }}
            title="Universal AI Document Scanner"
          >
            <Scan size={18} />
          </button>

          {/* Executive Profile & Settings Menu Trigger */}
          <div style={{ position: 'relative' }}>
          <button 
            onClick={() => setIsMenuOpen(!isMenuOpen)}
            style={{
              display: 'flex', alignItems: 'center', gap: '6px', padding: '5px 10px',
              borderRadius: '6px', border: '1px solid var(--border)',
              background: 'var(--bg-secondary)', fontWeight: '500', fontSize: '13px', color: 'var(--text-primary)',
              boxShadow: '0 1px 2px rgba(0,0,0,0.04)', flexShrink: 0
            }}
          >
            <Settings size={16} color="#60a5fa" />
            <span className="desktop-only">Menu</span>
            <ChevronDown size={13} style={{ transform: isMenuOpen ? 'rotate(180deg)' : 'none', transition: 'transform 0.2s' }} />
          </button>

          {/* Floating Dropdown Quick-Menu */}
          {isMenuOpen && (
            <div 
              className="animate-fade-in" 
              style={{
                position: 'absolute', top: '50px', right: '0', width: '280px',
                padding: '8px', borderRadius: '12px', border: '1px solid #e2e8f0',
                boxShadow: '0 10px 30px rgba(15, 23, 42, 0.12)', background: '#ffffff',
                display: 'flex', flexDirection: 'column', gap: '4px', zIndex: 500
              }}
            >
              {/* Physician Profile Card in Menu */}
              <div style={{ padding: '12px 14px', borderBottom: '1px solid #e2e8f0', marginBottom: '4px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                {user?.picture ? (
                  <img src={user.picture} alt="avatar" style={{ width: '36px', height: '36px', borderRadius: '50%', border: '1px solid #bfdbfe' }} />
                ) : (
                  <div style={{ width: '36px', height: '36px', borderRadius: '8px', background: '#2563eb', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', color: 'white' }}>{user?.initials || 'MD'}</div>
                )}
                <div style={{ overflow: 'hidden' }}>
                  <div style={{ fontWeight: '700', fontSize: '14px', color: '#0f172a', whiteSpace: 'nowrap', textOverflow: 'ellipsis', overflow: 'hidden' }}>{user?.name}</div>
                  <div style={{ fontSize: '11px', color: '#059669', display: 'flex', alignItems: 'center', gap: '4px', marginTop: '2px', fontWeight: '600' }}>
                    <Shield size={11} /> Verified Healthcare SSO
                  </div>
                </div>
              </div>

              {/* Quick Theme Switcher */}
              <button
                onClick={() => { toggleTheme(); }}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 12px',
                  borderRadius: '8px', border: 'none', background: 'transparent', color: '#0f172a',
                  cursor: 'pointer', fontSize: '13px', fontWeight: '500', transition: 'background 0.15s', textAlign: 'left'
                }}
                onMouseOver={(e) => e.currentTarget.style.background = '#f8fafc'}
                onMouseOut={(e) => e.currentTarget.style.background = 'transparent'}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  {theme === 'dark' ? <Sun size={16} color="#2563eb" /> : <Moon size={16} color="#2563eb" />}
                  <span>Appearance Mode</span>
                </div>
                <span style={{ fontSize: '11px', padding: '2px 8px', borderRadius: '10px', background: '#eff6ff', color: '#2563eb', fontWeight: '700', border: '1px solid #bfdbfe' }}>
                  {theme === 'dark' ? 'Night' : 'Day'}
                </span>
              </button>

              {/* Direct WhatsApp Patient Chat */}
              <button
                onClick={() => { setIsMenuOpen(false); launchDirectWhatsApp(activePatient); }}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 12px',
                  borderRadius: '8px', border: 'none', background: 'transparent', color: '#0f172a',
                  cursor: 'pointer', fontSize: '13px', fontWeight: '500', transition: 'background 0.15s', textAlign: 'left'
                }}
                onMouseOver={(e) => e.currentTarget.style.background = '#f8fafc'}
                onMouseOut={(e) => e.currentTarget.style.background = 'transparent'}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <MessageCircle size={16} color="#059669" />
                  <span>Launch WhatsApp Directly</span>
                </div>
                <span style={{ fontSize: '11px', padding: '2px 8px', borderRadius: '10px', background: '#ecfdf5', color: '#059669', fontWeight: '700' }}>
                  Direct
                </span>
              </button>

              {/* Central Cloud Patients Directory */}
              <button
                onClick={() => { setIsMenuOpen(false); handleTabClick('patients'); }}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 14px',
                  borderRadius: '10px', border: 'none', background: 'transparent', color: 'var(--text-primary)',
                  cursor: 'pointer', fontSize: '14px', fontWeight: '500', transition: 'background 0.2s', textAlign: 'left'
                }}
                onMouseOver={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.08)'}
                onMouseOut={(e) => e.currentTarget.style.background = 'transparent'}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <Users size={17} color="#3b82f6" />
                  <span>Patient Directory</span>
                </div>
                <span style={{ fontSize: '11px', padding: '2px 8px', borderRadius: '10px', background: 'rgba(59, 130, 246, 0.2)', color: '#60a5fa', fontWeight: '700' }}>
                  Cloud
                </span>
              </button>

              {/* Developer WhatsApp Simulator & Cloud API */}
              <button
                onClick={() => { setIsMenuOpen(false); setIsWhatsAppOpen(true); }}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 14px',
                  borderRadius: '10px', border: 'none', background: 'transparent', color: 'var(--text-primary)',
                  cursor: 'pointer', fontSize: '14px', fontWeight: '500', transition: 'background 0.2s', textAlign: 'left'
                }}
                onMouseOver={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.08)'}
                onMouseOut={(e) => e.currentTarget.style.background = 'transparent'}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <Activity size={17} color="#a855f7" />
                  <span>WhatsApp Bot Simulator</span>
                </div>
                <span style={{ fontSize: '11px', padding: '2px 8px', borderRadius: '10px', background: 'rgba(168, 85, 247, 0.2)', color: '#a855f7', fontWeight: '700' }}>
                  Demo
                </span>
              </button>

              {/* Open Complete Settings Suite */}
              <button
                onClick={() => { setIsMenuOpen(false); setIsSettingsOpen(true); }}
                style={{
                  display: 'flex', alignItems: 'center', gap: '10px', padding: '12px 14px',
                  borderRadius: '10px', border: 'none', background: 'transparent', color: 'var(--text-primary)',
                  cursor: 'pointer', fontSize: '14px', fontWeight: '500', transition: 'background 0.2s', textAlign: 'left'
                }}
                onMouseOver={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.08)'}
                onMouseOut={(e) => e.currentTarget.style.background = 'transparent'}
              >
                <Settings size={17} color="#60a5fa" />
                <span>Clinical Settings Console</span>
              </button>

              <div style={{ height: '1px', background: 'var(--glass-border)', margin: '4px 0' }} />

              {/* Sign Out Option */}
              <button
                onClick={handleLogout}
                style={{
                  display: 'flex', alignItems: 'center', gap: '10px', padding: '12px 14px',
                  borderRadius: '10px', border: 'none', background: 'transparent', color: '#ef4444',
                  cursor: 'pointer', fontSize: '14px', fontWeight: '600', transition: 'background 0.2s', textAlign: 'left'
                }}
                onMouseOver={(e) => e.currentTarget.style.background = 'rgba(239, 68, 68, 0.12)'}
                onMouseOut={(e) => e.currentTarget.style.background = 'transparent'}
              >
                <LogOut size={17} />
                <span>Sign Out of Portal</span>
              </button>
            </div>
          )}
        </div>
        </div>
      </header>

      {/* Global Notification Slide-out Panel */}
      {isNotificationsOpen && (
        <div style={{ position: 'fixed', top: '70px', right: '16px', width: '380px', bottom: '16px', zIndex: 1000, display: 'flex', flexDirection: 'column' }}>
          <div className="glass-panel animate-fade-in" style={{ flex: 1, padding: '24px', display: 'flex', flexDirection: 'column', gap: '16px', boxShadow: '-10px 0 30px rgba(0,0,0,0.2)', border: '1px solid rgba(255,255,255,0.1)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--glass-border)', paddingBottom: '16px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '18px', fontWeight: '700', color: 'var(--text-primary)' }}>
                <Activity size={22} color="#3b82f6" /> AI Copilot Activity
              </div>
              <button onClick={() => setIsNotificationsOpen(false)} style={{ background: 'transparent', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer' }}>
                <X size={20} />
              </button>
            </div>
            
            <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '16px', paddingRight: '4px' }}>
              {globalNotifications.map(note => (
                <div key={note.id} style={{ background: 'var(--bg-secondary)', padding: '16px', borderRadius: '12px', borderLeft: `4px solid ${note.color}`, boxShadow: '0 4px 10px rgba(0,0,0,0.05)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                    <span style={{ fontSize: '13px', fontWeight: '700', color: note.color }}>{note.title}</span>
                    <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>{note.time}</span>
                  </div>
                  <div style={{ fontSize: '14px', color: 'var(--text-primary)', lineHeight: '1.5' }}>
                    {note.message}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Voice Nav Status Toast */}
      {voiceNavStatus && (
        <div className="animate-fade-in" style={{ position: 'absolute', top: '90px', left: '50%', transform: 'translateX(-50%)', zIndex: 1000, background: 'rgba(16, 185, 129, 0.95)', color: 'white', padding: '12px 24px', borderRadius: '30px', fontWeight: '700', fontSize: '15px', display: 'flex', alignItems: 'center', gap: '10px', boxShadow: '0 10px 25px rgba(16, 185, 129, 0.5)' }}>
          <Mic size={18} className="animate-pulse" /> {voiceNavStatus}
        </div>
      )}

      <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }} onClick={() => { if (isMenuOpen) setIsMenuOpen(false); if (isNotificationsOpen) setIsNotificationsOpen(false); }}>
        {/* Sidebar Nav - Clean Clinical Blue & White (4 Primary Pillars + Preserved All Modules) */}
        <aside style={{ width: '240px', margin: '0 0 16px 16px', padding: '16px 10px', background: '#ffffff', border: '1px solid #e2e8f0', borderRadius: '14px', display: 'flex', flexDirection: 'column', gap: '4px', boxShadow: '0 1px 3px rgba(15, 23, 42, 0.04)', overflowY: 'auto' }} className="desktop-only">
          <div style={{ padding: '4px 12px 6px 12px', fontSize: '11px', fontWeight: '700', color: '#64748b', letterSpacing: '0.5px' }}>
            CLINICAL PILLARS
          </div>

          <NavButton icon={<LayoutDashboard size={17} />} label="Today's Clinic" badge={badges.dashboard} active={activeTab === 'dashboard'} onClick={() => handleTabClick('dashboard')} />
          <NavButton icon={<Users size={17} />} label="Patients & Watch" active={activeTab === 'patients'} onClick={() => handleTabClick('patients')} />
          <NavButton 
            icon={<Mic size={17} />} 
            label="Ambient AI Scribe" 
            onClick={() => {
              window.dispatchEvent(new CustomEvent('open-scribe', { detail: { patient: activePatient } }));
            }} 
          />
          <NavButton icon={<Inbox size={17} />} label="Inbox & WhatsApp" badge={badges.inbox} active={activeTab === 'inbox'} onClick={() => handleTabClick('inbox')} />

          <div style={{ height: '1px', background: '#e2e8f0', margin: '10px 6px' }} />

          <div 
            onClick={() => setIsMoreToolsOpen(!isMoreToolsOpen)}
            style={{
              padding: '6px 12px',
              fontSize: '11px',
              fontWeight: '700',
              color: '#64748b',
              letterSpacing: '0.5px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              cursor: 'pointer',
              borderRadius: '6px',
              userSelect: 'none'
            }}
          >
            <span>MORE MODULES</span>
            <ChevronDown size={14} style={{ transform: isMoreToolsOpen ? 'rotate(180deg)' : 'none', transition: 'transform 0.2s', color: '#64748b' }} />
          </div>

          {/* Expanded or preserved tools when toggled */}
          {isMoreToolsOpen && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '3px', paddingLeft: '4px' }}>
              <NavButton icon={<FileText size={16} />} label="Intake OCR Engine" badge={badges.formFiller} active={activeTab === 'formFiller'} onClick={() => handleTabClick('formFiller')} />
              <NavButton icon={<Send size={16} />} label="Referral AI Triage" badge={badges.referral} active={activeTab === 'referral'} onClick={() => handleTabClick('referral')} />
              <NavButton icon={<Activity size={16} />} label="Digital Twin" active={activeTab === 'twin'} onClick={() => handleTabClick('twin')} />
              <NavButton icon={<Calendar size={16} />} label="Smart Calendar" active={activeTab === 'calendar'} onClick={() => handleTabClick('calendar')} />
              <NavButton icon={<DollarSign size={16} />} label="OHIP Billing" badge={badges.billing} active={activeTab === 'billing'} onClick={() => handleTabClick('billing')} />
            </div>
          )}

          <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: '4px', paddingTop: '10px', borderTop: '1px solid #e2e8f0' }}>
            <NavButton 
              icon={<MessageCircle size={17} color="#059669" />} 
              label="WhatsApp Direct" 
              onClick={() => launchDirectWhatsApp(activePatient)} 
            />
            <NavButton icon={<ScanFace size={17} />} label="iPad Kiosk Mode" onClick={() => setIsKioskMode(true)} />
          </div>
        </aside>

        {/* Main Content Area */}
        <main id="main-scroll-area" className="glass-panel main-content-mobile" style={{ flex: 1, margin: '0 16px 16px 16px', overflowY: 'hidden', border: 'none', borderRadius: '16px', position: 'relative', display: 'flex', flexDirection: 'column' }}>
          
          {/* GLOBAL PATIENT BANNER */}
          <AnimatePresence>
            {activePatient && (
              <motion.div 
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                className="patient-banner-container"
              >
                {/* Desktop Layout */}
                <div className="patient-banner-desktop">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '14px', minWidth: 0, flex: 1 }}>
                    <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: '#2563eb', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: '13px', flexShrink: 0 }}>
                      {activePatient.initials}
                    </div>
                    <div style={{ minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                        <span style={{ fontWeight: '700', fontSize: '15px', color: '#0f172a' }}>{activePatient.name}</span>
                        <span style={{ fontSize: '11px', padding: '1px 8px', borderRadius: '4px', background: activePatient.allergies === 'NKDA' ? '#ecfdf5' : '#fef2f2', color: activePatient.allergies === 'NKDA' ? '#059669' : '#dc2626', fontWeight: '700', border: `1px solid ${activePatient.allergies === 'NKDA' ? '#a7f3d0' : '#fecaca'}` }}>
                          {activePatient.allergies === 'NKDA' ? 'NKDA' : `Allergies: ${activePatient.allergies}`}
                        </span>
                        <span style={{ fontSize: '11px', padding: '1px 8px', borderRadius: '4px', background: '#eff6ff', color: '#2563eb', fontWeight: '600', border: '1px solid #bfdbfe', display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                          ⌚ Apple Watch Synced · HR 71 bpm
                        </span>
                      </div>
                      <div style={{ fontSize: '12px', color: '#64748b', display: 'flex', alignItems: 'center', gap: '8px', marginTop: '2px' }}>
                        <span>DOB: {activePatient.dob} • MRN: {activePatient.mrn}</span>
                        {allPatients.length > 1 && (
                          <select
                            value={activePatient.id}
                            onChange={(e) => handleSelectPatientById(e.target.value)}
                            style={{
                              background: '#ffffff',
                              border: '1px solid #bfdbfe',
                              borderRadius: '4px',
                              color: '#2563eb',
                              fontSize: '11px',
                              fontWeight: '600',
                              cursor: 'pointer',
                              padding: '1px 6px',
                              outline: 'none'
                            }}
                            title="Switch active patient chart"
                          >
                            {allPatients.map(p => (
                              <option key={p.id} value={p.id} style={{ background: '#ffffff', color: '#0f172a' }}>
                                Switch: {p.name}
                              </option>
                            ))}
                          </select>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Desktop Actions: WhatsApp Icon Button + AI Scribe + Close */}
                  <div style={{ display: 'flex', gap: '10px', alignItems: 'center', flexShrink: 0 }}>
                    <button 
                      type="button"
                      onClick={() => launchDirectWhatsApp(activePatient)}
                      style={{
                        background: 'linear-gradient(135deg, #25D366, #128C7E)',
                        color: '#ffffff',
                        border: 'none',
                        width: '36px',
                        height: '36px',
                        borderRadius: '50%',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        boxShadow: '0 2px 10px rgba(37, 211, 102, 0.35)',
                        transition: 'transform 0.15s ease'
                      }}
                      title={`Open WhatsApp chat with ${activePatient.name}`}
                    >
                      <MessageCircle size={20} />
                    </button>
                    <button 
                      onClick={() => { window.dispatchEvent(new CustomEvent('open-scribe', { detail: { patient: activePatient } })); }}
                      style={{ background: 'rgba(16, 185, 129, 0.18)', color: '#34d399', border: '1px solid rgba(16, 185, 129, 0.35)', padding: '6px 12px', borderRadius: '8px', cursor: 'pointer', fontSize: '13px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '6px' }}
                      title="Open Ambient AI Scribe"
                    >
                      <Mic size={14} /> Open AI Scribe
                    </button>
                    <button 
                      onClick={() => {
                        setActivePatient(null);
                        try { localStorage.removeItem('active_patient_context'); } catch(e) {}
                        window.dispatchEvent(new CustomEvent('set-active-patient', { detail: null }));
                      }}
                      style={{ background: 'transparent', color: 'var(--text-secondary)', border: 'none', cursor: 'pointer', padding: '6px', borderRadius: '50%' }}
                      title="Dismiss patient banner"
                    >
                      <X size={18} />
                    </button>
                  </div>
                </div>

                {/* Mobile Layout: Simple, Clean Single-Row Strip */}
                <div className="patient-banner-mobile">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0, flex: 1 }}>
                    <div style={{ width: '34px', height: '34px', borderRadius: '50%', background: '#3b82f6', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: '13px', flexShrink: 0 }}>
                      {activePatient.initials}
                    </div>
                    <div style={{ minWidth: 0, flex: 1 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <span style={{ fontWeight: '700', fontSize: '14px', color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {activePatient.name}
                        </span>
                        <span style={{ fontSize: '9px', padding: '1px 5px', borderRadius: '4px', background: activePatient.allergies === 'NKDA' ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)', color: activePatient.allergies === 'NKDA' ? '#10b981' : '#f87171', fontWeight: '700', flexShrink: 0 }}>
                          {activePatient.allergies === 'NKDA' ? 'NKDA' : 'Allergies'}
                        </span>
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <span>MRN: {activePatient.mrn}</span>
                        {allPatients.length > 1 && (
                          <select
                            value={activePatient.id}
                            onChange={(e) => handleSelectPatientById(e.target.value)}
                            style={{
                              background: 'transparent',
                              border: 'none',
                              color: '#60a5fa',
                              fontSize: '10px',
                              fontWeight: '600',
                              cursor: 'pointer',
                              padding: 0,
                              outline: 'none'
                            }}
                            title="Switch patient"
                          >
                            {allPatients.map(p => (
                              <option key={p.id} value={p.id} style={{ background: '#161b22', color: '#e6edf3' }}>
                                ⇄ {p.name.split(' ')[0]}
                              </option>
                            ))}
                          </select>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Actions: Just WhatsApp Icon + Scribe Icon + Close */}
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexShrink: 0 }}>
                    <button 
                      type="button"
                      onClick={() => launchDirectWhatsApp(activePatient)}
                      style={{
                        background: 'linear-gradient(135deg, #25D366, #128C7E)',
                        color: '#ffffff',
                        border: 'none',
                        width: '36px',
                        height: '36px',
                        borderRadius: '50%',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        boxShadow: '0 2px 8px rgba(37, 211, 102, 0.35)',
                        flexShrink: 0
                      }}
                      title={`Chat with ${activePatient.name} on WhatsApp`}
                    >
                      <MessageCircle size={20} />
                    </button>
                    <button 
                      type="button"
                      onClick={() => { window.dispatchEvent(new CustomEvent('open-scribe', { detail: { patient: activePatient } })); }}
                      style={{
                        background: 'rgba(16, 185, 129, 0.2)',
                        color: '#34d399',
                        border: '1px solid rgba(16, 185, 129, 0.4)',
                        width: '34px',
                        height: '34px',
                        borderRadius: '50%',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        flexShrink: 0
                      }}
                      title="Open AI Scribe"
                    >
                      <Mic size={16} />
                    </button>
                    <button 
                      onClick={() => {
                        setActivePatient(null);
                        try { localStorage.removeItem('active_patient_context'); } catch(e) {}
                        window.dispatchEvent(new CustomEvent('set-active-patient', { detail: null }));
                      }}
                      style={{
                        background: 'rgba(255,255,255,0.06)',
                        border: 'none',
                        color: 'var(--text-secondary)',
                        borderRadius: '50%',
                        width: '30px',
                        height: '30px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        cursor: 'pointer',
                        flexShrink: 0
                      }}
                      title="Dismiss banner"
                    >
                      <X size={16} />
                    </button>
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          <AnimatePresence mode="wait">
            <motion.div
              key={activeTab}
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -20 }}
              transition={{ duration: 0.25, ease: 'easeOut' }}
              className="tab-viewport-container"
              style={{ width: '100%', height: '100%', overflowY: 'auto', flex: 1 }}
            >
              {activeTab === 'dashboard' && <Dashboard />}
              {activeTab === 'patients' && (
                <PatientDirectory 
                  onSelectPatient={handleSelectPatientFromDirectory} 
                  onOpenWhatsApp={(p) => launchDirectWhatsApp(p)} 
                />
              )}
              {activeTab === 'calendar' && <SmartCalendar />}
              {activeTab === 'formFiller' && <FormFiller triggerNotification={triggerNotification} />}
              {activeTab === 'referral' && <ReferralChecker triggerNotification={triggerNotification} />}
              {activeTab === 'inbound' && <InboundSummary setActiveTab={handleTabClick} triggerNotification={triggerNotification} />}
              {activeTab === 'inbox' && <SecureInbox triggerNotification={triggerNotification} />}
              {activeTab === 'billing' && <BillingDashboard />}
              {activeTab === 'twin' && <DigitalTwin />}
            </motion.div>
          </AnimatePresence>
        </main>
      </div>
      
      {/* Command Palette Modal */}
      <AnimatePresence>
        {isSearchOpen && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(4px)', zIndex: 9999, display: 'flex', justifyContent: 'center', alignItems: 'flex-start', paddingTop: '12vh' }}
            onClick={() => setIsSearchOpen(false)}
          >
            <motion.div 
              initial={{ opacity: 0, scale: 0.95, y: -20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: -20 }}
              transition={{ duration: 0.15 }}
              onClick={e => e.stopPropagation()}
              style={{ width: '600px', background: 'rgba(15, 23, 42, 0.95)', border: '1px solid #3b82f6', borderRadius: '16px', overflow: 'hidden', boxShadow: '0 25px 50px -12px rgba(0,0,0,0.7)' }}
            >
              <div style={{ display: 'flex', alignItems: 'center', padding: '16px 20px', borderBottom: '1px solid rgba(255,255,255,0.1)' }}>
                <Search size={22} color="#60a5fa" />
                <input 
                  autoFocus
                  ref={searchInputRef}
                  type="text" 
                  placeholder="Search patients, workflows, or type a command..."
                  value={searchQuery}
                  onChange={(e) => { setSearchQuery(e.target.value); setSearchSelectedIndex(0); }}
                  onKeyDown={(e) => {
                    if (e.key === 'ArrowDown') {
                      e.preventDefault();
                      setSearchSelectedIndex(prev => Math.min(prev + 1, (searchQuery ? filteredSearch.length : mockSearchResults.length) - 1));
                    } else if (e.key === 'ArrowUp') {
                      e.preventDefault();
                      setSearchSelectedIndex(prev => Math.max(prev - 1, 0));
                    } else if (e.key === 'Enter') {
                      e.preventDefault();
                      const list = searchQuery ? filteredSearch : mockSearchResults;
                      if (list[searchSelectedIndex]) {
                        const res = list[searchSelectedIndex];
                        if (res.action === 'settings') setIsSettingsOpen(true);
                        else handleTabClick(res.action);
                        setSearchQuery('');
                        setIsSearchOpen(false);
                      }
                    } else if (e.key === 'Escape') {
                      setIsSearchOpen(false);
                    }
                  }}
                  style={{ flex: 1, background: 'transparent', border: 'none', color: 'white', fontSize: '18px', outline: 'none', marginLeft: '16px' }}
                />
                <div style={{ display: 'flex', gap: '8px', fontSize: '11px', color: 'var(--text-secondary)' }}>
                  <span style={{ background: 'rgba(255,255,255,0.1)', padding: '4px 8px', borderRadius: '4px' }}>ESC</span> to close
                </div>
              </div>

              <div style={{ padding: '8px', maxHeight: '400px', overflowY: 'auto' }}>
                {(searchQuery ? filteredSearch : mockSearchResults).length > 0 ? (
                  (searchQuery ? filteredSearch : mockSearchResults).map((res, idx) => (
                    <div 
                      key={res.id} 
                      onClick={() => {
                        if (res.action === 'settings') setIsSettingsOpen(true);
                        else handleTabClick(res.action);
                        setSearchQuery('');
                        setIsSearchOpen(false);
                      }}
                      style={{ 
                        padding: '12px 16px', display: 'flex', alignItems: 'center', gap: '16px', cursor: 'pointer', borderRadius: '12px', transition: 'all 0.1s',
                        background: searchSelectedIndex === idx ? 'rgba(59, 130, 246, 0.2)' : 'transparent',
                        border: searchSelectedIndex === idx ? '1px solid rgba(59, 130, 246, 0.4)' : '1px solid transparent'
                      }}
                      onMouseOver={() => setSearchSelectedIndex(idx)}
                    >
                      <div style={{ padding: '10px', background: 'rgba(255,255,255,0.05)', borderRadius: '10px', border: '1px solid rgba(255,255,255,0.1)' }}>
                        {res.icon}
                      </div>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: '15px', fontWeight: '600', color: searchSelectedIndex === idx ? '#60a5fa' : 'var(--text-primary)' }}>{res.title}</div>
                        <div style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>{res.type} • {res.desc}</div>
                      </div>
                      {searchSelectedIndex === idx && (
                        <div style={{ color: 'var(--text-secondary)', fontSize: '12px' }}>↵ Jump</div>
                      )}
                    </div>
                  ))
                ) : (
                  <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-secondary)' }}>
                    No results found for "{searchQuery}"
                  </div>
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Floating Scribe & Settings Suite */}
      <Scribe />
      <SettingsModal 
        isOpen={isSettingsOpen} 
        onClose={() => setIsSettingsOpen(false)} 
        theme={theme} 
        toggleTheme={toggleTheme} 
        user={user} 
      />
      <UniversalScanner isOpen={isScannerOpen} onClose={() => setIsScannerOpen(false)} />
      <WhatsAppModal 
        isOpen={isWhatsAppOpen} 
        onClose={() => setIsWhatsAppOpen(false)} 
        activePatient={activePatient} 
      />

      {/* Native-Grade Mobile Bottom Navigation */}
      <div className="bottom-nav mobile-only">
        <div className={`bottom-nav-item ${activeTab === 'dashboard' ? 'active' : ''}`} onClick={() => handleTabClick('dashboard')}>
          <LayoutDashboard size={20} />
          <span>Home</span>
        </div>
        <div className={`bottom-nav-item ${activeTab === 'patients' ? 'active' : ''}`} onClick={() => handleTabClick('patients')}>
          <Users size={20} />
          <span>Patients</span>
        </div>
        
        {/* Prominent Center Scribe Floating Mic */}
        <div className="bottom-nav-center-action" onClick={() => window.dispatchEvent(new CustomEvent('open-scribe', { detail: { patient: activePatient } }))}>
          <div className="bottom-nav-center-btn" title="Open Ambient Voice Scribe" style={{ background: '#2563eb', boxShadow: '0 4px 12px rgba(37, 99, 235, 0.35)', border: '3px solid #ffffff' }}>
            <Mic size={22} />
          </div>
          <span style={{ fontSize: '10px', fontWeight: '700', color: '#2563eb', marginTop: '2px' }}>AI Scribe</span>
        </div>

        <div className={`bottom-nav-item ${activeTab === 'inbox' ? 'active' : ''}`} onClick={() => handleTabClick('inbox')}>
          <div style={{ position: 'relative' }}>
            <Inbox size={20} />
            {badges.inbox > 0 && (
              <span style={{ position: 'absolute', top: -5, right: -5, background: 'var(--error)', color: 'white', fontSize: '9px', borderRadius: '50%', width: '15px', height: '15px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold' }}>
                {badges.inbox}
              </span>
            )}
          </div>
          <span>Inbox</span>
        </div>
        <div className={`bottom-nav-item ${activeTab === 'billing' ? 'active' : ''}`} onClick={() => handleTabClick('billing')}>
          <DollarSign size={20} />
          <span>Billing</span>
        </div>
      </div>
    </div>
  );
}

function NavButton({ icon, label, active, onClick, badge }) {
  return (
    <button 
      onClick={onClick}
      style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '9px 12px', width: '100%',
        borderRadius: '8px', border: active ? '1px solid #bfdbfe' : '1px solid transparent', 
        background: active ? '#eff6ff' : 'transparent',
        color: active ? '#2563eb' : '#475569',
        cursor: 'pointer', fontSize: '13px', fontWeight: active ? '700' : '500', transition: 'all 0.15s',
        textAlign: 'left'
      }}
      onMouseOver={(e) => {
        if(!active) { e.currentTarget.style.background = '#f8fafc'; e.currentTarget.style.color = '#0f172a'; }
      }}
      onMouseOut={(e) => {
        if(!active) { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = '#475569'; }
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
        <span style={{ color: active ? '#2563eb' : '#64748b' }}>{icon}</span> 
        {label}
      </div>
      {badge > 0 && (
        <span style={{ 
          color: '#2563eb', background: '#eff6ff', border: '1px solid #bfdbfe', borderRadius: '10px', padding: '1px 6px', fontSize: '11px', fontWeight: '700'
        }}>
          {badge}
        </span>
      )}
    </button>
  );
}

export default App;
