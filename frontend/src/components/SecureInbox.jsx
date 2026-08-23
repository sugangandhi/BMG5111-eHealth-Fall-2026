import React, { useState } from 'react';
import axios from 'axios';
import { 
  Search, SlidersHorizontal, Settings, ChevronLeft, ChevronRight, 
  MoreVertical, RefreshCw, Archive, AlertOctagon, Mail, 
  Paperclip, Star, Square, CheckSquare, ShieldAlert, Zap, X, CheckCircle,
  FileText, Pill, Phone, Stethoscope, Inbox
} from 'lucide-react';

const MOCK_MESSAGES = [
  {
    id: 1,
    type: "emergency",
    sender: "Dr. James Smith (Cardiology)",
    subject: "STAT Consult Result - Patient John Doe",
    snippet: "- Patient John Doe presented with severe chest pain and elevated troponin levels. Diagnosed with acute myocardial infarction. Immediate transfer to CCU required. Please arrange stat follow-up.",
    timestamp: "10:14 AM",
    isUnread: true,
    status: "pending",
    hasAttachment: true,
    starred: true
  },
  {
    id: 2,
    type: "rx",
    sender: "Shoppers Drug Mart",
    subject: "Prescription Refill Request",
    snippet: "- Patient Mary Jane is requesting a 90-day refill for Metformin 500mg. Please authorize.",
    timestamp: "Yesterday",
    isUnread: true,
    status: "pending",
    hasAttachment: false,
    starred: false
  },
  {
    id: 3,
    type: "discharge",
    sender: "General Hospital ER",
    subject: "Discharge Summary - Robert Lee",
    snippet: "- Patient admitted for minor concussion following a slip and fall. CT scan clear. Discharged with instructions to rest and follow up with family physician in 1 week if headaches persist.",
    timestamp: "May 20",
    isUnread: false,
    status: "pending",
    hasAttachment: true,
    starred: false
  },
  {
    id: 4,
    type: "inquiry",
    sender: "Sarah Jenkins, RN",
    subject: "Update on Clinical Research Assistant II",
    snippet: "- Dear team, Thank you for the update regarding the Clinical Research Assistant II position. I appreciate the selection committee's time...",
    timestamp: "Jul 7",
    isUnread: false,
    status: "resolved",
    hasAttachment: false,
    starred: false
  },
  {
    id: 5,
    type: "admin",
    sender: "IT Support",
    subject: "System Maintenance Notice",
    snippet: "- Please be advised that the main EHR portal will undergo scheduled maintenance this Sunday between 2AM and 4AM EST.",
    timestamp: "Jul 23",
    isUnread: false,
    status: "resolved",
    hasAttachment: false,
    starred: false
  }
];

