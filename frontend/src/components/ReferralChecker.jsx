import React, { useState } from 'react';
import axios from 'axios';
import { CheckCircle, AlertCircle, Loader2, Printer, Sparkles, Calendar, UploadCloud, Layers, FileDigit, Stethoscope, User, Clock, FileText, Droplet, History, Mail, HeartPulse, ArrowRight, Database } from 'lucide-react';

const MOCK_PATIENT_DB = {
  "1234-567-890": {
    patientName: "Sarah Jenkins",
    visits: [
      { id: "V-9821", date: "2025-11-02", diagnosis: "Mild Mitral Valve Prolapse", status: "Completed" },
      { id: "V-8711", date: "2024-06-15", diagnosis: "Hypertension Routine Follow-up", status: "Completed" }
    ]
  },
  "4567-890-123": {
    patientName: "Tommy Oliver",
    visits: [
      { id: "V-1102", date: "2023-01-10", diagnosis: "Minor Meniscus Strain (Left Knee)", status: "Completed" }
    ]
  }
};

const INBOUND_REFERRALS = [
  {
    id: 1,
    patientName: "Sarah Jenkins",
    dob: "1963-04-12",
    ohip: "1234-567-890",
    specialty: "Cardiology",
    referringProvider: "Dr. Alan Grant",
    dateReceived: "10 mins ago",
    status: "Pending",
    scans: ["ECHO_Report.pdf", "ECG_Tracing.dcm"],
    text: "REFERRAL LETTER: Patient Sarah Jenkins (DOB: 04/12/1963). Referring Provider: Dr. Alan Grant, Family Practice.\n\nCLINICAL HISTORY: Patient presents with progressive dyspnea on exertion and orthopnea over 3 weeks. Patient's blood type is O+. Transthoracic echocardiogram (performed yesterday, full dicom attached) reveals severe symptomatic mitral regurgitation with left ventricular ejection fraction preserved at 56%. Blood pressure 138/84. \n\nPatient requires urgent evaluation for valvular surgery or edge-to-edge repair."
  },
  {
    id: 2,
    patientName: "Marcus Aurelius",
    dob: "1980-11-05",
    ohip: "9876-543-210",
    specialty: "Neurology",
    referringProvider: "Dr. Ellie Sattler",
    dateReceived: "1 hr ago",
    status: "Pending",
    scans: [],
    text: "REFERRAL LETTER: Patient Marcus Aurelius (DOB: 11/05/1980). Referring Provider: Dr. Ellie Sattler, Primary Care.\n\nCLINICAL HISTORY: Patient complains of chronic bi-temporal headache episodes occurring weekly for the past 6 months. Neurological exam in clinic was grossly normal. Patient has tried over-the-counter Tylenol with minimal relief. Patient notes their blood group is A-.\n\nRequesting neurology consult for headache management and evaluation. Note: we did an MRI of the Head last week but I forgot to attach it to this fax."
  },
  {
    id: 3,
    patientName: "Tommy Oliver",
    dob: "1995-09-14",
    ohip: "4567-890-123",
    specialty: "Orthopedics",
    referringProvider: "Urgent Care Med",
    dateReceived: "2 hrs ago",
    status: "Pending",
    scans: ["Knee_MRI_Report.pdf"],
    text: "REFERRAL LETTER: Patient Tommy Oliver (DOB: 09/14/1995). Referring Provider: Urgent Care Medical Group.\n\nCLINICAL HISTORY: 28-year-old male sustained an acute hyperextension injury to right knee during recreational football. Lachman test prominently positive with grade 3 anterior drawer laxity. Outpatient knee MRI from 48 hours ago confirms complete, retracted tear of anterior cruciate ligament (ACL) along with complex radial tear of the lateral meniscus. Blood type unknown. \n\nRequesting orthopedic surgery intervention."
  }
];

