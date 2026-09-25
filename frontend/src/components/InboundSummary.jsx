import React, { useState, useRef, useEffect } from 'react';
import axios from 'axios';
import { MessageSquare, FileText, Send, Loader2, Sparkles, Activity, AlertTriangle, Pill, Calendar, Download, CheckCircle, Clock, ArrowRight } from 'lucide-react';

const DEMO_SCENARIOS = {
  Oncology: `HOSPITAL DISCHARGE SUMMARY - PRINCESS MARGARET CANCER CENTRE
Patient: Eleanor Vance (DOB: 02/14/1958)
Date of Admission: 2026-07-20
Date of Discharge: 2026-08-05
Attending: Dr. S. Patel, Oncology

HOSPITAL COURSE: 
68F admitted for Cycle 4 of FOLFOX chemotherapy for Stage III colon adenocarcinoma. Course complicated by neutropenic fever on Day 4. Blood cultures positive for E. coli. Treated with IV Piperacillin-Tazobactam. Fever resolved by Day 8. 

MEDICATION CHANGES ON DISCHARGE:
1. STOP Capecitabine (due to severe hand-foot syndrome).
2. START Prophylactic Levofloxacin 500mg PO daily for 7 days.
3. INCREASE Ondansetron to 8mg PO Q8H PRN for severe nausea.

CRITICAL FOLLOW-UP:
Patient requires STAT CBC and metabolic panel in exactly 5 days (Aug 10). Primary care must assess renal function prior to clearing patient for Cycle 5 chemotherapy. If Creatinine > 150, hold chemo and page Oncology on-call.

DISCHARGE PLAN:
Patient discharged home in stable condition. Family educated on fever protocol. Primary care to schedule follow-up within 7 days.`,

  Ortho: `SURGICAL POST-OP REPORT - MT. SINAI ORTHOPEDICS
Patient: John Hammond (DOB: 11/22/1945)
Date of Surgery: 2026-08-01

PROCEDURE: Total Right Hip Arthroplasty (Posterior Approach).
SURGEON: Dr. Alan Grant

OPERATIVE FINDINGS: Severe osteoarthritis with bone-on-bone joint space narrowing. No complications during hardware placement. 

POST-OP COURSE:
Patient mobilized on Post-Op Day 1 with physiotherapy. Weight-bearing as tolerated. Mild postoperative anemia (Hgb 92) - did not require transfusion. 

MEDICATIONS:
1. START Rivaroxaban 10mg PO daily for 35 days (DVT prophylaxis).
2. Tylenol #3 (Acetaminophen/Codeine) 1-2 tabs PO Q6H PRN for pain.

RECOMMENDATIONS FOR PRIMARY CARE:
Monitor incision site for erythema. Remove surgical staples on Post-Op Day 14. Arrange outpatient physiotherapy 3x/week for 6 weeks.`
};

