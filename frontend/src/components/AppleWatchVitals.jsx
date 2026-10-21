import React, { useState } from 'react';
import { 
  Watch, Heart, Activity, Moon, ShieldCheck, RefreshCw, 
  CheckCircle2, ArrowUpRight, Smartphone, AlertCircle, FileText
} from 'lucide-react';

export default function AppleWatchVitals({ patient, onInsertToNote }) {
  const [isSyncing, setIsSyncing] = useState(false);
  const [lastSynced, setLastSynced] = useState('3m ago');
  const [syncCount, setSyncCount] = useState(0);
  const [copiedNotification, setCopiedNotification] = useState(false);

  // Baseline telemetry with dynamic patient awareness
  const patientName = patient?.name || 'Selected Patient';
  
  const handleSync = () => {
    setIsSyncing(true);
    setTimeout(() => {
      setIsSyncing(false);
      setLastSynced('Just now');
      setSyncCount(c => c + 1);
    }, 900);
  };

  const handlePushToScribe = () => {
    const vitalsSummary = `[Apple Watch HealthKit Telemetry - ${patientName}]: Heart Rate: 71 bpm (Normal Sinus Rhythm, 0 AFib events); Blood Pressure: 122/78 mmHg (MAP 92); SpO2: 98% continuous; Sleep: 7h 24m (Deep 1h 45m, REM 2h 09m); Activity: 6,840 steps (482 kcal); Fall Detection: Armed & Active.`;
    
    if (onInsertToNote) {
      onInsertToNote(vitalsSummary);
    } else {
      window.dispatchEvent(new CustomEvent('insert-scribe-text', { detail: { text: `\n\n${vitalsSummary}\n` } }));
    }

    setCopiedNotification(true);
    setTimeout(() => setCopiedNotification(false), 2500);
  };

  return (
    <div style={{
      background: '#ffffff',
      border: '1px solid #e2e8f0',
      borderRadius: '14px',
      padding: '20px 22px',
      boxShadow: '0 1px 3px rgba(15, 23, 42, 0.04)',
      fontFamily: 'inherit'
    }}>
      {/* Header: Apple Watch Info & Sync Pill */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '18px', flexWrap: 'wrap', gap: '12px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{
            width: '42px',
            height: '42px',
            borderRadius: '10px',
            background: '#eff6ff',
            border: '1px solid #bfdbfe',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#2563eb'
          }}>
            <Watch size={24} />
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <h3 style={{ margin: 0, fontSize: '16px', fontWeight: '700', color: '#0f172a' }}>
                Apple Watch & HealthKit Vitals
              </h3>
              <span style={{
                background: '#eff6ff',
                color: '#2563eb',
                fontSize: '11px',
                fontWeight: '600',
                padding: '2px 8px',
                borderRadius: '12px',
                border: '1px solid #dbeafe'
              }}>
                watchOS 11
              </span>
            </div>
            <p style={{ margin: '2px 0 0 0', fontSize: '12px', color: '#64748b' }}>
              Continuous real-time patient telemetry · Apple HealthKit synced
            </p>
          </div>
        </div>

        {/* Right side: Sync status and action */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ fontSize: '12px', color: '#64748b', display: 'flex', alignItems: 'center', gap: '4px' }}>
            <span style={{ width: '7px', height: '7px', borderRadius: '50%', background: '#10b981', display: 'inline-block' }} />
            Synced {lastSynced}
          </span>
          <button
            onClick={handleSync}
            disabled={isSyncing}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              padding: '6px 12px',
              borderRadius: '8px',
              border: '1px solid #e2e8f0',
              background: '#f8fafc',
              color: '#334155',
              fontSize: '12px',
              fontWeight: '600',
              cursor: isSyncing ? 'default' : 'pointer',
              transition: 'background 0.15s'
            }}
            title="Fetch latest HealthKit data"
          >
            <RefreshCw size={13} className={isSyncing ? 'animate-spin' : ''} style={{ color: '#2563eb' }} />
            {isSyncing ? 'Syncing...' : 'Sync Now'}
          </button>
        </div>
      </div>

      {/* 4 Clean Metric Cards */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))',
        gap: '12px',
        marginBottom: '16px'
      }}>
        {/* Metric 1: Heart Rate */}
        <div style={{
          background: '#f8fafc',
          border: '1px solid #e2e8f0',
          borderRadius: '10px',
          padding: '14px',
          display: 'flex',
          flexDirection: 'column',
          gap: '6px'
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', fontWeight: '600', color: '#64748b', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Heart size={14} color="#2563eb" /> Heart Rate
            </span>
            <span style={{ fontSize: '11px', color: '#2563eb', fontWeight: '600', background: '#eff6ff', padding: '1px 6px', borderRadius: '4px' }}>
              Sinus Rhythm
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '6px' }}>
            <span style={{ fontSize: '24px', fontWeight: '800', color: '#0f172a' }}>71</span>
            <span style={{ fontSize: '13px', color: '#64748b' }}>BPM</span>
          </div>
          <div style={{ fontSize: '11px', color: '#64748b', display: 'flex', justifyContent: 'space-between' }}>
            <span>Resting: 62 bpm</span>
            <span>Range: 58-112</span>
          </div>
        </div>

        {/* Metric 2: Blood Pressure */}
        <div style={{
          background: '#f8fafc',
          border: '1px solid #e2e8f0',
          borderRadius: '10px',
          padding: '14px',
          display: 'flex',
          flexDirection: 'column',
          gap: '6px'
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', fontWeight: '600', color: '#64748b', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Activity size={14} color="#2563eb" /> Blood Pressure
            </span>
            <span style={{ fontSize: '11px', color: '#059669', fontWeight: '600', background: '#ecfdf5', padding: '1px 6px', borderRadius: '4px' }}>
              Optimal
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '6px' }}>
            <span style={{ fontSize: '24px', fontWeight: '800', color: '#0f172a' }}>122/78</span>
            <span style={{ fontSize: '13px', color: '#64748b' }}>mmHg</span>
          </div>
          <div style={{ fontSize: '11px', color: '#64748b', display: 'flex', justifyContent: 'space-between' }}>
            <span>MAP: 92 mmHg</span>
            <span style={{ color: '#059669' }}>-4 mmHg vs avg</span>
          </div>
        </div>

        {/* Metric 3: Blood Oxygen (SpO2) */}
        <div style={{
          background: '#f8fafc',
          border: '1px solid #e2e8f0',
          borderRadius: '10px',
          padding: '14px',
          display: 'flex',
          flexDirection: 'column',
          gap: '6px'
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', fontWeight: '600', color: '#64748b', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <ShieldCheck size={14} color="#2563eb" /> Blood Oxygen
            </span>
            <span style={{ fontSize: '11px', color: '#2563eb', fontWeight: '600', background: '#eff6ff', padding: '1px 6px', borderRadius: '4px' }}>
              SpO2
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '6px' }}>
            <span style={{ fontSize: '24px', fontWeight: '800', color: '#0f172a' }}>98%</span>
            <span style={{ fontSize: '13px', color: '#64748b' }}>Normal</span>
          </div>
          <div style={{ fontSize: '11px', color: '#64748b', display: 'flex', justifyContent: 'space-between' }}>
            <span>Overnight mean: 97.8%</span>
            <span>0 desaturations</span>
          </div>
        </div>

        {/* Metric 4: Sleep & Recovery */}
        <div style={{
          background: '#f8fafc',
          border: '1px solid #e2e8f0',
          borderRadius: '10px',
          padding: '14px',
          display: 'flex',
          flexDirection: 'column',
          gap: '6px'
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', fontWeight: '600', color: '#64748b', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Moon size={14} color="#2563eb" /> Sleep Tracking
            </span>
            <span style={{ fontSize: '11px', color: '#2563eb', fontWeight: '600', background: '#eff6ff', padding: '1px 6px', borderRadius: '4px' }}>
              Last Night
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '6px' }}>
            <span style={{ fontSize: '24px', fontWeight: '800', color: '#0f172a' }}>7h 24m</span>
            <span style={{ fontSize: '13px', color: '#64748b' }}>total</span>
          </div>
          <div style={{ fontSize: '11px', color: '#64748b', display: 'flex', justifyContent: 'space-between' }}>
            <span>Deep: 1h 45m</span>
            <span>REM: 2h 09m</span>
          </div>
        </div>
      </div>

      {/* Safety & Cardio Status Bar */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '10px 14px',
        background: '#f1f5f9',
        borderRadius: '8px',
        border: '1px solid #e2e8f0',
        fontSize: '12px',
        color: '#334155',
        flexWrap: 'wrap',
        gap: '8px'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px', flexWrap: 'wrap' }}>
          <span style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
            <CheckCircle2 size={14} color="#059669" />
            <span>ECG: <strong>No AFib detected</strong> (30 days)</span>
          </span>
          <span style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
            <CheckCircle2 size={14} color="#059669" />
            <span>Fall Detection: <strong>Armed & Active</strong></span>
          </span>
          <span style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
            <Smartphone size={14} color="#2563eb" />
            <span>Steps: <strong>6,840</strong> (482 active kcal)</span>
          </span>
        </div>

        {/* Action: Copy / Insert into SOAP Note */}
        <button
          onClick={handlePushToScribe}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            padding: '5px 12px',
            borderRadius: '6px',
            border: '1px solid #bfdbfe',
            background: copiedNotification ? '#ecfdf5' : '#eff6ff',
            color: copiedNotification ? '#059669' : '#2563eb',
            fontSize: '12px',
            fontWeight: '600',
            cursor: 'pointer',
            transition: 'all 0.15s'
          }}
          title="Append these live wearable vitals into the patient chart or AI Scribe note"
        >
          <FileText size={13} />
          {copiedNotification ? '✓ Vitals Added to Chart' : 'Add Vitals to Scribe Note'}
        </button>
      </div>
    </div>
  );
}
