import React, { useState, useRef } from 'react';
import { Camera, Upload, CheckCircle, XCircle, Loader, CreditCard } from 'lucide-react';
import axios from 'axios';
import { motion, AnimatePresence } from 'framer-motion';

export default function HealthCardScanner({ onScanComplete }) {
  const [isScanning, setIsScanning] = useState(false);
  const [scanResult, setScanResult] = useState(null);
  const [error, setError] = useState(null);
  const fileInputRef = useRef(null);

  const handleFileUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    setIsScanning(true);
    setError(null);
    setScanResult(null);

    // In a real app, we'd use FormData. Here we just trigger the mock.
    try {
      const response = await axios.post('/api/ocr/health-card');
      setScanResult(response.data);
      if (onScanComplete) {
        onScanComplete(response.data);
      }
    } catch (err) {
      setError("Failed to scan card. Please try again.");
    } finally {
      setIsScanning(false);
    }
  };

  return (
    <div style={{ background: 'var(--surface)', padding: '20px', borderRadius: '12px', border: '1px solid var(--border)', marginBottom: '24px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' }}>
        <div style={{ background: 'rgba(59, 130, 246, 0.1)', padding: '8px', borderRadius: '8px', color: '#3b82f6' }}>
          <CreditCard size={20} />
        </div>
        <h3 style={{ margin: 0, color: 'var(--text-primary)' }}>Ontario Health Card Scanner</h3>
      </div>
      
      <div style={{ display: 'flex', gap: '16px', alignItems: 'flex-start' }}>
        <div style={{ flex: 1 }}>
          <div 
            onClick={() => fileInputRef.current.click()}
            style={{ 
              border: '2px dashed var(--border)', 
              borderRadius: '8px', 
              padding: '30px', 
              textAlign: 'center',
              cursor: 'pointer',
              background: 'rgba(0,0,0,0.02)',
              transition: 'all 0.2s'
            }}
          >
            {isScanning ? (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px', color: '#3b82f6' }}>
                <Loader className="animate-spin" size={32} />
                <span style={{ fontWeight: '500' }}>Extracting OHIP Data...</span>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px', color: 'var(--text-secondary)' }}>
                <Camera size={32} />
                <div>
                  <div style={{ fontWeight: '600', color: 'var(--text-primary)' }}>Click to Upload Health Card</div>
                  <div style={{ fontSize: '13px', marginTop: '4px' }}>Supports JPG, PNG, PDF</div>
                </div>
              </div>
            )}
            <input 
              type="file" 
              ref={fileInputRef} 
              style={{ display: 'none' }} 
              accept="image/*"
              onChange={handleFileUpload}
            />
          </div>
        </div>

        <AnimatePresence>
          {scanResult && (
            <motion.div 
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              style={{ flex: 1, background: 'rgba(16, 185, 129, 0.05)', border: '1px solid rgba(16, 185, 129, 0.2)', padding: '16px', borderRadius: '8px' }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#10b981', marginBottom: '12px', fontWeight: '600' }}>
                <CheckCircle size={18} /> OCR Extraction Successful
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', fontSize: '13px' }}>
                <div>
                  <div style={{ color: 'var(--text-secondary)', textTransform: 'uppercase', fontSize: '11px', marginBottom: '2px' }}>Patient Name</div>
                  <div style={{ fontWeight: '600', color: 'var(--text-primary)' }}>{scanResult.patient_name}</div>
                </div>
                <div>
                  <div style={{ color: 'var(--text-secondary)', textTransform: 'uppercase', fontSize: '11px', marginBottom: '2px' }}>DOB</div>
                  <div style={{ fontWeight: '600', color: 'var(--text-primary)' }}>{scanResult.dob}</div>
                </div>
                <div>
                  <div style={{ color: 'var(--text-secondary)', textTransform: 'uppercase', fontSize: '11px', marginBottom: '2px' }}>OHIP Number</div>
                  <div style={{ fontWeight: '700', color: '#3b82f6', letterSpacing: '1px' }}>{scanResult.health_card_number}</div>
                </div>
                <div>
                  <div style={{ color: 'var(--text-secondary)', textTransform: 'uppercase', fontSize: '11px', marginBottom: '2px' }}>Version Code</div>
                  <div style={{ fontWeight: '700', color: '#3b82f6' }}>{scanResult.version_code}</div>
                </div>
              </div>
            </motion.div>
          )}
          {error && (
            <motion.div 
              initial={{ opacity: 0 }} animate={{ opacity: 1 }}
              style={{ flex: 1, color: '#ef4444', display: 'flex', alignItems: 'center', gap: '8px', padding: '16px' }}
            >
              <XCircle size={18} /> {error}
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
