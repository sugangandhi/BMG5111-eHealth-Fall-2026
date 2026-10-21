import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { 
  Users, FileText, Activity, Clock, Paperclip, X, Download, Printer, 
  ShieldCheck, ExternalLink, TrendingUp, Sparkles, Award, Mic, Scan, 
  Zap, MessageSquare, ChevronRight, Stethoscope, CheckCircle2, MessageCircle,
  Watch, ChevronDown, ChevronUp, Calendar
} from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import AppleWatchVitals from './AppleWatchVitals';

const WEEKLY_TREND = [
  { day: 'Mon', hoursSaved: 2.5, patients: 32 },
  { day: 'Tue', hoursSaved: 3.1, patients: 38 },
  { day: 'Wed', hoursSaved: 3.8, patients: 42 },
  { day: 'Thu', hoursSaved: 4.2, patients: 45 },
  { day: 'Fri', hoursSaved: 5.0, patients: 51 },
  { day: 'Sat', hoursSaved: 1.5, patients: 15 },
  { day: 'Sun', hoursSaved: 1.0, patients: 12 }
];

const CustomTooltip = ({ active, payload, label }) => {
  if (active && payload && payload.length) {
    return (
      <div style={{ background: '#ffffff', border: '1px solid #bfdbfe', padding: '12px 16px', borderRadius: '10px', boxShadow: '0 4px 15px rgba(15, 23, 42, 0.08)' }}>
        <p style={{ margin: '0 0 8px 0', fontWeight: '700', color: '#0f172a', fontSize: '13px' }}>{label} Productivity</p>
        {payload.map((entry, index) => (
          <p key={index} style={{ margin: '4px 0', color: entry.color, fontSize: '12px', display: 'flex', justifyContent: 'space-between', gap: '16px' }}>
            <span>{entry.name}:</span> <strong style={{ color: '#0f172a' }}>{entry.value}</strong>
          </p>
        ))}
      </div>
    );
  }
  return null;
};

const ROI_BENCHMARKS = {
  "Orthopaedics": {
    title: "Office clinics were faster, fuller, and more productive after Prime Care AI",
    subtitle: "Pre/post comparison of an orthopaedic office practice before and after AI documentation implementation.",
    stats: [
      { value: "+79%", label: "total billed / clinic", color: "#2563eb" },
      { value: "+61%", label: "patients / clinic", color: "#2563eb" },
      { value: "+102%", label: "billing / clinic hour", color: "#2563eb" },
      { value: "-100%", label: "after-clinic documentation", color: "#059669" },
    ],
    quote: "Evening and after-clinic documentation time was reduced to zero following Prime Care AI implementation.",
    bars: [
      { label: "Total billed / clinic", pre: "Baseline Rate", post: "+79% Optimized Revenue", preWidth: 55, postWidth: 92 },
      { label: "Patients / clinic", pre: "13.2 pts", post: "21.2 pts (+61%)", preWidth: 50, postWidth: 85 },
      { label: "Total clinic minutes", pre: "274 min", post: "244 min (-11%)", preWidth: 85, postWidth: 70 },
      { label: "Billing / clinic hour", pre: "Standard RVU", post: "+102% RVU Efficiency", preWidth: 48, postWidth: 96 },
      { label: "After-clinic documentation / clinic", pre: "30 min evening charting", post: "0 min (-100%)", preWidth: 60, postWidth: 4 },
    ]
  },
  "Cardiology": {
    title: "Cardiovascular consults achieved record STAT turnaround times with AI Triage",
    subtitle: "Pre/post comparison of outpatient cardiology diagnostic analysis and telemetry review efficiency.",
    stats: [
      { value: "+84%", label: "total billed / clinic", color: "#2563eb" },
      { value: "+55%", label: "ECG & ECHO reviews / clinic", color: "#2563eb" },
      { value: "+115%", label: "RVU billing efficiency", color: "#2563eb" },
      { value: "-100%", label: "after-hours dictation backlog", color: "#059669" },
    ],
    quote: "Cardiologists regained an average of 6.5 hours of personal evening time per week while expediting STAT CCU referrals.",
    bars: [
      { label: "Total billed / clinic", pre: "Baseline Rate", post: "+84% Revenue Capture", preWidth: 52, postWidth: 94 },
      { label: "Diagnostic ECG reviews / clinic", pre: "18.4 reviews", post: "28.5 reviews (+55%)", preWidth: 58, postWidth: 90 },
      { label: "Average patient consult cycle", pre: "42 mins", post: "28 mins (-33%)", preWidth: 80, postWidth: 52 },
      { label: "Billing & coding per clinical hour", pre: "Manual coding", post: "+115% Automated ICD-10", preWidth: 45, postWidth: 96 },
      { label: "After-clinic EHR documentation", pre: "45 min dictation", post: "0 min (-100%)", preWidth: 65, postWidth: 4 },
    ]
  },
  "Oncology": {
    title: "Oncology tumor boards maximized direct patient clinical empathy and care delivery",
    subtitle: "Pre/post clinical trial matching and chemotherapy documentation review across oncology outpatient clinics.",
    stats: [
      { value: "+92%", label: "biopath review throughput", color: "#2563eb" },
      { value: "+48%", label: "patient consultations / day", color: "#2563eb" },
      { value: "+120%", label: "trial matching accuracy", color: "#2563eb" },
      { value: "-100%", label: "off-hours oncology charting", color: "#059669" },
    ],
    quote: "Zero after-hours administrative workload allows oncology teams to prioritize face-to-face patient clinical empathy.",
    bars: [
      { label: "Complex molecular case reviews", pre: "8.1 cases", post: "15.6 cases (+92%)", preWidth: 50, postWidth: 92 },
      { label: "Daily patient consults", pre: "10.5 pts", post: "15.6 pts (+48%)", preWidth: 58, postWidth: 86 },
      { label: "Pre-auth billing approval time", pre: "4.5 days", post: "1.2 days (-73%)", preWidth: 88, postWidth: 28 },
      { label: "Clinical trial criteria evaluation", pre: "Manual review", post: "+120% Instant Match", preWidth: 45, postWidth: 95 },
      { label: "After-clinic pathology reporting", pre: "52 min paperwork", post: "0 min (-100%)", preWidth: 72, postWidth: 4 },
    ]
  }
};

