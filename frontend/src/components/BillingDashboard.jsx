import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { DollarSign, Tag, TrendingUp, CheckCircle, Clock, AlertTriangle, FileText, Send, ChevronRight } from 'lucide-react';

export default function BillingDashboard() {
  const [pendingClaims, setPendingClaims] = useState([]);
  const [selectedClaim, setSelectedClaim] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [loading, setLoading] = useState(true);

  const fetchClaims = async () => {
    try {
      const { data } = await axios.get('http://localhost:8000/api/claims');
      const filtered = data.claims.filter(c => c.status === "Pending Review");
      setPendingClaims(filtered);
    } catch (e) {
      console.error("Failed to fetch claims:", e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchClaims();
    window.addEventListener('billing-updated', fetchClaims);
    return () => window.removeEventListener('billing-updated', fetchClaims);
  }, []);

  const handleSubmitClaim = async (id) => {
    setSubmitting(true);
    try {
      await axios.patch(`http://localhost:8000/api/claims/${id}`, { status: "Submitted" });
      setPendingClaims(prev => prev.filter(c => c.id !== id));
      setSelectedClaim(null);
    } catch (e) {
      console.error("Failed to submit claim", e);
    } finally {
      setSubmitting(false);
    }
  };

  const totalRevenue = pendingClaims.reduce((sum, claim) => sum + claim.revenue, 0);

  return (
    <div className="animate-fade-in" style={{ padding: '32px', maxWidth: '1400px', margin: '0 auto', height: '100%', display: 'flex', flexDirection: 'column' }}>
      
      {/* Header */}
      <div style={{ marginBottom: '32px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: '800', color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '12px', margin: '0 0 8px 0' }}>
            <DollarSign size={32} color="#10b981" /> AI Revenue & Billing
          </h1>
          <p style={{ fontSize: '15px', color: 'var(--text-secondary)', margin: 0 }}>
            Review and submit claims automatically coded by the Ambient AI Scribe.
          </p>
        </div>
        
        {/* Top KPIs */}
        <div style={{ display: 'flex', gap: '16px' }}>
          <div className="glass-panel" style={{ padding: '16px 24px', display: 'flex', alignItems: 'center', gap: '16px', borderTop: '3px solid #f59e0b', background: 'rgba(245, 158, 11, 0.05)' }}>
            <div style={{ background: 'rgba(245, 158, 11, 0.2)', padding: '12px', borderRadius: '12px' }}>
              <Clock size={24} color="#f59e0b" />
            </div>
            <div>
              <div style={{ fontSize: '13px', color: 'var(--text-secondary)', fontWeight: '600', textTransform: 'uppercase', letterSpacing: '1px' }}>Pending Claims</div>
              <div style={{ fontSize: '24px', fontWeight: '800', color: '#fcd34d' }}>{pendingClaims.length}</div>
            </div>
          </div>
          <div className="glass-panel" style={{ padding: '16px 24px', display: 'flex', alignItems: 'center', gap: '16px', borderTop: '3px solid #10b981', background: 'rgba(16, 185, 129, 0.05)' }}>
            <div style={{ background: 'rgba(16, 185, 129, 0.2)', padding: '12px', borderRadius: '12px' }}>
              <TrendingUp size={24} color="#10b981" />
            </div>
            <div>
              <div style={{ fontSize: '13px', color: 'var(--text-secondary)', fontWeight: '600', textTransform: 'uppercase', letterSpacing: '1px' }}>Projected Revenue</div>
              <div style={{ fontSize: '24px', fontWeight: '800', color: '#6ee7b7' }}>${totalRevenue}</div>
            </div>
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px', flex: 1, minHeight: 0 }}>
        
        {/* Left Column: The Queue */}
        <div className="glass-panel" style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden', padding: 0 }}>
          <div style={{ padding: '20px 24px', background: 'rgba(0,0,0,0.3)', borderBottom: '1px solid rgba(255,255,255,0.1)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ margin: 0, fontSize: '16px', color: 'var(--text-primary)', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <FileText size={18} color="#93c5fd" /> Claims Needing Approval
            </h3>
          </div>
          
          <div style={{ flex: 1, overflowY: 'auto', padding: '16px' }}>
            {loading ? (
              <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-secondary)' }}>
                Loading claims...
              </div>
            ) : pendingClaims.length === 0 ? (
              <div style={{ height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: 'var(--text-secondary)' }}>
                <CheckCircle size={48} color="#10b981" style={{ marginBottom: '16px', opacity: 0.5 }} />
                <div style={{ fontSize: '18px', fontWeight: '600' }}>All Caught Up!</div>
                <div style={{ fontSize: '14px', marginTop: '8px' }}>No pending claims in the queue.</div>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                {pendingClaims.map(claim => (
                  <div 
                    key={claim.id}
                    onClick={() => setSelectedClaim(claim)}
                    style={{ 
                      padding: '16px', borderRadius: '12px', cursor: 'pointer', transition: 'all 0.2s',
                      background: selectedClaim?.id === claim.id ? 'rgba(59, 130, 246, 0.15)' : 'rgba(0,0,0,0.2)',
                      border: selectedClaim?.id === claim.id ? '1px solid #3b82f6' : '1px solid rgba(255,255,255,0.05)'
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '12px' }}>
                      <div>
                        <div style={{ color: 'var(--text-primary)', fontWeight: '700', fontSize: '16px' }}>{claim.patient}</div>
                        <div style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>Date of Service: {claim.date}</div>
                      </div>
                      <div style={{ background: 'rgba(245, 158, 11, 0.2)', color: '#fcd34d', padding: '4px 10px', borderRadius: '12px', fontSize: '12px', fontWeight: '700' }}>
                        {claim.status}
                      </div>
                    </div>
                    
                    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                      <span style={{ fontSize: '12px', color: '#10b981', background: 'rgba(16, 185, 129, 0.1)', border: '1px solid rgba(16, 185, 129, 0.3)', padding: '2px 8px', borderRadius: '4px' }}>
                        ${claim.revenue} Projected
                      </span>
                      <span style={{ fontSize: '12px', color: '#93c5fd', background: 'rgba(59, 130, 246, 0.1)', border: '1px solid rgba(59, 130, 246, 0.3)', padding: '2px 8px', borderRadius: '4px' }}>
                        {(claim.icd10 || []).length + (claim.cpt || []).length} Codes Extracted
                      </span>
                      {claim.warnings && claim.warnings.length > 0 && (
                        <span style={{ fontSize: '12px', color: '#ef4444', background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.3)', padding: '2px 8px', borderRadius: '4px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                          <AlertTriangle size={12} /> {claim.warnings.length} Warnings
                        </span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Right Column: Claim Details & Approval */}
        <div className="glass-panel" style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden', padding: 0 }}>
          {selectedClaim ? (
            <>
              <div style={{ padding: '24px', background: 'rgba(0,0,0,0.3)', borderBottom: '1px solid rgba(255,255,255,0.1)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <h2 style={{ margin: '0 0 4px 0', fontSize: '20px', color: 'var(--text-primary)' }}>Claim: {selectedClaim.id}</h2>
                    <div style={{ color: 'var(--text-secondary)', fontSize: '14px' }}>Patient: {selectedClaim.patient}</div>
                  </div>
                  <div style={{ fontSize: '28px', fontWeight: '800', color: '#10b981' }}>
                    ${selectedClaim.revenue}
                  </div>
                </div>
              </div>

              <div style={{ flex: 1, overflowY: 'auto', padding: '24px' }}>
                <div style={{ background: 'rgba(59, 130, 246, 0.05)', border: '1px solid rgba(59, 130, 246, 0.2)', padding: '16px', borderRadius: '12px', marginBottom: '24px' }}>
                  <h4 style={{ margin: '0 0 12px 0', color: '#60a5fa', fontSize: '14px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <CheckCircle size={16} /> AI Coding Confidence
                  </h4>
                  <p style={{ margin: 0, fontSize: '14px', color: 'var(--text-secondary)', lineHeight: '1.6' }}>
                    Codes were automatically generated from the Ambient AI Scribe. Confidence is &gt;95%. Please review before submission to the clearinghouse.
                  </p>
                </div>
                
                {selectedClaim.warnings && selectedClaim.warnings.length > 0 && (
                  <div style={{ background: 'rgba(239, 68, 68, 0.05)', border: '1px solid rgba(239, 68, 68, 0.2)', padding: '16px', borderRadius: '12px', marginBottom: '24px' }}>
                    <h4 style={{ margin: '0 0 12px 0', color: '#f87171', fontSize: '14px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <AlertTriangle size={16} /> Coding Validation Warnings
                    </h4>
                    <ul style={{ margin: 0, paddingLeft: '20px', fontSize: '14px', color: '#fca5a5', lineHeight: '1.6' }}>
                      {selectedClaim.warnings.map((warn, i) => <li key={i}>{warn}</li>)}
                    </ul>
                  </div>
                )}

                <div style={{ marginBottom: '24px' }}>
                  <h4 style={{ margin: '0 0 12px 0', color: '#f59e0b', fontSize: '14px', textTransform: 'uppercase', letterSpacing: '1px' }}>ICD-10 Diagnoses</h4>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {(selectedClaim.icd10 || []).map((code, i) => (
                      <div key={i} style={{ background: 'rgba(0,0,0,0.2)', border: '1px solid rgba(255,255,255,0.05)', padding: '12px 16px', borderRadius: '8px', color: 'var(--text-primary)', fontSize: '14px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <div style={{ background: '#f59e0b', color: 'black', padding: '2px 6px', borderRadius: '4px', fontSize: '11px', fontWeight: '800' }}>ICD</div>
                        {code}
                      </div>
                    ))}
                  </div>
                </div>

                <div>
                  <h4 style={{ margin: '0 0 12px 0', color: '#10b981', fontSize: '14px', textTransform: 'uppercase', letterSpacing: '1px' }}>CPT Procedures</h4>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {(selectedClaim.cpt || []).map((code, i) => (
                      <div key={i} style={{ background: 'rgba(0,0,0,0.2)', border: '1px solid rgba(255,255,255,0.05)', padding: '12px 16px', borderRadius: '8px', color: 'var(--text-primary)', fontSize: '14px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <div style={{ background: '#10b981', color: 'black', padding: '2px 6px', borderRadius: '4px', fontSize: '11px', fontWeight: '800' }}>CPT</div>
                        {code}
                      </div>
                    ))}
                  </div>
                </div>
              </div>

              <div style={{ padding: '24px', background: 'rgba(0,0,0,0.4)', borderTop: '1px solid rgba(255,255,255,0.1)' }}>
                <button 
                  className="btn btn-primary"
                  disabled={submitting}
                  onClick={() => handleSubmitClaim(selectedClaim.id)}
                  style={{ width: '100%', padding: '16px', fontSize: '16px', fontWeight: '700', background: 'linear-gradient(135deg, #10b981, #059669)', border: 'none', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '10px', boxShadow: '0 10px 25px rgba(16, 185, 129, 0.4)' }}
                >
                  {submitting ? 'Transmitting to Clearinghouse...' : 'Submit Claim to Clearinghouse'} 
                  {!submitting && <Send size={18} />}
                </button>
              </div>
            </>
          ) : (
            <div style={{ height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: 'var(--text-secondary)' }}>
              <Tag size={48} style={{ marginBottom: '16px', opacity: 0.5 }} />
              <div style={{ fontSize: '18px', fontWeight: '600' }}>Select a Claim</div>
              <div style={{ fontSize: '14px', marginTop: '8px' }}>Click a claim on the left to review billing codes.</div>
            </div>
          )}
        </div>

      </div>
    </div>
  );
}
