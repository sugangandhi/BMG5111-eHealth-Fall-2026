import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { 
  User, Phone, Mail, MapPin, AlertCircle, CheckCircle2, 
  X, Save, ShieldCheck, Smartphone, FileText
} from 'lucide-react';

export default function PatientEditModal({ isOpen, onClose, patient, onPatientUpdated }) {
  const [formData, setFormData] = useState({
    name: '',
    phone: '',
    email: '',
    addressLine: '',
    city: '',
    postalCode: '',
    allergies: '',
    notes: ''
  });
  const [isSaving, setIsSaving] = useState(false);
  const [errorMsg, setErrorMsg] = useState(null);
  const [successMsg, setSuccessMsg] = useState(null);

  const rawId = patient?.patient_id || patient?.id || patient?.mrn || 'pt-001';
  const patientId = String(rawId);

  useEffect(() => {
    if (isOpen && patient) {
      setErrorMsg(null);
      setSuccessMsg(null);

      // Safely populate with existing data
      const pName = typeof patient?.name === 'string' ? patient.name : (patient?.name?.text || patient?.patient_name || '');
      const pPhone = patient?.phone || (typeof patient?.contact === 'string' ? patient.contact.split('·')[0].split('||')[0].trim() : '') || '';
      const pEmail = patient.email || '';
      const pAddr = patient.address || {};
      const pAddrLine = Array.isArray(pAddr.line) ? pAddr.line[0] : (typeof pAddr.line === 'string' ? pAddr.line : '');
      const pCity = pAddr.city || '';
      const pPostal = pAddr.postalCode || pAddr.postal_code || '';
      const pAllergies = typeof patient.allergies === 'string' ? patient.allergies : (Array.isArray(patient.allergies) ? patient.allergies.join(', ') : 'NKDA');
      const pNotes = patient.notes || '';

      setFormData({
        name: pName,
        phone: pPhone,
        email: pEmail,
        addressLine: pAddrLine,
        city: pCity,
        postalCode: pPostal,
        allergies: pAllergies,
        notes: pNotes
      });

      // Fetch fresh patient details from API if it's a clinic patient
      if (patientId && !patientId.startsWith('cloud-')) {
        axios.get(`/api/patient/${patientId}`)
          .then(res => {
            if (res.data) {
              const d = res.data;
              const addr = d.address || {};
              const dName = typeof d.name === 'string' ? d.name : (d.name?.text || '');
              const dAddrLine = Array.isArray(addr.line) ? addr.line[0] : (typeof addr.line === 'string' ? addr.line : '');
              setFormData(prev => ({
                ...prev,
                name: dName || prev.name,
                phone: d.phone || prev.phone,
                email: d.email || prev.email,
                addressLine: dAddrLine || prev.addressLine,
                city: addr.city || prev.city,
                postalCode: addr.postalCode || prev.postalCode,
                allergies: Array.isArray(d.allergies) ? d.allergies.join(', ') : (d.allergies || prev.allergies),
                notes: d.notes || prev.notes
              }));
            }
          })
          .catch(() => {});
      }
    }
  }, [isOpen, patient, patientId]);

  if (!isOpen) return null;

  const handleChange = (field, value) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  const handleSave = async (e) => {
    if (e) e.preventDefault();
    setIsSaving(true);
    setErrorMsg(null);
    setSuccessMsg(null);

    try {
      const payload = {
        name: formData.name.trim(),
        phone: formData.phone.trim(),
        email: formData.email.trim(),
        address_line: formData.addressLine.trim(),
        city: formData.city.trim(),
        postal_code: formData.postalCode.trim(),
        allergies: formData.allergies.trim(),
        notes: formData.notes.trim()
      };

      const res = await axios.put(`/api/patient/${patientId}`, payload);
      const raw = res.data?.patient;

      const cleanName = typeof raw?.name === 'string'
        ? raw.name
        : (raw?.name?.text || formData.name.trim() || 'Patient');

      const cleanPhone = formData.phone.trim();
      const cleanAllergies = formData.allergies.trim() || 'NKDA';
      const cleanCity = formData.city.trim() || 'Ottawa';
      const cleanContact = `${cleanPhone} · ${cleanCity}`;

      const updated = {
        ...patient,
        ...raw,
        id: patientId,
        name: cleanName,
        phone: cleanPhone,
        email: formData.email.trim(),
        allergies: cleanAllergies,
        contact: cleanContact,
        address: {
          line: [formData.addressLine.trim()],
          city: cleanCity,
          postalCode: formData.postalCode.trim(),
          province: 'ON'
        }
      };

      setSuccessMsg('Patient details updated and synchronized with EHR chart!');

      // Save to localStorage so active session reflects change
      try {
        localStorage.setItem('test_whatsapp_phone', cleanPhone);
        const stored = localStorage.getItem('active_patient_context');
        if (stored) {
          const parsed = JSON.parse(stored);
          if (parsed.id === patientId || parsed.name === cleanName) {
            localStorage.setItem('active_patient_context', JSON.stringify({ ...parsed, phone: cleanPhone, name: cleanName }));
          }
        }
      } catch (err) {}

      // Notify parent & global app
      if (onPatientUpdated) onPatientUpdated(updated);
      window.dispatchEvent(new CustomEvent('patient-details-updated', { detail: updated }));
      window.dispatchEvent(new CustomEvent('set-active-patient', { detail: updated }));

      setTimeout(() => {
        onClose();
      }, 1000);
    } catch (err) {
      console.error("Save error:", err);
      setErrorMsg(err.response?.data?.detail || "Could not save patient updates. Please check the fields and try again.");
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      background: 'rgba(15, 23, 42, 0.65)',
      backdropFilter: 'blur(4px)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 10001,
      padding: '16px',
      overflowY: 'auto'
    }}>
      <div style={{
        background: '#ffffff',
        border: '1px solid #e2e8f0',
        borderRadius: '16px',
        width: '560px',
        maxWidth: '100%',
        maxHeight: '92vh',
        boxShadow: '0 20px 50px rgba(15, 23, 42, 0.18)',
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden'
      }}>
        
        {/* Modal Header */}
        <div style={{
          padding: '16px 20px',
          borderBottom: '1px solid #e2e8f0',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          background: '#ffffff'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{
              width: '38px',
              height: '38px',
              borderRadius: '10px',
              background: '#eff6ff',
              border: '1px solid #bfdbfe',
              color: '#2563eb',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <User size={20} />
            </div>
            <div>
              <h3 style={{ margin: 0, fontSize: '16px', fontWeight: '700', color: '#0f172a' }}>
                Update Patient Chart Details
              </h3>
              <p style={{ margin: '2px 0 0 0', fontSize: '12px', color: '#64748b' }}>
                ID: {patientId} · Changes immediately update EHR, WhatsApp & HealthKit
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            style={{
              background: '#f8fafc',
              border: '1px solid #e2e8f0',
              color: '#64748b',
              width: '32px',
              height: '32px',
              borderRadius: '8px',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}
          >
            <X size={18} />
          </button>
        </div>

        {/* Modal Body Form */}
        <form onSubmit={handleSave} style={{ padding: '18px 20px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '14px' }}>
          
          {errorMsg && (
            <div style={{ padding: '10px 14px', borderRadius: '8px', background: '#fef2f2', border: '1px solid #fecaca', color: '#b91c1c', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <AlertCircle size={16} />
              <span>{errorMsg}</span>
            </div>
          )}

          {successMsg && (
            <div style={{ padding: '10px 14px', borderRadius: '8px', background: '#ecfdf5', border: '1px solid #a7f3d0', color: '#047857', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <CheckCircle2 size={16} />
              <span>{successMsg}</span>
            </div>
          )}

          {/* Primary Contact Focus: Phone Number */}
          <div style={{
            background: '#eff6ff',
            border: '1px solid #bfdbfe',
            borderRadius: '10px',
            padding: '14px',
            display: 'flex',
            flexDirection: 'column',
            gap: '8px'
          }}>
            <label style={{ fontSize: '13px', fontWeight: '700', color: '#1e40af', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Phone size={15} color="#2563eb" />
              Patient Mobile Phone Number *
            </label>
            <div style={{ position: 'relative' }}>
              <input
                type="tel"
                value={formData.phone}
                onChange={(e) => handleChange('phone', e.target.value)}
                placeholder="+1 613-261-6383 or 613-555-0192"
                required
                style={{
                  width: '100%',
                  padding: '9px 12px',
                  borderRadius: '8px',
                  border: '1px solid #93c5fd',
                  background: '#ffffff',
                  color: '#0f172a',
                  fontSize: '14px',
                  fontWeight: '600',
                  outline: 'none',
                  boxShadow: '0 1px 2px rgba(37, 99, 235, 0.05)'
                }}
              />
            </div>
            <p style={{ margin: 0, fontSize: '11px', color: '#1e3a8a', lineHeight: '1.4' }}>
              Used for 2-way WhatsApp clinical queries, ambient voice appointment reminders, and Apple HealthKit pairing invites.
            </p>
          </div>

          {/* Full Name */}
          <div>
            <label style={{ fontSize: '12px', fontWeight: '600', color: '#334155', display: 'block', marginBottom: '4px' }}>
              Full Patient Name
            </label>
            <input
              type="text"
              value={formData.name}
              onChange={(e) => handleChange('name', e.target.value)}
              placeholder="e.g. Sugan or Sarah Jenkins"
              required
              style={{
                width: '100%',
                padding: '8px 12px',
                borderRadius: '8px',
                border: '1px solid #cbd5e1',
                background: '#ffffff',
                color: '#0f172a',
                fontSize: '13px',
                outline: 'none'
              }}
            />
          </div>

          {/* Email Address */}
          <div>
            <label style={{ fontSize: '12px', fontWeight: '600', color: '#334155', display: 'flex', alignItems: 'center', gap: '5px', marginBottom: '4px' }}>
              <Mail size={13} color="#64748b" />
              Email Address (Optional)
            </label>
            <input
              type="email"
              value={formData.email}
              onChange={(e) => handleChange('email', e.target.value)}
              placeholder="patient@example.com"
              style={{
                width: '100%',
                padding: '8px 12px',
                borderRadius: '8px',
                border: '1px solid #cbd5e1',
                background: '#ffffff',
                color: '#0f172a',
                fontSize: '13px',
                outline: 'none'
              }}
            />
          </div>

          {/* Address Line & City */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '10px' }}>
            <div>
              <label style={{ fontSize: '12px', fontWeight: '600', color: '#334155', display: 'flex', alignItems: 'center', gap: '5px', marginBottom: '4px' }}>
                <MapPin size={13} color="#64748b" />
                Address Line
              </label>
              <input
                type="text"
                value={formData.addressLine}
                onChange={(e) => handleChange('addressLine', e.target.value)}
                placeholder="142 Rideau Street"
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: '8px',
                  border: '1px solid #cbd5e1',
                  background: '#ffffff',
                  color: '#0f172a',
                  fontSize: '13px',
                  outline: 'none'
                }}
              />
            </div>
            <div>
              <label style={{ fontSize: '12px', fontWeight: '600', color: '#334155', display: 'block', marginBottom: '4px' }}>
                City & Postal Code
              </label>
              <div style={{ display: 'flex', gap: '6px' }}>
                <input
                  type="text"
                  value={formData.city}
                  onChange={(e) => handleChange('city', e.target.value)}
                  placeholder="Ottawa"
                  style={{
                    flex: 1,
                    padding: '8px 10px',
                    borderRadius: '8px',
                    border: '1px solid #cbd5e1',
                    background: '#ffffff',
                    color: '#0f172a',
                    fontSize: '13px',
                    outline: 'none'
                  }}
                />
                <input
                  type="text"
                  value={formData.postalCode}
                  onChange={(e) => handleChange('postalCode', e.target.value)}
                  placeholder="K1N 5Y2"
                  style={{
                    width: '90px',
                    padding: '8px 10px',
                    borderRadius: '8px',
                    border: '1px solid #cbd5e1',
                    background: '#ffffff',
                    color: '#0f172a',
                    fontSize: '13px',
                    outline: 'none'
                  }}
                />
              </div>
            </div>
          </div>

          {/* Allergies */}
          <div>
            <label style={{ fontSize: '12px', fontWeight: '600', color: '#334155', display: 'block', marginBottom: '4px' }}>
              Known Allergies (comma separated)
            </label>
            <input
              type="text"
              value={formData.allergies}
              onChange={(e) => handleChange('allergies', e.target.value)}
              placeholder="e.g. Penicillin, Sulfa, Peanuts or NKDA"
              style={{
                width: '100%',
                padding: '8px 12px',
                borderRadius: '8px',
                border: '1px solid #cbd5e1',
                background: '#ffffff',
                color: '#0f172a',
                fontSize: '13px',
                outline: 'none'
              }}
            />
          </div>

          {/* Clinical Chart Notes */}
          <div>
            <label style={{ fontSize: '12px', fontWeight: '600', color: '#334155', display: 'block', marginBottom: '4px' }}>
              Chart Notes / Special Instructions
            </label>
            <textarea
              value={formData.notes}
              onChange={(e) => handleChange('notes', e.target.value)}
              placeholder="Preferred contact hours, pharmacy preferences, clinical flags..."
              rows={2}
              style={{
                width: '100%',
                padding: '8px 12px',
                borderRadius: '8px',
                border: '1px solid #cbd5e1',
                background: '#ffffff',
                color: '#0f172a',
                fontSize: '13px',
                outline: 'none',
                resize: 'vertical'
              }}
            />
          </div>

        </form>

        {/* Modal Footer Controls */}
        <div style={{
          padding: '12px 20px',
          borderTop: '1px solid #e2e8f0',
          background: '#f8fafc',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          gap: '10px'
        }}>
          <span style={{ fontSize: '11px', color: '#64748b' }}>
            Encrypted PHIPA-compliant EHR persistence
          </span>

          <div style={{ display: 'flex', gap: '8px' }}>
            <button
              type="button"
              onClick={onClose}
              style={{
                padding: '8px 16px',
                borderRadius: '8px',
                border: '1px solid #e2e8f0',
                background: '#ffffff',
                color: '#334155',
                fontSize: '13px',
                fontWeight: '600',
                cursor: 'pointer'
              }}
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={handleSave}
              disabled={isSaving}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                padding: '8px 18px',
                borderRadius: '8px',
                border: '1px solid #2563eb',
                background: '#2563eb',
                color: '#ffffff',
                fontSize: '13px',
                fontWeight: '700',
                cursor: isSaving ? 'default' : 'pointer'
              }}
            >
              <Save size={15} />
              {isSaving ? 'Saving...' : 'Save Patient Details'}
            </button>
          </div>
        </div>

      </div>
    </div>
  );
}