export default function ReferralChecker({ triggerNotification }) {
  const [selectedReferral, setSelectedReferral] = useState(null);
  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [faxStatus, setFaxStatus] = useState(null);
  const [scheduled, setScheduled] = useState(false);
  const [viewScan, setViewScan] = useState(null);

  const handleSelectReferral = (ref) => {
    setSelectedReferral(ref);
    setResult(null);
    setFaxStatus(null);
    setScheduled(false);
    setViewScan(null);
  };

  const handleCheck = async () => {
    if (!selectedReferral) return;
    setLoading(true);
    setResult(null);
    setFaxStatus(null);
    setScheduled(false);

    try {
      const res = await axios.post('/api/referral/check', {
        text: selectedReferral.text,
        specialty: selectedReferral.specialty
      });
      setResult(res.data);
      
      const token = localStorage.getItem('medoffice_token') || 'demo-token';
      await axios.post('/api/activity/log', {
        action: "referral_evaluated",
        description: `Deep Data Extraction on ${selectedReferral.specialty} referral`,
        patient_name: selectedReferral.patientName,
        detail: `Decision: ${res.data.status} | Blood: ${res.data.blood_group || 'N/A'}`,
        color: res.data.status === 'ACCEPTED' ? 'emerald' : res.data.status === 'REJECTED' ? 'red' : 'orange'
      }, { headers: { Authorization: `Bearer ${token}` } }).catch(e => {});

    } catch (err) {
      console.error(err);
      setResult({
        status: "MISSING_INFO",
        priority: "DEFERRED",
        cpt_codes: [],
        reason: `Backend Error: AI engine unreachable.`,
        missing_items: ["Ensure local Python backend and AI model are running."],
        blood_group: "Unknown",
        extracted_scans: [],
        clinical_summary: "Error processing."
      });
    } finally {
      setLoading(false);
    }
  };

  const handleSendFax = () => {
    setFaxStatus('transmitting');
    setTimeout(() => {
      setFaxStatus('sent');
      const token = localStorage.getItem('medoffice_token') || 'demo-token';
      axios.post('/api/activity/log', {
        action: "fax_transmitted",
        description: `Automated Fax transmitted for missing ${selectedReferral.specialty} criteria`,
        patient_name: selectedReferral.patientName,
        detail: `Sent secure email/fax requesting missing items.`,
        color: "orange"
      }, { headers: { Authorization: `Bearer ${token}` } }).then(() => {
        // Mock sending to SecureInbox by saving to localStorage
        const draftEmails = JSON.parse(localStorage.getItem('drafted_emails') || '[]');
        draftEmails.push({
          id: Date.now(),
          type: "inquiry",
          sender: "Referral Engine AI",
          subject: `Missing Scans - ${selectedReferral.patientName}`,
          snippet: `- Automated Request: Please securely upload the missing scans for ${selectedReferral.patientName} (${selectedReferral.ohip}).`,
          timestamp: "Just now",
          isUnread: true,
          status: "pending",
          hasAttachment: false,
          starred: false
        });
        localStorage.setItem('drafted_emails', JSON.stringify(draftEmails));

        if (triggerNotification) triggerNotification('dashboard');
        if (triggerNotification) triggerNotification('inbox');
      }).catch(e => {});
    }, 2500);
  };

  const handleScheduleConsult = () => {
    setScheduled(true);
    const token = localStorage.getItem('medoffice_token') || 'demo-token';
    axios.post('/api/activity/log', {
      action: "consult_scheduled",
      description: `Scheduled priority consult for ${selectedReferral.specialty}`,
      patient_name: selectedReferral.patientName,
      detail: `Approved clinical referral added to upcoming outpatient consultation schedule.`,
      color: "emerald"
    }, { headers: { Authorization: `Bearer ${token}` } }).then(() => {
      if (triggerNotification) triggerNotification('dashboard');
    }).catch(e => {});
  };

  const patientHistory = selectedReferral ? MOCK_PATIENT_DB[selectedReferral.ohip] : null;

  return (
    <div className="animate-fade-in" style={{ padding: '32px', maxWidth: '1600px', margin: '0 auto', height: '100%', display: 'flex', flexDirection: 'column' }}>
      
      {/* Header */}
      <div style={{ marginBottom: '32px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: '800', color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '12px', margin: '0 0 8px 0' }}>
          <FileDigit size={32} color="#8b5cf6" /> Prime Care Deep Clinical Extraction
        </h1>
        <p style={{ fontSize: '15px', color: 'var(--text-secondary)', margin: 0, maxWidth: '800px', lineHeight: '1.6' }}>
          Instantly evaluate incoming referrals, extract structured vitals, match to existing patient records, and detect missing documentation before scheduling.
        </p>
      </div>

      <div className="referral-checker-grid" style={{ display: 'grid', gridTemplateColumns: '350px 1fr', gap: '32px', flex: 1, minHeight: '600px' }}>
        
        {/* Left Sidebar: Inbox Queue */}
        <div className="glass-panel" style={{ padding: '24px', display: 'flex', flexDirection: 'column', borderTop: '4px solid #8b5cf6' }}>
          <h2 style={{ margin: '0 0 16px 0', fontSize: '16px', display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)' }}>
            <UploadCloud size={18} color="#a855f7" /> Inbound Referral Queue
          </h2>
          
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', overflowY: 'auto' }}>
            {INBOUND_REFERRALS.map(ref => (
              <div 
                key={ref.id}
                onClick={() => handleSelectReferral(ref)}
                style={{
                  padding: '16px', borderRadius: '12px', cursor: 'pointer', transition: 'all 0.2s',
                  background: selectedReferral?.id === ref.id ? 'rgba(139, 92, 246, 0.15)' : 'rgba(0,0,0,0.2)',
                  border: selectedReferral?.id === ref.id ? '1px solid #8b5cf6' : '1px solid rgba(255,255,255,0.05)',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '8px' }}>
                  <span style={{ fontWeight: '700', fontSize: '15px', color: 'var(--text-primary)' }}>{ref.patientName}</span>
                  <span style={{ fontSize: '11px', color: '#8b5cf6', background: 'rgba(139, 92, 246, 0.2)', padding: '2px 8px', borderRadius: '10px', fontWeight: '600' }}>{ref.specialty}</span>
                </div>
                <div style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '4px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <User size={12} /> {ref.referringProvider}
                </div>
                <div style={{ fontSize: '11px', color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <Clock size={12} /> Received: {ref.dateReceived}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Right Content: Detail View & AI Triage */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          
          {!selectedReferral ? (
            <div className="glass-panel" style={{ flex: 1, padding: '40px', display: 'flex', flexDirection: 'column', justifyContent: 'center', position: 'relative', overflow: 'hidden' }}>
              <div style={{ position: 'absolute', top: '-10%', right: '-5%', width: '300px', height: '300px', background: 'radial-gradient(circle, rgba(139, 92, 246, 0.1) 0%, transparent 70%)', borderRadius: '50%' }} />
              
              <div style={{ marginBottom: '32px' }}>
                <div style={{ width: '64px', height: '64px', background: 'var(--bg-tertiary)', borderRadius: '16px', display: 'flex', alignItems: 'center', justifyContent: 'center', border: '1px solid var(--border)', marginBottom: '24px' }}>
                  <FileDigit size={32} color="#8b5cf6" />
                </div>
                <h2 style={{ fontSize: '24px', fontWeight: '700', color: 'var(--text-primary)', marginBottom: '12px' }}>Intelligent Referral Triage</h2>
                <p style={{ fontSize: '15px', color: 'var(--text-secondary)', lineHeight: '1.6', maxWidth: '600px' }}>
                  Prime Care AI instantly analyzes unstructured clinical referrals to extract vital information, detect missing documentation (like MRIs or lab results), and automatically draft follow-up requests to referring providers.
                </p>
              </div>

              <div className="referral-checker-2col" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '32px' }}>
                {[
                  { icon: <Database size={18} color="#3b82f6" />, title: "Automated EMR Matching", desc: "Cross-references OHIP numbers with existing patient records." },
                  { icon: <AlertCircle size={18} color="#f97316" />, title: "Missing Data Detection", desc: "Flags referrals that are missing required clinical criteria." },
                  { icon: <Mail size={18} color="#10b981" />, title: "Automated Provider Comms", desc: "Drafts secure faxes/emails requesting missing scans." },
                  { icon: <Calendar size={18} color="#a855f7" />, title: "1-Click Scheduling", desc: "Approves and queues complete referrals for booking." }
                ].map((feat, i) => (
                  <div key={i} style={{ background: 'var(--bg-tertiary)', padding: '16px', borderRadius: '12px', border: '1px solid var(--border)' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px' }}>
                      {feat.icon}
                      <h4 style={{ margin: 0, fontSize: '14px', color: 'var(--text-primary)', fontWeight: '600' }}>{feat.title}</h4>
                    </div>
                    <p style={{ margin: 0, fontSize: '13px', color: 'var(--text-secondary)' }}>{feat.desc}</p>
                  </div>
                ))}
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '12px', background: 'rgba(139, 92, 246, 0.05)', padding: '16px', borderRadius: '8px', border: '1px solid rgba(139, 92, 246, 0.2)' }}>
                <ArrowRight size={20} color="#8b5cf6" className="animate-pulse" />
                <span style={{ fontSize: '14px', fontWeight: '600', color: 'var(--text-primary)' }}>Select an inbound referral from the queue on the left to see the AI in action.</span>
              </div>
            </div>
          ) : (
            <>
              {/* Top Row: Demographics & History Match */}
              <div className="referral-checker-2col" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px' }}>
                
                {/* Clinical Detail Panel */}
                <div className="glass-panel animate-fade-in" style={{ padding: '24px' }}>
                  <div style={{ borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '16px', marginBottom: '16px' }}>
                    <h2 style={{ margin: '0 0 4px 0', fontSize: '22px', fontWeight: '800', color: 'var(--text-primary)' }}>{selectedReferral.patientName}</h2>
                    <div style={{ fontSize: '14px', color: 'var(--text-secondary)', display: 'flex', gap: '16px' }}>
                      <span><strong>DOB:</strong> {selectedReferral.dob}</span>
                      <span><strong>OHIP:</strong> {selectedReferral.ohip}</span>
                    </div>
                  </div>
                  <div>
                    <div style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '4px' }}>Referring Provider</div>
                    <div style={{ fontSize: '15px', fontWeight: '600', color: 'var(--text-primary)' }}>{selectedReferral.referringProvider}</div>
                  </div>
                </div>

                {/* EMR Match Panel */}
                <div className="glass-panel animate-fade-in" style={{ padding: '24px', borderTop: patientHistory ? '4px solid #3b82f6' : '4px solid #64748b' }}>
                  <h3 style={{ margin: '0 0 16px 0', fontSize: '15px', color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <History size={18} color={patientHistory ? "#3b82f6" : "#64748b"} /> EMR Patient Database Match
                  </h3>
                  {patientHistory ? (
                    <div>
                      <div style={{ display: 'inline-block', background: 'rgba(59, 130, 246, 0.2)', color: '#60a5fa', padding: '4px 10px', borderRadius: '12px', fontSize: '11px', fontWeight: '700', marginBottom: '12px', border: '1px solid rgba(59, 130, 246, 0.4)' }}>
                        RETURNING PATIENT
                      </div>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                        {patientHistory.visits.map((v, i) => (
                          <div key={i} style={{ background: 'rgba(0,0,0,0.2)', padding: '10px', borderRadius: '8px', fontSize: '13px' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', color: 'var(--text-secondary)', marginBottom: '4px' }}>
                              <span>Visit #{v.id}</span>
                              <span>{v.date}</span>
                            </div>
                            <div style={{ color: 'var(--text-primary)', fontWeight: '500' }}>{v.diagnosis}</div>
                          </div>
                        ))}
                      </div>
                    </div>
                  ) : (
                    <div style={{ fontSize: '14px', color: 'var(--text-secondary)', fontStyle: 'italic', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <AlertCircle size={16} /> No existing records found for this OHIP.
                    </div>
                  )}
                </div>
              </div>

              {/* Referral Text & Attached Scans */}
              <div className="glass-panel animate-fade-in" style={{ padding: '24px' }}>
                <div className="referral-checker-2col" style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '32px' }}>
                  
                  <div>
                    <h3 style={{ fontSize: '13px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.5px', marginBottom: '8px' }}>Raw Referral Text</h3>
                    <div style={{ background: 'rgba(0,0,0,0.3)', border: '1px dashed rgba(255,255,255,0.1)', borderRadius: '12px', padding: '16px', fontSize: '14px', lineHeight: '1.7', color: 'var(--text-primary)', whiteSpace: 'pre-wrap' }}>
                      {selectedReferral.text}
                    </div>
                  </div>

                  <div>
                    <h3 style={{ fontSize: '13px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.5px', marginBottom: '8px' }}>Physically Attached Scans</h3>
                    {selectedReferral.scans.length > 0 ? (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                        {selectedReferral.scans.map((scan, i) => (
                          <div 
                            key={i} 
                            onClick={() => setViewScan(scan)}
                            style={{ display: 'flex', alignItems: 'center', gap: '10px', background: 'rgba(59, 130, 246, 0.1)', border: '1px solid rgba(59, 130, 246, 0.3)', color: '#93c5fd', padding: '12px', borderRadius: '8px', fontSize: '13px', fontWeight: '600', cursor: 'pointer', transition: 'all 0.2s' }}
                            onMouseOver={e => e.currentTarget.style.background = 'rgba(59, 130, 246, 0.2)'}
                            onMouseOut={e => e.currentTarget.style.background = 'rgba(59, 130, 246, 0.1)'}
                          >
                            <FileText size={18} /> {scan}
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div style={{ fontSize: '13px', color: '#ef4444', fontStyle: 'italic', display: 'flex', alignItems: 'center', gap: '6px', background: 'rgba(239, 68, 68, 0.1)', padding: '12px', borderRadius: '8px', border: '1px solid rgba(239, 68, 68, 0.3)' }}>
                        <AlertCircle size={16} /> No documents attached to this fax.
                      </div>
                    )}
                  </div>
                </div>

                {/* AI Trigger */}
                {!result && (
                  <button 
                    className="btn btn-primary" 
                    style={{ 
                      marginTop: '24px', width: '100%', padding: '16px', fontSize: '15px', fontWeight: '700', 
                      background: 'linear-gradient(135deg, #8b5cf6, #6d28d9)', border: 'none', 
                      display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', 
                      boxShadow: '0 10px 25px rgba(139, 92, 246, 0.4)', transition: 'all 0.3s'
                    }}
                    onClick={handleCheck}
                    disabled={loading}
                  >
                    {loading ? (
                      <><Loader2 size={20} className="animate-spin" /> Performing Deep Clinical Extraction...</>
                    ) : (
                      <><Sparkles size={20} /> Run AI Deep Clinical Extraction</>
                    )}
                  </button>
                )}
              </div>

              {/* AI Output Panels */}
              {result && (
                <div className="animate-fade-in" style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
                  
                  {/* Extracted Data Row */}
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 2fr', gap: '24px' }}>
                    
                    {/* Vitals Box */}
                    <div className="glass-panel" style={{ padding: '20px', borderTop: '4px solid #f43f5e' }}>
                      <h4 style={{ margin: '0 0 12px 0', fontSize: '13px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.5px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <Droplet size={14} color="#f43f5e" /> Extracted Blood Group
                      </h4>
                      <div style={{ fontSize: '24px', fontWeight: '800', color: result.blood_group === 'Not provided' ? 'var(--text-secondary)' : '#f43f5e' }}>
                        {result.blood_group || 'Unknown'}
                      </div>
                    </div>

                    {/* Extracted Scans Verification */}
                    <div className="glass-panel" style={{ padding: '20px', borderTop: '4px solid #eab308' }}>
                      <h4 style={{ margin: '0 0 12px 0', fontSize: '13px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.5px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <Layers size={14} color="#eab308" /> Scans Mentioned in Text
                      </h4>
                      {result.extracted_scans && result.extracted_scans.length > 0 ? (
                        <ul style={{ margin: 0, paddingLeft: '20px', fontSize: '13px', color: 'var(--text-primary)' }}>
                          {result.extracted_scans.map((s, i) => <li key={i} style={{ marginBottom: '4px' }}>{s}</li>)}
                        </ul>
                      ) : (
                        <div style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>None extracted.</div>
                      )}
                    </div>

                    {/* Clinical Summary */}
                    <div className="glass-panel" style={{ padding: '20px', borderTop: '4px solid #8b5cf6' }}>
                      <h4 style={{ margin: '0 0 12px 0', fontSize: '13px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '0.5px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <HeartPulse size={14} color="#8b5cf6" /> AI Clinical TL;DR
                      </h4>
                      <p style={{ margin: 0, fontSize: '14px', lineHeight: '1.6', color: 'var(--text-primary)' }}>
                        {result.clinical_summary || "Could not generate summary."}
                      </p>
                    </div>

                  </div>

                  {/* Triage Decision Banner */}
                  <div className="glass-panel" style={{ padding: '24px', borderTop: result.status === 'ACCEPTED' ? '4px solid #10b981' : '4px solid #f97316' }}>
                    <div style={{ 
                      background: result.status === 'ACCEPTED' ? 'rgba(16, 185, 129, 0.1)' : 'rgba(249, 115, 22, 0.1)',
                      border: result.status === 'ACCEPTED' ? '1px solid rgba(16, 185, 129, 0.3)' : '1px solid rgba(249, 115, 22, 0.3)',
                      padding: '20px', borderRadius: '12px', display: 'flex', alignItems: 'center', gap: '16px', marginBottom: '20px' 
                    }}>
                      <div style={{ 
                        width: '48px', height: '48px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                        background: result.status === 'ACCEPTED' ? '#10b981' : '#f97316', color: 'white'
                      }}>
                        {result.status === 'ACCEPTED' ? <CheckCircle size={24} /> : <AlertCircle size={24} />}
                      </div>
                      <div>
                        <h3 style={{ margin: '0 0 4px 0', fontSize: '20px', fontWeight: '800', color: result.status === 'ACCEPTED' ? '#34d399' : '#fdba74' }}>
                          {result.status === 'ACCEPTED' ? 'Triage Cleared (Accepted)' : 'Missing Clinical Criteria'}
                        </h3>
                        {result.status !== 'ACCEPTED' && <span style={{ fontSize: '13px', color: 'var(--text-primary)' }}>Priority: DEFERRED</span>}
                      </div>
                    </div>

                    <div style={{ marginBottom: '24px' }}>
                      <p style={{ margin: 0, fontSize: '14px', color: 'var(--text-primary)', lineHeight: '1.6', background: 'rgba(0,0,0,0.2)', padding: '16px', borderRadius: '8px', borderLeft: result.status === 'ACCEPTED' ? '3px solid #10b981' : '3px solid #f97316' }}>
                        {result.reason}
                      </p>
                    </div>

                    {result.status === 'ACCEPTED' ? (
                      <div>
                        {scheduled ? (
                          <div className="animate-fade-in" style={{ background: 'rgba(16, 185, 129, 0.2)', color: '#10b981', padding: '16px', borderRadius: '12px', textAlign: 'center', fontWeight: '700', fontSize: '14px', border: '1px solid #10b981', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px' }}>
                            <CheckCircle size={18} /> Added to Specialist Schedule!
                          </div>
                        ) : (
                          <button 
                            className="btn btn-primary" 
                            style={{ width: '100%', padding: '14px', fontSize: '14px', fontWeight: '700', background: '#10b981', border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', boxShadow: '0 4px 15px rgba(16, 185, 129, 0.3)' }}
                            onClick={handleScheduleConsult}
                          >
                            <Calendar size={18} /> Approve & Schedule Clinical Consult
                          </button>
                        )}
                      </div>
                    ) : (
                      <div>
                        <div style={{ background: 'rgba(249, 115, 22, 0.05)', padding: '16px', borderRadius: '8px', border: '1px solid rgba(249, 115, 22, 0.2)', marginBottom: '16px' }}>
                          <h4 style={{ margin: '0 0 8px 0', fontSize: '13px', color: '#fdba74', display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <Layers size={16} /> Required Action Items for Approval
                          </h4>
                          <ul style={{ margin: 0, paddingLeft: '20px', color: 'var(--text-primary)', fontSize: '13px', lineHeight: '1.6' }}>
                            {(result.missing_items || []).map((item, i) => (
                              <li key={i} style={{ marginBottom: '4px' }}>{item}</li>
                            ))}
                          </ul>
                          
                          {/* Intelligent Scan Checking Logic */}
                          {result.extracted_scans && result.extracted_scans.length > 0 && selectedReferral.scans.length === 0 && (
                            <div style={{ marginTop: '12px', background: 'rgba(239, 68, 68, 0.1)', padding: '12px', borderRadius: '8px', border: '1px solid rgba(239, 68, 68, 0.3)', color: '#f87171', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '8px', fontWeight: '600' }}>
                              <AlertCircle size={16} /> AI Detected Scans mentioned in text, but no files are attached!
                            </div>
                          )}
                        </div>

                        {faxStatus === 'transmitting' ? (
                          <div style={{ background: 'rgba(0,0,0,0.4)', color: 'var(--text-secondary)', padding: '14px', borderRadius: '8px', textAlign: 'center', fontWeight: '600', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', border: '1px solid rgba(255,255,255,0.1)' }}>
                            <Loader2 size={18} className="animate-spin" /> Synthesizing & Drafting Email to Provider...
                          </div>
                        ) : faxStatus === 'sent' ? (
                          <div className="animate-fade-in" style={{ background: 'rgba(59, 130, 246, 0.2)', color: '#60a5fa', padding: '14px', borderRadius: '8px', textAlign: 'center', fontWeight: '700', border: '1px solid #3b82f6', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
                            <Mail size={18} /> Reply Drafted & Sent to Referring Provider!
                          </div>
                        ) : (
                          <button 
                            className="btn" 
                            style={{ width: '100%', padding: '14px', fontSize: '14px', fontWeight: '700', background: 'rgba(59, 130, 246, 0.1)', border: '1px solid #3b82f6', color: '#93c5fd', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}
                            onClick={handleSendFax}
                          >
                            <Mail size={18} /> Draft Reply Email Requesting Missing Items
                          </button>
                        )}
                      </div>
                    )}
                  </div>

                </div>
              )}
            </>
          )}

        </div>
      </div>
      
      {/* Scan Viewer Modal */}
      {viewScan && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.85)', zIndex: 9999, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '40px', backdropFilter: 'blur(4px)' }} onClick={() => setViewScan(null)}>
          <div style={{ width: '100%', maxWidth: '900px', display: 'flex', justifyContent: 'space-between', marginBottom: '16px', color: 'white' }}>
            <h3 style={{ margin: 0, fontSize: '20px', display: 'flex', alignItems: 'center', gap: '8px' }}><FileText /> {viewScan}</h3>
            <button onClick={() => setViewScan(null)} style={{ background: 'none', border: 'none', color: 'white', cursor: 'pointer', fontSize: '32px', lineHeight: 1 }}>&times;</button>
          </div>
          <div style={{ background: 'black', width: '100%', maxWidth: '900px', height: '80vh', borderRadius: '12px', overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center', border: '1px solid rgba(255,255,255,0.2)', boxShadow: '0 20px 50px rgba(0,0,0,0.5)' }} onClick={e => e.stopPropagation()}>
             {/* Map scan name to the correct mock image */}
             <img 
               src={viewScan.includes('MRI') ? "/mock_knee_mri.jpg" : "/mock_ecg.jpg"} 
               alt="Medical Scan" 
               style={{ width: '100%', height: '100%', objectFit: 'contain' }} 
             />
          </div>
        </div>
      )}

    </div>
  );
}
