import { useState, useEffect, useRef } from 'react';
import { LayoutDashboard, FileText, Send, MessageSquare, LogOut, Inbox, Sun, Moon, Settings, ChevronDown, Shield, User, Plus, Bell, X, Activity, Mic, Search, Calendar, DollarSign, Scan, ScanFace, MessageCircle } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import './index.css';

// We will create these components next
import Dashboard from './components/Dashboard';
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
  const [theme, setTheme] = useState(localStorage.getItem('medoffice_theme') || 'dark');
  
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isVoiceNavActive, setIsVoiceNavActive] = useState(false);
  const [voiceNavStatus, setVoiceNavStatus] = useState('');
  const [isKioskMode, setIsKioskMode] = useState(false);
  
  const [searchQuery, setSearchQuery] = useState('');
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [isScannerOpen, setIsScannerOpen] = useState(false);
  const [searchSelectedIndex, setSearchSelectedIndex] = useState(0);
  const [activePatient, setActivePatient] = useState(null);
  const searchInputRef = useRef(null);


  const mockSearchResults = [
    { id: 'p1', type: 'Patient', title: 'John Doe', desc: 'DOB: 04/12/1985 • Hypertension', action: 'dashboard', icon: <User size={14} color="#3b82f6" /> },
    { id: 'p2', type: 'Patient', title: 'Sarah Jenkins', desc: 'DOB: 11/23/1992 • MRI Referral', action: 'dashboard', icon: <User size={14} color="#3b82f6" /> },
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

  // Handle active patient setting from other components
  useEffect(() => {
    const handleSetActivePatient = (e) => {
      setActivePatient(e.detail);
    };
    window.addEventListener('set-active-patient', handleSetActivePatient);
    return () => window.removeEventListener('set-active-patient', handleSetActivePatient);
  }, []);

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
    <div className="app-shell" style={{ display: 'flex', flexDirection: 'column', height: '100vh', position: 'relative' }}>
      <header className="glass-panel" style={{ display: 'flex', justifyContent: 'space-between', padding: '16px 24px', margin: '16px', borderBottom: 'none', borderRadius: '16px', alignItems: 'center', position: 'relative', zIndex: 100 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          {user?.picture ? (
            <img src={user.picture} alt={user?.name || 'User'} style={{ width: '42px', height: '42px', borderRadius: '50%', border: '1px solid var(--border)' }} />
          ) : (
            <div style={{ width: '42px', height: '42px', borderRadius: '8px', background: 'var(--primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '600', fontSize: '18px', color: 'white' }}>
              {user?.initials || 'MD'}
            </div>
          )}
          <div>
            <h2 style={{ margin: 0, fontSize: '18px', fontWeight: '600', color: 'var(--text-primary)' }}>Prime Care App <span style={{ fontSize: '11px', background: 'rgba(47, 129, 247, 0.1)', color: 'var(--primary)', padding: '2px 6px', borderRadius: '4px', marginLeft: '8px', verticalAlign: 'middle', border: '1px solid rgba(47, 129, 247, 0.2)', fontWeight: '600' }}>PRO</span></h2>
            <p style={{ margin: '2px 0 0 0', fontSize: '13px', color: 'var(--text-secondary)' }}>{user?.clinic || 'Prime Care Medical Group'} · <strong style={{ color: 'var(--text-primary)', fontWeight: '500' }}>{user?.name}</strong> {user?.email && `(${user.email})`}</p>
          </div>
        </div>

        {/* Header Right Actions */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', position: 'relative' }}>
          
          {/* Spotlight Search Trigger */}
          <button 
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
            <span style={{ fontSize: '13px', marginRight: '32px' }}>Search Prime Care...</span>
            <div style={{ display: 'flex', alignItems: 'center', gap: '2px', background: 'var(--bg-tertiary)', padding: '2px 4px', borderRadius: '4px', fontSize: '10px', fontWeight: '500', color: 'var(--text-secondary)' }}>
              <span>⌘</span><span>K</span>
            </div>
          </button>

          {/* Hands-Free Navigation Toggle */}
          <button 
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
              borderRadius: '6px', width: '34px', height: '34px', display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: 'var(--text-secondary)', cursor: 'pointer', position: 'relative',
              boxShadow: '0 1px 2px rgba(0,0,0,0.04)'
            }}
          >
            <Bell size={18} />
            <div style={{ position: 'absolute', top: '-4px', right: '-4px', background: 'var(--error)', width: '10px', height: '10px', borderRadius: '50%', border: '2px solid var(--bg-primary)' }} />
          </button>

          <button 
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
              display: 'flex', alignItems: 'center', gap: '8px', padding: '6px 12px',
              borderRadius: '6px', border: '1px solid var(--border)',
              background: 'var(--bg-secondary)', fontWeight: '500', fontSize: '13px', color: 'var(--text-primary)',
              boxShadow: '0 1px 2px rgba(0,0,0,0.04)'
            }}
          >
            <Settings size={17} color="#60a5fa" />
            <span>Menu & Settings</span>
            <ChevronDown size={15} style={{ transform: isMenuOpen ? 'rotate(180deg)' : 'none', transition: 'transform 0.2s' }} />
          </button>

          {/* Floating Dropdown Quick-Menu */}
          {isMenuOpen && (
            <div 
              className="glass-panel animate-fade-in" 
              style={{
                position: 'absolute', top: '54px', right: '0', width: '280px',
                padding: '8px', borderRadius: '16px', border: '1px solid #3b82f6',
                boxShadow: '0 20px 50px rgba(0,0,0,0.65)', background: 'rgba(15, 23, 42, 0.95)',
                display: 'flex', flexDirection: 'column', gap: '4px', zIndex: 500
              }}
            >
              {/* Physician Profile Card in Menu */}
              <div style={{ padding: '12px 14px', borderBottom: '1px solid var(--glass-border)', marginBottom: '4px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                {user?.picture ? (
                  <img src={user.picture} alt="avatar" style={{ width: '36px', height: '36px', borderRadius: '50%', border: '1px solid #3b82f6' }} />
                ) : (
                  <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: '#3b82f6', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', color: 'white' }}>{user?.initials || 'MD'}</div>
                )}
                <div style={{ overflow: 'hidden' }}>
                  <div style={{ fontWeight: '700', fontSize: '14px', color: 'var(--text-primary)', whiteSpace: 'nowrap', textOverflow: 'ellipsis', overflow: 'hidden' }}>{user?.name}</div>
                  <div style={{ fontSize: '11px', color: '#10b981', display: 'flex', alignItems: 'center', gap: '4px', marginTop: '2px' }}>
                    <Shield size={11} /> Verified Healthcare SSO
                  </div>
                </div>
              </div>

              {/* Quick Theme Switcher */}
              <button
                onClick={() => { toggleTheme(); }}
                style={{
                  display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 14px',
                  borderRadius: '10px', border: 'none', background: 'transparent', color: 'var(--text-primary)',
                  cursor: 'pointer', fontSize: '14px', fontWeight: '500', transition: 'background 0.2s', textAlign: 'left'
                }}
                onMouseOver={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.08)'}
                onMouseOut={(e) => e.currentTarget.style.background = 'transparent'}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  {theme === 'dark' ? <Sun size={17} color="#fbbf24" /> : <Moon size={17} color="#3b82f6" />}
                  <span>Appearance Mode</span>
                </div>
                <span style={{ fontSize: '11px', padding: '2px 8px', borderRadius: '10px', background: theme === 'dark' ? 'rgba(251, 191, 36, 0.2)' : 'rgba(59, 130, 246, 0.2)', color: theme === 'dark' ? '#fbbf24' : '#2563eb', fontWeight: '700' }}>
                  {theme === 'dark' ? 'Night' : 'Day'}
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
        {/* Sidebar Nav */}
        <aside className="glass-panel desktop-only" style={{ width: '250px', margin: '0 0 16px 16px', padding: '20px 12px', display: 'flex', flexDirection: 'column', gap: '8px', border: 'none', backdropFilter: 'blur(30px)' }}>
          <NavButton icon={<LayoutDashboard size={18} />} label="Dashboard" badge={badges.dashboard} active={activeTab === 'dashboard'} onClick={() => handleTabClick('dashboard')} />
          <NavButton icon={<Activity size={18} />} label="Digital Twin" active={activeTab === 'twin'} onClick={() => handleTabClick('twin')} />
          <NavButton icon={<Calendar size={18} />} label="Smart Calendar" active={activeTab === 'calendar'} onClick={() => handleTabClick('calendar')} />
          <NavButton icon={<FileText size={18} />} label="Intake OCR Engine" badge={badges.formFiller} active={activeTab === 'formFiller'} onClick={() => handleTabClick('formFiller')} />
          <NavButton icon={<Send size={18} />} label="Referral AI Triage" badge={badges.referral} active={activeTab === 'referral'} onClick={() => handleTabClick('referral')} />
          <NavButton icon={<MessageSquare size={18} />} label="Inbound Summary & Chat" badge={badges.inbound} active={activeTab === 'inbound'} onClick={() => handleTabClick('inbound')} />
          <NavButton icon={<Inbox size={18} />} label="Secure Inbox" badge={badges.inbox} active={activeTab === 'inbox'} onClick={() => handleTabClick('inbox')} />
          <NavButton icon={<DollarSign size={18} />} label="Billing" badge={badges.billing} active={activeTab === 'billing'} onClick={() => handleTabClick('billing')} />
          <div style={{ marginTop: 'auto' }}>
            <NavButton 
              icon={<MessageCircle size={18} />} 
              label="WhatsApp Patient Chat" 
              onClick={() => {
                const phoneNumber = '1234567890';
                const defaultMessage = 'Hello, I am a patient reaching out to update my records. My name is [Your Name] and my DOB is [YYYY-MM-DD].';
                window.open(`https://wa.me/${phoneNumber}?text=${encodeURIComponent(defaultMessage)}`, '_blank');
              }} 
            />
            <NavButton icon={<ScanFace size={18} />} label="iPad Kiosk Mode" onClick={() => setIsKioskMode(true)} />
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
                style={{ 
                  background: 'rgba(59, 130, 246, 0.1)', 
                  borderBottom: '1px solid rgba(59, 130, 246, 0.3)', 
                  padding: '12px 24px', 
                  display: 'flex', 
                  alignItems: 'center', 
                  justifyContent: 'space-between',
                  boxShadow: '0 4px 15px rgba(0,0,0,0.1)',
                  zIndex: 10
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: '#3b82f6', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold' }}>
                      {activePatient.initials}
                    </div>
                    <div>
                      <div style={{ fontWeight: '700', fontSize: '16px', color: 'var(--text-primary)' }}>{activePatient.name}</div>
                      <div style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>DOB: {activePatient.dob} • MRN: {activePatient.mrn}</div>
                    </div>
                  </div>
                  <div style={{ width: '1px', height: '30px', background: 'rgba(255,255,255,0.1)' }} />
                  <div>
                    <div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Allergies</div>
                    <div style={{ fontSize: '13px', fontWeight: '600', color: activePatient.allergies === 'NKDA' ? '#10b981' : '#ef4444' }}>{activePatient.allergies}</div>
                  </div>
                  <div style={{ width: '1px', height: '30px', background: 'rgba(255,255,255,0.1)' }} />
                  <div>
                    <div style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase' }}>Code Status</div>
                    <div style={{ fontSize: '13px', fontWeight: '600', color: '#60a5fa' }}>{activePatient.codeStatus || 'Full Code'}</div>
                  </div>
                </div>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button 
                    onClick={() => { window.dispatchEvent(new CustomEvent('open-scribe')); }}
                    style={{ background: 'rgba(16, 185, 129, 0.2)', color: '#34d399', border: '1px solid rgba(16, 185, 129, 0.4)', padding: '6px 12px', borderRadius: '8px', cursor: 'pointer', fontSize: '13px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '6px' }}
                  >
                    <Mic size={14} /> Open AI Scribe
                  </button>
                  <button 
                    onClick={() => setActivePatient(null)}
                    style={{ background: 'transparent', color: 'var(--text-secondary)', border: 'none', cursor: 'pointer', padding: '6px' }}
                  >
                    <X size={18} />
                  </button>
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
              style={{ width: '100%', height: '100%', overflowY: 'auto', padding: '24px', flex: 1 }}
            >
              {activeTab === 'dashboard' && <Dashboard />}
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

      {/* Mobile Bottom Navigation */}
      <div className="bottom-nav mobile-only">
        <div className={`bottom-nav-item ${activeTab === 'dashboard' ? 'active' : ''}`} onClick={() => handleTabClick('dashboard')}>
          <LayoutDashboard size={24} />
          <span>Home</span>
        </div>
        <div className={`bottom-nav-item ${activeTab === 'calendar' ? 'active' : ''}`} onClick={() => handleTabClick('calendar')}>
          <Calendar size={24} />
          <span>Calendar</span>
        </div>
        <div className={`bottom-nav-item ${activeTab === 'inbox' ? 'active' : ''}`} onClick={() => handleTabClick('inbox')}>
          <div style={{ position: 'relative' }}>
            <Inbox size={24} />
            {badges.inbox > 0 && (
              <span style={{ position: 'absolute', top: -5, right: -5, background: 'var(--error)', color: 'white', fontSize: '10px', borderRadius: '50%', width: '16px', height: '16px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold' }}>
                {badges.inbox}
              </span>
            )}
          </div>
          <span>Inbox</span>
        </div>
        <div className={`bottom-nav-item ${activeTab === 'billing' ? 'active' : ''}`} onClick={() => handleTabClick('billing')}>
          <DollarSign size={24} />
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
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 16px', width: '100%',
        borderRadius: '20px', border: 'none', background: active ? 'rgba(59, 130, 246, 0.2)' : 'transparent',
        color: active ? 'var(--primary)' : 'var(--text-secondary)',
        cursor: 'pointer', fontSize: '14px', fontWeight: active ? '700' : '500', transition: 'all 0.2s',
        textAlign: 'left'
      }}
      onMouseOver={(e) => {
        if(!active) { e.currentTarget.style.background = 'rgba(150,150,150,0.1)'; e.currentTarget.style.color = 'var(--text-primary)'; }
      }}
      onMouseOut={(e) => {
        if(!active) { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = 'var(--text-secondary)'; }
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
        <span style={{ color: active ? 'var(--primary)' : 'var(--text-secondary)' }}>{icon}</span> 
        {label}
      </div>
      {badge > 0 && (
        <span style={{ 
          color: 'var(--primary)', fontSize: '12px', fontWeight: '700'
        }}>
          {badge}
        </span>
      )}
    </button>
  );
}

export default App;
