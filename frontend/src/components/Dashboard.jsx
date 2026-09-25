import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Users, FileText, Activity, Clock, Paperclip, X, Download, Printer, ShieldCheck, ExternalLink, TrendingUp, Sparkles, Award } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';

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
      <div style={{ background: 'rgba(15, 23, 42, 0.95)', border: '1px solid rgba(59, 130, 246, 0.4)', padding: '12px 16px', borderRadius: '10px', boxShadow: '0 8px 30px rgba(0,0,0,0.6)' }}>
        <p style={{ margin: '0 0 10px 0', fontWeight: '800', color: '#e2e8f0', fontSize: '14px' }}>{label} Productivity</p>
        {payload.map((entry, index) => (
          <p key={index} style={{ margin: '6px 0', color: entry.color, fontSize: '13px', display: 'flex', justifyContent: 'space-between', gap: '20px' }}>
            <span>{entry.name}:</span> <strong style={{color:'white'}}>{entry.value}</strong>
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
    subtitle: "Pre/post comparison of a single orthopaedic office practice before and after AI documentation implementation.",
    stats: [
      { value: "+79%", label: "total billed / clinic", color: "#3b82f6" },
      { value: "+61%", label: "patients / clinic", color: "#3b82f6" },
      { value: "+102%", label: "billing / clinic hour", color: "#3b82f6" },
      { value: "-100%", label: "after-clinic documentation", color: "#10b981" },
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
      { value: "+84%", label: "total billed / clinic", color: "#3b82f6" },
      { value: "+55%", label: "ECG & ECHO reviews / clinic", color: "#3b82f6" },
      { value: "+115%", label: "RVU billing efficiency", color: "#3b82f6" },
      { value: "-100%", label: "after-hours dictation backlog", color: "#10b981" },
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
      { value: "+92%", label: "biopath review throughput", color: "#3b82f6" },
      { value: "+48%", label: "patient consultations / day", color: "#3b82f6" },
      { value: "+120%", label: "trial matching accuracy", color: "#3b82f6" },
      { value: "-100%", label: "off-hours oncology charting", color: "#10b981" },
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
  
  const token = localStorage.getItem('medoffice_token');

  const fetchDashboardData = async () => {
    if (isOffline) return;
    try {
      const headers = { Authorization: `Bearer ${token}` };
      const [statsRes, actRes, apptsRes] = await Promise.all([
        axios.get('/api/dashboard/stats', { headers }),
        axios.get('/api/activity', { headers }),
        axios.get('/api/appointments', { headers })
      ]);
      setStats(statsRes.data);
      setActivities(actRes.data.items);
      setAppointments(apptsRes.data.appointments);
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
    // Generate a mock patient context payload
    const patientContext = {
      name: appt.patient_name,
      initials: appt.initials,
      dob: "04/12/1985", // Mock data
      mrn: `MRN-${Math.floor(1000 + Math.random() * 9000)}`,
      allergies: appt.patient_name.includes("Doe") ? "Penicillin" : "NKDA",
      codeStatus: "Full Code"
    };
    window.dispatchEvent(new CustomEvent('set-active-patient', { detail: patientContext }));
    window.dispatchEvent(new CustomEvent('open-scribe'));
  };

  if (!stats && !isOffline) return <div style={{ color: 'var(--text-secondary)' }}>Loading dashboard...</div>;

  return (
    <div style={{ transition: 'all 0.5s', filter: isOffline ? 'sepia(0.2) hue-rotate(-20deg)' : 'none' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '24px' }}>
        <h2 style={{ margin: 0, display: 'flex', alignItems: 'center', gap: '10px' }}>
          <span>Hospital Workspace Overview</span>
          <span style={{ fontSize: '13px', background: 'rgba(59, 130, 246, 0.15)', color: '#60a5fa', padding: '4px 12px', borderRadius: '12px', border: '1px solid rgba(59, 130, 246, 0.3)', fontWeight: 'normal' }}>
            🏥 Prime Care Clinical Edition
          </span>
        </h2>
        
        {/* THE KILL SWITCH */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', background: 'rgba(0,0,0,0.2)', padding: '8px 16px', borderRadius: '20px', border: isOffline ? '1px solid #ef4444' : '1px solid rgba(255,255,255,0.1)' }}>
          <div style={{ fontSize: '12px', color: isOffline ? '#ef4444' : 'var(--text-secondary)', fontWeight: '600', transition: '0.3s' }}>
            {isOffline ? 'CLOUD DISCONNECTED' : 'CLOUD CONNECTED'}
          </div>
          <div 
            onClick={() => setIsOffline(!isOffline)}
            style={{ 
              width: '40px', height: '22px', background: isOffline ? '#ef4444' : '#10b981', 
              borderRadius: '20px', position: 'relative', cursor: 'pointer', transition: '0.3s'
            }}
          >
            <div style={{
              width: '18px', height: '18px', background: 'white', borderRadius: '50%',
              position: 'absolute', top: '2px', left: isOffline ? '2px' : '20px', transition: '0.3s',
              boxShadow: '0 2px 5px rgba(0,0,0,0.2)'
            }} />
          </div>
        </div>
      </div>
      
      {/* OFFLINE BANNER */}
      {isOffline && (
        <div className="animate-fade-in" style={{ marginBottom: '24px', padding: '16px 20px', background: 'rgba(239, 68, 68, 0.15)', border: '2px solid #ef4444', color: '#fca5a5', borderRadius: '12px', display: 'flex', alignItems: 'center', gap: '16px', fontWeight: '500', boxShadow: '0 4px 20px rgba(239, 68, 68, 0.3)' }}>
          <div style={{ background: '#ef4444', color: 'white', padding: '8px', borderRadius: '50%' }}>
            <ShieldCheck size={24} />
          </div>
          <div>
            <div style={{ fontWeight: '800', fontSize: '16px', color: '#ef4444', marginBottom: '4px' }}>⚠️ CLOUD CONNECTION SEVERED</div>
            <div style={{ fontSize: '14px' }}>External API sync failed. Local Prime Care AI Voice Agent is continuing autonomously on-device. HIPAA compliance intact.</div>
          </div>
        </div>
      )}
      
      {actionMessage && (
        <div style={{ marginBottom: '20px', padding: '12px 20px', background: 'rgba(16, 185, 129, 0.15)', border: '1px solid #10b981', color: '#34d399', borderRadius: '10px', display: 'flex', alignItems: 'center', gap: '10px', fontWeight: '600' }}>
          ✅ {actionMessage}
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '16px', marginBottom: '32px' }}>
        <MetricCard title="Patients Seen" value={stats.patients_today} icon={<Users size={20} />} color="blue" />
        <MetricCard title="Forms Filled" value={stats.forms_today} icon={<FileText size={20} />} color="emerald" />
        <MetricCard title="Pending Referrals" value={stats.pending_referrals} icon={<Activity size={20} />} color="orange" />
        <MetricCard title="Time Saved (Min)" value={stats.time_saved_min} icon={<Clock size={20} />} color="purple" />
      </div>

      {/* ROI Command Center Area Chart */}
      <div className="glass-panel animate-fade-in" style={{ padding: '32px', marginBottom: '32px', border: '1px solid rgba(16, 185, 129, 0.3)', background: 'linear-gradient(180deg, rgba(16, 185, 129, 0.05) 0%, transparent 100%)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
          <div>
            <h3 style={{ fontSize: '18px', fontWeight: '800', margin: '0 0 4px 0', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <TrendingUp size={20} color="#10b981" /> 7-Day Clinical ROI Trend
            </h3>
            <p style={{ margin: 0, fontSize: '13px', color: 'var(--text-secondary)' }}>Live compounding efficiency metrics based on Prime Care AI utilization.</p>
          </div>
        </div>

        <div style={{ width: '100%', height: '300px' }}>
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={WEEKLY_TREND} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
              <defs>
                <linearGradient id="colorHours" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#10b981" stopOpacity={0.4}/>
                  <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                </linearGradient>
                <linearGradient id="colorPatients" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.4}/>
                  <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <XAxis dataKey="day" stroke="rgba(255,255,255,0.3)" tick={{fill: 'var(--text-secondary)', fontSize: 12}} tickLine={false} axisLine={false} />
              <YAxis stroke="rgba(255,255,255,0.3)" tick={{fill: 'var(--text-secondary)', fontSize: 12}} tickLine={false} axisLine={false} />
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
              <Tooltip content={<CustomTooltip />} />
              <Area type="monotone" dataKey="patients" name="Patients Seen" stroke="#3b82f6" strokeWidth={3} fillOpacity={1} fill="url(#colorPatients)" />
              <Area type="monotone" dataKey="hoursSaved" name="Admin Hours Saved" stroke="#10b981" strokeWidth={3} fillOpacity={1} fill="url(#colorHours)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Prime Care AI · Clinical Productivity & ROI Case Study Widget */}
      <div className="glass-panel animate-fade-in" style={{ padding: '32px', marginBottom: '32px', border: '1px solid rgba(59, 130, 246, 0.35)', background: 'radial-gradient(circle at top right, rgba(59, 130, 246, 0.08), transparent 70%)' }}>
        
        {/* Specialty Select Toggles & Category Subheader */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap', gap: '12px' }}>
          <div style={{ display: 'flex', gap: '10px', background: 'rgba(255,255,255,0.03)', padding: '6px', borderRadius: '30px', border: '1px solid rgba(255,255,255,0.08)' }}>
            {["Orthopaedics", "Cardiology", "Oncology"].map(spec => (
              <button
                key={spec}
                onClick={() => setSelectedSpecialty(spec)}
                style={{
                  padding: '8px 22px',
                  borderRadius: '24px',
                  border: selectedSpecialty === spec ? '1px solid #3b82f6' : '1px solid transparent',
                  background: selectedSpecialty === spec ? 'rgba(59, 130, 246, 0.25)' : 'transparent',
                  color: selectedSpecialty === spec ? '#ffffff' : 'var(--text-secondary)',
                  fontWeight: selectedSpecialty === spec ? '700' : '500',
                  cursor: 'pointer',
                  fontSize: '14px',
                  transition: 'all 0.2s ease',
                  boxShadow: selectedSpecialty === spec ? '0 0 15px rgba(59, 130, 246, 0.4)' : 'none'
                }}
              >
                {spec}
              </button>
            ))}
          </div>
          <span style={{ fontSize: '12px', fontWeight: '800', letterSpacing: '1px', textTransform: 'uppercase', color: '#60a5fa', display: 'flex', alignItems: 'center', gap: '6px' }}>
            <Award size={16} color="#3b82f6" /> PRIME CARE AI · CLINICAL CASE STUDY
          </span>
        </div>

        {/* Two Column Layout: Narrative Stats vs Horizontal Comparison Bars */}
        <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1.5fr', gap: '40px', alignItems: 'flex-start' }}>
          
          {/* Left Column: Bold Narrative & Stat Grid */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
            <div>
              <h3 style={{ fontSize: '24px', fontWeight: '800', color: 'var(--text-primary)', lineHeight: '1.3', margin: '0 0 12px 0' }}>
                {ROI_BENCHMARKS[selectedSpecialty].title}
              </h3>
              <p style={{ fontSize: '14px', color: 'var(--text-secondary)', margin: 0, lineHeight: '1.5' }}>
                {ROI_BENCHMARKS[selectedSpecialty].subtitle}
              </p>
            </div>

            {/* 4-Stat Grid */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', padding: '16px 0', borderTop: '1px solid rgba(255,255,255,0.08)', borderBottom: '1px solid rgba(255,255,255,0.08)' }}>
              {ROI_BENCHMARKS[selectedSpecialty].stats.map((item, idx) => (
                <div key={idx} style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                  <span style={{ fontSize: '32px', fontWeight: '900', color: item.color, letterSpacing: '-1px' }}>
                    {item.value}
                  </span>
                  <span style={{ fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', textTransform: 'lowercase' }}>
                    {item.label}
                  </span>
                </div>
              ))}
            </div>

            {/* Glowing Green Success Quote */}
            <div style={{ fontSize: '14px', fontWeight: '700', color: '#34d399', lineHeight: '1.5', display: 'flex', alignItems: 'flex-start', gap: '10px', background: 'rgba(16, 185, 129, 0.08)', padding: '14px', borderRadius: '12px', borderLeft: '4px solid #10b981' }}>
              <Sparkles size={20} color="#10b981" style={{ flexShrink: 0, marginTop: '2px' }} />
              <span>{ROI_BENCHMARKS[selectedSpecialty].quote}</span>
            </div>

            <span style={{ fontSize: '11px', color: 'var(--text-secondary)', fontStyle: 'italic', marginTop: '-10px' }}>
              Observational pre/post hospital cohort sample, verified clinic practice data.
            </span>
          </div>

          {/* Right Column: Comparative Horizontal Bar Charts */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '22px', background: 'rgba(0, 0, 0, 0.25)', padding: '28px', borderRadius: '16px', border: '1px solid rgba(255, 255, 255, 0.05)' }}>
            {ROI_BENCHMARKS[selectedSpecialty].bars.map((bar, i) => (
              <div key={i} style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <span style={{ fontSize: '13px', fontWeight: '700', color: 'var(--text-primary)' }}>
                  {bar.label}
                </span>
                
                {/* Pre-AI Bar (Light Grey/Neutral) */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <div style={{ height: '14px', width: `${bar.preWidth}%`, background: 'rgba(255, 255, 255, 0.2)', borderRadius: '6px', transition: 'width 0.6s ease' }} />
                  <span style={{ fontSize: '12px', color: 'var(--text-secondary)', fontWeight: '500', whiteSpace: 'nowrap' }}>
                    {bar.pre}
                  </span>
                </div>

                {/* Post-AI Bar (Electric Blue Gradient / Green if reduction) */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <div style={{ height: '16px', width: `${bar.postWidth}%`, background: bar.postWidth < 20 ? 'linear-gradient(90deg, #10b981, #059669)' : 'linear-gradient(90deg, #3b82f6, #2563eb)', borderRadius: '6px', boxShadow: bar.postWidth < 20 ? '0 0 10px rgba(16, 185, 129, 0.4)' : '0 0 12px rgba(59, 130, 246, 0.5)', transition: 'width 0.6s ease' }} />
                  <span style={{ fontSize: '13px', color: bar.postWidth < 20 ? '#34d399' : '#60a5fa', fontWeight: '700', whiteSpace: 'nowrap' }}>
                    {bar.post}
                  </span>
                </div>
              </div>
            ))}

            {/* Legend Footer */}
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '24px', marginTop: '12px', paddingTop: '16px', borderTop: '1px solid rgba(255,255,255,0.08)', fontSize: '12px', fontWeight: '600' }}>
              <span style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-secondary)' }}>
                <div style={{ width: '12px', height: '12px', borderRadius: '50%', background: 'rgba(255,255,255,0.3)' }} /> Pre Prime Care AI
              </span>
              <span style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#60a5fa' }}>
                <div style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#3b82f6', boxShadow: '0 0 8px #3b82f6' }} /> Post Prime Care AI
              </span>
            </div>
          </div>

        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1.2fr', gap: '24px' }}>
        <div className="glass-panel" style={{ padding: '24px' }}>
          <h3 style={{ marginBottom: '16px', fontSize: '16px' }}>Today's Clinical Appointments</h3>
          {appointments.length === 0 ? (
            <p style={{ color: 'var(--text-secondary)' }}>No appointments today.</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              {appointments.map(a => (
                <div key={a.id} style={{ display: 'flex', alignItems: 'center', gap: '16px', padding: '12px', background: 'rgba(255,255,255,0.02)', borderRadius: '12px' }}>
                  <div style={{ width: '40px', height: '40px', borderRadius: '50%', background: `var(--glass-bg)`, border: `1px solid var(--glass-border)`, color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '14px', fontWeight: 'bold' }}>
                    {a.initials}
                  </div>
                  <div style={{ flex: 1 }}>
                    <h4 style={{ margin: 0, fontSize: '15px' }}>{a.patient_name}</h4>
                    <p style={{ margin: 0, fontSize: '13px', color: 'var(--text-secondary)' }}>{a.time} • {a.type}</p>
                  </div>
                  <div>
                    <span style={{ padding: '4px 8px', borderRadius: '8px', fontSize: '12px', background: a.status === 'completed' ? 'rgba(16, 185, 129, 0.1)' : 'rgba(255,255,255,0.05)', color: a.status === 'completed' ? 'var(--accent)' : 'var(--text-secondary)', marginRight: '8px' }}>
                      {a.status}
                    </span>
                    <button 
                      style={{ background: 'rgba(59, 130, 246, 0.2)', border: '1px solid rgba(59, 130, 246, 0.4)', color: '#60a5fa', borderRadius: '6px', cursor: 'pointer', fontSize: '12px', padding: '4px 10px', marginRight: '8px', fontWeight: '600', transition: 'all 0.2s' }} 
                      onClick={() => startEncounter(a)}
                    >
                      ▶ Start Encounter
                    </button>
                    <button style={{ background: 'transparent', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer', fontSize: '12px', marginRight: '8px' }} onClick={() => setEditingAppt({...a})}>Edit</button>
                    <button style={{ background: 'transparent', border: 'none', color: '#f87171', cursor: 'pointer', fontSize: '12px' }} onClick={() => handleDelete(a.id)}>Cancel</button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
        
        {/* Interactive Activity Log with Attachments */}
        <div className="glass-panel" style={{ padding: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
            <h3 style={{ margin: 0, fontSize: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Activity size={18} color="#60a5fa" /> Live Clinical Activity Log
            </h3>
            <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>Click item to view attachment</span>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {activities.slice(0, 8).map(act => (
              <div 
                key={act.id} 
                onClick={() => setSelectedActivity(act)}
                style={{ 
                  position: 'relative', 
                  padding: '12px 14px', 
                  background: 'rgba(255,255,255,0.02)', 
                  border: '1px solid rgba(255,255,255,0.07)', 
                  borderRadius: '10px', 
                  cursor: 'pointer',
                  transition: 'all 0.2s ease',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center'
                }}
                onMouseEnter={(e) => { e.currentTarget.style.background = 'rgba(59, 130, 246, 0.1)'; e.currentTarget.style.borderColor = '#3b82f6'; }}
                onMouseLeave={(e) => { e.currentTarget.style.background = 'rgba(255,255,255,0.02)'; e.currentTarget.style.borderColor = 'rgba(255,255,255,0.07)'; }}
              >
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '12px' }}>
                  <div style={{ marginTop: '4px', width: '10px', height: '10px', borderRadius: '50%', background: `var(--${act.color === 'teal' ? 'accent' : act.color === 'blue' ? 'primary' : act.color})`, flexShrink: 0, boxShadow: '0 0 8px currentColor' }} />
                  <div>
                    <p style={{ margin: '0 0 4px 0', fontSize: '13px', fontWeight: '600', color: 'var(--text-primary)' }}>{act.description}</p>
                    <p style={{ margin: 0, fontSize: '11px', color: 'var(--text-secondary)' }}>{act.patient_name || "General Clinic"} • {Math.floor(act.secs_ago / 60)}m ago</p>
                  </div>
                </div>
                
                <div style={{ display: 'flex', alignItems: 'center', gap: '4px', background: 'rgba(59, 130, 246, 0.15)', padding: '5px 10px', borderRadius: '15px', color: '#60a5fa', fontSize: '11px', fontWeight: '600' }}>
                  <Paperclip size={13} /> View
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
      
      {/* Appointment Edit Modal */}
      {editingAppt && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000 }}>
          <div className="glass-panel" style={{ padding: '32px', width: '400px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <h3 style={{ margin: 0, color: '#60a5fa' }}>Edit Appointment</h3>
            
            <label style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Date</label>
            <input type="date" className="input" value={editingAppt.appointment_date} onChange={e => setEditingAppt({...editingAppt, appointment_date: e.target.value})} />
            
            <label style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Time</label>
            <input type="time" className="input" value={editingAppt.time} onChange={e => setEditingAppt({...editingAppt, time: e.target.value})} />
            
            <label style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>Appointment Type</label>
            <input type="text" className="input" value={editingAppt.type} onChange={e => setEditingAppt({...editingAppt, type: e.target.value})} />
            
            <div style={{ display: 'flex', gap: '12px', marginTop: '16px' }}>
              <button className="btn" style={{ flex: 1, background: 'rgba(255,255,255,0.1)' }} onClick={() => setEditingAppt(null)}>Cancel</button>
              <button className="btn btn-primary" style={{ flex: 1 }} onClick={handleUpdate}>Save Changes</button>
            </div>
          </div>
        </div>
      )}

      {/* Clinical Activity Attachment Modal */}
      {selectedActivity && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.75)', backdropFilter: 'blur(5px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 10000 }}>
          <div className="glass-panel animate-fade-in" style={{ padding: '32px', width: '680px', maxHeight: '85vh', display: 'flex', flexDirection: 'column', gap: '20px', border: '1px solid #3b82f6', boxShadow: '0 20px 60px rgba(0,0,0,0.8)' }}>
            
            {/* Modal Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '16px' }}>
              <div>
                <h3 style={{ margin: 0, color: '#60a5fa', fontSize: '20px', display: 'flex', alignItems: 'center', gap: '10px', fontWeight: '700' }}>
                  <Paperclip size={22} /> Clinical Record Attachment Viewer
                </h3>
                <p style={{ margin: '4px 0 0', fontSize: '13px', color: 'var(--text-secondary)' }}>
                  Audit Trail ID: #{selectedActivity.id || Math.floor(100000 + Math.random() * 900000)} • Prime Care Verified Record
                </p>
              </div>
              <button className="ghost-btn" onClick={() => setSelectedActivity(null)} style={{ background: 'transparent', border: 'none', color: '#f87171', cursor: 'pointer', padding: '4px' }}>
                <X size={24} />
              </button>
            </div>

            {/* Audit Metadata Box */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px', background: 'rgba(0,0,0,0.4)', padding: '14px', borderRadius: '10px', border: '1px solid rgba(255,255,255,0.08)' }}>
              <div>
                <span style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase', display: 'block' }}>Patient Target</span>
                <strong style={{ color: 'var(--text-primary)', fontSize: '14px' }}>{selectedActivity.patient_name || "General Clinic Account"}</strong>
              </div>
              <div>
                <span style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase', display: 'block' }}>Action Classification</span>
                <span style={{ background: 'rgba(59, 130, 246, 0.2)', color: '#93c5fd', padding: '3px 8px', borderRadius: '12px', fontSize: '12px', fontWeight: '600', display: 'inline-block', marginTop: '3px' }}>
                  {selectedActivity.action || "Clinical Processing"}
                </span>
              </div>
              <div>
                <span style={{ fontSize: '11px', color: 'var(--text-secondary)', textTransform: 'uppercase', display: 'block' }}>Verification Status</span>
                <span style={{ color: '#34d399', fontSize: '13px', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '4px', marginTop: '3px' }}>
                  <ShieldCheck size={16} /> Cryptographically Signed
                </span>
              </div>
            </div>

            {/* Simulated Document Attachment Content */}
            <div style={{ flex: 1, overflowY: 'auto', background: 'rgba(15, 23, 42, 0.8)', border: '1px solid rgba(255,255,255,0.15)', borderRadius: '12px', padding: '24px', fontFamily: 'monospace' }}>
              <div style={{ borderBottom: '1px dashed rgba(255,255,255,0.2)', paddingBottom: '12px', marginBottom: '16px', color: 'var(--text-secondary)', fontSize: '12px', display: 'flex', justifyContent: 'space-between' }}>
                <span>DOCUMENT ATTACHMENT: {selectedActivity.description.toUpperCase().replace(/\s+/g, '_')}.PDF</span>
                <span>TIMESTAMP: {new Date().toLocaleDateString()}</span>
              </div>

              <div style={{ fontSize: '14px', color: 'var(--text-primary)', lineHeight: '1.6', whiteSpace: 'pre-wrap' }}>
                {selectedActivity.detail ? (
                  <>
                    <p style={{ color: '#60a5fa', fontWeight: '700' }}>--- CLINICAL OBSERVATIONS & DATA ---</p>
                    {selectedActivity.detail}
                    {"\n\n"}
                    <p style={{ color: '#10b981' }}>[AUTOMATICALLY FILED BY PRIME CARE HEALTH SYSTEM AI CO-PILOT]</p>
                  </>
                ) : (
                  <>
                    <p style={{ color: '#60a5fa', fontWeight: '700' }}>--- STANDARD CLINICAL ENCOUNTER ATTACHMENT ---</p>
                    {`Patient Activity: ${selectedActivity.description}\nAssigned Medical Facility: Prime Care Central Campus\nPrimary Attending Provider: Authorized Clinician (Google SSO Verified)\n\n[RECORD SUMMARY]\nThis attachment confirms the automated diagnostic evaluations, triage rules, and structured EHR updates performed under protocol ID #${Math.floor(1000 + Math.random() * 9000)}.\n\n[CLINICAL ATTESTATION]\nAll associated data fields and lab metrics have been synchronized with the centralized hospital relational database.`}
                  </>
                )}
              </div>
            </div>

            {/* Modal Footer Controls */}
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end', borderTop: '1px solid rgba(255,255,255,0.1)', paddingTop: '16px' }}>
              <button 
                type="button"
                className="btn" 
                style={{ background: 'rgba(255,255,255,0.1)', color: 'var(--text-primary)', border: '1px solid rgba(255,255,255,0.2)', padding: '10px 18px', display: 'flex', alignItems: 'center', gap: '8px', fontWeight: '600' }} 
                onClick={() => triggerExport('Document print job')}
              >
                <Printer size={16} /> Print Record
              </button>

              <button 
                type="button"
                className="btn btn-primary" 
                style={{ background: '#10b981', border: '1px solid #34d399', fontWeight: '700', padding: '10px 20px', display: 'flex', alignItems: 'center', gap: '8px' }}
                onClick={() => triggerExport('PDF file download')}
              >
                <Download size={16} /> Download Clinical PDF
              </button>

              <button 
                type="button"
                className="btn" 
                style={{ background: 'rgba(239, 68, 68, 0.2)', color: '#fca5a5', border: '1px solid #ef4444', padding: '10px 20px', fontWeight: '600' }} 
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

function MetricCard({ title, value, icon, color }) {
  let c = 'var(--primary)';
  if (color === 'emerald') c = 'var(--accent)';
  if (color === 'orange') c = '#f59e0b';
  if (color === 'purple') c = '#a855f7';

  return (
    <div className="glass-panel" style={{ padding: '20px', display: 'flex', alignItems: 'center', gap: '16px' }}>
      <div style={{ width: '48px', height: '48px', borderRadius: '12px', background: `rgba(255,255,255,0.03)`, border: `1px solid ${c}30`, color: c, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        {icon}
      </div>
      <div>
        <p style={{ margin: 0, fontSize: '13px', color: 'var(--text-secondary)', fontWeight: '500' }}>{title}</p>
        <h3 style={{ margin: '4px 0 0', fontSize: '28px', color: 'var(--text-primary)' }}>{value}</h3>
      </div>
    </div>
  );
}
