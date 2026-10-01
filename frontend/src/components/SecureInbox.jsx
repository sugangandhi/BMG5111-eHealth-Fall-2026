import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { 
  Search, SlidersHorizontal, Settings, ChevronLeft, ChevronRight, 
  MoreVertical, RefreshCw, Archive, AlertOctagon, Mail, 
  Paperclip, Star, Square, CheckSquare, ShieldAlert, Zap, X, CheckCircle, CheckCircle2,
  FileText, Pill, Phone, Stethoscope, Inbox, MessageCircle, ExternalLink, Activity
} from 'lucide-react';

const MOCK_MESSAGES = [
  {
    id: 101,
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
    id: 102,
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
    id: 103,
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
    id: 104,
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
    id: 105,
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
  const [selectedMsg, setSelectedMsg] = useState(null);
  const [actionToast, setActionToast] = useState(null);
  const [copilotOpen, setCopilotOpen] = useState(false);
  const [processingAction, setProcessingAction] = useState(false);
  const [selectedIds, setSelectedIds] = useState([]);
  const [activeFilter, setActiveFilter] = useState(null);
  const [activeFolder, setActiveFolder] = useState('inbox');
  const [filterTime, setFilterTime] = useState(null);
  const [filterTo, setFilterTo] = useState(null);

  const activeUser = JSON.parse(localStorage.getItem('medoffice_user') || '{}');
  const doctorName = activeUser.name || 'the attending physician';

  // Load all messages from backend store
  const fetchAllMessages = async () => {
    try {
      const res = await axios.get('/api/inbox/messages');
      if (res.data && res.data.messages && res.data.messages.length > 0) {
        const draftEmails = JSON.parse(localStorage.getItem('drafted_emails') || '[]');
        setMessages([...draftEmails, ...res.data.messages]);
      }
    } catch (err) {
      console.log("[SecureInbox] Backend load note, using local fallback:", err);
    }
  };

  useEffect(() => {
    fetchAllMessages();

    // Real-time polling for inbound WhatsApp consults & live dispatches
    const pollInterval = setInterval(async () => {
      try {
        const res = await axios.get('/api/inbox/sync');
        if (res.data && res.data.messages && res.data.messages.length > 0) {
          const incoming = res.data.messages;
          setMessages(prev => {
            const incomingIds = new Set(incoming.map(m => m.id));
            const existing = prev.filter(p => !incomingIds.has(p.id));
            return [...incoming, ...existing];
          });
          if (triggerNotification) {
            triggerNotification('inbox');
          }
        }
      } catch (err) {
        // Polling silent catch
      }
    }, 3500);

    return () => clearInterval(pollInterval);
  }, [triggerNotification]);

  useEffect(() => {
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

  // Continue exact patient conversation directly on WhatsApp
  const handleContinueWhatsApp = async (msg) => {
    const rawPhone = msg.patient_phone || msg.clean_phone || '6135550192';
    const digits = rawPhone.replace(/\D/g, '') || '16135550192';
    const cleanNumber = digits.length === 10 ? `1${digits}` : digits;

    const activeUser = JSON.parse(localStorage.getItem('medoffice_user') || '{}');
    const doctorName = activeUser.name || 'your attending physician';
    const pName = msg.patient_name || msg.sender.replace(' (via WhatsApp)', '') || 'there';
    const first = pName.split(' ')[0] || 'there';
    const textPrompt = `Hello ${first}, this is ${doctorName} following up directly on your message on WhatsApp. How are you feeling now?`;

    const waUrl = `https://wa.me/${cleanNumber}?text=${encodeURIComponent(textPrompt)}`;
    window.open(waUrl, '_blank');

    // Update status in backend & log audit trail
    try {
      await axios.post('/api/inbox/status', {
        message_id: msg.id,
        status: 'Doctor Responded on WhatsApp'
      });

      const token = localStorage.getItem('medoffice_token') || 'demo-token';
      await axios.post('/api/activity/log', {
        action: "whatsapp_doctor_replied",
        description: `${doctorName} resumed WhatsApp encounter with ${pName}`,
        patient_name: pName,
        detail: `Direct WhatsApp conversation opened with ${pName} (+${cleanNumber}). Clinical status: Doctor Responded.`,
        color: "emerald"
      }, { headers: { Authorization: `Bearer ${token}` } });
    } catch (err) {
      console.log("[SecureInbox] Status update note:", err);
    }

    setMessages(prev => prev.map(m => m.id === msg.id ? { ...m, status: 'Doctor Responded on WhatsApp', isUnread: false } : m));
    setSelectedMsg(prev => prev ? { ...prev, status: 'Doctor Responded on WhatsApp', isUnread: false } : null);
    setActionToast(`💬 Successfully opened WhatsApp chat with ${pName}. Audit log recorded.`);
  };

  const handleCopilotAction = async (actionName, triggerDashUpdate = false) => {
    setProcessingAction(true);
    
    if (triggerDashUpdate) {
      try {
        const token = localStorage.getItem('medoffice_token') || 'demo-token';
        await axios.post('/api/activity/log', {
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
    }, 1200);
  };

  if (selectedMsg) {
    return (
      <div className="inbox-detail-view" style={{ display: 'flex', flexDirection: 'column', height: '100%', borderRadius: '16px', overflow: 'hidden', background: 'var(--bg-secondary)' }}>
        {/* Detail View Toolbar */}
        <div style={{ display: 'flex', alignItems: 'center', padding: '12px 16px', borderBottom: '1px solid var(--border)' }}>
          <button onClick={() => setSelectedMsg(null)} style={{ background: 'transparent', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', color: 'var(--text-secondary)', padding: '8px', borderRadius: '50%' }} onMouseOver={e=>e.currentTarget.style.background='rgba(0,0,0,0.05)'} onMouseOut={e=>e.currentTarget.style.background='transparent'}>
            <ChevronLeft size={20} />
          </button>
          <div style={{ width: '12px' }} />
          <div style={{ display: 'flex', gap: '14px', color: 'var(--text-secondary)' }}>
            <Archive size={18} style={{ cursor: 'pointer' }} />
            <AlertOctagon size={18} style={{ cursor: 'pointer' }} />
            <Mail size={18} style={{ cursor: 'pointer' }} />
          </div>
          <div style={{ flex: 1 }} />
          <div style={{ display: 'flex', gap: '8px', color: 'var(--text-secondary)' }}>
            <span style={{ fontSize: '12px', alignSelf: 'center' }}>Message {selectedMsg.id}</span>
          </div>
        </div>

        {/* Message Content */}
        <div className="inbox-detail-body" style={{ flex: 1, overflowY: 'auto', padding: '24px 28px', position: 'relative' }}>
          
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '24px' }}>
            <h2 style={{ fontSize: '22px', fontWeight: '600', color: 'var(--text-primary)', margin: 0, display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap' }}>
              {selectedMsg.subject}
              {selectedMsg.type === 'whatsapp' ? (
                <span style={{ fontSize: '12px', background: 'rgba(37, 211, 102, 0.15)', color: '#25D366', border: '1px solid rgba(37, 211, 102, 0.3)', padding: '3px 10px', borderRadius: '12px', fontWeight: '700' }}>
                  WhatsApp Patient Consult
                </span>
              ) : (
                <span style={{ fontSize: '12px', background: 'rgba(0,0,0,0.05)', padding: '2px 6px', borderRadius: '4px', verticalAlign: 'middle', color: 'var(--text-secondary)' }}>Inbox</span>
              )}
            </h2>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '24px' }}>
            <div style={{ display: 'flex', gap: '12px' }}>
              <div style={{ 
                width: '42px', height: '42px', borderRadius: '50%', 
                background: selectedMsg.type === 'whatsapp' ? '#25D366' : '#3b82f6', 
                color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: '18px',
                boxShadow: selectedMsg.type === 'whatsapp' ? '0 4px 12px rgba(37, 211, 102, 0.3)' : 'none'
              }}>
                {selectedMsg.type === 'whatsapp' ? <MessageCircle size={22} /> : selectedMsg.sender.charAt(0)}
              </div>
              <div>
                <div style={{ fontSize: '14px', fontWeight: '700', color: 'var(--text-primary)' }}>
                  {selectedMsg.sender} {selectedMsg.patient_phone && <span style={{ fontWeight: '500', color: '#10b981', marginLeft: '6px' }}>({selectedMsg.patient_phone})</span>}
                </div>
                <div style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                  {selectedMsg.type === 'whatsapp' ? 'Inbound WhatsApp Business Channel • Verified Patient' : `to ${doctorName} ▾`}
                </div>
              </div>
            </div>
            <div style={{ fontSize: '12px', color: '#6b7280', display: 'flex', alignItems: 'center', gap: '12px' }}>
              {selectedMsg.timestamp}
              <Star size={16} fill={selectedMsg.starred ? "#f59e0b" : "transparent"} color={selectedMsg.starred ? "#f59e0b" : "#9ca3af"} style={{ cursor: 'pointer' }} onClick={(e) => toggleStar(e, selectedMsg.id)}/>
            </div>
          </div>

          {actionToast && (
            <div className="animate-fade-in" style={{ background: 'rgba(16, 185, 129, 0.12)', border: '1px solid #10b981', color: '#059669', padding: '14px 18px', borderRadius: '10px', fontWeight: '600', fontSize: '14px', display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '24px' }}>
              <CheckCircle size={20} />
              <span>{actionToast}</span>
            </div>
          )}

          {/* 🟢 SPECIAL WHATSAPP PATIENT ENCOUNTER CARD */}
          {selectedMsg.type === 'whatsapp' && (
            <div className="animate-fade-in" style={{ 
              background: 'linear-gradient(135deg, rgba(37, 211, 102, 0.1), rgba(18, 140, 126, 0.05))', 
              border: '1px solid rgba(37, 211, 102, 0.35)', 
              borderRadius: '16px', 
              padding: '22px', 
              marginBottom: '28px',
              boxShadow: '0 8px 24px rgba(37, 211, 102, 0.08)'
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px', flexWrap: 'wrap', gap: '8px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <div style={{ background: '#25D366', color: 'white', padding: '6px', borderRadius: '8px', display: 'flex' }}>
                    <MessageCircle size={18} />
                  </div>
                  <div>
                    <span style={{ fontWeight: '700', fontSize: '15px', color: 'var(--text-primary)' }}>
                      Inbound WhatsApp Clinical Consultation
                    </span>
                    <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                      Automated e-Hospital Bot Triage · Synced to Central Clinical EMR
                    </div>
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                  <span style={{ 
                    fontSize: '11px', 
                    padding: '4px 10px', 
                    borderRadius: '20px', 
                    background: selectedMsg.status.includes('Responded') ? 'rgba(16, 185, 129, 0.2)' : 'rgba(239, 68, 68, 0.2)', 
                    color: selectedMsg.status.includes('Responded') ? '#10b981' : '#ef4444', 
                    fontWeight: '700' 
                  }}>
                    {selectedMsg.status.includes('Responded') ? '✅ DOCTOR RESPONDED' : '🚨 STAT REVIEW NEEDED'}
                  </span>
                </div>
              </div>

              {/* Bot status alert */}
              <div style={{ background: 'var(--bg-tertiary)', padding: '12px 14px', borderRadius: '10px', marginBottom: '16px', fontSize: '13px', color: 'var(--text-primary)', borderLeft: '4px solid #25D366' }}>
                <strong>🤖 Automated Bot Reply Sent to Patient:</strong>
                <p style={{ margin: '4px 0 0 0', color: 'var(--text-secondary)', fontStyle: 'italic', fontSize: '12.5px' }}>
                  {`"I have recorded your message and connected you directly to ${doctorName}. The doctor has your chart and will reply to you on this WhatsApp chat shortly."`}
                </p>
              </div>

              {/* Extracted Vitals chips if present */}
              {selectedMsg.vitals && Object.keys(selectedMsg.vitals).length > 0 && (
                <div style={{ marginBottom: '18px' }}>
                  <div style={{ fontSize: '12px', fontWeight: '700', color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '8px' }}>
                    🩺 Extracted Patient Vitals (Auto-logged into Chart):
                  </div>
                  <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                    {selectedMsg.vitals.bp && (
                      <div style={{ background: 'rgba(239, 68, 68, 0.12)', border: '1px solid rgba(239, 68, 68, 0.3)', padding: '6px 14px', borderRadius: '8px', fontSize: '13px', fontWeight: '700', color: '#ef4444' }}>
                        Blood Pressure: {selectedMsg.vitals.bp} mmHg
                      </div>
                    )}
                    {selectedMsg.vitals.hr && (
                      <div style={{ background: 'rgba(59, 130, 246, 0.12)', border: '1px solid rgba(59, 130, 246, 0.3)', padding: '6px 14px', borderRadius: '8px', fontSize: '13px', fontWeight: '700', color: '#3b82f6' }}>
                        Heart Rate: {selectedMsg.vitals.hr} bpm
                      </div>
                    )}
                    {selectedMsg.vitals.glucose && (
                      <div style={{ background: 'rgba(245, 158, 11, 0.12)', border: '1px solid rgba(245, 158, 11, 0.3)', padding: '6px 14px', borderRadius: '8px', fontSize: '13px', fontWeight: '700', color: '#f59e0b' }}>
                        Glucose: {selectedMsg.vitals.glucose} mmol/L
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* 1-Tap Action Button: Continue Exact Chat on WhatsApp */}
              <div style={{ display: 'flex', gap: '14px', alignItems: 'center', flexWrap: 'wrap', paddingTop: '4px' }}>
                <button
                  type="button"
                  onClick={() => handleContinueWhatsApp(selectedMsg)}
                  style={{
                    background: 'linear-gradient(135deg, #25D366, #128C7E)',
                    color: 'white',
                    border: 'none',
                    padding: '12px 24px',
                    borderRadius: '12px',
                    fontSize: '14px',
                    fontWeight: '700',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px',
                    cursor: 'pointer',
                    boxShadow: '0 6px 18px rgba(37, 211, 102, 0.35)',
                    transition: 'transform 0.15s, box-shadow 0.15s'
                  }}
                  onMouseOver={(e) => e.currentTarget.style.transform = 'translateY(-1px)'}
                  onMouseOut={(e) => e.currentTarget.style.transform = 'translateY(0)'}
                >
                  <MessageCircle size={19} />
                  <span>Continue Chat on WhatsApp</span>
                  <ExternalLink size={16} />
                </button>

                <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                  {`Opens patient's exact WhatsApp thread with ${doctorName}'s follow-up prompt`}
                </span>
              </div>
            </div>
          )}

          {/* Full Message Body */}
          <div style={{ fontSize: '14px', color: 'var(--text-primary)', lineHeight: '1.7', whiteSpace: 'pre-wrap', maxWidth: '820px' }}>
            {selectedMsg.body ? selectedMsg.body : selectedMsg.snippet.replace("- ", "")}
          </div>

          {/* AI Copilot Inline Trigger for Emergency/Rx/Discharge messages */}
          {selectedMsg.type !== 'whatsapp' && selectedMsg.status === 'pending' && !copilotOpen && (
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
    <div className="inbox-main-container" style={{ display: 'flex', height: '100%', background: 'var(--bg-secondary)', borderRadius: '16px', overflow: 'hidden' }}>
      
      {/* Sidebar Folders (Desktop) */}
      <div className="desktop-only inbox-folder-sidebar" style={{ width: '220px', borderRight: '1px solid var(--border)', padding: '24px 16px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
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

      <div style={{ display: 'flex', flexDirection: 'column', flex: 1, minWidth: 0, overflow: 'hidden' }}>
        {/* Mobile Horizontal Folder Pills */}
        <div className="mobile-only inbox-mobile-folder-tabs" style={{ display: 'flex', gap: '8px', padding: '12px 14px', borderBottom: '1px solid var(--border)', overflowX: 'auto', background: 'var(--bg-secondary)', flexShrink: 0 }}>
          <button onClick={() => setActiveFolder('inbox')} style={{ padding: '6px 14px', borderRadius: '20px', border: 'none', background: activeFolder === 'inbox' ? 'var(--primary)' : 'var(--bg-tertiary)', color: activeFolder === 'inbox' ? '#fff' : 'var(--text-secondary)', fontSize: '12px', fontWeight: '700', whiteSpace: 'nowrap', display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Inbox size={14} /> Inbox
          </button>
          <button onClick={() => setActiveFolder('unread')} style={{ padding: '6px 14px', borderRadius: '20px', border: 'none', background: activeFolder === 'unread' ? 'var(--primary)' : 'var(--bg-tertiary)', color: activeFolder === 'unread' ? '#fff' : 'var(--text-secondary)', fontSize: '12px', fontWeight: '700', whiteSpace: 'nowrap', display: 'flex', alignItems: 'center', gap: '6px' }}>
            <AlertOctagon size={14} /> Unread
          </button>
          <button onClick={() => setActiveFolder('starred')} style={{ padding: '6px 14px', borderRadius: '20px', border: 'none', background: activeFolder === 'starred' ? '#d97706' : 'var(--bg-tertiary)', color: activeFolder === 'starred' ? '#fff' : 'var(--text-secondary)', fontSize: '12px', fontWeight: '700', whiteSpace: 'nowrap', display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Star size={14} /> Starred
          </button>
          <button onClick={() => setActiveFolder('resolved')} style={{ padding: '6px 14px', borderRadius: '20px', border: 'none', background: activeFolder === 'resolved' ? '#059669' : 'var(--bg-tertiary)', color: activeFolder === 'resolved' ? '#fff' : 'var(--text-secondary)', fontSize: '12px', fontWeight: '700', whiteSpace: 'nowrap', display: 'flex', alignItems: 'center', gap: '6px' }}>
            <CheckCircle size={14} /> Resolved
          </button>
        </div>

        {/* Top Search Bar */}
        <div className="inbox-search-bar" style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '12px 16px', borderBottom: '1px solid var(--border)' }}>
          <div style={{ flex: 1, maxWidth: '700px', display: 'flex', alignItems: 'center', background: 'var(--bg-tertiary)', borderRadius: '24px', padding: '8px 14px', boxShadow: '0 2px 5px rgba(0,0,0,0.05)', border: '1px solid var(--border)' }}>
            <Search size={18} color="#9ca3af" />
            <input 
              type="text" 
              placeholder="Search clinical emails & WhatsApp consults..." 
              style={{ border: 'none', background: 'transparent', width: '100%', outline: 'none', padding: '0 10px', fontSize: '14px', color: 'var(--text-primary)' }}
              defaultValue="in:inbox"
            />
            <SlidersHorizontal size={18} color="#9ca3af" style={{ cursor: 'pointer' }} />
          </div>
          <div style={{ flex: 1 }} className="desktop-only" />
          <Settings size={18} color="#6b7280" style={{ cursor: 'pointer' }} />
        </div>

        {/* Filter Chips */}
        <div className="inbox-chips-bar" style={{ position: 'relative', zIndex: 50, padding: '10px 16px', borderBottom: '1px solid var(--border)', overflowX: 'auto', WebkitOverflowScrolling: 'touch' }}>
        <div style={{ display: 'flex', gap: '10px' }}>
          {["Any time", "WhatsApp Consults", "Has attachment", "Advanced search"].map(chip => (
            <button 
              key={chip} 
              onClick={() => setActiveFilter(activeFilter === chip ? null : chip)}
              style={{
                display: 'flex', alignItems: 'center', gap: '6px', padding: '6px 14px', borderRadius: '16px',
                border: activeFilter === chip ? '1px solid #3b82f6' : '1px solid var(--border)',
                background: activeFilter === chip ? 'rgba(59, 130, 246, 0.15)' : 'var(--bg-secondary)',
                color: activeFilter === chip ? '#2563eb' : 'var(--text-primary)',
                cursor: 'pointer', fontSize: '13px', fontWeight: '500', whiteSpace: 'nowrap'
              }}
            >
              {chip === "WhatsApp Consults" && <MessageCircle size={14} color="#25D366" />}
              {chip}
            </button>
          ))}
        </div>
      </div>

      {/* Toolbar */}
      <div style={{ display: 'flex', alignItems: 'center', padding: '8px 24px', borderBottom: '1px solid rgba(0,0,0,0.05)' }}>
        <Square size={18} color="#9ca3af" style={{ cursor: 'pointer', marginRight: '16px' }} />
        <RefreshCw size={16} color="#6b7280" style={{ cursor: 'pointer', marginRight: '16px' }} onClick={fetchAllMessages} title="Refresh Messages" />
        <MoreVertical size={16} color="#6b7280" style={{ cursor: 'pointer' }} />
        <div style={{ flex: 1 }} />
        <div style={{ fontSize: '12px', color: '#6b7280', display: 'flex', alignItems: 'center', gap: '8px' }}>
          {messages.length} Total Messages
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
          if (activeFilter === 'WhatsApp Consults' && m.type !== 'whatsapp') return false;
          if (activeFilter === 'Has attachment' && !m.hasAttachment) return false;

          return true;
        }).map((msg) => {
          const isSelected = selectedIds.includes(msg.id);
          const isWhatsApp = msg.type === 'whatsapp';
          const isReplied = msg.status && msg.status.includes('Doctor Responded');

          return (
            <div 
              key={msg.id}
              className="inbox-msg-row"
              style={{ 
                padding: '12px 16px', 
                background: isSelected ? 'rgba(191, 219, 254, 0.4)' : msg.isUnread ? (isWhatsApp ? 'rgba(37, 211, 102, 0.06)' : 'var(--bg-tertiary)') : 'transparent',
                borderBottom: '1px solid var(--border)',
                borderLeft: isWhatsApp ? '4px solid #25D366' : '4px solid transparent',
                cursor: 'pointer',
                transition: 'background 0.15s ease',
                fontWeight: msg.isUnread ? '700' : '400',
                color: msg.isUnread ? 'var(--text-primary)' : 'var(--text-secondary)'
              }}
              onClick={() => handleSelectMessage(msg)}
            >
              {/* Desktop layout row */}
              <div className="desktop-only" style={{ display: 'flex', alignItems: 'center', width: '100%' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginRight: '16px', minWidth: '60px' }}>
                  <span onClick={(e) => toggleSelect(e, msg.id)}>
                    {isSelected ? <CheckSquare size={18} color="#1d4ed8" /> : <Square size={18} color="#9ca3af" />}
                  </span>
                  <Star size={18} fill={msg.starred ? "#f59e0b" : "transparent"} color={msg.starred ? "#f59e0b" : "#9ca3af"} onClick={(e) => toggleStar(e, msg.id)} />
                </div>
                
                <div style={{ minWidth: '220px', maxWidth: '220px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  {isWhatsApp ? (
                    <span style={{ 
                      fontSize: '10px', 
                      background: isReplied ? 'rgba(16, 185, 129, 0.15)' : 'rgba(37, 211, 102, 0.2)', 
                      color: isReplied ? '#10b981' : '#25D366', 
                      padding: '2px 8px', borderRadius: '10px', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '4px' 
                    }}>
                      <MessageCircle size={10} /> {isReplied ? 'Replied' : 'WhatsApp'}
                    </span>
                  ) : (
                    msg.status !== 'pending' && <span style={{ fontSize: '10px', background: 'rgba(16, 185, 129, 0.1)', color: '#059669', padding: '2px 6px', borderRadius: '10px' }}>Resolved</span>
                  )}
                  <span style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>{msg.sender}</span>
                </div>

                <div style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', paddingRight: '16px' }}>
                  <span>{msg.subject}</span>
                  <span style={{ color: 'var(--text-secondary)', fontWeight: '400', marginLeft: '8px' }}>
                    {msg.snippet}
                  </span>
                </div>

                {isWhatsApp && (
                  <button 
                    onClick={(e) => { e.stopPropagation(); handleContinueWhatsApp(msg); }}
                    style={{
                      marginRight: '12px', background: 'rgba(37, 211, 102, 0.12)', border: '1px solid rgba(37, 211, 102, 0.3)',
                      color: '#25D366', borderRadius: '6px', padding: '4px 8px', fontSize: '11px', fontWeight: '700',
                      cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px'
                    }}
                    title="Open directly in WhatsApp"
                  >
                    <MessageCircle size={13} /> Chat
                  </button>
                )}

                {msg.hasAttachment && <Paperclip size={16} color="#9ca3af" style={{ marginRight: '16px' }} />}
                
                <div style={{ minWidth: '80px', textAlign: 'right', fontSize: '12px', fontWeight: msg.isUnread ? '700' : '500' }}>
                  {msg.timestamp}
                </div>
              </div>

              {/* Mobile Native Card Layout */}
              <div className="mobile-only" style={{ display: 'flex', flexDirection: 'column', gap: '5px', width: '100%' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', width: '100%' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', overflow: 'hidden' }}>
                    <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: msg.isUnread ? (isWhatsApp ? '#25D366' : 'var(--primary)') : 'transparent', flexShrink: 0 }} />
                    <span style={{ fontWeight: msg.isUnread ? '700' : '600', fontSize: '14px', color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {msg.sender}
                    </span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexShrink: 0 }}>
                    {isWhatsApp && (
                      <span style={{ fontSize: '10px', background: 'rgba(37, 211, 102, 0.15)', color: '#25D366', padding: '2px 6px', borderRadius: '6px', fontWeight: '700' }}>
                        WA
                      </span>
                    )}
                    {msg.hasAttachment && <Paperclip size={14} color="#9ca3af" />}
                    <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>{msg.timestamp}</span>
                    <Star size={16} fill={msg.starred ? "#f59e0b" : "transparent"} color={msg.starred ? "#f59e0b" : "#9ca3af"} onClick={(e) => toggleStar(e, msg.id)} />
                  </div>
                </div>

                <div style={{ fontSize: '13px', fontWeight: msg.isUnread ? '700' : '600', color: 'var(--text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {msg.subject}
                </div>

                <div style={{ fontSize: '12px', color: 'var(--text-secondary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {msg.snippet.replace(/^- /, '')}
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '4px' }}>
                  {msg.status !== 'pending' && (
                    <span style={{ fontSize: '10px', background: 'rgba(16, 185, 129, 0.1)', color: '#059669', padding: '2px 6px', borderRadius: '10px', fontWeight: '600' }}>
                      {msg.status}
                    </span>
                  )}
                  {isWhatsApp && (
                    <button
                      type="button"
                      onClick={(e) => { e.stopPropagation(); handleContinueWhatsApp(msg); }}
                      style={{
                        marginLeft: 'auto', background: '#25D366', color: 'white', border: 'none',
                        borderRadius: '6px', padding: '3px 8px', fontSize: '11px', fontWeight: '700',
                        display: 'flex', alignItems: 'center', gap: '4px'
                      }}
                    >
                      <MessageCircle size={12} /> WhatsApp ↗
                    </button>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>
      </div>
    </div>
  );
}