export default function Dashboard() {
  const [stats, setStats] = useState(null);
  const [selectedSpecialty, setSelectedSpecialty] = useState("Orthopaedics");
  const [activities, setActivities] = useState([]);
  const [appointments, setAppointments] = useState([]);
  const [editingAppt, setEditingAppt] = useState(null);
  const [selectedActivity, setSelectedActivity] = useState(null);
  const [actionMessage, setActionMessage] = useState(null);
  const [isOffline, setIsOffline] = useState(false);
  const [patientsList, setPatientsList] = useState([]);
  const [showAnalytics, setShowAnalytics] = useState(false);
  
  const token = localStorage.getItem('medoffice_token');

  const fetchDashboardData = async () => {
    if (isOffline) return;
    try {
      const headers = { Authorization: `Bearer ${token}` };
      const [statsRes, actRes, apptsRes, patientsRes] = await Promise.all([
        axios.get('/api/dashboard/stats', { headers }),
        axios.get('/api/activity', { headers }),
        axios.get('/api/appointments', { headers }),
        axios.get('/api/patients', { headers }).catch(() => ({ data: { patients: [] } }))
      ]);
      setStats(statsRes.data);
      setActivities(actRes.data.items);
      setAppointments(apptsRes.data.appointments);
      if (patientsRes.data?.patients) {
        setPatientsList(patientsRes.data.patients);
      }
    } catch (err) {
      console.error("Dashboard error:", err);
    }
  };

  useEffect(() => {
    fetchDashboardData();

    const handleVoiceCommand = (e) => {
      const { action, target } = e.detail;
      if (action === 'click_case') {
        if (target === 'oncology') setSelectedSpecialty('Oncology');
        if (target === 'cardiology') setSelectedSpecialty('Cardiology');
        if (target === 'orthopaedics') setSelectedSpecialty('Orthopaedics');
      }
    };

    window.addEventListener('voice-command', handleVoiceCommand);
    return () => window.removeEventListener('voice-command', handleVoiceCommand);
  }, [token]);

  const handleDelete = async (id) => {
    if (!window.confirm("Are you sure you want to cancel this appointment?")) return;
    try {
      await axios.delete(`/api/appointments/${id}`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      fetchDashboardData();
    } catch (err) {
      console.error(err);
    }
  };

  const handleUpdate = async () => {
    if (!editingAppt) return;
    try {
      await axios.put(`/api/appointments/${editingAppt.id}`, {
        appointment_date: editingAppt.appointment_date,
        time: editingAppt.time,
        type: editingAppt.type
      }, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setEditingAppt(null);
      fetchDashboardData();
    } catch (err) {
      console.error(err);
    }
  };

  const triggerExport = (label) => {
    setActionMessage(`${label} initiated for clinical attachment!`);
    setTimeout(() => setActionMessage(null), 3000);
  };

  const startEncounter = (appt) => {
    const matched = patientsList.find(p => p.id === appt.patient_id || (p.name && p.name.toLowerCase() === appt.patient_name.toLowerCase()));
    const patientContext = {
      id: matched?.id || appt.patient_id || 'pt-001',
      name: appt.patient_name,
      initials: appt.initials,
      dob: matched?.birthDate || "1981-04-14",
      phone: matched?.phone || "613-555-0192",
      mrn: matched?.mrn || `MRN-${Math.floor(1000 + Math.random() * 9000)}`,
      allergies: matched?.allergies || (appt.patient_name.includes("Doe") ? "Penicillin" : "NKDA"),
      codeStatus: "Full Code"
    };
    try {
      localStorage.setItem('active_patient_context', JSON.stringify(patientContext));
    } catch (e) {}
    window.dispatchEvent(new CustomEvent('set-active-patient', { detail: patientContext }));
    window.dispatchEvent(new CustomEvent('open-scribe', { detail: { patient: patientContext } }));
  };

  const user = JSON.parse(localStorage.getItem('medoffice_user')) || { name: 'Clinician' };
  const upNextAppt = appointments.find(a => a.status !== 'completed') || appointments[0];

  let storedActivePatient = null;
  try {
    storedActivePatient = JSON.parse(localStorage.getItem('active_patient_context') || 'null');
  } catch (e) {}
  
  const currentWatchPatient = storedActivePatient || (upNextAppt ? {
    name: upNextAppt.patient_name,
    mrn: upNextAppt.mrn || 'MRN-4821',
    initials: upNextAppt.initials
  } : { name: 'John Doe', mrn: 'MRN-1002' });

  if (!stats && !isOffline) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>
        <div style={{ display: 'inline-block', width: '30px', height: '30px', border: '3px solid #bfdbfe', borderTopColor: '#2563eb', borderRadius: '50%', animation: 'spin 1s linear infinite' }} />
        <p style={{ marginTop: '12px', fontSize: '14px', fontWeight: '500' }}>Loading clinic workspace...</p>
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px', paddingBottom: '32px' }}>
      
      {/* Action Notification Banner */}
      {actionMessage && (
        <div style={{ padding: '12px 18px', background: '#eff6ff', border: '1px solid #bfdbfe', color: '#1d4ed8', borderRadius: '10px', display: 'flex', alignItems: 'center', gap: '10px', fontWeight: '600', fontSize: '13px' }}>
          <CheckCircle2 size={16} color="#2563eb" /> {actionMessage}
        </div>
      )}

      {/* ── DESKTOP CLINIC WORKSPACE ─────────────────────────────────────── */}
      <div className="desktop-only" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        
        {/* Workspace Title & Live Connection Status */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h1 style={{ margin: 0, fontSize: '22px', fontWeight: '700', color: '#0f172a' }}>
              Clinic Workspace
            </h1>
            <p style={{ margin: '3px 0 0 0', fontSize: '13px', color: '#64748b' }}>
              Physician schedule, Apple Watch telemetry & ambient documentation
            </p>
          </div>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <span style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px',
              padding: '6px 12px',
              borderRadius: '20px',
              background: '#eff6ff',
              border: '1px solid #bfdbfe',
              color: '#1d4ed8',
              fontSize: '12px',
              fontWeight: '600'
            }}>
              <span style={{ width: '7px', height: '7px', borderRadius: '50%', background: '#2563eb' }} />
              Live EHR & Wearables Connected
            </span>
          </div>
        </div>

        {/* 4 Clean Metric Cards (Blue & White) */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '14px' }}>
          <MetricCard title="Patients Seen" value={stats?.patients_today || 0} icon={<Users size={20} />} subtitle="Today's encounters" />
          <MetricCard title="Automated Forms" value={stats?.forms_today || 0} icon={<FileText size={20} />} subtitle="100% Zero-Click" />
          <MetricCard title="Pending Triage" value={stats?.pending_referrals || 0} icon={<Activity size={20} />} subtitle="Incoming referrals" />
          <MetricCard title="Time Saved" value={`${stats?.time_saved_min || 0}m`} icon={<Clock size={20} />} subtitle="Ambient AI dictation" />
        </div>

        {/* Primary Row: Up Next Patient + Apple Watch Vitals Integration */}
        <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 1.6fr', gap: '18px', alignItems: 'stretch' }}>
          
          {/* Left: Up Next Patient Card & Schedule */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            
            {/* Up Next Patient Hero */}
            {upNextAppt ? (
              <div style={{
                background: '#ffffff',
                border: '1px solid #bfdbfe',
                borderRadius: '14px',
                padding: '20px',
                boxShadow: '0 1px 3px rgba(37, 99, 235, 0.05)',
                display: 'flex',
                flexDirection: 'column',
                gap: '14px'
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{
                    fontSize: '11px',
                    fontWeight: '700',
                    color: '#2563eb',
                    background: '#eff6ff',
                    padding: '3px 10px',
                    borderRadius: '12px',
                    border: '1px solid #dbeafe',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '5px'
                  }}>
                    <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#2563eb' }} />
                    UP NEXT IN CLINIC
                  </span>
                  <span style={{ fontSize: '13px', fontWeight: '700', color: '#0f172a' }}>
                    {upNextAppt.time}
                  </span>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                  <div style={{
                    width: '46px',
                    height: '46px',
                    borderRadius: '50%',
                    background: '#2563eb',
                    color: '#ffffff',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: '700',
                    fontSize: '16px',
                    flexShrink: 0
                  }}>
                    {upNextAppt.initials || 'PT'}
                  </div>
                  <div>
                    <h3 style={{ margin: 0, fontSize: '17px', fontWeight: '700', color: '#0f172a' }}>
                      {upNextAppt.patient_name}
                    </h3>
                    <p style={{ margin: '2px 0 0 0', fontSize: '13px', color: '#64748b' }}>
                      {upNextAppt.type} · Room 3B
                    </p>
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '10px', paddingTop: '4px' }}>
                  <button
                    onClick={() => startEncounter(upNextAppt)}
                    style={{
                      flex: 1,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: '8px',
                      background: '#2563eb',
                      color: '#ffffff',
                      border: 'none',
                      padding: '10px 16px',
                      borderRadius: '8px',
                      fontWeight: '600',
                      fontSize: '13px',
                      cursor: 'pointer',
                      transition: 'background 0.15s'
                    }}
                  >
                    <Mic size={16} /> Start AI Scribe Encounter
                  </button>
                  <button
                    onClick={() => {
                      const matched = patientsList.find(p => p.id === upNextAppt.patient_id || p.name === upNextAppt.patient_name);
                      window.dispatchEvent(new CustomEvent('open-whatsapp', { detail: { patient: matched || upNextAppt } }));
                    }}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      background: '#f8fafc',
                      color: '#0f172a',
                      border: '1px solid #e2e8f0',
                      padding: '10px 14px',
                      borderRadius: '8px',
                      fontWeight: '600',
                      fontSize: '13px',
                      cursor: 'pointer'
                    }}
                    title="Message patient on WhatsApp"
                  >
                    <MessageCircle size={16} color="#059669" /> WhatsApp
                  </button>

                  <button
                    onClick={() => window.dispatchEvent(new CustomEvent('open-apple-watch', { detail: { patient: upNextAppt } }))}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      background: '#eff6ff',
                      color: '#2563eb',
                      border: '1px solid #bfdbfe',
                      padding: '10px 14px',
                      borderRadius: '8px',
                      fontWeight: '600',
                      fontSize: '13px',
                      cursor: 'pointer'
                    }}
                    title="View live Apple Watch & HealthKit vitals"
                  >
                    <Watch size={16} /> Watch Vitals
                  </button>
                </div>
              </div>
            ) : null}

            {/* Today's Appointments List */}
            <div style={{
              background: '#ffffff',
              border: '1px solid #e2e8f0',
              borderRadius: '14px',
              padding: '20px',
              boxShadow: '0 1px 3px rgba(15, 23, 42, 0.04)',
              flex: 1
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' }}>
                <h3 style={{ margin: 0, fontSize: '15px', fontWeight: '700', color: '#0f172a', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Calendar size={17} color="#2563eb" /> Today's Clinical Schedule
                </h3>
                <span style={{ fontSize: '12px', color: '#64748b' }}>{appointments.length} scheduled</span>
              </div>

              {appointments.length === 0 ? (
                <p style={{ color: '#64748b', fontSize: '13px', margin: '20px 0', textAlign: 'center' }}>No appointments scheduled for today.</p>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  {appointments.slice(0, 6).map(a => (
                    <div key={a.id} style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '10px 12px',
                      background: '#f8fafc',
                      border: '1px solid #e2e8f0',
                      borderRadius: '8px'
                    }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
                        <div style={{
                          width: '32px',
                          height: '32px',
                          borderRadius: '50%',
                          background: '#eff6ff',
                          color: '#2563eb',
                          border: '1px solid #bfdbfe',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontSize: '12px',
                          fontWeight: '700',
                          flexShrink: 0
                        }}>
                          {a.initials}
                        </div>
                        <div style={{ minWidth: 0 }}>
                          <h4 style={{ margin: 0, fontSize: '13px', fontWeight: '600', color: '#0f172a', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                            {a.patient_name}
                          </h4>
                          <span style={{ fontSize: '11px', color: '#64748b' }}>{a.time} · {a.type}</span>
                        </div>
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <button
                          onClick={() => window.dispatchEvent(new CustomEvent('open-apple-watch', { detail: { patient: a } }))}
                          style={{
                            background: '#ffffff',
                            border: '1px solid #bfdbfe',
                            color: '#2563eb',
                            borderRadius: '6px',
                            padding: '4px 8px',
                            fontSize: '11px',
                            fontWeight: '600',
                            cursor: 'pointer',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '4px'
                          }}
                          title={`Inspect ${a.patient_name}'s Apple Watch telemetry`}
                        >
                          <Watch size={13} /> Watch
                        </button>
                        <button
                          onClick={() => startEncounter(a)}
                          style={{
                            background: '#eff6ff',
                            border: '1px solid #bfdbfe',
                            color: '#2563eb',
                            borderRadius: '6px',
                            padding: '4px 10px',
                            fontSize: '12px',
                            fontWeight: '600',
                            cursor: 'pointer'
                          }}
                        >
                          Encounter
                        </button>
                        <button
                          onClick={() => setEditingAppt({ ...a })}
                          style={{
                            background: 'transparent',
                            border: 'none',
                            color: '#64748b',
                            fontSize: '12px',
                            cursor: 'pointer',
                            padding: '4px 6px'
                          }}
                        >
                          Edit
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

          </div>

          {/* Right: Live Clinical Activity & Practice Analytics */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            
            {/* Live Clinical Activity Stream */}
            <div style={{
              background: '#ffffff',
              border: '1px solid #e2e8f0',
              borderRadius: '14px',
              padding: '20px',
              boxShadow: '0 1px 3px rgba(15, 23, 42, 0.04)',
              flex: 1
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '14px' }}>
                <h3 style={{ margin: 0, fontSize: '15px', fontWeight: '700', color: '#0f172a', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Activity size={17} color="#2563eb" /> Recent Clinical Activity
                </h3>
                <span style={{ fontSize: '11px', color: '#64748b' }}>Click item to view attachment</span>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {activities.slice(0, 6).map(act => (
                  <div
                    key={act.id}
                    onClick={() => setSelectedActivity(act)}
                    style={{
                      padding: '10px 12px',
                      background: '#f8fafc',
                      border: '1px solid #e2e8f0',
                      borderRadius: '8px',
                      cursor: 'pointer',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      transition: 'background 0.15s, border-color 0.15s'
                    }}
                    onMouseEnter={(e) => { e.currentTarget.style.background = '#eff6ff'; e.currentTarget.style.borderColor = '#bfdbfe'; }}
                    onMouseLeave={(e) => { e.currentTarget.style.background = '#f8fafc'; e.currentTarget.style.borderColor = '#e2e8f0'; }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                      <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: '#2563eb' }} />
                      <div>
                        <p style={{ margin: 0, fontSize: '12px', fontWeight: '600', color: '#0f172a' }}>{act.description}</p>
                        <p style={{ margin: 0, fontSize: '11px', color: '#64748b' }}>
                          {act.patient_name || "General Clinic"} · {Math.floor(act.secs_ago / 60)}m ago
                        </p>
                      </div>
                    </div>
                    <span style={{ fontSize: '11px', color: '#2563eb', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '4px' }}>
                      <Paperclip size={12} /> View
                    </span>
                  </div>
                ))}
              </div>
            </div>

          </div>

        </div>

        {/* Collapsible Clinical Analytics & Practice Insights Section */}
        <div style={{
          background: '#ffffff',
          border: '1px solid #e2e8f0',
          borderRadius: '14px',
          overflow: 'hidden',
          boxShadow: '0 1px 3px rgba(15, 23, 42, 0.04)'
        }}>
          <button
            onClick={() => setShowAnalytics(!showAnalytics)}
            style={{
              width: '100%',
              padding: '14px 20px',
              background: '#f8fafc',
              border: 'none',
              borderBottom: showAnalytics ? '1px solid #e2e8f0' : 'none',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              cursor: 'pointer',
              color: '#0f172a',
              fontSize: '14px',
              fontWeight: '600'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <TrendingUp size={18} color="#2563eb" />
              <span>Practice Analytics & Documentation Efficiency Trends</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#64748b', fontSize: '12px' }}>
              <span>{showAnalytics ? 'Hide Trends' : 'View 7-Day Trend'}</span>
              {showAnalytics ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
            </div>
          </button>

          {showAnalytics && (
            <div style={{ padding: '24px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px' }}>
                <div>
                  <h4 style={{ margin: 0, fontSize: '15px', fontWeight: '700', color: '#0f172a' }}>7-Day Clinical Volume & Admin Hours Saved</h4>
                  <p style={{ margin: '2px 0 0 0', fontSize: '12px', color: '#64748b' }}>Automated telemetry & ambient voice transcription metrics</p>
                </div>
              </div>

              <div style={{ width: '100%', height: '240px' }}>
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={WEEKLY_TREND} margin={{ top: 10, right: 20, left: 0, bottom: 0 }}>
                    <defs>
                      <linearGradient id="colorHours" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#2563eb" stopOpacity={0.2}/>
                        <stop offset="95%" stopColor="#2563eb" stopOpacity={0}/>
                      </linearGradient>
                      <linearGradient id="colorPatients" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#0284c7" stopOpacity={0.2}/>
                        <stop offset="95%" stopColor="#0284c7" stopOpacity={0}/>
                      </linearGradient>
                    </defs>
                    <XAxis dataKey="day" stroke="#94a3b8" tick={{ fill: '#64748b', fontSize: 11 }} tickLine={false} axisLine={false} />
                    <YAxis stroke="#94a3b8" tick={{ fill: '#64748b', fontSize: 11 }} tickLine={false} axisLine={false} />
                    <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
                    <Tooltip content={<CustomTooltip />} />
                    <Area type="monotone" dataKey="patients" name="Patients Seen" stroke="#0284c7" strokeWidth={2} fillOpacity={1} fill="url(#colorPatients)" />
                    <Area type="monotone" dataKey="hoursSaved" name="Admin Hours Saved" stroke="#2563eb" strokeWidth={2} fillOpacity={1} fill="url(#colorHours)" />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </div>
          )}
        </div>

      </div>
      {/* ── END DESKTOP CLINIC WORKSPACE ───────────────────────────────── */}

      {/* ── MOBILE CLINIC WORKSPACE ────────────────────────────────────── */}
      <div className="mobile-only" style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
        
        {/* Simple 4 Clinical Actions (Clean Blue & White) */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '8px' }}>
          <button 
            type="button"
            onClick={() => {
              let stored = null;
              try { stored = JSON.parse(localStorage.getItem('active_patient_context') || 'null'); } catch(e) {}
              window.dispatchEvent(new CustomEvent('open-scribe', { detail: { patient: stored } }));
            }}
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              padding: '12px 6px',
              background: '#ffffff',
              border: '1px solid #bfdbfe',
              borderRadius: '12px',
              cursor: 'pointer'
            }}
          >
            <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: '#eff6ff', color: '#2563eb', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Mic size={18} />
            </div>
            <span style={{ fontSize: '11px', fontWeight: '600', color: '#0f172a' }}>AI Scribe</span>
          </button>

          <button 
            type="button"
            onClick={() => window.dispatchEvent(new CustomEvent('open-scanner'))}
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              padding: '12px 6px',
              background: '#ffffff',
              border: '1px solid #e2e8f0',
              borderRadius: '12px',
              cursor: 'pointer'
            }}
          >
            <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: '#f8fafc', color: '#2563eb', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Scan size={18} />
            </div>
            <span style={{ fontSize: '11px', fontWeight: '600', color: '#0f172a' }}>OCR Scan</span>
          </button>

          <button 
            type="button"
            onClick={() => {
              const matched = patientsList.find(p => p.id === upNextAppt?.patient_id || (p.name && p.name.toLowerCase() === upNextAppt?.patient_name?.toLowerCase()));
              window.dispatchEvent(new CustomEvent('open-whatsapp', { detail: { patient: matched || upNextAppt } }));
            }}
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              padding: '12px 6px',
              background: '#ffffff',
              border: '1px solid #e2e8f0',
              borderRadius: '12px',
              cursor: 'pointer'
            }}
          >
            <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: '#f8fafc', color: '#059669', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <MessageCircle size={18} />
            </div>
            <span style={{ fontSize: '11px', fontWeight: '600', color: '#0f172a' }}>WhatsApp</span>
          </button>

          <button 
            type="button"
            onClick={() => window.dispatchEvent(new CustomEvent('switch-tab', { detail: 'referral' }))}
            style={{
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              padding: '12px 6px',
              background: '#ffffff',
              border: '1px solid #e2e8f0',
              borderRadius: '12px',
              cursor: 'pointer'
            }}
          >
            <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: '#f8fafc', color: '#2563eb', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <Zap size={18} />
            </div>
            <span style={{ fontSize: '11px', fontWeight: '600', color: '#0f172a' }}>AI Triage</span>
          </button>
        </div>

        {/* Up Next Patient Hero Card */}
        {upNextAppt && (
          <div style={{
            background: '#ffffff',
            border: '1px solid #bfdbfe',
            borderRadius: '14px',
            padding: '16px',
            boxShadow: '0 1px 3px rgba(37, 99, 235, 0.05)',
            display: 'flex',
            flexDirection: 'column',
            gap: '12px'
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '11px', fontWeight: '700', color: '#2563eb', background: '#eff6ff', padding: '2px 8px', borderRadius: '10px' }}>
                UP NEXT IN CLINIC
              </span>
              <span style={{ fontSize: '12px', fontWeight: '700', color: '#0f172a' }}>{upNextAppt.time}</span>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <div style={{ width: '42px', height: '42px', borderRadius: '50%', background: '#2563eb', color: '#ffffff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '700', fontSize: '15px' }}>
                {upNextAppt.initials || 'PT'}
              </div>
              <div>
                <h3 style={{ margin: 0, fontSize: '16px', fontWeight: '700', color: '#0f172a' }}>{upNextAppt.patient_name}</h3>
                <p style={{ margin: '1px 0 0 0', fontSize: '12px', color: '#64748b' }}>{upNextAppt.type}</p>
              </div>
            </div>

            <div style={{ display: 'flex', gap: '8px' }}>
              <button
                onClick={() => startEncounter(upNextAppt)}
                style={{
                  flex: 1,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '6px',
                  background: '#2563eb',
                  color: '#ffffff',
                  border: 'none',
                  padding: '10px 12px',
                  borderRadius: '8px',
                  fontWeight: '600',
                  fontSize: '13px',
                  cursor: 'pointer'
                }}
              >
                <Mic size={15} /> Start AI Scribe
              </button>
              <button
                onClick={() => window.dispatchEvent(new CustomEvent('open-apple-watch', { detail: { patient: upNextAppt } }))}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '6px',
                  background: '#eff6ff',
                  color: '#2563eb',
                  border: '1px solid #bfdbfe',
                  padding: '10px 14px',
                  borderRadius: '8px',
                  fontWeight: '600',
                  fontSize: '13px',
                  cursor: 'pointer'
                }}
                title="View Apple Watch vitals"
              >
                <Watch size={15} /> Watch
              </button>
            </div>
          </div>
        )}

        {/* Schedule List (Mobile) */}
        <div style={{
          background: '#ffffff',
          border: '1px solid #e2e8f0',
          borderRadius: '14px',
          padding: '16px'
        }}>
          <h3 style={{ margin: '0 0 12px 0', fontSize: '14px', fontWeight: '700', color: '#0f172a' }}>
            Today's Schedule ({appointments.length})
          </h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
            {appointments.map(a => (
              <div key={a.id} style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '10px',
                background: '#f8fafc',
                border: '1px solid #e2e8f0',
                borderRadius: '8px'
              }}>
                <div>
                  <h4 style={{ margin: 0, fontSize: '13px', fontWeight: '600', color: '#0f172a' }}>{a.patient_name}</h4>
                  <span style={{ fontSize: '11px', color: '#64748b' }}>{a.time} · {a.type}</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <button
                    onClick={() => window.dispatchEvent(new CustomEvent('open-apple-watch', { detail: { patient: a } }))}
                    style={{
                      background: '#ffffff',
                      border: '1px solid #bfdbfe',
                      color: '#2563eb',
                      padding: '4px 8px',
                      borderRadius: '6px',
                      fontSize: '11px',
                      fontWeight: '600',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '3px'
                    }}
                  >
                    <Watch size={11} /> Watch
                  </button>
                  <button
                    onClick={() => startEncounter(a)}
                    style={{
                      background: '#eff6ff',
                      border: '1px solid #bfdbfe',
                      color: '#2563eb',
                      padding: '4px 8px',
                      borderRadius: '6px',
                      fontSize: '11px',
                      fontWeight: '600',
                      cursor: 'pointer'
                    }}
                  >
                    Start
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>

      </div>
      {/* ── END MOBILE CLINIC WORKSPACE ─────────────────────────────────── */}

      {/* Appointment Edit Modal */}
      {editingAppt && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(15, 23, 42, 0.6)', backdropFilter: 'blur(3px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '16px' }}>
          <div style={{ background: '#ffffff', border: '1px solid #e2e8f0', borderRadius: '14px', padding: '24px', width: '420px', maxWidth: '100%', boxShadow: '0 10px 30px rgba(15, 23, 42, 0.15)', display: 'flex', flexDirection: 'column', gap: '14px' }}>
            <h3 style={{ margin: 0, color: '#0f172a', fontSize: '16px', fontWeight: '700' }}>Edit Appointment</h3>
            
            <div>
              <label style={{ fontSize: '12px', color: '#64748b', fontWeight: '600', display: 'block', marginBottom: '4px' }}>Date</label>
              <input type="date" className="input" value={editingAppt.appointment_date} onChange={e => setEditingAppt({...editingAppt, appointment_date: e.target.value})} />
            </div>
            
            <div>
              <label style={{ fontSize: '12px', color: '#64748b', fontWeight: '600', display: 'block', marginBottom: '4px' }}>Time</label>
              <input type="time" className="input" value={editingAppt.time} onChange={e => setEditingAppt({...editingAppt, time: e.target.value})} />
            </div>
            
            <div>
              <label style={{ fontSize: '12px', color: '#64748b', fontWeight: '600', display: 'block', marginBottom: '4px' }}>Appointment Type</label>
              <input type="text" className="input" value={editingAppt.type} onChange={e => setEditingAppt({...editingAppt, type: e.target.value})} />
            </div>
            
            <div style={{ display: 'flex', gap: '10px', marginTop: '8px' }}>
              <button className="btn btn-secondary" style={{ flex: 1 }} onClick={() => setEditingAppt(null)}>Cancel</button>
              <button className="btn btn-primary" style={{ flex: 1 }} onClick={handleUpdate}>Save Changes</button>
            </div>
          </div>
        </div>
      )}

      {/* Clinical Activity Attachment Modal */}
      {selectedActivity && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(15, 23, 42, 0.6)', backdropFilter: 'blur(3px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000, padding: '16px' }}>
          <div style={{ background: '#ffffff', border: '1px solid #e2e8f0', borderRadius: '14px', padding: '24px', width: '680px', maxWidth: '100%', maxHeight: '85vh', display: 'flex', flexDirection: 'column', gap: '16px', boxShadow: '0 10px 40px rgba(15, 23, 42, 0.15)' }}>
            
            {/* Modal Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid #e2e8f0', paddingBottom: '12px' }}>
              <div>
                <h3 style={{ margin: 0, color: '#0f172a', fontSize: '17px', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Paperclip size={18} color="#2563eb" /> Clinical Record Attachment
                </h3>
                <p style={{ margin: '2px 0 0', fontSize: '12px', color: '#64748b' }}>
                  Audit Trail ID: #{selectedActivity.id || '84291'} · Prime Care Verified
                </p>
              </div>
              <button onClick={() => setSelectedActivity(null)} style={{ background: 'none', border: 'none', color: '#64748b', cursor: 'pointer' }}>
                <X size={20} />
              </button>
            </div>

            {/* Audit Metadata Box */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px', background: '#f8fafc', padding: '12px 14px', borderRadius: '10px', border: '1px solid #e2e8f0' }}>
              <div>
                <span style={{ fontSize: '11px', color: '#64748b', fontWeight: '600', textTransform: 'uppercase', display: 'block' }}>Patient</span>
                <strong style={{ color: '#0f172a', fontSize: '13px' }}>{selectedActivity.patient_name || "General Clinic"}</strong>
              </div>
              <div>
                <span style={{ fontSize: '11px', color: '#64748b', fontWeight: '600', textTransform: 'uppercase', display: 'block' }}>Action</span>
                <span style={{ background: '#eff6ff', color: '#2563eb', padding: '2px 8px', borderRadius: '10px', fontSize: '11px', fontWeight: '600', display: 'inline-block', marginTop: '2px' }}>
                  {selectedActivity.action || "Clinical Processing"}
                </span>
              </div>
              <div>
                <span style={{ fontSize: '11px', color: '#64748b', fontWeight: '600', textTransform: 'uppercase', display: 'block' }}>Verification</span>
                <span style={{ color: '#059669', fontSize: '12px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '4px', marginTop: '2px' }}>
                  <ShieldCheck size={14} /> Signed
                </span>
              </div>
            </div>

            {/* Attachment Content */}
            <div style={{ flex: 1, overflowY: 'auto', background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: '10px', padding: '18px', fontFamily: 'monospace', fontSize: '13px', color: '#334155', lineHeight: '1.6' }}>
              <div style={{ borderBottom: '1px dashed #cbd5e1', paddingBottom: '8px', marginBottom: '12px', color: '#64748b', fontSize: '11px', display: 'flex', justifyContent: 'space-between' }}>
                <span>RECORD: {selectedActivity.description.toUpperCase().replace(/\s+/g, '_')}.PDF</span>
                <span>{new Date().toLocaleDateString()}</span>
              </div>

              <div style={{ whiteSpace: 'pre-wrap' }}>
                {selectedActivity.detail ? (
                  <>
                    <p style={{ color: '#2563eb', fontWeight: '700' }}>--- CLINICAL OBSERVATIONS & DATA ---</p>
                    {selectedActivity.detail}
                    {"\n\n"}
                    <p style={{ color: '#059669' }}>[AUTOMATICALLY FILED BY PRIME CARE HEALTH SYSTEM AI CO-PILOT]</p>
                  </>
                ) : (
                  <>
                    <p style={{ color: '#2563eb', fontWeight: '700' }}>--- STANDARD CLINICAL ENCOUNTER ATTACHMENT ---</p>
                    {`Patient Activity: ${selectedActivity.description}\nMedical Facility: Prime Care Central Campus\nPrimary Attending Provider: Authorized Clinician\n\n[RECORD SUMMARY]\nThis attachment confirms the automated diagnostic evaluations, triage rules, and structured EHR updates performed under protocol ID #${Math.floor(1000 + Math.random() * 9000)}.\n\n[CLINICAL ATTESTATION]\nAll associated data fields have been synchronized with the centralized hospital database.`}
                  </>
                )}
              </div>
            </div>

            {/* Footer Buttons */}
            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end', borderTop: '1px solid #e2e8f0', paddingTop: '12px' }}>
              <button 
                type="button"
                className="btn btn-secondary" 
                onClick={() => triggerExport('Document print job')}
              >
                <Printer size={15} /> Print
              </button>

              <button 
                type="button"
                className="btn btn-primary" 
                onClick={() => triggerExport('PDF download')}
              >
                <Download size={15} /> Download PDF
              </button>

              <button 
                type="button"
                className="btn btn-secondary" 
                onClick={() => setSelectedActivity(null)}
              >
                Close
              </button>
            </div>

          </div>
        </div>
      )}

    </div>
  );
}

function MetricCard({ title, value, icon, subtitle }) {
  return (
    <div style={{
      background: '#ffffff',
      border: '1px solid #e2e8f0',
      borderRadius: '12px',
      padding: '16px 18px',
      boxShadow: '0 1px 3px rgba(15, 23, 42, 0.04)',
      display: 'flex',
      alignItems: 'center',
      gap: '14px'
    }}>
      <div style={{
        width: '42px',
        height: '42px',
        borderRadius: '10px',
        background: '#eff6ff',
        border: '1px solid #bfdbfe',
        color: '#2563eb',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0
      }}>
        {icon}
      </div>
      <div style={{ minWidth: 0 }}>
        <p style={{ margin: 0, fontSize: '12px', color: '#64748b', fontWeight: '500' }}>{title}</p>
        <h3 style={{ margin: '2px 0 0 0', fontSize: '22px', fontWeight: '800', color: '#0f172a' }}>{value}</h3>
        {subtitle && <p style={{ margin: '1px 0 0 0', fontSize: '11px', color: '#94a3b8' }}>{subtitle}</p>}
      </div>
    </div>
  );
}
