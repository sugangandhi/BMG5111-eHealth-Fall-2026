import React, { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import { motion, AnimatePresence } from 'framer-motion';
import { 
  Watch, HeartPulse, Activity, Flame, Moon, Footprints, 
  BatteryCharging, RefreshCw, AlertTriangle, Radio, CheckCircle2, 
  Copy, MessageCircle, User, ChevronDown, Sparkles, ShieldAlert
} from 'lucide-react';

export default function AppleWatchVitalsCard({ 
  patient, 
  allPatients = [], 
  onSelectPatient,
  onOpenWhatsApp,
  compact = false 
}) {
  const [selectedPatientId, setSelectedPatientId] = useState(patient?.id || 'pt-011');
  const [vitals, setVitals] = useState(null);
  const [loading, setLoading] = useState(true);
  const [isLiveMode, setIsLiveMode] = useState(false);
  const [copied, setCopied] = useState(false);
  const [lastRefreshed, setLastRefreshed] = useState(new Date());
  const [isSyncModalOpen, setIsSyncModalOpen] = useState(false);
  const [syncSubmitting, setSyncSubmitting] = useState(false);
  const [syncSuccessMsg, setSyncSuccessMsg] = useState(null);
  const [manualForm, setManualForm] = useState({
    heart_rate: '74',
    resting_heart_rate: '64',
    blood_pressure: '118/78',
    steps: '7250',
    calories: '450',
    sleep: '7.5'
  });
  const timerRef = useRef(null);

  // Sync internal selected ID with external patient prop if provided
  useEffect(() => {
    if (patient?.id && patient.id !== selectedPatientId) {
      setSelectedPatientId(patient.id);
    }
  }, [patient?.id]);

  // Fetch Vitals from backend
  const fetchVitals = async (pid = selectedPatientId) => {
    try {
      const res = await axios.get(`/api/wearables/patient/${pid}/vitals`);
      setVitals(res.data);
      if (res.data?.is_live_telemetry_enabled !== undefined) {
        setIsLiveMode(res.data.is_live_telemetry_enabled);
      }
      setLastRefreshed(new Date());
    } catch (err) {
      console.warn('[AppleWatchCard] Fetch note:', err);
    } finally {
      setLoading(false);
    }
  };

  // Initial fetch and on patient switch
  useEffect(() => {
    fetchVitals(selectedPatientId);
  }, [selectedPatientId]);

  // Live Mode Polling Loop (Every 3.5 seconds when Live is ON)
  useEffect(() => {
    if (isLiveMode) {
      timerRef.current = setInterval(() => {
        fetchVitals(selectedPatientId);
      }, 3500);
    } else {
      if (timerRef.current) clearInterval(timerRef.current);
    }

    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [isLiveMode, selectedPatientId]);

  // Toggle Live Mode via Backend API
  const handleToggleLiveMode = async () => {
    const nextState = !isLiveMode;
    setIsLiveMode(nextState);
    try {
      await axios.post(`/api/wearables/patient/${selectedPatientId}/live-mode`, {
        enabled: nextState,
        alert_high: 105,
        alert_low: 50
      });
      fetchVitals(selectedPatientId);
    } catch (err) {
      console.warn('[AppleWatchCard] Toggle live mode note:', err);
    }
  };

  // Copy vitals to clipboard for clinical note injection
  const handleCopyVitals = () => {
    if (!vitals) return;
    const summary = `Apple Watch Telemetry (${vitals.device_info?.model || 'Apple Watch'}): HR ${vitals.heart_rate} bpm (Resting: ${vitals.resting_heart_rate} bpm), BP ${vitals.blood_pressure} mmHg, Steps ${vitals.steps?.toLocaleString()}, Active Calories ${vitals.calories} kcal, Sleep ${vitals.sleep_hours}h (${vitals.sleep_quality}), SpO2 ${vitals.spo2}%.`;
    navigator.clipboard.writeText(summary);
    setCopied(true);
    setTimeout(() => setCopied(false), 2200);

    // Also dispatch event for Scribe component to automatically ingest
    window.dispatchEvent(new CustomEvent('insert-scribe-text', { detail: { text: `\n[Objective Wearable Vitals]: ${summary}\n` } }));
  };

  const handleManualSync = async (e) => {
    if (e) e.preventDefault();
    setSyncSubmitting(true);
    setSyncSuccessMsg(null);
    try {
      await axios.post('/api/wearables/ingest', {
        patient_id: selectedPatientId,
        heart_rate: parseInt(manualForm.heart_rate) || 74,
        resting_heart_rate: parseInt(manualForm.resting_heart_rate) || 64,
        blood_pressure: manualForm.blood_pressure || '118/78',
        steps: parseInt(manualForm.steps) || 7000,
        calories: parseInt(manualForm.calories) || 450,
        sleep: parseFloat(manualForm.sleep) || 7.5,
        annotation: 'Live Apple Watch Reading from Sahithya'
      });
      setSyncSuccessMsg('✅ Live Watch Vitals uploaded directly to AWS Cloud EMR!');
      setTimeout(() => {
        setIsSyncModalOpen(false);
        setSyncSuccessMsg(null);
      }, 1500);
      fetchVitals(selectedPatientId);
    } catch (err) {
      console.warn('Sync error:', err);
    } finally {
      setSyncSubmitting(false);
    }
  };

  const currentPatientName = patient?.name || allPatients.find(p => p.id === selectedPatientId)?.name || 'Active Patient';
  const pulseDuration = (vitals?.heart_rate && vitals.heart_rate > 0) ? (60 / vitals.heart_rate) : 1.0;

  return (
    <div 
      className="glass-panel"
      style={{
        background: 'linear-gradient(135deg, rgba(15, 23, 42, 0.95) 0%, rgba(10, 15, 30, 0.98) 100%)',
        border: isLiveMode ? '1px solid rgba(16, 185, 129, 0.6)' : '1px solid rgba(6, 182, 212, 0.35)',
        boxShadow: isLiveMode ? '0 0 30px rgba(16, 185, 129, 0.15)' : '0 10px 30px rgba(0, 0, 0, 0.4)',
        borderRadius: '20px',
        padding: compact ? '16px' : '22px',
        position: 'relative',
        overflow: 'hidden',
        transition: 'all 0.3s ease'
      }}
    >
      {/* Top Header Bar: Device Info & Patient Selector */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px', marginBottom: '18px' }}>
        
        {/* Device Badge */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <div style={{
            width: '38px',
            height: '38px',
            borderRadius: '10px',
            background: isLiveMode ? 'rgba(16, 185, 129, 0.2)' : 'rgba(6, 182, 212, 0.15)',
            border: `1px solid ${isLiveMode ? '#10b981' : '#06b6d4'}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: isLiveMode ? '#10b981' : '#06b6d4'
          }}>
            <Watch size={20} />
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span style={{ fontSize: '15px', fontWeight: '800', color: '#f8fafc', letterSpacing: '0.3px' }}>
                Apple Watch Telemetry
              </span>
              <span style={{
                fontSize: '10px',
                padding: '2px 8px',
                borderRadius: '12px',
                background: isLiveMode ? 'rgba(16, 185, 129, 0.25)' : 'rgba(100, 116, 139, 0.2)',
                color: isLiveMode ? '#34d399' : '#94a3b8',
                fontWeight: '700',
                border: `1px solid ${isLiveMode ? 'rgba(16, 185, 129, 0.5)' : 'rgba(100, 116, 139, 0.3)'}`,
                display: 'inline-flex',
                alignItems: 'center',
                gap: '4px'
              }}>
                {isLiveMode ? (
                  <>
                    <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: '#10b981', display: 'inline-block', animation: 'ping 1.5s infinite' }} />
                    LIVE STREAM
                  </>
                ) : 'PERIODIC SYNC'}
              </span>
            </div>
            <div style={{ fontSize: '11px', color: '#94a3b8', display: 'flex', alignItems: 'center', gap: '8px', marginTop: '2px' }}>
              <span>Series 9 • watchOS 11</span>
              <span>•</span>
              <span style={{ display: 'flex', alignItems: 'center', gap: '3px', color: '#38bdf8' }}>
                <BatteryCharging size={12} /> {vitals?.device_info?.battery_level || 84}%
              </span>
            </div>
          </div>
        </div>

        {/* Doctor Controls: Patient Selector & Live Toggle */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          
          {/* Patient Selector Dropdown */}
          {allPatients && allPatients.length > 0 && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', background: 'rgba(30, 41, 59, 0.8)', padding: '5px 10px', borderRadius: '10px', border: '1px solid rgba(255, 255, 255, 0.1)' }}>
              <User size={13} color="#94a3b8" />
              <select
                value={selectedPatientId}
                onChange={(e) => {
                  const newId = e.target.value;
                  setSelectedPatientId(newId);
                  if (onSelectPatient) {
                    const found = allPatients.find(p => p.id === newId);
                    if (found) onSelectPatient(found);
                  }
                }}
                style={{
                  background: 'transparent',
                  border: 'none',
                  color: '#e2e8f0',
                  fontSize: '12px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  outline: 'none'
                }}
              >
                {allPatients.map(p => (
                  <option key={p.id} value={p.id} style={{ background: '#0f172a', color: 'white' }}>
                    Dr. View: {p.name}
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Live Telemetry Mode Toggle Button */}
          <button
            onClick={handleToggleLiveMode}
            style={{
              background: isLiveMode ? 'linear-gradient(135deg, #059669, #10b981)' : 'rgba(30, 41, 59, 0.9)',
              border: `1px solid ${isLiveMode ? '#10b981' : 'rgba(255, 255, 255, 0.15)'}`,
              color: 'white',
              borderRadius: '10px',
              padding: '6px 12px',
              fontSize: '12px',
              fontWeight: '700',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              boxShadow: isLiveMode ? '0 0 16px rgba(16, 185, 129, 0.4)' : 'none',
              transition: 'all 0.2s ease'
            }}
            title={isLiveMode ? "Disable high-frequency live stream" : "Enable real-time 3-second live telemetry for this patient"}
          >
            <Radio size={14} className={isLiveMode ? 'animate-pulse' : ''} />
            <span>{isLiveMode ? 'Live Mode: ON' : 'Enable Live Mode'}</span>
          </button>

          {/* Manual Refresh Button */}
          <button
            onClick={() => fetchVitals(selectedPatientId)}
            style={{
              background: 'rgba(255, 255, 255, 0.05)',
              border: '1px solid rgba(255, 255, 255, 0.1)',
              color: '#cbd5e1',
              borderRadius: '8px',
              width: '32px',
              height: '32px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer'
            }}
            title="Refresh vitals now"
          >
            <RefreshCw size={13} className={loading ? 'animate-spin' : ''} />
          </button>
        </div>
      </div>

      {/* Clinical Alert Banner (If abnormal HR or BP triggered) */}
      <AnimatePresence>
        {vitals?.alert && (
          <motion.div
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            style={{
              background: vitals.alert.level === 'warning' ? 'rgba(239, 68, 68, 0.18)' : 'rgba(245, 158, 11, 0.18)',
              border: `1px solid ${vitals.alert.level === 'warning' ? '#ef4444' : '#f59e0b'}`,
              borderRadius: '12px',
              padding: '10px 14px',
              marginBottom: '16px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: '12px'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <ShieldAlert size={18} color={vitals.alert.level === 'warning' ? '#ef4444' : '#f59e0b'} />
              <div style={{ fontSize: '12px', color: '#f8fafc', fontWeight: '600' }}>
                <span style={{ fontWeight: '800', color: vitals.alert.level === 'warning' ? '#f87171' : '#fbbf24', textTransform: 'uppercase', marginRight: '6px' }}>
                  {vitals.alert.type}:
                </span>
                {vitals.alert.message}
              </div>
            </div>
            {onOpenWhatsApp && (
              <button
                onClick={() => onOpenWhatsApp(patient)}
                style={{
                  background: 'rgba(37, 211, 102, 0.2)',
                  border: '1px solid rgba(37, 211, 102, 0.4)',
                  color: '#4ade80',
                  borderRadius: '6px',
                  padding: '4px 8px',
                  fontSize: '11px',
                  fontWeight: '700',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px',
                  flexShrink: 0
                }}
              >
                <MessageCircle size={12} /> WhatsApp Patient
              </button>
            )}
          </motion.div>
        )}
      </AnimatePresence>

      {/* Primary Metrics Grid (HR, BP, Steps, Calories, Sleep, SpO2) */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: compact ? 'repeat(2, 1fr)' : 'repeat(auto-fit, minmax(140px, 1fr))',
        gap: '12px',
        marginBottom: '18px'
      }}>
        
        {/* Metric 1: Heart Rate */}
        <div style={{
          background: 'rgba(30, 41, 59, 0.6)',
          border: '1px solid rgba(244, 63, 94, 0.3)',
          borderRadius: '14px',
          padding: '14px',
          display: 'flex',
          flexDirection: 'column',
          position: 'relative'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
            <span style={{ fontSize: '11px', color: '#fda4af', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              Heart Rate
            </span>
            <HeartPulse 
              size={17} 
              color="#f43f5e" 
              style={{
                animation: isLiveMode ? `pulse ${pulseDuration}s infinite ease-in-out` : 'none'
              }} 
            />
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '4px', margin: '2px 0' }}>
            <span style={{ fontSize: '26px', fontWeight: '900', color: (vitals?.heart_rate && vitals.heart_rate > 0) ? '#ffffff' : '#94a3b8' }}>
              {(vitals?.heart_rate && vitals.heart_rate > 0) ? vitals.heart_rate : '--'}
            </span>
            <span style={{ fontSize: '12px', color: (vitals?.heart_rate && vitals.heart_rate > 0) ? '#fda4af' : '#94a3b8', fontWeight: '700' }}>
              {(vitals?.heart_rate && vitals.heart_rate > 0) ? 'BPM' : 'Off-Wrist'}
            </span>
          </div>
          <span style={{ fontSize: '11px', color: '#94a3b8' }}>
            Resting: <strong style={{ color: '#f8fafc' }}>{vitals?.resting_heart_rate || 62} BPM</strong>
          </span>
        </div>

        {/* Metric 2: Blood Pressure */}
        <div style={{
          background: 'rgba(30, 41, 59, 0.6)',
          border: '1px solid rgba(59, 130, 246, 0.3)',
          borderRadius: '14px',
          padding: '14px',
          display: 'flex',
          flexDirection: 'column'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
            <span style={{ fontSize: '11px', color: '#93c5fd', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              Blood Pressure
            </span>
            <Activity size={17} color="#3b82f6" />
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '4px', margin: '2px 0' }}>
            <span style={{ fontSize: '22px', fontWeight: '900', color: '#ffffff' }}>
              {vitals?.blood_pressure || '120/80'}
            </span>
            <span style={{ fontSize: '11px', color: '#93c5fd', fontWeight: '600' }}>mmHg</span>
          </div>
          <span style={{
            fontSize: '10px',
            fontWeight: '700',
            color: vitals?.blood_pressure_severity === 'high' ? '#f87171' : (vitals?.blood_pressure_severity === 'warning' ? '#fbbf24' : '#34d399')
          }}>
            {vitals?.blood_pressure_status || 'Optimal'}
          </span>
        </div>

        {/* Metric 3: Daily Steps */}
        <div style={{
          background: 'rgba(30, 41, 59, 0.6)',
          border: '1px solid rgba(16, 185, 129, 0.3)',
          borderRadius: '14px',
          padding: '14px',
          display: 'flex',
          flexDirection: 'column'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
            <span style={{ fontSize: '11px', color: '#6ee7b7', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              Steps Today
            </span>
            <Footprints size={17} color="#10b981" />
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '4px', margin: '2px 0' }}>
            <span style={{ fontSize: '24px', fontWeight: '900', color: '#ffffff' }}>
              {(vitals?.steps || 5840).toLocaleString()}
            </span>
          </div>
          <div style={{ width: '100%', height: '4px', background: 'rgba(255, 255, 255, 0.1)', borderRadius: '2px', marginTop: '6px', overflow: 'hidden' }}>
            <div style={{
              width: `${Math.min(100, ((vitals?.steps || 5840) / 10000) * 100)}%`,
              height: '100%',
              background: '#10b981',
              borderRadius: '2px'
            }} />
          </div>
        </div>

        {/* Metric 4: Active Calories */}
        <div style={{
          background: 'rgba(30, 41, 59, 0.6)',
          border: '1px solid rgba(249, 115, 22, 0.3)',
          borderRadius: '14px',
          padding: '14px',
          display: 'flex',
          flexDirection: 'column'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
            <span style={{ fontSize: '11px', color: '#fdba74', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              Active Burn
            </span>
            <Flame size={17} color="#f97316" />
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '4px', margin: '2px 0' }}>
            <span style={{ fontSize: '24px', fontWeight: '900', color: '#ffffff' }}>
              {vitals?.calories || 430}
            </span>
            <span style={{ fontSize: '11px', color: '#fdba74', fontWeight: '700' }}>kcal</span>
          </div>
          <span style={{ fontSize: '11px', color: '#94a3b8' }}>
            Target: 600 kcal
          </span>
        </div>

        {/* Metric 5: Sleep */}
        <div style={{
          background: 'rgba(30, 41, 59, 0.6)',
          border: '1px solid rgba(168, 85, 247, 0.3)',
          borderRadius: '14px',
          padding: '14px',
          display: 'flex',
          flexDirection: 'column'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
            <span style={{ fontSize: '11px', color: '#d8b4fe', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              Sleep Quality
            </span>
            <Moon size={17} color="#a855f7" />
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '4px', margin: '2px 0' }}>
            <span style={{ fontSize: '24px', fontWeight: '900', color: '#ffffff' }}>
              {vitals?.sleep_hours || 7.2}
            </span>
            <span style={{ fontSize: '11px', color: '#d8b4fe', fontWeight: '700' }}>hrs</span>
          </div>
          <span style={{ fontSize: '11px', color: '#c084fc', fontWeight: '600' }}>
            {vitals?.sleep_quality || 'Optimal'} (Score: {vitals?.sleep_score || 84})
          </span>
        </div>

        {/* Metric 6: SpO2 & Respiration */}
        <div style={{
          background: 'rgba(30, 41, 59, 0.6)',
          border: '1px solid rgba(6, 182, 212, 0.3)',
          borderRadius: '14px',
          padding: '14px',
          display: 'flex',
          flexDirection: 'column'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
            <span style={{ fontSize: '11px', color: '#67e8f9', fontWeight: '700', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
              Blood Oxygen
            </span>
            <Sparkles size={17} color="#06b6d4" />
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '4px', margin: '2px 0' }}>
            <span style={{ fontSize: '24px', fontWeight: '900', color: '#ffffff' }}>
              {vitals?.spo2 || 98}
            </span>
            <span style={{ fontSize: '12px', color: '#67e8f9', fontWeight: '700' }}>%</span>
          </div>
          <span style={{ fontSize: '11px', color: '#94a3b8' }}>
            Resp: <strong style={{ color: '#f8fafc' }}>{vitals?.respiratory_rate || 15} rpm</strong>
          </span>
        </div>

      </div>

      {/* Footer Actions: Copy for Clinical Scribe & WhatsApp Follow-up */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '10px', paddingTop: '10px', borderTop: '1px solid rgba(255, 255, 255, 0.08)' }}>
        <div style={{ fontSize: '11px', color: '#64748b', display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span>Active Patient: <strong style={{ color: '#cbd5e1' }}>{currentPatientName}</strong></span>
          <span>•</span>
          <span>Updated: {lastRefreshed.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</span>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <button
            onClick={() => setIsSyncModalOpen(true)}
            style={{
              background: 'linear-gradient(135deg, rgba(6, 182, 212, 0.25), rgba(59, 130, 246, 0.2))',
              border: '1px solid #06b6d4',
              color: '#38bdf8',
              borderRadius: '8px',
              padding: '6px 12px',
              fontSize: '11px',
              fontWeight: '700',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              transition: 'all 0.2s'
            }}
            title="Upload live reading from your physical Apple Watch into eHospital"
          >
            <Watch size={13} />
            <span>Sync Watch</span>
          </button>

          <button
            onClick={handleCopyVitals}
            style={{
              background: copied ? 'rgba(16, 185, 129, 0.2)' : 'rgba(255, 255, 255, 0.06)',
              border: `1px solid ${copied ? '#10b981' : 'rgba(255, 255, 255, 0.15)'}`,
              color: copied ? '#34d399' : '#e2e8f0',
              borderRadius: '8px',
              padding: '6px 12px',
              fontSize: '11px',
              fontWeight: '700',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              transition: 'all 0.2s'
            }}
            title="Inject vitals summary directly into physician consultation SOAP notes"
          >
            {copied ? <CheckCircle2 size={13} color="#34d399" /> : <Copy size={13} />}
            <span>{copied ? 'Copied to Scribe!' : 'Copy to Clinical Scribe'}</span>
          </button>
        </div>
      </div>

      {/* Live Apple Watch Manual Ingestion & Sync Modal */}
      {isSyncModalOpen && (
        <div style={{
          position: 'fixed',
          top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0,0,0,0.8)',
          backdropFilter: 'blur(6px)',
          zIndex: 99999,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '16px'
        }}>
          <div style={{
            background: 'rgba(15, 23, 42, 0.98)',
            border: '1px solid #06b6d4',
            borderRadius: '18px',
            width: '460px',
            maxWidth: '95vw',
            padding: '24px',
            boxShadow: '0 20px 50px rgba(0,0,0,0.7)',
            display: 'flex',
            flexDirection: 'column',
            gap: '16px'
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '12px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Watch size={20} color="#06b6d4" />
                <h3 style={{ margin: 0, fontSize: '16px', color: '#f8fafc', fontWeight: '800' }}>
                  Sync Apple Watch to {currentPatientName}
                </h3>
              </div>
              <button 
                onClick={() => setIsSyncModalOpen(false)}
                style={{ background: 'none', border: 'none', color: '#94a3b8', cursor: 'pointer', fontSize: '18px' }}
              >
                ✕
              </button>
            </div>

            {syncSuccessMsg && (
              <div style={{ padding: '10px 14px', background: 'rgba(16, 185, 129, 0.2)', border: '1px solid #10b981', color: '#34d399', borderRadius: '8px', fontSize: '12px', fontWeight: '700' }}>
                {syncSuccessMsg}
              </div>
            )}

            <form onSubmit={handleManualSync} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ fontSize: '11px', color: '#94a3b8', fontWeight: '600', display: 'block', marginBottom: '4px' }}>
                    Heart Rate (BPM)
                  </label>
                  <input
                    type="number"
                    value={manualForm.heart_rate}
                    onChange={(e) => setManualForm({ ...manualForm, heart_rate: e.target.value })}
                    style={{ width: '100%', padding: '8px 10px', background: 'rgba(30, 41, 59, 0.8)', border: '1px solid rgba(255,255,255,0.15)', borderRadius: '8px', color: 'white', fontSize: '13px', outline: 'none' }}
                  />
                </div>
                <div>
                  <label style={{ fontSize: '11px', color: '#94a3b8', fontWeight: '600', display: 'block', marginBottom: '4px' }}>
                    Resting HR (BPM)
                  </label>
                  <input
                    type="number"
                    value={manualForm.resting_heart_rate}
                    onChange={(e) => setManualForm({ ...manualForm, resting_heart_rate: e.target.value })}
                    style={{ width: '100%', padding: '8px 10px', background: 'rgba(30, 41, 59, 0.8)', border: '1px solid rgba(255,255,255,0.15)', borderRadius: '8px', color: 'white', fontSize: '13px', outline: 'none' }}
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ fontSize: '11px', color: '#94a3b8', fontWeight: '600', display: 'block', marginBottom: '4px' }}>
                    Blood Pressure (mmHg)
                  </label>
                  <input
                    type="text"
                    value={manualForm.blood_pressure}
                    onChange={(e) => setManualForm({ ...manualForm, blood_pressure: e.target.value })}
                    style={{ width: '100%', padding: '8px 10px', background: 'rgba(30, 41, 59, 0.8)', border: '1px solid rgba(255,255,255,0.15)', borderRadius: '8px', color: 'white', fontSize: '13px', outline: 'none' }}
                  />
                </div>
                <div>
                  <label style={{ fontSize: '11px', color: '#94a3b8', fontWeight: '600', display: 'block', marginBottom: '4px' }}>
                    Daily Steps
                  </label>
                  <input
                    type="number"
                    value={manualForm.steps}
                    onChange={(e) => setManualForm({ ...manualForm, steps: e.target.value })}
                    style={{ width: '100%', padding: '8px 10px', background: 'rgba(30, 41, 59, 0.8)', border: '1px solid rgba(255,255,255,0.15)', borderRadius: '8px', color: 'white', fontSize: '13px', outline: 'none' }}
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                <div>
                  <label style={{ fontSize: '11px', color: '#94a3b8', fontWeight: '600', display: 'block', marginBottom: '4px' }}>
                    Active Energy (kcal)
                  </label>
                  <input
                    type="number"
                    value={manualForm.calories}
                    onChange={(e) => setManualForm({ ...manualForm, calories: e.target.value })}
                    style={{ width: '100%', padding: '8px 10px', background: 'rgba(30, 41, 59, 0.8)', border: '1px solid rgba(255,255,255,0.15)', borderRadius: '8px', color: 'white', fontSize: '13px', outline: 'none' }}
                  />
                </div>
                <div>
                  <label style={{ fontSize: '11px', color: '#94a3b8', fontWeight: '600', display: 'block', marginBottom: '4px' }}>
                    Sleep Duration (hrs)
                  </label>
                  <input
                    type="number"
                    step="0.1"
                    value={manualForm.sleep}
                    onChange={(e) => setManualForm({ ...manualForm, sleep: e.target.value })}
                    style={{ width: '100%', padding: '8px 10px', background: 'rgba(30, 41, 59, 0.8)', border: '1px solid rgba(255,255,255,0.15)', borderRadius: '8px', color: 'white', fontSize: '13px', outline: 'none' }}
                  />
                </div>
              </div>

              <div style={{ marginTop: '8px', display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
                <button
                  type="button"
                  onClick={() => setIsSyncModalOpen(false)}
                  style={{ padding: '8px 14px', background: 'transparent', border: '1px solid rgba(255,255,255,0.2)', color: '#94a3b8', borderRadius: '8px', fontSize: '12px', cursor: 'pointer' }}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={syncSubmitting}
                  style={{
                    padding: '8px 18px',
                    background: 'linear-gradient(135deg, #0284c7, #06b6d4)',
                    border: 'none',
                    color: 'white',
                    borderRadius: '8px',
                    fontSize: '12px',
                    fontWeight: '700',
                    cursor: 'pointer',
                    boxShadow: '0 4px 14px rgba(6, 182, 212, 0.4)'
                  }}
                >
                  {syncSubmitting ? 'Syncing...' : 'Upload to Cloud Database'}
                </button>
              </div>
            </form>

            <div style={{ borderTop: '1px solid rgba(255,255,255,0.08)', paddingTop: '10px', fontSize: '11px', color: '#64748b' }}>
              💡 <strong>Automatic Sync:</strong> Run the companion iOS Flutter app or set up an Apple Shortcut to POST to <code>/api/wearables/ingest</code> for zero-touch background watch syncing.
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