export default function InboundSummary({ setActiveTab, triggerNotification }) {
  const [docText, setDocText] = useState('');
  const [scenario, setScenario] = useState(null);
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(false);
  const [chatLoading, setChatLoading] = useState(false);
  
  const [messages, setMessages] = useState([
    { role: 'system', content: "Hi Dr. Prime, I'm ready to review clinical charts. Load a document to begin." }
  ]);
  const [chatInput, setChatInput] = useState('');
  
  const [scheduled, setScheduled] = useState(false);
  const [requisitionFilled, setRequisitionFilled] = useState(false);

  const messagesEndRef = useRef(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const loadScenario = (type) => {
    setScenario(type);
    setDocText(DEMO_SCENARIOS[type]);
    setSummary(null);
    setScheduled(false);
    setRequisitionFilled(false);
    setMessages([{ role: 'system', content: "Document loaded. Click 'Generate Clinical Insights' to analyze the chart." }]);
  };

  const handleSummarize = () => {
    if (!docText) return;
    setLoading(true);
    
    // Simulate AI Processing time
    setTimeout(() => {
      if (scenario === 'Oncology' || docText.includes('Oncology') || docText.includes('FOLFOX')) {
        setSummary({
          patient: "Eleanor Vance",
          med_changes: [
            { type: 'stop', drug: 'Capecitabine', reason: 'Severe hand-foot syndrome' },
            { type: 'start', drug: 'Levofloxacin 500mg PO daily', reason: 'Prophylaxis (7 days)' },
            { type: 'increase', drug: 'Ondansetron 8mg PO Q8H', reason: 'Severe nausea' }
          ],
          critical_flags: [
            "Neutropenic fever episode during admission (E. coli bacteremia).",
            "STAT bloodwork required prior to next chemo cycle."
          ],
          actions: [
            { id: 'blood', label: 'Order STAT CBC & Metabolic Panel', date: 'Aug 10', done: requisitionFilled },
            { id: 'followup', label: 'Schedule 7-Day Clinical Assessment', date: 'ASAP', done: scheduled }
          ]
        });
        setMessages([
          { role: 'system', content: "Chart analysis complete. Found 3 medication changes and 1 critical alert regarding neutropenic fever. The oncologist requires STAT bloodwork by Aug 10. How can I assist you with this patient?" }
        ]);
      } else {
        // Generic/Ortho Summary
        setSummary({
          patient: "John Hammond",
          med_changes: [
            { type: 'start', drug: 'Rivaroxaban 10mg PO daily', reason: 'DVT Prophylaxis (35 days)' },
            { type: 'start', drug: 'Tylenol #3 PO Q6H', reason: 'Post-op pain management' }
          ],
          critical_flags: [
            "Postoperative anemia (Hgb 92) - monitor for symptoms."
          ],
          actions: [
            { id: 'staples', label: 'Schedule Staple Removal (Post-Op Day 14)', date: 'Aug 15', done: scheduled },
            { id: 'physio', label: 'Generate Outpatient Physio Referral', date: 'Routine', done: requisitionFilled }
          ]
        });
        setMessages([
          { role: 'system', content: "Chart analysis complete. Surgical course was uncomplicated. Patient is on DVT prophylaxis for 35 days. Would you like me to schedule the staple removal?" }
        ]);
      }
      setLoading(false);
    }, 2000);
  };

  const handleScheduleConsult = async () => {
    setScheduled(true);
    try {
      const token = localStorage.getItem('medoffice_token') || 'demo-token';
      
      // 1. Post to appointments so it shows up in Upcoming Appointments
      await axios.post('/api/appointments', {
        patient_id: "P-456", 
        patient_name: summary?.patient || "Demo Patient",
        time: "10:00 AM",
        type: "Post-Discharge Follow-up",
        appointment_date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0], // 7 days from now
        color: "purple"
      });

      // 2. Post to Activity Log
      await axios.post('/api/activity/log', {
        action: "consult_scheduled",
        description: `Scheduled 7-Day Follow-Up from Chart Review`,
        patient_name: summary?.patient || "Demo Patient",
        detail: `Added to schedule based on hospital discharge requirements.`,
        color: "emerald"
      }, { headers: { Authorization: `Bearer ${token}` } });

      if (triggerNotification) {
        triggerNotification('dashboard');
      }

    } catch (e) {
      console.error("Failed to schedule:", e);
    }
  };

  const executeAction = (actionId) => {
    if (actionId === 'blood' || actionId === 'physio') {
      setRequisitionFilled(true);
      // Optional: switch to form filler
      // if (setActiveTab) setActiveTab('formFiller');
    } else {
      handleScheduleConsult();
    }
  };

  const handleChat = (e) => {
    e.preventDefault();
    if (!chatInput.trim() || chatLoading) return;
    
    const userMsg = chatInput;
    setMessages(prev => [...prev, { role: 'user', content: userMsg }]);
    setChatInput('');
    setChatLoading(true);

    setTimeout(() => {
      const lower = userMsg.toLowerCase();
      let aiResponse = "I have noted that in the chart.";
      let widget = null;

      if (lower.includes("schedule") || lower.includes("book") || lower.includes("follow")) {
        aiResponse = "I have prepared the scheduling request. Click the interactive widget below to finalize the booking in the EMR.";
        widget = 'calendar';
      } else if (lower.includes("blood") || lower.includes("form") || lower.includes("requisition") || lower.includes("order")) {
        aiResponse = "I have generated the requisition form based on the oncologist's request. Click below to submit to the lab.";
        widget = 'requisition';
      } else if (lower.includes("fever") || lower.includes("infection")) {
        aiResponse = "According to the discharge summary, the patient developed neutropenic fever on Day 4 of admission. Blood cultures were positive for E. coli. She was treated with IV Piperacillin-Tazobactam and the fever resolved by Day 8.";
      } else if (lower.includes("meds") || lower.includes("medication")) {
        aiResponse = "Yes. Capecitabine was stopped due to toxicity. Levofloxacin was started for 7 days, and Ondansetron was increased to 8mg Q8H.";
      }

      setMessages(prev => [...prev, { role: 'system', content: aiResponse, widget: widget }]);
      setChatLoading(false);
    }, 1500);
  };

  return (
    <div className="animate-fade-in" style={{ display: 'flex', flexDirection: 'column', height: '100%', maxWidth: '1600px', margin: '0 auto' }}>
      
      {/* Header */}
      <div style={{ marginBottom: '24px', padding: '0 16px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: '800', color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '12px', margin: '0 0 8px 0' }}>
          <Sparkles size={32} color="#a855f7" /> AI Clinical Chart Review & Chat
        </h1>
        <p style={{ fontSize: '15px', color: 'var(--text-secondary)', margin: 0, maxWidth: '900px', lineHeight: '1.6' }}>
          Stop spending 45 minutes reading 40-page hospital discharge summaries. Load a complex clinical document below to instantly extract medication changes, critical flags, and chat directly with the chart.
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: '24px', flex: 1, minHeight: 0, padding: '0 16px 16px 16px' }}>
        
        {/* Left Column: Document Viewer */}
        <div className="glass-panel" style={{ display: 'flex', flexDirection: 'column', borderTop: '4px solid #64748b', overflow: 'hidden' }}>
          <div style={{ padding: '16px', background: 'rgba(0,0,0,0.3)', borderBottom: '1px solid rgba(255,255,255,0.1)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)', fontWeight: '700' }}>
              <FileText size={18} /> Source Document Viewer
            </div>
            
            {/* Demo Buttons */}
            <div style={{ display: 'flex', gap: '8px' }}>
              <button 
                className="btn" 
                style={{ padding: '6px 12px', fontSize: '12px', background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)', color: '#fca5a5' }} 
                onClick={() => loadScenario('Oncology')}
              >
                Complex Oncology Discharge
              </button>
              <button 
                className="btn" 
                style={{ padding: '6px 12px', fontSize: '12px', background: 'rgba(59, 130, 246, 0.1)', border: '1px solid rgba(59, 130, 246, 0.3)', color: '#93c5fd' }} 
                onClick={() => loadScenario('Ortho')}
              >
                Ortho Surgical Note
              </button>
            </div>
          </div>
          
          <div style={{ flex: 1, padding: '24px', overflowY: 'auto', background: 'var(--bg-tertiary)', position: 'relative' }}>
            {docText ? (
              <div style={{ background: 'var(--bg-secondary)', padding: '32px', border: '1px solid var(--border)', borderRadius: '8px', minHeight: '100%', color: 'var(--text-primary)', fontFamily: 'monospace', fontSize: '14.5px', lineHeight: '1.8', whiteSpace: 'pre-wrap' }}>
                {docText}
              </div>
            ) : (
              <div style={{ height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center', padding: '40px' }}>
                <div style={{ width: '80px', height: '80px', background: 'rgba(168, 85, 247, 0.1)', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '24px' }}>
                  <Sparkles size={40} color="#a855f7" />
                </div>
                <h3 style={{ fontSize: '20px', color: 'var(--text-primary)', marginBottom: '12px', fontWeight: '700' }}>Chart Review Assistant</h3>
                <p style={{ color: 'var(--text-secondary)', fontSize: '14px', lineHeight: '1.6', maxWidth: '400px', marginBottom: '32px' }}>
                  The AI Assistant can extract medication changes, detect critical alerts, and answer questions about 100+ page clinical documents in seconds.
                </p>
                <div style={{ display: 'flex', gap: '12px', background: 'var(--bg-secondary)', padding: '16px', borderRadius: '12px', border: '1px solid var(--border)', textAlign: 'left', width: '100%', maxWidth: '400px' }}>
                  <ArrowRight size={20} color="#a855f7" style={{ flexShrink: 0, marginTop: '2px' }} className="animate-pulse" />
                  <span style={{ fontSize: '13px', color: 'var(--text-primary)', fontWeight: '500' }}>To get started, click on one of the Demo Scenarios above (e.g., Complex Oncology Discharge) to load a chart.</span>
                </div>
              </div>
            )}
          </div>
          
          <div style={{ padding: '16px', background: 'rgba(0,0,0,0.4)', borderTop: '1px solid rgba(255,255,255,0.1)' }}>
            <button 
              className="btn btn-primary" 
              style={{ width: '100%', padding: '16px', fontSize: '15px', fontWeight: '800', background: 'linear-gradient(135deg, #a855f7, #7e22ce)', border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', boxShadow: '0 10px 25px rgba(168, 85, 247, 0.4)', transition: 'all 0.3s' }}
              onClick={handleSummarize}
              disabled={!docText || loading}
            >
              {loading ? <Loader2 size={22} className="animate-spin" /> : <Sparkles size={22} />}
              {loading ? 'Prime Care AI is analyzing 40 pages of medical history...' : 'Generate Clinical Insights'}
            </button>
          </div>
        </div>

        {/* Right Column: AI Assistant (Summary & Chat) */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px', overflow: 'hidden' }}>
          
          {/* Summary Dashboard (Only shows if summarized) */}
          {summary && (
            <div className="glass-panel animate-fade-in" style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: '20px', borderTop: '4px solid #a855f7', maxHeight: '50%', overflowY: 'auto' }}>
              
              {/* Patient Header */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '12px' }}>
                <h3 style={{ margin: 0, fontSize: '18px', color: 'var(--text-primary)', fontWeight: '800' }}>AI Clinical Brief: {summary.patient}</h3>
                <span style={{ background: 'rgba(168, 85, 247, 0.2)', color: '#d8b4fe', padding: '4px 10px', borderRadius: '12px', fontSize: '12px', fontWeight: '700' }}>Chart Reviewed</span>
              </div>

              {/* Medication Changes */}
              <div>
                <h4 style={{ margin: '0 0 12px 0', fontSize: '13px', color: '#93c5fd', textTransform: 'uppercase', letterSpacing: '1px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Pill size={16} /> Medication Reconciliations
                </h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {summary.med_changes.map((med, i) => (
                    <div key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: '12px', background: 'rgba(0,0,0,0.2)', padding: '12px', borderRadius: '8px', borderLeft: med.type === 'stop' ? '3px solid #ef4444' : med.type === 'start' ? '3px solid #10b981' : '3px solid #f59e0b' }}>
                      <div style={{ padding: '4px 8px', borderRadius: '4px', fontSize: '11px', fontWeight: '800', textTransform: 'uppercase', 
                        background: med.type === 'stop' ? 'rgba(239, 68, 68, 0.2)' : med.type === 'start' ? 'rgba(16, 185, 129, 0.2)' : 'rgba(245, 158, 11, 0.2)',
                        color: med.type === 'stop' ? '#fca5a5' : med.type === 'start' ? '#6ee7b7' : '#fcd34d'
                      }}>
                        {med.type}
                      </div>
                      <div>
                        <div style={{ color: 'var(--text-primary)', fontWeight: '700', fontSize: '14px', marginBottom: '2px' }}>{med.drug}</div>
                        <div style={{ color: 'var(--text-secondary)', fontSize: '12px' }}>Reason: {med.reason}</div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Critical Flags */}
              <div>
                <h4 style={{ margin: '0 0 12px 0', fontSize: '13px', color: '#fca5a5', textTransform: 'uppercase', letterSpacing: '1px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <AlertTriangle size={16} /> Critical Flags
                </h4>
                <ul style={{ margin: 0, paddingLeft: '20px', color: 'var(--text-primary)', fontSize: '14px', lineHeight: '1.6' }}>
                  {summary.critical_flags.map((flag, i) => (
                    <li key={i} style={{ marginBottom: '6px' }}>{flag}</li>
                  ))}
                </ul>
              </div>

              {/* Actionable Recommendations */}
              <div>
                <h4 style={{ margin: '0 0 12px 0', fontSize: '13px', color: '#6ee7b7', textTransform: 'uppercase', letterSpacing: '1px', fontWeight: '800', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Activity size={16} /> Recommended Actions
                </h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {summary.actions.map((act, i) => (
                    <div key={i} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'rgba(16, 185, 129, 0.05)', border: '1px solid rgba(16, 185, 129, 0.2)', padding: '12px 16px', borderRadius: '8px' }}>
                      <div>
                        <div style={{ color: 'var(--text-primary)', fontWeight: '600', fontSize: '14px' }}>{act.label}</div>
                        <div style={{ color: '#6ee7b7', fontSize: '12px', marginTop: '2px' }}>Due: {act.date}</div>
                      </div>
                      {act.done ? (
                        <span style={{ color: '#10b981', display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: '700' }}>
                          <CheckCircle size={16} /> Completed
                        </span>
                      ) : (
                        <button className="btn btn-secondary" style={{ padding: '6px 12px', fontSize: '12px', border: '1px solid #10b981', color: '#6ee7b7' }} onClick={() => executeAction(act.id)}>
                          Execute
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              </div>

            </div>
          )}

          {/* Interactive Chat Pane */}
          <div className="glass-panel" style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
            <div style={{ padding: '16px', background: 'rgba(0,0,0,0.3)', borderBottom: '1px solid rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <MessageSquare size={18} color="#a855f7" />
              <span style={{ color: 'var(--text-primary)', fontWeight: '700', fontSize: '15px' }}>Chat with this Chart</span>
            </div>
            
            <div style={{ flex: 1, overflowY: 'auto', padding: '20px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {messages.map((msg, i) => (
                <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: msg.role === 'user' ? 'flex-end' : 'flex-start' }}>
                  <div style={{ 
                    maxWidth: '85%', padding: '14px 18px', borderRadius: '16px', fontSize: '14.5px', lineHeight: '1.6',
                    background: msg.role === 'user' ? '#a855f7' : 'rgba(0,0,0,0.4)',
                    color: '#ffffff',
                    borderBottomRightRadius: msg.role === 'user' ? '4px' : '16px',
                    borderBottomLeftRadius: msg.role === 'system' ? '4px' : '16px',
                    border: msg.role === 'system' ? '1px solid rgba(168, 85, 247, 0.3)' : 'none'
                  }}>
                    {msg.content}
                  </div>
                  
                  {/* Render Interactive UI Widgets if present in chat */}
                  {msg.widget === 'calendar' && (
                    <div className="animate-fade-in" style={{ marginTop: '12px', background: 'rgba(16, 185, 129, 0.1)', border: '1px solid #10b981', padding: '16px', borderRadius: '12px', width: '280px' }}>
                      <div style={{ color: '#6ee7b7', fontWeight: '800', marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <Calendar size={16} /> 1-Click EMR Booking
                      </div>
                      <div style={{ color: 'var(--text-primary)', fontSize: '13px', marginBottom: '12px' }}>Book: {summary?.patient}<br/>Type: 7-Day Follow-Up</div>
                      {scheduled ? (
                        <div style={{ color: '#10b981', fontWeight: '700', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '4px' }}><CheckCircle size={14}/> Successfully Booked</div>
                      ) : (
                        <button className="btn btn-primary" style={{ width: '100%', padding: '8px', background: '#10b981', border: 'none', fontSize: '13px', fontWeight: '700' }} onClick={handleScheduleConsult}>Confirm Booking</button>
                      )}
                    </div>
                  )}

                  {msg.widget === 'requisition' && (
                    <div className="animate-fade-in" style={{ marginTop: '12px', background: 'rgba(59, 130, 246, 0.1)', border: '1px solid #3b82f6', padding: '16px', borderRadius: '12px', width: '280px' }}>
                      <div style={{ color: '#93c5fd', fontWeight: '800', marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <FileText size={16} /> Lab Requisition Generated
                      </div>
                      <div style={{ color: 'var(--text-primary)', fontSize: '13px', marginBottom: '12px' }}>Order: STAT CBC & Metabolic<br/>For: {summary?.patient}</div>
                      {requisitionFilled ? (
                        <div style={{ color: '#3b82f6', fontWeight: '700', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '4px' }}><CheckCircle size={14}/> E-Fax Transmitted to Lab</div>
                      ) : (
                        <button className="btn btn-primary" style={{ width: '100%', padding: '8px', background: '#3b82f6', border: 'none', fontSize: '13px', fontWeight: '700' }} onClick={() => setRequisitionFilled(true)}>Sign & Send E-Fax</button>
                      )}
                    </div>
                  )}
                </div>
              ))}
              {chatLoading && (
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#a855f7' }}>
                  <Loader2 size={18} className="animate-spin" /> <span style={{ fontSize: '13px', fontWeight: '600' }}>AI is reviewing the chart...</span>
                </div>
              )}
              <div ref={messagesEndRef} />
            </div>

            <form onSubmit={handleChat} style={{ padding: '16px', background: 'rgba(0,0,0,0.3)', borderTop: '1px solid rgba(255,255,255,0.1)', display: 'flex', gap: '12px' }}>
              <input 
                type="text" 
                value={chatInput}
                onChange={e => setChatInput(e.target.value)}
                placeholder={docText ? "Ask a question about this patient's chart..." : "Load a document first..."}
                disabled={!docText || chatLoading}
                style={{ flex: 1, background: 'rgba(0,0,0,0.4)', border: '1px solid rgba(255,255,255,0.2)', borderRadius: '24px', padding: '12px 20px', color: 'white', fontSize: '15px' }}
              />
              <button 
                type="submit" 
                disabled={!docText || !chatInput.trim() || chatLoading}
                style={{ width: '46px', height: '46px', borderRadius: '50%', background: chatInput.trim() ? '#a855f7' : 'rgba(255,255,255,0.1)', border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', cursor: chatInput.trim() ? 'pointer' : 'not-allowed', transition: 'all 0.2s' }}
              >
                <Send size={18} style={{ marginLeft: '2px' }} />
              </button>
            </form>
          </div>

        </div>
      </div>
    </div>
  );
}