export default function SecureInbox({ triggerNotification }) {
  const [messages, setMessages] = useState(MOCK_MESSAGES);

  React.useEffect(() => {
    const draftEmails = JSON.parse(localStorage.getItem('drafted_emails') || '[]');
    if (draftEmails.length > 0) {
      setMessages([...draftEmails, ...MOCK_MESSAGES]);
    }
  }, []);
  const [selectedMsg, setSelectedMsg] = useState(null);
  const [actionToast, setActionToast] = useState(null);
  const [copilotOpen, setCopilotOpen] = useState(false);
  const [processingAction, setProcessingAction] = useState(false);
  const [selectedIds, setSelectedIds] = useState([]);
  const [activeFilter, setActiveFilter] = useState(null);
  const [activeFolder, setActiveFolder] = useState('inbox');
  const [filterTime, setFilterTime] = useState(null);
  const [filterTo, setFilterTo] = useState(null);

  React.useEffect(() => {
    const handleVoiceCommand = (e) => {
       const act = e.detail;
       if (act.action === 'inbox_folder') {
          setActiveFolder(act.target);
          setSelectedMsg(null);
       }
    };
    window.addEventListener('voice-command', handleVoiceCommand);
    return () => window.removeEventListener('voice-command', handleVoiceCommand);
  }, []);

  const handleSelectMessage = (msg) => {
    setSelectedMsg(msg);
    setCopilotOpen(false);
    setActionToast(null);
    setMessages(prev => prev.map(m => m.id === msg.id ? { ...m, isUnread: false } : m));
  };

  const toggleSelect = (e, id) => {
    e.stopPropagation();
    if (selectedIds.includes(id)) {
      setSelectedIds(selectedIds.filter(i => i !== id));
    } else {
      setSelectedIds([...selectedIds, id]);
    }
  };

  const toggleStar = (e, id) => {
    e.stopPropagation();
    setMessages(prev => prev.map(m => m.id === id ? { ...m, starred: !m.starred } : m));
  };

  const handleCopilotAction = async (actionName, triggerDashUpdate = false) => {
    setProcessingAction(true);
    
    if (triggerDashUpdate) {
      try {
        const token = localStorage.getItem('medoffice_token') || 'demo-token';
        await axios.post('http://localhost:8000/api/activity/log', {
          action: "secure_inbox_resolved",
          description: `Executed AI Copilot Workflow: ${actionName}`,
          patient_name: selectedMsg?.sender || "Unknown",
          detail: `Automatically processed via Smart Clinical Inbox. Status marked as ${actionName}.`,
          color: actionName.includes("Approve") ? "red" : actionName.includes("Refill") ? "emerald" : "purple"
        }, { headers: { Authorization: `Bearer ${token}` } });
      } catch (err) {
        console.error("Failed to log activity:", err);
      }
    }

    setTimeout(() => {
      setMessages(prev => prev.map(m => m.id === selectedMsg.id ? { ...m, status: actionName } : m));
      setSelectedMsg(prev => ({...prev, status: actionName}));
      setActionToast(`✅ Successfully executed: ${actionName}`);
      setCopilotOpen(false);
      setProcessingAction(false);
      
      if (triggerDashUpdate && triggerNotification) {
        triggerNotification('dashboard');
      }
      
      setTimeout(() => setActionToast(null), 5000);
    }, 1500);
  };

  if (selectedMsg) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', height: '100%', borderRadius: '16px', overflow: 'hidden' }}>
        {/* Detail View Toolbar */}
        <div style={{ display: 'flex', alignItems: 'center', padding: '12px 24px', borderBottom: '1px solid rgba(0,0,0,0.1)' }}>
          <button onClick={() => setSelectedMsg(null)} style={{ background: 'transparent', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', color: 'var(--text-secondary)', padding: '8px', borderRadius: '50%' }} onMouseOver={e=>e.currentTarget.style.background='rgba(0,0,0,0.05)'} onMouseOut={e=>e.currentTarget.style.background='transparent'}>
            <ChevronLeft size={20} />
          </button>
          <div style={{ width: '16px' }} />
          <div style={{ display: 'flex', gap: '16px', color: 'var(--text-secondary)' }}>
            <Archive size={18} style={{ cursor: 'pointer' }} />
            <AlertOctagon size={18} style={{ cursor: 'pointer' }} />
            <Mail size={18} style={{ cursor: 'pointer' }} />
          </div>
          <div style={{ flex: 1 }} />
          <div style={{ display: 'flex', gap: '8px', color: 'var(--text-secondary)' }}>
            <span style={{ fontSize: '13px', alignSelf: 'center' }}>1 of 286</span>
            <ChevronLeft size={18} style={{ cursor: 'pointer' }} />
            <ChevronRight size={18} style={{ cursor: 'pointer' }} />
          </div>
        </div>

        {/* Email Content */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '32px 48px', position: 'relative' }}>
          
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '24px' }}>
            <h2 style={{ fontSize: '22px', fontWeight: '400', color: 'var(--text-primary)', margin: 0 }}>
              {selectedMsg.subject}
              <span style={{ fontSize: '12px', background: 'rgba(0,0,0,0.05)', padding: '2px 6px', borderRadius: '4px', marginLeft: '12px', verticalAlign: 'middle', color: 'var(--text-secondary)' }}>Inbox</span>
            </h2>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '32px' }}>
            <div style={{ display: 'flex', gap: '12px' }}>
              <div style={{ width: '40px', height: '40px', borderRadius: '50%', background: '#3b82f6', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: '18px' }}>
                {selectedMsg.sender.charAt(0)}
              </div>
              <div>
                <div style={{ fontSize: '14px', fontWeight: '700', color: 'var(--text-primary)' }}>
                  {selectedMsg.sender} <span style={{ fontWeight: '400', color: '#6b7280' }}>&lt;secure@primecare.org&gt;</span>
                </div>
                <div style={{ fontSize: '12px', color: '#6b7280' }}>to me ▾</div>
              </div>
            </div>
            <div style={{ fontSize: '12px', color: '#6b7280', display: 'flex', alignItems: 'center', gap: '12px' }}>
              {selectedMsg.timestamp}
              <Star size={16} fill={selectedMsg.starred ? "#f59e0b" : "transparent"} color={selectedMsg.starred ? "#f59e0b" : "#9ca3af"} style={{ cursor: 'pointer' }} onClick={(e) => toggleStar(e, selectedMsg.id)}/>
            </div>
          </div>

          {actionToast && (
            <div className="animate-fade-in" style={{ background: 'rgba(16, 185, 129, 0.1)', border: '1px solid #10b981', color: '#059669', padding: '16px 20px', borderRadius: '8px', fontWeight: '600', fontSize: '14px', display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '24px' }}>
              <CheckCircle size={20} />
              <span>{actionToast}</span>
            </div>
          )}

          <div style={{ fontSize: '14px', color: 'var(--text-primary)', lineHeight: '1.6', whiteSpace: 'pre-wrap', maxWidth: '800px' }}>
            {selectedMsg.snippet.replace("- ", "")}
          </div>

          {/* AI Copilot Inline Trigger */}
          {selectedMsg.status === 'pending' && !copilotOpen && (
             <div style={{ marginTop: '48px', maxWidth: '800px' }}>
               <button 
                 className="animate-fade-in"
                 onClick={() => setCopilotOpen(true)}
                 style={{ 
                   background: 'linear-gradient(135deg, #a855f7, #6366f1)', color: 'white', border: 'none', 
                   padding: '12px 24px', borderRadius: '24px', fontSize: '14px', fontWeight: '600',
                   display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer',
                   boxShadow: '0 4px 15px rgba(168, 85, 247, 0.3)'
                 }}
               >
                 <Zap size={16} /> Launch AI Copilot Responses
               </button>
             </div>
          )}

          {/* Inline AI Copilot Panel */}
          {copilotOpen && (
            <div className="animate-fade-in" style={{ marginTop: '40px', maxWidth: '800px', background: 'var(--bg-secondary)', border: '1px solid #e5e7eb', borderRadius: '12px', padding: '24px', boxShadow: '0 10px 25px rgba(0,0,0,0.05)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#6366f1', fontWeight: '700', fontSize: '14px' }}>
                  <Zap size={18} /> AI Suggested Actions
                </div>
                <button onClick={() => setCopilotOpen(false)} style={{ background: 'none', border: 'none', color: '#9ca3af', cursor: 'pointer' }}>
                  <X size={18} />
                </button>
              </div>
              
              {processingAction ? (
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px', color: '#6366f1', gap: '10px', fontWeight: '600', fontSize: '14px' }}>
                    <Zap className="animate-spin" size={18} /> Executing Protocol & Securing Audit Trail...
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {selectedMsg.type === 'emergency' && (
                    <>
                      <button style={{ background: 'rgba(239, 68, 68, 0.1)', color: '#dc2626', border: 'none', padding: '14px', borderRadius: '8px', fontSize: '14px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '12px', cursor: 'pointer' }} onClick={() => handleCopilotAction("CCU Transfer Approved", true)}>
                        <ShieldAlert size={18} /> Approve CCU Transfer & Notify Dr. Smith
                      </button>
                      <button style={{ background: 'transparent', color: 'var(--text-secondary)', border: '1px solid #e5e7eb', padding: '14px', borderRadius: '8px', fontSize: '14px', fontWeight: '500', display: 'flex', alignItems: 'center', gap: '12px', cursor: 'pointer' }} onClick={() => handleCopilotAction("Requested Labs", false)}>
                        <FileText size={18} /> Request ECG & Labs Before Approval
                      </button>
                    </>
                  )}
                  {selectedMsg.type === 'rx' && (
                    <>
                      <button style={{ background: 'rgba(16, 185, 129, 0.1)', color: '#059669', border: 'none', padding: '14px', borderRadius: '8px', fontSize: '14px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '12px', cursor: 'pointer' }} onClick={() => handleCopilotAction("Refill Authorized", true)}>
                        <Pill size={18} /> E-Sign & Authorize 90-Day Metformin Refill
                      </button>
                      <button style={{ background: 'transparent', color: 'var(--text-secondary)', border: '1px solid #e5e7eb', padding: '14px', borderRadius: '8px', fontSize: '14px', fontWeight: '500', display: 'flex', alignItems: 'center', gap: '12px', cursor: 'pointer' }} onClick={() => handleCopilotAction("Refill Denied", false)}>
                        <Phone size={18} /> Deny Refill & Request Patient Visit
                      </button>
                    </>
                  )}
                  {selectedMsg.type === 'discharge' && (
                    <>
                      <button style={{ background: 'rgba(59, 130, 246, 0.1)', color: '#2563eb', border: 'none', padding: '14px', borderRadius: '8px', fontSize: '14px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '12px', cursor: 'pointer' }} onClick={() => handleCopilotAction("1-Week Follow-Up Scheduled", true)}>
                        <Stethoscope size={18} /> Book 1-Week Follow-Up & Save to Chart
                      </button>
                    </>
                  )}
                </div>
              )}
            </div>
          )}

        </div>
      </div>
    );
  }

  // Full-width List View
  return (
    <div style={{ display: 'flex', height: '100%', background: 'var(--bg-secondary)', borderRadius: '16px', overflow: 'hidden' }}>
      
      {/* Sidebar Folders */}
      <div style={{ width: '220px', borderRight: '1px solid rgba(0,0,0,0.05)', padding: '24px 16px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
         <button onClick={() => setActiveFolder('inbox')} style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '10px 16px', borderRadius: '8px', border: 'none', background: activeFolder === 'inbox' ? 'rgba(59, 130, 246, 0.15)' : 'transparent', color: activeFolder === 'inbox' ? '#2563eb' : 'var(--text-secondary)', cursor: 'pointer', fontWeight: activeFolder === 'inbox' ? '600' : '500', fontSize: '14px', textAlign: 'left' }}> 
           <Inbox size={18} /> Inbox
         </button>
         <button onClick={() => setActiveFolder('unread')} style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '10px 16px', borderRadius: '8px', border: 'none', background: activeFolder === 'unread' ? 'rgba(59, 130, 246, 0.15)' : 'transparent', color: activeFolder === 'unread' ? '#2563eb' : 'var(--text-secondary)', cursor: 'pointer', fontWeight: activeFolder === 'unread' ? '600' : '500', fontSize: '14px', textAlign: 'left' }}> 
           <AlertOctagon size={18} /> Unread
         </button>
         <button onClick={() => setActiveFolder('starred')} style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '10px 16px', borderRadius: '8px', border: 'none', background: activeFolder === 'starred' ? 'rgba(245, 158, 11, 0.15)' : 'transparent', color: activeFolder === 'starred' ? '#d97706' : 'var(--text-secondary)', cursor: 'pointer', fontWeight: activeFolder === 'starred' ? '600' : '500', fontSize: '14px', textAlign: 'left' }}> 
           <Star size={18} /> Starred
         </button>
         <button onClick={() => setActiveFolder('resolved')} style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '10px 16px', borderRadius: '8px', border: 'none', background: activeFolder === 'resolved' ? 'rgba(16, 185, 129, 0.15)' : 'transparent', color: activeFolder === 'resolved' ? '#059669' : 'var(--text-secondary)', cursor: 'pointer', fontWeight: activeFolder === 'resolved' ? '600' : '500', fontSize: '14px', textAlign: 'left' }}> 
           <CheckCircle size={18} /> Resolved
         </button>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', flex: 1, overflow: 'hidden' }}>
      {/* Top Search Bar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '16px', padding: '16px 24px', borderBottom: '1px solid rgba(0,0,0,0.05)' }}>
        <div style={{ flex: 1, maxWidth: '700px', display: 'flex', alignItems: 'center', background: 'var(--bg-tertiary)', borderRadius: '24px', padding: '8px 16px', boxShadow: '0 2px 5px rgba(0,0,0,0.05)', border: '1px solid rgba(0,0,0,0.05)' }}>
          <Search size={20} color="#9ca3af" />
          <input 
            type="text" 
            placeholder="Search all clinical emails" 
            style={{ border: 'none', background: 'transparent', width: '100%', outline: 'none', padding: '0 12px', fontSize: '15px', color: 'var(--text-primary)' }}
            defaultValue="in:inbox"
          />
          <SlidersHorizontal size={20} color="#9ca3af" style={{ cursor: 'pointer' }} />
        </div>
        <div style={{ flex: 1 }} />
        <Settings size={20} color="#6b7280" style={{ cursor: 'pointer' }} />
      </div>

      {/* Filter Chips */}
      <div style={{ position: 'relative', zIndex: 50, padding: '12px 24px', borderBottom: '1px solid rgba(0,0,0,0.05)' }}>
        <div style={{ display: 'flex', gap: '10px' }}>
          {["Any time", "Has attachment", "To", "Advanced search"].map(chip => (
            <button 
              key={chip} 
              onClick={() => setActiveFilter(prev => prev === chip ? null : chip)}
              style={{ 
                background: activeFilter === chip ? 'rgba(59, 130, 246, 0.2)' : 'var(--bg-secondary)', 
                border: '1px solid #e5e7eb', 
                borderColor: activeFilter === chip ? '#3b82f6' : '#e5e7eb',
                borderRadius: '16px', 
                padding: '6px 12px', 
                fontSize: '13px', 
                color: activeFilter === chip ? '#3b82f6' : 'var(--text-primary)', 
                cursor: 'pointer', 
                display: 'flex', 
                alignItems: 'center', 
                gap: '4px',
                fontWeight: activeFilter === chip ? '600' : '400',
                transition: 'all 0.2s'
              }}
            >
              {chip} {chip !== "Advanced search" && <span style={{ fontSize: '10px' }}>▼</span>}
            </button>
          ))}
        </div>

        {/* Dropdown menus for the tabs */}
        {activeFilter === 'Any time' && (
          <div style={{ position: 'absolute', top: '100%', left: '24px', zIndex: 9999, padding: '16px', minWidth: '150px', display: 'flex', flexDirection: 'column', gap: '8px', background: 'var(--bg-secondary)', borderRadius: '8px', border: '1px solid rgba(0,0,0,0.1)', boxShadow: '0 4px 15px rgba(0,0,0,0.1)' }}>
            {['Any time', 'Older than a week', 'Older than a month'].map(opt => (
              <button key={opt} onClick={() => { setFilterTime(opt === 'Any time' ? null : opt); setActiveFilter(null); }} style={{ textAlign: 'left', padding: '8px 12px', background: filterTime === opt ? 'rgba(59, 130, 246, 0.1)' : 'transparent', border: 'none', color: 'var(--text-primary)', fontSize: '13px', cursor: 'pointer', borderRadius: '6px', fontWeight: filterTime === opt ? '600' : '400' }}>{opt}</button>
            ))}
          </div>
        )}
        
        {activeFilter === 'To' && (
          <div style={{ position: 'absolute', top: '100%', left: '160px', zIndex: 9999, padding: '16px', minWidth: '220px', display: 'flex', flexDirection: 'column', gap: '8px', background: 'var(--bg-secondary)', borderRadius: '8px', border: '1px solid rgba(0,0,0,0.1)', boxShadow: '0 4px 15px rgba(0,0,0,0.1)' }}>
            <input type="text" placeholder="Search contacts..." style={{ padding: '8px', borderRadius: '6px', border: '1px solid rgba(0,0,0,0.1)', background: 'var(--bg-tertiary)', color: 'var(--text-primary)', outline: 'none' }} autoFocus />
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', marginTop: '4px' }}>
              {['All senders', 'Cardiology Dept', 'Neurology', 'Dr. Smith', 'Pharmacy'].map(opt => (
                <button key={opt} onClick={() => { setFilterTo(opt === 'All senders' ? null : opt); setActiveFilter(null); }} style={{ textAlign: 'left', padding: '6px 8px', background: filterTo === opt ? 'rgba(59, 130, 246, 0.1)' : 'transparent', border: 'none', color: 'var(--text-primary)', fontSize: '13px', cursor: 'pointer', borderRadius: '6px', fontWeight: filterTo === opt ? '600' : '400' }}>{opt}</button>
              ))}
            </div>
          </div>
        )}

        {activeFilter === 'Advanced search' && (
          <div style={{ position: 'absolute', top: '100%', right: '24px', zIndex: 9999, padding: '16px', width: '300px', display: 'flex', flexDirection: 'column', gap: '12px', background: '#10b981', borderRadius: '8px', border: '2px solid white' }}>
            <div style={{ fontWeight: '600', color: 'white', marginBottom: '4px' }}>Advanced Search</div>
            <input type="text" placeholder="From" style={{ padding: '8px', borderRadius: '6px', border: 'none', background: 'white', color: 'black' }} />
            <input type="text" placeholder="Subject" style={{ padding: '8px', borderRadius: '6px', border: 'none', background: 'white', color: 'black' }} />
            <div style={{ display: 'flex', gap: '8px', marginTop: '8px' }}>
              <button onClick={() => setActiveFilter(null)} style={{ flex: 1, padding: '8px', background: 'white', color: 'black', border: 'none', cursor: 'pointer', borderRadius: '6px' }}>Cancel</button>
              <button onClick={() => setActiveFilter(null)} style={{ flex: 1, padding: '8px', background: 'black', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer', fontWeight: '600' }}>Search</button>
            </div>
          </div>
        )}
      </div>

      {/* Toolbar */}
      <div style={{ display: 'flex', alignItems: 'center', padding: '8px 24px', borderBottom: '1px solid rgba(0,0,0,0.05)' }}>
        <Square size={18} color="#9ca3af" style={{ cursor: 'pointer', marginRight: '16px' }} />
        <RefreshCw size={16} color="#6b7280" style={{ cursor: 'pointer', marginRight: '16px' }} />
        <MoreVertical size={16} color="#6b7280" style={{ cursor: 'pointer' }} />
        <div style={{ flex: 1 }} />
        <div style={{ fontSize: '12px', color: '#6b7280', display: 'flex', alignItems: 'center', gap: '8px' }}>
          1-25 of 286
          <ChevronLeft size={16} style={{ cursor: 'pointer' }} />
          <ChevronRight size={16} style={{ cursor: 'pointer' }} />
        </div>
      </div>

      {/* Inbox List */}
      <div style={{ flex: 1, overflowY: 'auto' }}>
        {messages.filter(m => {
          // Folder filtering
          if (activeFolder === 'unread' && !m.isUnread) return false;
          if (activeFolder === 'starred' && !m.starred) return false;
          if (activeFolder === 'resolved' && m.status === 'pending') return false;
          if (activeFolder === 'inbox' && m.status !== 'pending') return false;

          // Chip filtering
          if (activeFilter === 'Has attachment' && !m.hasAttachment) return false;
          
          if (filterTo === 'Cardiology Dept' && !m.sender.includes('Cardiology')) return false;
          if (filterTo === 'Dr. Smith' && !m.sender.includes('Dr. James Smith')) return false;
          if (filterTo === 'Neurology' && !m.sender.includes('Neurology')) return false;
          if (filterTo === 'Pharmacy' && !m.sender.includes('Drug Mart')) return false;
          
          if (filterTime === 'Older than a week' && (m.timestamp.includes('AM') || m.timestamp.includes('Yesterday'))) return false;
          if (filterTime === 'Older than a month' && !m.timestamp.includes('May')) return false;

          return true;
        }).map((msg) => {
          const isSelected = selectedIds.includes(msg.id);
          return (
            <div 
              key={msg.id}
              style={{ 
                display: 'flex', alignItems: 'center', padding: '10px 24px', 
                background: isSelected ? 'rgba(191, 219, 254, 0.4)' : msg.isUnread ? 'var(--bg-tertiary)' : 'transparent',
                borderBottom: '1px solid rgba(0,0,0,0.03)',
                cursor: 'pointer',
                transition: 'box-shadow 0.1s',
                fontWeight: msg.isUnread ? '700' : '400',
                color: msg.isUnread ? 'var(--text-primary)' : 'var(--text-secondary)'
              }}
              onMouseOver={e => e.currentTarget.style.boxShadow = 'inset 1px 0 0 #d1d5db, inset -1px 0 0 #d1d5db, 0 1px 2px 0 rgba(60,64,67,.3), 0 1px 3px 1px rgba(60,64,67,.15)'}
              onMouseOut={e => e.currentTarget.style.boxShadow = 'none'}
              onClick={() => handleSelectMessage(msg)}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginRight: '16px', minWidth: '60px' }}>
                <span onClick={(e) => toggleSelect(e, msg.id)}>
                  {isSelected ? <CheckSquare size={18} color="#1d4ed8" /> : <Square size={18} color="#9ca3af" />}
                </span>
                <Star size={18} fill={msg.starred ? "#f59e0b" : "transparent"} color={msg.starred ? "#f59e0b" : "#9ca3af"} onClick={(e) => toggleStar(e, msg.id)} />
              </div>
              
              <div style={{ minWidth: '220px', maxWidth: '220px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'flex', alignItems: 'center', gap: '8px' }}>
                {msg.status !== 'pending' && <span style={{ fontSize: '10px', background: 'rgba(16, 185, 129, 0.1)', color: '#059669', padding: '2px 6px', borderRadius: '10px' }}>Resolved</span>}
                {msg.sender}
              </div>

              <div style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', paddingRight: '16px' }}>
                <span>{msg.subject}</span>
                <span style={{ color: 'var(--text-secondary)', fontWeight: '400', marginLeft: '8px' }}>
                  {msg.snippet}
                </span>
              </div>

              {msg.hasAttachment && <Paperclip size={16} color="#9ca3af" style={{ marginRight: '16px' }} />}
              
              <div style={{ minWidth: '60px', textAlign: 'right', fontSize: '12px', fontWeight: msg.isUnread ? '700' : '500' }}>
                {msg.timestamp}
              </div>
            </div>
          );
        })}
      </div>
      </div>
    </div>
  );
}
