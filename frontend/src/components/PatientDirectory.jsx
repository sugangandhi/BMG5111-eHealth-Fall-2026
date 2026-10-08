import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { 
  Users, Cloud, Database, Search, MessageCircle, Mic, ShieldCheck, 
  RefreshCw, Activity, CheckCircle2, ChevronRight, X, Calendar, UserCheck
} from 'lucide-react';

export default function PatientDirectory({ onSelectPatient, onOpenWhatsApp }) {
  const [patients, setPatients] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filterSource, setFilterSource] = useState('all'); // 'all' | 'central_cloud' | 'clinic_ehr'
  const [searchQuery, setSearchQuery] = useState('');
  const [cloudStatus, setCloudStatus] = useState(null);
  const [selectedVitalsPatient, setSelectedVitalsPatient] = useState(null);
  const [vitalsHistory, setVitalsHistory] = useState([]);
  const [vitalsLoading, setVitalsLoading] = useState(false);

  useEffect(() => {
    loadPatients();
    loadCloudHealth();
  }, []);

  const loadPatients = async () => {
    setLoading(true);
    try {
      const res = await axios.get('/api/patients');
      if (res.data?.patients) {
        setPatients(res.data.patients);
      }
    } catch (err) {
      console.error("Error loading patient directory:", err);
    } finally {
      setLoading(false);
    }
  };

  const loadCloudHealth = async () => {
    try {
      const res = await axios.get('/api/central/status');
      setCloudStatus(res.data);
    } catch (err) {
      console.error("Central cloud status check failed:", err);
    }
  };

  const handleInspectVitals = async (patient) => {
    setSelectedVitalsPatient(patient);
    setVitalsLoading(true);
    setVitalsHistory([]);
    try {
      const pId = patient.raw_id || patient.id.replace('cloud-', '');
      const res = await axios.get(`/api/central/vitals/${pId}`);
      if (res.data?.vitals) {
        setVitalsHistory(res.data.vitals);
      }
    } catch (err) {
      console.error("Failed to query central vitals:", err);
    } finally {
      setVitalsLoading(false);
    }
  };

  const clinicCount = patients.filter(p => p.source === 'clinic_ehr').length;
  const cloudCount = patients.filter(p => p.source === 'central_cloud').length;

  const filteredPatients = patients.filter(p => {
    const matchesFilter = 
      filterSource === 'all' || 
      (filterSource === 'central_cloud' && p.source === 'central_cloud') ||
      (filterSource === 'clinic_ehr' && p.source === 'clinic_ehr');
    
    if (!matchesFilter) return false;

    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    const nameMatch = (p.name || '').toLowerCase().includes(q);
    const mrnMatch = (p.mrn || '').toLowerCase().includes(q);
    const contactMatch = (p.contact || '').toLowerCase().includes(q);
    const genderMatch = (p.gender || '').toLowerCase().includes(q);

    return nameMatch || mrnMatch || contactMatch || genderMatch;
  });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px', paddingBottom: '40px' }}>
      
      {/* Directory Banner Header */}
      <div className="glass-panel" style={{ padding: '24px', borderRadius: '16px', border: '1px solid var(--border)', background: 'linear-gradient(135deg, rgba(15, 23, 42, 0.95), rgba(30, 41, 59, 0.95))' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '16px' }}>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <div style={{ width: '40px', height: '40px', borderRadius: '10px', background: 'rgba(59, 130, 246, 0.2)', border: '1px solid rgba(59, 130, 246, 0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#60a5fa' }}>
                <Users size={22} />
              </div>
              <div>
                <h1 style={{ margin: 0, fontSize: '22px', fontWeight: '800', color: 'var(--text-primary)' }}>Institutional Patient Directory</h1>
                <p style={{ margin: '4px 0 0 0', fontSize: '13px', color: 'var(--text-secondary)' }}>
                  Unified registry linking local clinic medical charts with the central AWS App Runner clinical database.
                </p>
              </div>
            </div>
          </div>

          {/* Central Cloud Telemetry Status Pill */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '8px',
              padding: '8px 14px',
              borderRadius: '20px',
              background: cloudStatus?.connected ? 'rgba(16, 185, 129, 0.12)' : 'rgba(239, 68, 68, 0.12)',
              border: `1px solid ${cloudStatus?.connected ? 'rgba(16, 185, 129, 0.35)' : 'rgba(239, 68, 68, 0.35)'}`,
              color: cloudStatus?.connected ? '#34d399' : '#f87171',
              fontSize: '12px',
              fontWeight: '700'
            }}>
              <Cloud size={16} />
              <span>{cloudStatus?.connected ? `Central Cloud MySQL: ${cloudStatus.tables_count || 77} Tables Synced` : 'Central Cloud: Connecting...'}</span>
              <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: cloudStatus?.connected ? '#10b981' : '#ef4444', boxShadow: cloudStatus?.connected ? '0 0 8px #10b981' : 'none' }} />
            </div>

            <button
              onClick={() => { loadPatients(); loadCloudHealth(); }}
              style={{
                background: 'var(--bg-secondary)',
                border: '1px solid var(--border)',
                borderRadius: '8px',
                padding: '8px 12px',
                color: 'var(--text-primary)',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                fontSize: '12px',
                fontWeight: '600'
              }}
              title="Refresh Registry"
            >
              <RefreshCw size={14} className={loading ? 'animate-spin' : ''} /> Refresh
            </button>
          </div>
        </div>

        {/* Quick KPI Metrics */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '14px', marginTop: '20px' }}>
          <div style={{ background: 'rgba(0,0,0,0.25)', padding: '12px 16px', borderRadius: '10px', border: '1px solid rgba(255,255,255,0.06)' }}>
            <span style={{ fontSize: '11px', color: 'var(--text-secondary)', fontWeight: '600', textTransform: 'uppercase' }}>Total Patients</span>
            <div style={{ fontSize: '22px', fontWeight: '800', color: 'var(--text-primary)', marginTop: '2px' }}>{patients.length}</div>
          </div>
          <div style={{ background: 'rgba(59, 130, 246, 0.1)', padding: '12px 16px', borderRadius: '10px', border: '1px solid rgba(59, 130, 246, 0.3)' }}>
            <span style={{ fontSize: '11px', color: '#60a5fa', fontWeight: '600', textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: '4px' }}>
              <Cloud size={12} /> Central Cloud Database
            </span>
            <div style={{ fontSize: '22px', fontWeight: '800', color: '#60a5fa', marginTop: '2px' }}>{cloudCount}</div>
            <span style={{ fontSize: '10px', color: 'var(--text-secondary)' }}>Table: patients_registration</span>
          </div>
          <div style={{ background: 'rgba(16, 185, 129, 0.1)', padding: '12px 16px', borderRadius: '10px', border: '1px solid rgba(16, 185, 129, 0.3)' }}>
            <span style={{ fontSize: '11px', color: '#34d399', fontWeight: '600', textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: '4px' }}>
              <Database size={12} /> Local Clinic EHR
            </span>
            <div style={{ fontSize: '22px', fontWeight: '800', color: '#34d399', marginTop: '2px' }}>{clinicCount}</div>
            <span style={{ fontSize: '10px', color: 'var(--text-secondary)' }}>Full FHIR Clinical Charts</span>
          </div>
        </div>
      </div>

      {/* Filter and Search Controls */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        {/* Source Filter Tabs */}
        <div style={{ display: 'flex', gap: '8px', background: 'var(--bg-secondary)', padding: '4px', borderRadius: '10px', border: '1px solid var(--border)' }}>
          <button
            onClick={() => setFilterSource('all')}
            style={{
              padding: '6px 14px',
              borderRadius: '8px',
              border: 'none',
              background: filterSource === 'all' ? 'var(--primary)' : 'transparent',
              color: filterSource === 'all' ? '#fff' : 'var(--text-secondary)',
              fontSize: '12px',
              fontWeight: '700',
              cursor: 'pointer',
              transition: 'all 0.15s'
            }}
          >
            All Patients ({patients.length})
          </button>
          <button
            onClick={() => setFilterSource('central_cloud')}
            style={{
              padding: '6px 14px',
              borderRadius: '8px',
              border: 'none',
              background: filterSource === 'central_cloud' ? 'rgba(59, 130, 246, 0.25)' : 'transparent',
              color: filterSource === 'central_cloud' ? '#60a5fa' : 'var(--text-secondary)',
              fontSize: '12px',
              fontWeight: '700',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              transition: 'all 0.15s'
            }}
          >
            <Cloud size={14} /> Central Cloud ({cloudCount})
          </button>
          <button
            onClick={() => setFilterSource('clinic_ehr')}
            style={{
              padding: '6px 14px',
              borderRadius: '8px',
              border: 'none',
              background: filterSource === 'clinic_ehr' ? 'rgba(16, 185, 129, 0.25)' : 'transparent',
              color: filterSource === 'clinic_ehr' ? '#34d399' : 'var(--text-secondary)',
              fontSize: '12px',
              fontWeight: '700',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              transition: 'all 0.15s'
            }}
          >
            <Database size={14} /> Clinic EHR ({clinicCount})
          </button>
        </div>

        {/* Search Bar */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', background: 'var(--bg-secondary)', border: '1px solid var(--border)', borderRadius: '10px', padding: '6px 14px', minWidth: '280px', flex: 1, maxWidth: '400px' }}>
          <Search size={16} color="var(--text-secondary)" />
          <input
            type="text"
            placeholder="Search by name, MRN, contact, or gender..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            style={{ background: 'transparent', border: 'none', color: 'var(--text-primary)', fontSize: '13px', outline: 'none', width: '100%' }}
          />
          {searchQuery && (
            <button onClick={() => setSearchQuery('')} style={{ background: 'none', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer', padding: 0 }}>
              <X size={14} />
            </button>
          )}
        </div>
      </div>

      {/* Patients Grid */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px 20px', color: 'var(--text-secondary)' }}>
          <RefreshCw size={32} className="animate-spin" style={{ margin: '0 auto 12px', color: 'var(--primary)' }} />
          <p style={{ fontSize: '14px', fontWeight: '600' }}>Fetching clinical records from local store and AWS Cloud...</p>
        </div>
      ) : filteredPatients.length === 0 ? (
        <div className="glass-panel" style={{ textAlign: 'center', padding: '50px 20px', borderRadius: '16px' }}>
          <Users size={36} color="var(--text-secondary)" style={{ margin: '0 auto 12px' }} />
          <h3 style={{ margin: '0 0 6px 0', fontSize: '16px' }}>No patients found</h3>
          <p style={{ margin: 0, fontSize: '13px', color: 'var(--text-secondary)' }}>
            Try adjusting your search query or switching the registry source filter.
          </p>
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))', gap: '14px' }}>
          {filteredPatients.map((p) => {
            const isCloud = p.source === 'central_cloud';
            return (
              <div
                key={p.id}
                className="glass-panel"
                style={{
                  padding: '16px 18px',
                  borderRadius: '14px',
                  border: isCloud ? '1px solid rgba(59, 130, 246, 0.3)' : '1px solid rgba(16, 185, 129, 0.3)',
                  background: 'var(--bg-secondary)',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '12px',
                  position: 'relative',
                  transition: 'transform 0.15s, box-shadow 0.15s'
                }}
              >
                {/* Top Row: Avatar + Name + Source Tag */}
                <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: '10px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px', minWidth: 0 }}>
                    <div style={{
                      width: '40px',
                      height: '40px',
                      borderRadius: '50%',
                      background: isCloud ? 'linear-gradient(135deg, #2563eb, #1d4ed8)' : 'linear-gradient(135deg, #059669, #047857)',
                      color: 'white',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontWeight: '800',
                      fontSize: '14px',
                      flexShrink: 0
                    }}>
                      {p.initials || 'PT'}
                    </div>
                    <div style={{ minWidth: 0 }}>
                      <div style={{ fontWeight: '700', fontSize: '15px', color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {p.name}
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                        DOB: {p.birthDate} • {p.gender || 'Patient'}
                      </div>
                    </div>
                  </div>

                  {/* Origin Badge */}
                  <span style={{
                    fontSize: '10px',
                    fontWeight: '700',
                    padding: '3px 8px',
                    borderRadius: '6px',
                    background: isCloud ? 'rgba(59, 130, 246, 0.15)' : 'rgba(16, 185, 129, 0.15)',
                    color: isCloud ? '#60a5fa' : '#34d399',
                    border: `1px solid ${isCloud ? 'rgba(59, 130, 246, 0.35)' : 'rgba(16, 185, 129, 0.35)'}`,
                    whiteSpace: 'nowrap',
                    flexShrink: 0
                  }}>
                    {isCloud ? '☁️ Central Cloud' : '🏥 Clinic EHR'}
                  </span>
                </div>

                {/* Metadata Row */}
                <div style={{ fontSize: '12px', color: 'var(--text-secondary)', background: 'rgba(0,0,0,0.2)', padding: '8px 12px', borderRadius: '8px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span>MRN / OHIP:</span>
                    <strong style={{ color: 'var(--text-primary)' }}>{p.mrn}</strong>
                  </div>
                  {p.contact && (
                    <div style={{ display: 'flex', justifyContent: 'space-between', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      <span>Contact / Info:</span>
                      <span style={{ color: 'var(--text-primary)', maxWidth: '180px', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {p.contact.split('||')[0]}
                      </span>
                    </div>
                  )}
                </div>

                {/* Action Buttons */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: 'auto', paddingTop: '4px' }}>
                  <button
                    onClick={() => {
                      const patientObj = {
                        id: p.id || p.mrn,
                        name: p.name,
                        mrn: p.mrn,
                        conditions: p.conditions || [p.badge || ''],
                        badge: p.badge || '',
                        allergies: p.allergies || 'NKDA'
                      };
                      try {
                        localStorage.setItem('active_patient_context', JSON.stringify(patientObj));
                      } catch (e) {}
                      window.dispatchEvent(new CustomEvent('set-active-patient', { detail: patientObj }));
                      if (onSelectPatient) onSelectPatient(p);
                    }}
                    style={{
                      flex: 1,
                      background: 'rgba(59, 130, 246, 0.15)',
                      border: '1px solid rgba(59, 130, 246, 0.4)',
                      color: '#60a5fa',
                      borderRadius: '8px',
                      padding: '7px 10px',
                      fontSize: '12px',
                      fontWeight: '700',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: '5px'
                    }}
                    title="Load into global top banner"
                  >
                    <UserCheck size={14} /> Select Patient
                  </button>

                  <button
                    onClick={() => onOpenWhatsApp && onOpenWhatsApp(p)}
                    style={{
                      background: '#25D366',
                      border: 'none',
                      color: '#ffffff',
                      borderRadius: '8px',
                      width: '34px',
                      height: '34px',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0
                    }}
                    title={`1-Tap WhatsApp chat with ${p.name}`}
                  >
                    <MessageCircle size={16} />
                  </button>

                  <button
                    onClick={() => {
                      const patientObj = {
                        id: p.id || p.mrn,
                        name: p.name,
                        mrn: p.mrn,
                        conditions: p.conditions || [p.badge || ''],
                        badge: p.badge || '',
                        allergies: p.allergies || 'NKDA'
                      };
                      try {
                        localStorage.setItem('active_patient_context', JSON.stringify(patientObj));
                      } catch (e) {}
                      if (onSelectPatient) onSelectPatient(p);
                      window.dispatchEvent(new CustomEvent('open-scribe', { detail: { patient: patientObj } }));
                    }}
                    style={{
                      background: 'rgba(16, 185, 129, 0.15)',
                      border: '1px solid rgba(16, 185, 129, 0.4)',
                      color: '#34d399',
                      borderRadius: '8px',
                      width: '34px',
                      height: '34px',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0
                    }}
                    title="Open Ambient AI Scribe for this patient"
                  >
                    <Mic size={15} />
                  </button>

                  {isCloud && (
                    <button
                      onClick={() => handleInspectVitals(p)}
                      style={{
                        background: 'rgba(168, 85, 247, 0.15)',
                        border: '1px solid rgba(168, 85, 247, 0.4)',
                        color: '#c084fc',
                        borderRadius: '8px',
                        padding: '7px 10px',
                        fontSize: '11px',
                        fontWeight: '700',
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px',
                        flexShrink: 0
                      }}
                      title="Inspect vitals_history recorded on Central Cloud database"
                    >
                      <Activity size={13} /> Cloud Vitals
                    </button>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Cloud Vitals Modal */}
      {selectedVitalsPatient && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.75)', backdropFilter: 'blur(5px)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '16px' }}>
          <div className="glass-panel" style={{ width: '600px', maxWidth: '95vw', maxHeight: '85vh', borderRadius: '16px', border: '1px solid #3b82f6', background: 'rgba(15, 23, 42, 0.98)', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
            
            {/* Modal Header */}
            <div style={{ padding: '16px 20px', borderBottom: '1px solid rgba(255,255,255,0.1)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                <Activity size={20} color="#c084fc" />
                <div>
                  <h3 style={{ margin: 0, fontSize: '16px', color: 'var(--text-primary)' }}>
                    Central Cloud Vitals History: {selectedVitalsPatient.name}
                  </h3>
                  <span style={{ fontSize: '11px', color: 'var(--text-secondary)' }}>
                    Queried from AWS App Runner MySQL table: <code>vitals_history</code>
                  </span>
                </div>
              </div>
              <button onClick={() => setSelectedVitalsPatient(null)} style={{ background: 'none', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer' }}>
                <X size={20} />
              </button>
            </div>

            {/* Modal Body */}
            <div style={{ padding: '20px', overflowY: 'auto', flex: 1 }}>
              {vitalsLoading ? (
                <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
                  <RefreshCw size={24} className="animate-spin" style={{ margin: '0 auto 8px', color: '#c084fc' }} />
                  <p style={{ margin: 0, fontSize: '13px' }}>Executing read-only SQL SELECT on AWS MySQL...</p>
                </div>
              ) : vitalsHistory.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-secondary)' }}>
                  <Activity size={28} style={{ margin: '0 auto 8px', opacity: 0.5 }} />
                  <p style={{ margin: '0 0 4px', fontSize: '14px', fontWeight: '600', color: 'var(--text-primary)' }}>No Cloud Vitals Recorded Yet</p>
                  <p style={{ margin: 0, fontSize: '12px' }}>
                    When this patient submits vitals over WhatsApp or telemetry, they are automatically stored into <code>vitals_history</code> on AWS.
                  </p>
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  {vitalsHistory.map((v, i) => (
                    <div key={v.vital_id || i} style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: '10px', padding: '12px 14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div>
                        <div style={{ fontSize: '13px', fontWeight: '700', color: 'var(--text-primary)' }}>
                          {v.blood_pressure && <span style={{ marginRight: '12px' }}>BP: <strong style={{ color: '#38bdf8' }}>{v.blood_pressure}</strong></span>}
                          {v.heart_rate && <span style={{ marginRight: '12px' }}>HR: <strong style={{ color: '#f43f5e' }}>{v.heart_rate} bpm</strong></span>}
                          {v.temperature && <span>Temp: <strong>{v.temperature}°C</strong></span>}
                        </div>
                        {v.notes && <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginTop: '3px' }}>{v.notes}</div>}
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--text-secondary)', textAlign: 'right' }}>
                        {v.recorded_on ? new Date(v.recorded_on).toLocaleString() : 'Recent'}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Modal Footer */}
            <div style={{ padding: '12px 20px', borderTop: '1px solid rgba(255,255,255,0.1)', background: 'rgba(0,0,0,0.2)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: '11px', color: '#10b981', display: 'flex', alignItems: 'center', gap: '4px' }}>
                <CheckCircle2 size={13} /> Verified MySQL Introspected Endpoint
              </span>
              <button
                onClick={() => setSelectedVitalsPatient(null)}
                style={{ background: 'var(--bg-secondary)', border: '1px solid var(--border)', color: 'var(--text-primary)', padding: '6px 14px', borderRadius: '8px', fontSize: '12px', fontWeight: '600', cursor: 'pointer' }}
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
