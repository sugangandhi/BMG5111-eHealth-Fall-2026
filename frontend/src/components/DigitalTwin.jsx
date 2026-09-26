import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { motion, AnimatePresence } from 'framer-motion';
import { Activity, Bone, HeartPulse, Brain, Crosshair, ChevronRight, CheckCircle2, FileText, Download, Flame, Layers, Clock, Watch, Loader, Dna, Sparkles } from 'lucide-react';
import True3DTwin from './True3DTwin';
import SynchronizedCTViewer from './SynchronizedCTViewer';

export default function DigitalTwin() {
  const [selectedPatientId, setSelectedPatientId] = useState('p1');
  const [selectedPart, setSelectedPart] = useState(null);
  
  // New State Features
  const [year, setYear] = useState(2024);
  const [activeLayer, setActiveLayer] = useState('all');
  const [showHeatmap, setShowHeatmap] = useState(false);
  const [heartRate, setHeartRate] = useState(72);
  const [spo2, setSpo2] = useState(98);
  const [viewMode, setViewMode] = useState('ct-sync'); // 'ct-sync' | '2d' | '3d'

  // When patient changes, close the panel
  useEffect(() => {
    setSelectedPart(null);
  }, [selectedPatientId]);

  // Live Biometrics Simulator
  useEffect(() => {
    const interval = setInterval(() => {
      setHeartRate(prev => {
        const jump = Math.floor(Math.random() * 5) - 2; // -2 to +2
        let newHr = prev + jump;
        if (newHr < 65) newHr = 65;
        if (newHr > 85) newHr = 85;
        return newHr;
      });
      
      setSpo2(prev => {
        if (Math.random() > 0.8) return prev === 99 ? 98 : 99;
        return prev;
      });
    }, 2000);
    return () => clearInterval(interval);
  }, []);


  const [patients, setPatients] = useState({});
  const [loading, setLoading] = useState(true);

  const HOLO_BLUE = "#3b82f6";
  const HOLO_CYAN = "#06b6d4";
  const HOLO_GREEN = "#10b981";
  const HOLO_RED = "#ef4444";

  useEffect(() => {
    const fetchPatients = async () => {
      try {
        const token = localStorage.getItem('medoffice_token');
        const res = await axios.get('/api/appointments', {
          headers: { Authorization: `Bearer ${token}` }
        });
        
        // Filter upcoming
        const appointmentsArray = res.data.appointments || [];
        const upcoming = appointmentsArray.filter(a => a.status === 'upcoming' || a.status === 'in-progress');
        
        let pMap = {};
        upcoming.forEach(appt => {
            const p = appt.type.toLowerCase();
            let anatomy = {};
            if (p.includes('asthma') || p.includes('copd') || p.includes('oncology') || p.includes('chest') || p.includes('heart')) {
              anatomy.chest = {
                  id: 'chest', system: 'cardio', year: 2022, title: 'Cardiology / Lungs',
                  icon: <HeartPulse size={24} color={HOLO_CYAN} />, status: 'Attention Required',
                  color: HOLO_CYAN, image: '/mock_ecg.jpg', x: 50, y: 32, risk: 0.8,
                  records: [
                    { date: '2024-05-12', type: '12-Lead ECG', notes: 'Sinus rhythm with occasional PACs.' },
                    { date: '2022-09-21', type: 'Chest X-Ray', notes: 'Clear lungs. No active disease.' }
                  ]
              };
            }
            if (p.includes('wsib') || p.includes('ra') || p.includes('knee') || p.includes('bone') || p.includes('ortho')) {
              anatomy.knee = {
                  id: 'knee', system: 'skeletal', year: 2023, title: 'Right Knee Joint',
                  icon: <Bone size={24} color={HOLO_GREEN} />, status: 'Post-Op Recovery',
                  color: HOLO_GREEN, image: '/mock_knee_mri.jpg', x: 42, y: 72, risk: 0.3,
                  hasPlate: true, plateYear: 2024,
                  records: [
                    { date: '2024-01-18', type: 'Surgical Note', notes: 'Arthroscopic ACL reconstruction. Titanium plate.' },
                    { date: '2023-12-05', type: 'MRI Right Knee', notes: 'Complete tear of the ACL.' }
                  ]
              };
            }
            if (p.includes('mental health') || p.includes('oat') || p.includes('migraine') || p.includes('neuro')) {
              anatomy.head = {
                  id: 'head', system: 'neuro', year: 2023, title: 'Neurology / Brain',
                  icon: <Brain size={24} color={HOLO_BLUE} />, status: 'Normal',
                  color: HOLO_BLUE, x: 50, y: 12, risk: 0.9,
                  records: [
                    { date: '2023-11-04', type: 'MRI Brain', notes: 'No acute intracranial abnormality.' },
                    { date: '2023-02-15', type: 'Concussion Screening', notes: 'Cleared.' }
                  ]
              };
            }
            
            // Fallback
            if (Object.keys(anatomy).length === 0) {
               anatomy.chest = {
                  id: 'chest', system: 'cardio', year: 2022, title: 'General Checkup',
                  icon: <HeartPulse size={24} color={HOLO_CYAN} />, status: 'Normal', color: HOLO_CYAN,
                  x: 50, y: 32, risk: 0.2, records: [{ date: '2022-09-21', type: 'Vitals', notes: 'Normal.' }]
               };
            }

            pMap[appt.patient_id] = {
                id: appt.patient_id,
                name: appt.patient_name,
                dob: '01/01/1980', // mockup
                mrn: appt.patient_id.toUpperCase(),
                reason: appt.type,
                anatomy: anatomy
            };
        });
        
        setPatients(pMap);
        if (upcoming.length > 0) {
            setSelectedPatientId(upcoming[0].patient_id);
        }
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    fetchPatients();
  }, []);

  const activePatient = patients[selectedPatientId];

  if (loading) {
    return <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100%' }}><Loader className="animate-spin" color="#06b6d4" /></div>;
  }
  
  if (!activePatient) {
    return <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100%', color: 'white' }}>No upcoming patients found.</div>;
  }

  const activeAnatomy = activePatient.anatomy;


  // Node Component
  const AnatomyNode = ({ id, x, y, pulseColor, label, nodeYear, system }) => {
    // Idea 1: Time Machine Filter
    if (year < nodeYear) return null;
    
    // Idea 5: System Layers Filter
    if (activeLayer !== 'all' && activeLayer !== system) return null;

    const isActive = selectedPart === id;
    
    return (
      <motion.div 
        initial={{ opacity: 0, scale: 0 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0 }}
        onClick={() => setSelectedPart(id)}
        style={{
          position: 'absolute', top: `${y}%`, left: `${x}%`, transform: 'translate(-50%, -50%)',
          display: 'flex', flexDirection: 'column', alignItems: 'center', cursor: 'pointer', zIndex: 10
        }}
      >
        <div style={{ position: 'relative', display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
          {/* Glowing pulse ring */}
          <motion.div 
            animate={{ scale: [1, 1.5, 1], opacity: [0.5, 0, 0.5] }} 
            transition={{ repeat: Infinity, duration: 2 }}
            style={{ position: 'absolute', width: '32px', height: '32px', borderRadius: '50%', border: `2px solid ${pulseColor}` }}
          />
          {/* Core dot */}
          <div style={{ 
            width: '16px', height: '16px', borderRadius: '50%', background: pulseColor, 
            boxShadow: `0 0 15px ${pulseColor}, 0 0 30px ${pulseColor}`, border: '2px solid white',
            transform: isActive ? 'scale(1.2)' : 'scale(1)', transition: 'transform 0.2s'
          }} />
        </div>
        
        {/* Floating Label */}
        <div style={{ 
          marginTop: '12px', background: 'rgba(15, 23, 42, 0.8)', border: `1px solid ${pulseColor}`, 
          color: 'white', padding: '4px 10px', borderRadius: '20px', fontSize: '11px', fontWeight: 'bold',
          letterSpacing: '1px', textTransform: 'uppercase', backdropFilter: 'blur(4px)',
          boxShadow: `0 4px 10px rgba(0,0,0,0.5)`, opacity: isActive ? 1 : 0.7, transition: 'all 0.2s'
        }}>
          {label}
        </div>
      </motion.div>
    );
  };

  return (
    <div className="digital-twin-container" style={{ padding: '24px', height: '100%', display: 'flex', gap: '24px', overflow: 'hidden' }}>
      
      {/* Sidebar Controls */}
      <div className="glass-panel digital-twin-sidebar" style={{ width: '320px', display: 'flex', flexDirection: 'column', borderRadius: '24px', padding: '24px', border: '1px solid rgba(6, 182, 212, 0.3)', overflowY: 'auto' }}>
        <h2 style={{ fontSize: '20px', fontWeight: '800', margin: '0 0 24px 0', display: 'flex', alignItems: 'center', gap: '10px' }}>
          <Activity color={HOLO_CYAN} />
          Digital Twin
        </h2>
        
        {/* Patient Selection */}
        <div style={{ fontSize: '12px', fontWeight: '700', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '1px', marginBottom: '12px' }}>
          Active Patient
        </div>
        
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginBottom: '32px' }}>
          {Object.values(patients).map(p => (
            <div 
              key={p.id}
              onClick={() => setSelectedPatientId(p.id)}
              style={{
                padding: '16px', borderRadius: '16px', cursor: 'pointer', transition: 'all 0.2s',
                background: selectedPatientId === p.id ? 'rgba(6, 182, 212, 0.15)' : 'var(--bg-secondary)',
                border: selectedPatientId === p.id ? `1px solid ${HOLO_CYAN}` : '1px solid var(--border)'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px' }}>
                <div style={{ width: '32px', height: '32px', borderRadius: '50%', background: selectedPatientId === p.id ? HOLO_CYAN : 'var(--bg-tertiary)', color: selectedPatientId === p.id ? 'black' : 'var(--text-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: '700', fontSize: '14px' }}>
                  {p.name.charAt(0)}
                </div>
                <div style={{ fontWeight: '700', fontSize: '15px' }}>{p.name}</div>
              </div>
              <div style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>
                MRN: {p.mrn} • {p.dob}
              </div>
            </div>
          ))}
        </div>

        {/* Global Controls */}
        <div style={{ fontSize: '12px', fontWeight: '700', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '1px', marginBottom: '12px' }}>
          Display Controls
        </div>

        {/* View Mode Toggle: 3 Modes */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginBottom: '24px' }}>
          <button 
            onClick={() => setViewMode('ct-sync')}
            style={{ 
              padding: '10px 14px', 
              background: viewMode === 'ct-sync' ? 'linear-gradient(135deg, #0284c7, #06b6d4)' : 'rgba(255,255,255,0.04)', 
              border: `1px solid ${viewMode === 'ct-sync' ? '#06b6d4' : 'var(--border)'}`, 
              color: 'white', 
              borderRadius: '10px', 
              cursor: 'pointer', 
              fontSize: '13px', 
              fontWeight: '700', 
              display: 'flex', 
              alignItems: 'center', 
              justifyContent: 'space-between',
              boxShadow: viewMode === 'ct-sync' ? '0 0 16px rgba(6, 182, 212, 0.4)' : 'none'
            }}
          >
            <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Sparkles size={16} /> Sync 3D & CT MPR
            </span>
            <span style={{ fontSize: '10px', padding: '2px 6px', borderRadius: '4px', background: 'rgba(255,255,255,0.2)', fontWeight: 'bold' }}>HIGH-END</span>
          </button>

          <div style={{ display: 'flex', gap: '8px' }}>
            <button 
              onClick={() => setViewMode('2d')}
              style={{ flex: 1, padding: '9px', background: viewMode === '2d' ? '#06b6d4' : 'transparent', border: `1px solid ${viewMode === '2d' ? '#06b6d4' : 'var(--border)'}`, color: viewMode === '2d' ? 'white' : 'var(--text-primary)', borderRadius: '6px', cursor: 'pointer', fontSize: '12px', fontWeight: '600', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
            >
              <Crosshair size={13} /> 2D Scan
            </button>
            <button 
              onClick={() => setViewMode('3d')}
              style={{ flex: 1, padding: '9px', background: viewMode === '3d' ? '#10b981' : 'transparent', border: `1px solid ${viewMode === '3d' ? '#10b981' : 'var(--border)'}`, color: viewMode === '3d' ? 'white' : 'var(--text-primary)', borderRadius: '6px', cursor: 'pointer', fontSize: '12px', fontWeight: '600', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}
            >
              <Dna size={13} /> Point Cloud
            </button>
          </div>
        </div>

        {/* Idea 5: System Layers */}
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px', marginBottom: '24px' }}>
          {['all', 'cardio', 'neuro', 'skeletal'].map(layer => (
            <button
              key={layer}
              onClick={() => setActiveLayer(layer)}
              style={{
                padding: '6px 12px', borderRadius: '20px', fontSize: '12px', fontWeight: '700', textTransform: 'capitalize', cursor: 'pointer',
                background: activeLayer === layer ? HOLO_CYAN : 'transparent',
                color: activeLayer === layer ? 'black' : 'var(--text-secondary)',
                border: `1px solid ${activeLayer === layer ? HOLO_CYAN : 'var(--border)'}`,
                display: 'flex', alignItems: 'center', gap: '6px'
              }}
            >
              <Layers size={14} /> {layer}
            </button>
          ))}
        </div>

        {/* Idea 2: AI Predictive Heatmap */}
        <div 
          onClick={() => setShowHeatmap(!showHeatmap)}
          style={{ 
            background: showHeatmap ? 'rgba(239, 68, 68, 0.15)' : 'var(--bg-secondary)', 
            border: `1px solid ${showHeatmap ? HOLO_RED : 'var(--border)'}`, 
            padding: '16px', borderRadius: '12px', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            marginBottom: '32px'
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <Flame color={showHeatmap ? HOLO_RED : 'var(--text-secondary)'} size={20} className={showHeatmap ? 'animate-pulse' : ''} />
            <span style={{ fontWeight: '600', color: showHeatmap ? HOLO_RED : 'var(--text-primary)' }}>AI Risk Heatmap</span>
          </div>
          <div style={{ width: '40px', height: '24px', background: showHeatmap ? HOLO_RED : 'var(--bg-tertiary)', borderRadius: '12px', position: 'relative', transition: '0.3s' }}>
            <div style={{ position: 'absolute', top: '2px', left: showHeatmap ? '18px' : '2px', width: '20px', height: '20px', background: 'white', borderRadius: '50%', transition: '0.3s' }} />
          </div>
        </div>

      </div>

      <div style={{ flex: 1, display: 'flex', gap: '24px', position: 'relative', flexDirection: 'column', minHeight: 0 }}>
        
        {viewMode === 'ct-sync' ? (
          <SynchronizedCTViewer activePatient={activePatient} />
        ) : (
          <>
            {/* Hologram Container */}
            <motion.div 
              className="digital-twin-viewport"
              layout
              initial={{ borderRadius: '24px' }}
          animate={{ width: selectedPart ? '45%' : '100%' }}
          transition={{ type: 'spring', bounce: 0, duration: 0.5 }}
          style={{ 
            background: 'radial-gradient(circle at center, rgba(15,23,42,1) 0%, rgba(0,0,0,1) 100%)', 
            border: `1px solid rgba(6, 182, 212, 0.3)`, 
            boxShadow: 'inset 0 0 60px rgba(6, 182, 212, 0.1)',
            position: 'relative', overflow: 'hidden', display: 'flex', justifyContent: 'center', alignItems: 'center',
            borderRadius: '24px', flex: 1
          }}
        >
          {/* Cybernetic grid background overlay */}
          <div style={{ 
            position: 'absolute', inset: 0, opacity: 0.05, pointerEvents: 'none',
            backgroundImage: `linear-gradient(${HOLO_CYAN} 1px, transparent 1px), linear-gradient(90deg, ${HOLO_CYAN} 1px, transparent 1px)`,
            backgroundSize: '40px 40px'
          }} />

          {/* High-fidelity Realistic Skeleton Scan Map */}
          <div style={{ position: 'relative', height: '95%', aspectRatio: '9/16' }}>
            
          {/* 3D View Overwrite */}
          {viewMode === '3d' && <True3DTwin />}

          {/* Hologram Core (Only show in 2D mode) */}
          <div style={{ 
            width: '100%', height: '100%', 
            backgroundImage: `url(/skeleton_scan.jpg)`, 
            backgroundSize: 'cover', backgroundPosition: 'center',
            mixBlendMode: 'screen', opacity: viewMode === '3d' ? 0 : (showHeatmap ? 0.6 : 0.85),
            transition: 'opacity 0.3s',
            pointerEvents: viewMode === '3d' ? 'none' : 'auto',
            display: viewMode === '3d' ? 'none' : 'block'
          }} />

            {/* Idea 2: Heatmap Overlay */}
            <AnimatePresence>
              {showHeatmap && Object.values(activeAnatomy).map(node => (
                <motion.div 
                  key={`heat-${node.id}`}
                  initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                  style={{ 
                    position: 'absolute', top: `${node.y}%`, left: `${node.x}%`, transform: 'translate(-50%, -50%)',
                    width: `${node.risk * 200}px`, height: `${node.risk * 200}px`,
                    background: `radial-gradient(circle, rgba(239, 68, 68, 0.4) 0%, rgba(239, 68, 68, 0) 70%)`,
                    pointerEvents: 'none', mixBlendMode: 'screen', zIndex: 5,
                    filter: 'blur(10px)'
                  }}
                />
              ))}
            </AnimatePresence>

            {/* Idea 3: Spatial Anatomy Nodes (Only show in 2D mode) */}
            <AnimatePresence>
              {viewMode === '2d' && Object.values(activeAnatomy).map(node => (
                <AnatomyNode 
                  key={node.id} 
                  id={node.id} 
                  x={node.x} 
                  y={node.y} 
                  pulseColor={node.color} 
                  label={node.title} 
                  nodeYear={node.year}
                  system={node.system}
                />
              ))}
            </AnimatePresence>
            
            {/* Holographic Overlay for Knee (Titanium Plate Indicator) */}
            <AnimatePresence>
              {selectedPart === 'knee' && activeAnatomy.knee?.hasPlate && year >= activeAnatomy.knee.plateYear && (
                <motion.div 
                  initial={{ opacity: 0, scale: 0.5 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0 }}
                  style={{ position: 'absolute', top: `${activeAnatomy.knee.y}%`, left: `${activeAnatomy.knee.x}%`, transform: 'translate(-50%, -50%)', zIndex: 5, pointerEvents: 'none' }}
                >
                  <div style={{ width: '40px', height: '60px', border: `2px solid ${HOLO_GREEN}`, borderRadius: '4px', background: 'rgba(16, 185, 129, 0.2)', boxShadow: `0 0 20px ${HOLO_GREEN}`, display: 'flex', flexDirection: 'column', gap: '4px', padding: '4px', alignItems: 'center', justifyContent: 'center' }}>
                    <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: HOLO_GREEN }} />
                    <div style={{ width: '2px', height: '30px', background: HOLO_GREEN }} />
                    <div style={{ width: '6px', height: '6px', borderRadius: '50%', background: HOLO_GREEN }} />
                  </div>
                </motion.div>
              )}
            </AnimatePresence>

            {/* Idea 4: Live Biometric HUD (only if Cardio is active and Chest is rendered) */}
            <AnimatePresence>
              {activeAnatomy.chest && year >= activeAnatomy.chest.year && (activeLayer === 'all' || activeLayer === 'cardio') && (
                <motion.div 
                  initial={{ opacity: 0, x: -20 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -20 }}
                  style={{ position: 'absolute', top: `${activeAnatomy.chest.y}%`, left: `${activeAnatomy.chest.x + 15}%`, transform: 'translateY(-50%)', zIndex: 10, pointerEvents: 'none' }}
                >
                  <div style={{ background: 'rgba(15, 23, 42, 0.9)', border: `1px solid ${HOLO_CYAN}`, padding: '10px 16px', borderRadius: '12px', display: 'flex', flexDirection: 'column', gap: '8px', boxShadow: `0 10px 30px rgba(0,0,0,0.5)` }}>
                    <div style={{ fontSize: '10px', color: HOLO_CYAN, fontWeight: '700', textTransform: 'uppercase', letterSpacing: '1px', display: 'flex', alignItems: 'center', gap: '6px' }}><Watch size={12} /> Live Apple Watch Telemetry</div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                      <div>
                        <div style={{ fontSize: '10px', color: 'var(--text-secondary)' }}>HEART RATE</div>
                        <div style={{ fontSize: '20px', fontWeight: '800', color: 'white', display: 'flex', alignItems: 'baseline', gap: '4px' }}>{heartRate} <span style={{ fontSize: '10px', color: HOLO_CYAN }}>BPM</span></div>
                      </div>
                      <div style={{ width: '1px', height: '20px', background: 'rgba(255,255,255,0.1)' }} />
                      <div>
                        <div style={{ fontSize: '10px', color: 'var(--text-secondary)' }}>SpO2</div>
                        <div style={{ fontSize: '20px', fontWeight: '800', color: 'white', display: 'flex', alignItems: 'baseline', gap: '4px' }}>{spo2} <span style={{ fontSize: '10px', color: HOLO_CYAN }}>%</span></div>
                      </div>
                    </div>
                  </div>
                  {/* Connecting Line */}
                  <svg style={{ position: 'absolute', top: '50%', left: '-15%', width: '15%', height: '2px', overflow: 'visible' }}>
                    <line x1="0" y1="0" x2="100%" y2="0" stroke={HOLO_CYAN} strokeWidth="1" strokeDasharray="2 2" />
                    <circle cx="0" cy="0" r="3" fill={HOLO_CYAN} />
                  </svg>
                </motion.div>
              )}
            </AnimatePresence>
            
          </div>
        </motion.div>

        {/* Idea 1: Time Machine Slider */}
        <div className="glass-panel" style={{ height: '80px', borderRadius: '24px', padding: '0 32px', display: 'flex', alignItems: 'center', gap: '24px', border: '1px solid rgba(6, 182, 212, 0.3)' }}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '4px', minWidth: '80px' }}>
            <Clock size={20} color={HOLO_CYAN} />
            <span style={{ fontSize: '10px', fontWeight: '700', color: HOLO_CYAN, textTransform: 'uppercase' }}>Time Machine</span>
          </div>
          
          <input 
            type="range" min="2020" max="2024" step="1" 
            value={year} onChange={(e) => setYear(parseInt(e.target.value))}
            style={{ flex: 1, accentColor: HOLO_CYAN, cursor: 'pointer' }}
          />
          
          <div style={{ fontSize: '32px', fontWeight: '800', color: 'var(--text-primary)', fontVariantNumeric: 'tabular-nums', minWidth: '80px', textAlign: 'right' }}>
            {year}
          </div>
        </div>

        {/* Dynamic Context Panel */}
        <AnimatePresence>
          {selectedPart && activeAnatomy[selectedPart] && (
            <motion.div 
              layout
              initial={{ opacity: 0, x: 50 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: 50, display: 'none' }}
              transition={{ type: 'spring', bounce: 0, duration: 0.5 }}
              className="glass-panel"
              style={{ 
                position: 'absolute', right: 0, top: 0, bottom: '104px', width: '50%',
                borderRadius: '24px', padding: '32px', display: 'flex', flexDirection: 'column', 
                border: `1px solid ${activeAnatomy[selectedPart].color}`, overflowY: 'auto',
                boxShadow: '-20px 0 50px rgba(0,0,0,0.5)'
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '24px' }}>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px' }}>
                    {activeAnatomy[selectedPart].icon}
                    <h3 style={{ fontSize: '28px', fontWeight: '800', margin: 0, color: activeAnatomy[selectedPart].color }}>
                      {activeAnatomy[selectedPart].title}
                    </h3>
                  </div>
                  <div style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', background: 'rgba(255,255,255,0.1)', padding: '6px 12px', borderRadius: '20px', fontSize: '12px', fontWeight: 'bold', color: 'var(--text-secondary)', border: '1px solid rgba(255,255,255,0.05)' }}>
                    <Crosshair size={14} /> STATUS: <span style={{ color: activeAnatomy[selectedPart].color }}>{activeAnatomy[selectedPart].status}</span>
                  </div>
                </div>
                
                <button 
                  onClick={() => setSelectedPart(null)}
                  style={{ background: 'rgba(255,255,255,0.1)', border: 'none', color: 'var(--text-secondary)', padding: '8px 16px', borderRadius: '20px', fontSize: '13px', fontWeight: 'bold', cursor: 'pointer', transition: 'background 0.2s' }}
                  onMouseOver={e => e.currentTarget.style.background = 'rgba(255,255,255,0.15)'}
                  onMouseOut={e => e.currentTarget.style.background = 'rgba(255,255,255,0.1)'}
                >
                  Close Panel
                </button>
              </div>

              {/* Mapped Imaging */}
              {activeAnatomy[selectedPart].image && (
                <div style={{ marginBottom: '32px' }}>
                  <h4 style={{ fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '1px', marginBottom: '12px', fontWeight: '700' }}>Attached Imaging</h4>
                  <div style={{ position: 'relative', borderRadius: '16px', overflow: 'hidden', border: `1px solid ${activeAnatomy[selectedPart].color}`, boxShadow: `0 10px 30px rgba(0,0,0,0.3)` }}>
                    <img src={activeAnatomy[selectedPart].image} alt="Medical Scan" style={{ width: '100%', height: '250px', objectFit: 'cover', display: 'block' }} />
                    <div style={{ position: 'absolute', bottom: '12px', right: '12px', display: 'flex', gap: '8px' }}>
                      <button style={{ background: 'rgba(0,0,0,0.7)', border: '1px solid rgba(255,255,255,0.2)', color: 'white', padding: '6px 12px', borderRadius: '8px', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', cursor: 'pointer' }}>
                        <Download size={14} /> DICOM
                      </button>
                    </div>
                  </div>
                </div>
              )}

              {/* Historical Records filtered by Year slider */}
              <div>
                <h4 style={{ fontSize: '12px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '1px', marginBottom: '12px', fontWeight: '700' }}>Clinical History (Up to {year})</h4>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {activeAnatomy[selectedPart].records.filter(r => parseInt(r.date.split('-')[0]) <= year).length > 0 ? (
                    activeAnatomy[selectedPart].records.filter(r => parseInt(r.date.split('-')[0]) <= year).map((rec, i) => (
                      <div key={i} style={{ background: 'var(--bg-tertiary)', border: '1px solid var(--border)', padding: '16px', borderRadius: '12px', display: 'flex', gap: '16px', alignItems: 'flex-start' }}>
                        <div style={{ background: 'var(--bg-secondary)', padding: '8px', borderRadius: '8px', border: '1px solid var(--border)' }}>
                          <FileText size={20} color={activeAnatomy[selectedPart].color} />
                        </div>
                        <div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '4px' }}>
                            <span style={{ fontSize: '15px', fontWeight: '700', color: 'var(--text-primary)' }}>{rec.type}</span>
                            <span style={{ fontSize: '12px', color: 'var(--text-secondary)' }}>{rec.date}</span>
                          </div>
                          <div style={{ fontSize: '14px', color: 'var(--text-secondary)', lineHeight: '1.5' }}>
                            {rec.notes}
                          </div>
                        </div>
                      </div>
                    ))
                  ) : (
                    <div style={{ color: 'var(--text-secondary)', fontStyle: 'italic', padding: '20px', textAlign: 'center', background: 'rgba(0,0,0,0.2)', borderRadius: '12px' }}>
                      No records found prior to {year}. Slide forward in time.
                    </div>
                  )}
                </div>
              </div>
              
            </motion.div>
          )}
        </AnimatePresence>
          </>
        )}
        
      </div>
    </div>
  );
}
