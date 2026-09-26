import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { DollarSign, Tag, TrendingUp, CheckCircle, Clock, AlertTriangle, FileText, Send, ChevronRight, Search, Save, CreditCard, BarChart2 } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

export default function BillingDashboard() {
  const [activeTab, setActiveTab] = useState('queue'); // queue, search, analytics, templates
  const [claims, setClaims] = useState([]);
  const [selectedClaim, setSelectedClaim] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const [loading, setLoading] = useState(true);

  // OHIP Search State
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState([]);

  // Analytics State
  const [analytics, setAnalytics] = useState(null);

  // Templates State
  const [templates, setTemplates] = useState([]);

  const fetchClaims = async () => {
    try {
      const { data } = await axios.get('/api/claims');
      setClaims(data.claims);
    } catch (e) {
      console.error("Failed to fetch claims:", e);
    } finally {
      setLoading(false);
    }
  };

  const fetchAnalytics = async () => {
    try {
      const { data } = await axios.get('/api/analytics/billing');
      setAnalytics(data);
    } catch (e) {
      console.error(e);
    }
  };

  const fetchTemplates = async () => {
    try {
      const { data } = await axios.get('/api/claims/templates');
      setTemplates(data.templates);
    } catch (e) {
      console.error(e);
    }
  };

  useEffect(() => {
    fetchClaims();
    fetchAnalytics();
    fetchTemplates();
    window.addEventListener('billing-updated', fetchClaims);
    return () => window.removeEventListener('billing-updated', fetchClaims);
  }, []);

  useEffect(() => {
    if (searchQuery.length > 1) {
      const delay = setTimeout(async () => {
        try {
          const { data } = await axios.get(`/api/ohip/search?q=${searchQuery}`);
          setSearchResults(data.results);
        } catch (e) {}
      }, 300);
      return () => clearTimeout(delay);
    } else {
      setSearchResults([]);
    }
  }, [searchQuery]);

  const handleSubmitClaim = async (id) => {
    setSubmitting(true);
    try {
      // Simulate real-time MCEDT submission
      const { data } = await axios.get(`/api/mcedt/submit/${id}`);
      setClaims(prev => prev.map(c => c.id === id ? data.claim : c));
      setSelectedClaim(data.claim);
      fetchAnalytics(); // update stats
    } catch (e) {
      console.error("Failed to submit claim", e);
    } finally {
      setSubmitting(false);
    }
  };

  const handleSaveTemplate = async () => {
    if (!selectedClaim) return;
    const name = prompt("Enter a name for this template (e.g. 'Standard Diabetes Check'):");
    if (!name) return;
    try {
      const { data } = await axios.post('/api/claims/templates', {
        name,
        ohip_diagnostic_codes: selectedClaim.ohip_diagnostic_codes,
        ohip_fee_codes: selectedClaim.ohip_fee_codes,
        revenue: selectedClaim.revenue
      });
      setTemplates(prev => [data, ...prev]);
      alert("Template saved successfully!");
    } catch (e) {
      alert("Failed to save template.");
    }
  };

  const pendingClaims = claims.filter(c => c.status === "Pending Review");
  const processedClaims = claims.filter(c => c.status !== "Pending Review");

  return (
    <div className="animate-fade-in" style={{ padding: '32px', maxWidth: '1400px', margin: '0 auto', height: '100%', display: 'flex', flexDirection: 'column', gap: '24px' }}>
      
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
        <div>
          <h1 style={{ fontSize: '28px', fontWeight: '800', color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '12px', margin: '0 0 8px 0' }}>
            <DollarSign size={32} color="#10b981" /> Ontario MCEDT Billing
          </h1>
          <p style={{ fontSize: '15px', color: 'var(--text-secondary)', margin: 0 }}>
            OHIP Claims management, real-time MCEDT submission, and health card scanning.
          </p>
        </div>
        
        {/* Top KPIs */}
        <div className="billing-kpi-row" style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
          <div className="glass-panel" style={{ padding: '16px 20px', display: 'flex', alignItems: 'center', gap: '16px', borderTop: '3px solid #f59e0b', background: 'rgba(245, 158, 11, 0.05)', flex: 1 }}>
            <div style={{ background: 'rgba(245, 158, 11, 0.2)', padding: '12px', borderRadius: '12px' }}>
              <Clock size={24} color="#f59e0b" />
            </div>
            <div>
              <div style={{ fontSize: '13px', color: 'var(--text-secondary)', fontWeight: '600', textTransform: 'uppercase', letterSpacing: '1px' }}>Pending Action</div>
              <div style={{ fontSize: '24px', fontWeight: '800', color: '#fcd34d' }}>{pendingClaims.length}</div>
            </div>
          </div>
          <div className="glass-panel" style={{ padding: '16px 20px', display: 'flex', alignItems: 'center', gap: '16px', borderTop: '3px solid #10b981', background: 'rgba(16, 185, 129, 0.05)', flex: 1 }}>
            <div style={{ background: 'rgba(16, 185, 129, 0.2)', padding: '12px', borderRadius: '12px' }}>
              <TrendingUp size={24} color="#10b981" />
            </div>
            <div>
              <div style={{ fontSize: '13px', color: 'var(--text-secondary)', fontWeight: '600', textTransform: 'uppercase', letterSpacing: '1px' }}>Paid Revenue</div>
              <div style={{ fontSize: '24px', fontWeight: '800', color: '#6ee7b7' }}>${analytics?.revenue_paid || 0}</div>
            </div>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="billing-tabs-bar" style={{ display: 'flex', gap: '8px', borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '12px', overflowX: 'auto', WebkitOverflowScrolling: 'touch' }}>
        <button onClick={() => setActiveTab('queue')} style={{ padding: '8px 16px', background: activeTab === 'queue' ? 'rgba(59, 130, 246, 0.2)' : 'transparent', color: activeTab === 'queue' ? '#60a5fa' : 'var(--text-secondary)', border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '8px', whiteSpace: 'nowrap' }}>
          <FileText size={16} /> Claims Queue
        </button>
        <button onClick={() => setActiveTab('search')} style={{ padding: '8px 16px', background: activeTab === 'search' ? 'rgba(59, 130, 246, 0.2)' : 'transparent', color: activeTab === 'search' ? '#60a5fa' : 'var(--text-secondary)', border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '8px', whiteSpace: 'nowrap' }}>
          <Search size={16} /> OHIP Code Lookup
        </button>
        <button onClick={() => setActiveTab('templates')} style={{ padding: '8px 16px', background: activeTab === 'templates' ? 'rgba(59, 130, 246, 0.2)' : 'transparent', color: activeTab === 'templates' ? '#60a5fa' : 'var(--text-secondary)', border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '8px', whiteSpace: 'nowrap' }}>
          <Save size={16} /> Claim Templates
        </button>
        <button onClick={() => setActiveTab('analytics')} style={{ padding: '8px 16px', background: activeTab === 'analytics' ? 'rgba(59, 130, 246, 0.2)' : 'transparent', color: activeTab === 'analytics' ? '#60a5fa' : 'var(--text-secondary)', border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '8px', whiteSpace: 'nowrap' }}>
          <BarChart2 size={16} /> Analytics & Reporting
        </button>
      </div>

      <div className="billing-split-view" style={{ flex: 1, minHeight: 0, display: 'flex', gap: '24px' }}>
        {activeTab === 'queue' && (
          <>
            {/* Left Column: The Queue */}
            <div className="glass-panel" style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', padding: 0 }}>
              <div style={{ padding: '20px 24px', background: 'rgba(0,0,0,0.3)', borderBottom: '1px solid rgba(255,255,255,0.1)' }}>
                <h3 style={{ margin: 0, fontSize: '16px', color: 'var(--text-primary)', fontWeight: '700', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  Pending Review ({pendingClaims.length})
                </h3>
              </div>
              
              <div style={{ flex: 1, overflowY: 'auto', padding: '16px', display: 'flex', flexDirection: 'column', gap: '12px' }}>
                {loading ? (
                  <div style={{ padding: '20px', textAlign: 'center', color: 'var(--text-secondary)' }}>Loading claims...</div>
                ) : pendingClaims.length === 0 ? (
                  <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-secondary)' }}>No pending claims.</div>
                ) : pendingClaims.map(claim => (
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
                        <div style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>Date: {claim.date}</div>
                      </div>
                      <div style={{ background: 'rgba(245, 158, 11, 0.2)', color: '#fcd34d', padding: '4px 10px', borderRadius: '12px', fontSize: '12px', fontWeight: '700' }}>
                        {claim.status}
                      </div>
                    </div>
                  </div>
                ))}

                <h3 style={{ margin: '16px 0 8px 0', fontSize: '14px', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '1px' }}>Processed Claims</h3>
                {processedClaims.map(claim => (
                  <div 
                    key={claim.id}
                    onClick={() => setSelectedClaim(claim)}
                    style={{ 
                      padding: '12px 16px', borderRadius: '12px', cursor: 'pointer', transition: 'all 0.2s',
                      background: selectedClaim?.id === claim.id ? 'rgba(59, 130, 246, 0.15)' : 'rgba(0,0,0,0.1)',
                      border: selectedClaim?.id === claim.id ? '1px solid #3b82f6' : '1px solid transparent',
                      display: 'flex', justifyContent: 'space-between', alignItems: 'center'
                    }}
                  >
                    <div>
                      <div style={{ color: 'var(--text-primary)', fontWeight: '600', fontSize: '14px' }}>{claim.patient}</div>
                    </div>
                    <div style={{ 
                      background: claim.status === 'Paid' ? 'rgba(16, 185, 129, 0.2)' : claim.status === 'Rejected' ? 'rgba(239, 68, 68, 0.2)' : 'rgba(245, 158, 11, 0.2)', 
                      color: claim.status === 'Paid' ? '#34d399' : claim.status === 'Rejected' ? '#f87171' : '#fcd34d', 
                      padding: '4px 10px', borderRadius: '12px', fontSize: '11px', fontWeight: '700' 
                    }}>
                      {claim.status}
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Right Column: Claim Details & Approval */}
            <div className="glass-panel" style={{ flex: 1.5, display: 'flex', flexDirection: 'column', overflow: 'hidden', padding: 0 }}>
              {selectedClaim ? (
                <>
                  <div style={{ padding: '24px', background: 'rgba(0,0,0,0.3)', borderBottom: '1px solid rgba(255,255,255,0.1)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div>
                        <h2 style={{ margin: '0 0 4px 0', fontSize: '20px', color: 'var(--text-primary)' }}>Claim: {selectedClaim.id}</h2>
                        <div style={{ color: 'var(--text-secondary)', fontSize: '14px', display: 'flex', gap: '16px' }}>
                          <span>Patient: {selectedClaim.patient}</span>
                          {selectedClaim.health_card_number && <span>Health Card: {selectedClaim.health_card_number} ({selectedClaim.version_code})</span>}
                        </div>
                      </div>
                      <div style={{ fontSize: '28px', fontWeight: '800', color: '#10b981' }}>
                        ${selectedClaim.revenue}
                      </div>
                    </div>
                  </div>

                  <div style={{ flex: 1, overflowY: 'auto', padding: '24px' }}>
                    
                    {selectedClaim.warnings && selectedClaim.warnings.length > 0 && (
                      <div style={{ background: 'rgba(239, 68, 68, 0.05)', border: '1px solid rgba(239, 68, 68, 0.2)', padding: '16px', borderRadius: '12px', marginBottom: '24px' }}>
                        <h4 style={{ margin: '0 0 12px 0', color: '#f87171', fontSize: '14px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <AlertTriangle size={16} /> MCEDT Validation Warnings
                        </h4>
                        <ul style={{ margin: 0, paddingLeft: '20px', fontSize: '14px', color: '#fca5a5', lineHeight: '1.6' }}>
                          {selectedClaim.warnings.map((warn, i) => <li key={i}>{warn}</li>)}
                        </ul>
                      </div>
                    )}

                    <div style={{ marginBottom: '24px' }}>
                      <h4 style={{ margin: '0 0 12px 0', color: '#f59e0b', fontSize: '14px', textTransform: 'uppercase', letterSpacing: '1px' }}>OHIP Diagnostic Codes</h4>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                        {(selectedClaim.ohip_diagnostic_codes || []).map((code, i) => (
                          <div key={i} style={{ background: 'rgba(0,0,0,0.2)', border: '1px solid rgba(255,255,255,0.05)', padding: '12px 16px', borderRadius: '8px', color: 'var(--text-primary)', fontSize: '14px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                            <div style={{ background: '#f59e0b', color: 'black', padding: '2px 6px', borderRadius: '4px', fontSize: '11px', fontWeight: '800' }}>DX</div>
                            {code}
                          </div>
                        ))}
                      </div>
                    </div>

                    <div>
                      <h4 style={{ margin: '0 0 12px 0', color: '#10b981', fontSize: '14px', textTransform: 'uppercase', letterSpacing: '1px' }}>OHIP Fee Codes</h4>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                        {(selectedClaim.ohip_fee_codes || []).map((code, i) => (
                          <div key={i} style={{ background: 'rgba(0,0,0,0.2)', border: '1px solid rgba(255,255,255,0.05)', padding: '12px 16px', borderRadius: '8px', color: 'var(--text-primary)', fontSize: '14px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                            <div style={{ background: '#10b981', color: 'black', padding: '2px 6px', borderRadius: '4px', fontSize: '11px', fontWeight: '800' }}>FEE</div>
                            {code}
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>

                  <div style={{ padding: '24px', background: 'rgba(0,0,0,0.4)', borderTop: '1px solid rgba(255,255,255,0.1)', display: 'flex', gap: '16px' }}>
                    {selectedClaim.status === "Pending Review" ? (
                      <button 
                        className="btn btn-primary"
                        disabled={submitting}
                        onClick={() => handleSubmitClaim(selectedClaim.id)}
                        style={{ flex: 1, padding: '16px', fontSize: '16px', fontWeight: '700', background: 'linear-gradient(135deg, #10b981, #059669)', border: 'none', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '10px', boxShadow: '0 10px 25px rgba(16, 185, 129, 0.4)' }}
                      >
                        {submitting ? 'Transmitting to MCEDT...' : 'Submit to MCEDT'} 
                        {!submitting && <Send size={18} />}
                      </button>
                    ) : (
                      <div style={{ flex: 1, padding: '16px', textAlign: 'center', color: 'var(--text-secondary)', fontWeight: '600' }}>
                        This claim has been processed ({selectedClaim.status}).
                      </div>
                    )}
                    <button 
                      onClick={handleSaveTemplate}
                      style={{ padding: '16px 24px', background: 'rgba(255,255,255,0.1)', color: 'white', border: 'none', borderRadius: '12px', fontWeight: '600', cursor: 'pointer' }}
                    >
                      <Save size={18} />
                    </button>
                  </div>
                </>
              ) : (
                <div style={{ height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '40px', textAlign: 'center', background: 'var(--bg-tertiary)', position: 'relative', overflow: 'hidden' }}>
                  <div style={{ position: 'absolute', top: '0', left: '0', width: '100%', height: '4px', background: 'linear-gradient(to right, #10b981, #059669)' }} />
                  <div style={{ width: '80px', height: '80px', background: 'rgba(16, 185, 129, 0.1)', borderRadius: '20px', display: 'flex', alignItems: 'center', justifyContent: 'center', border: '1px solid rgba(16, 185, 129, 0.2)', marginBottom: '24px' }}>
                    <DollarSign size={40} color="#10b981" />
                  </div>
                  <h3 style={{ fontSize: '22px', fontWeight: '700', color: 'var(--text-primary)', margin: '0 0 12px 0' }}>Smart Billing & MCEDT Integration</h3>
                  <p style={{ fontSize: '15px', color: 'var(--text-secondary)', maxWidth: '400px', lineHeight: '1.6', margin: '0 0 32px 0' }}>
                    Process claims instantly with real-time MCEDT validation. Our AI automatically flags missing diagnostic codes before submission to prevent rejections.
                  </p>
                  
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', maxWidth: '500px', width: '100%', textAlign: 'left', marginBottom: '32px' }}>
                    <div style={{ background: 'var(--bg-secondary)', padding: '16px', borderRadius: '12px', border: '1px solid var(--border)' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#10b981', fontWeight: '600', marginBottom: '8px' }}>
                        <Send size={16} /> Real-Time MCEDT
                      </div>
                      <div style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Instant claim validation and submission.</div>
                    </div>
                    <div style={{ background: 'var(--bg-secondary)', padding: '16px', borderRadius: '12px', border: '1px solid var(--border)' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#f59e0b', fontWeight: '600', marginBottom: '8px' }}>
                        <AlertTriangle size={16} /> Error Prevention
                      </div>
                      <div style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Proactive rejection flagging.</div>
                    </div>
                    <div style={{ background: 'var(--bg-secondary)', padding: '16px', borderRadius: '12px', border: '1px solid var(--border)' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#3b82f6', fontWeight: '600', marginBottom: '8px' }}>
                        <Search size={16} /> Fast OHIP Lookup
                      </div>
                      <div style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Live schedule of benefits search.</div>
                    </div>
                    <div style={{ background: 'var(--bg-secondary)', padding: '16px', borderRadius: '12px', border: '1px solid var(--border)' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#a855f7', fontWeight: '600', marginBottom: '8px' }}>
                        <Save size={16} /> Claim Templates
                      </div>
                      <div style={{ fontSize: '13px', color: 'var(--text-secondary)' }}>Save frequent billing codes.</div>
                    </div>
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', background: 'rgba(16, 185, 129, 0.05)', padding: '16px 24px', borderRadius: '8px', border: '1px solid rgba(16, 185, 129, 0.2)' }}>
                    <ChevronRight size={20} color="#10b981" className="animate-pulse" />
                    <span style={{ fontSize: '14px', fontWeight: '600', color: 'var(--text-primary)' }}>Select a pending claim from the queue to review and submit.</span>
                  </div>
                </div>
              )}
            </div>
          </>
        )}

        {activeTab === 'search' && (
          <div className="glass-panel" style={{ flex: 1, padding: '32px' }}>
            <h2 style={{ margin: '0 0 24px 0', color: 'var(--text-primary)' }}>OHIP Schedule of Benefits Search</h2>
            <div style={{ position: 'relative', marginBottom: '24px' }}>
              <Search size={20} color="var(--text-secondary)" style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)' }} />
              <input 
                type="text" 
                placeholder="Search by code (e.g., A007) or description (e.g., assessment)..." 
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                style={{ width: '100%', padding: '16px 16px 16px 48px', background: 'rgba(0,0,0,0.2)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '12px', color: 'white', fontSize: '16px' }}
              />
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              {searchResults.length === 0 && searchQuery.length > 1 && (
                <div style={{ color: 'var(--text-secondary)', padding: '20px' }}>No results found for "{searchQuery}"</div>
              )}
              {searchResults.map((res, i) => (
                <div key={i} style={{ background: 'rgba(0,0,0,0.2)', padding: '16px', borderRadius: '12px', border: '1px solid rgba(255,255,255,0.05)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <div style={{ fontWeight: '700', fontSize: '16px', color: '#60a5fa' }}>{res.code}</div>
                    <div style={{ color: 'var(--text-secondary)', marginTop: '4px' }}>{res.description}</div>
                  </div>
                  <div style={{ fontSize: '18px', fontWeight: '800', color: '#10b981' }}>
                    ${res.fee.toFixed(2)}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === 'templates' && (
          <div className="glass-panel" style={{ flex: 1, padding: '32px' }}>
            <h2 style={{ margin: '0 0 24px 0', color: 'var(--text-primary)' }}>Reusable Claim Templates</h2>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '20px' }}>
              {templates.length === 0 ? (
                <div style={{ color: 'var(--text-secondary)' }}>No templates saved yet. Save a template from the queue screen.</div>
              ) : templates.map(t => (
                <div key={t.id} style={{ background: 'rgba(0,0,0,0.2)', border: '1px solid rgba(255,255,255,0.05)', padding: '20px', borderRadius: '12px' }}>
                  <div style={{ fontWeight: '700', fontSize: '18px', color: 'var(--text-primary)', marginBottom: '16px' }}>{t.name}</div>
                  <div style={{ color: 'var(--text-secondary)', fontSize: '13px', marginBottom: '8px' }}>Diagnostic: {(t.ohip_diagnostic_codes || []).join(', ')}</div>
                  <div style={{ color: 'var(--text-secondary)', fontSize: '13px', marginBottom: '16px' }}>Fees: {(t.ohip_fee_codes || []).join(', ')}</div>
                  <div style={{ color: '#10b981', fontWeight: '700' }}>${t.revenue}</div>
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === 'analytics' && analytics && (
          <div className="glass-panel" style={{ flex: 1, padding: '32px' }}>
            <h2 style={{ margin: '0 0 24px 0', color: 'var(--text-primary)' }}>MCEDT Billing Analytics</h2>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '24px', marginBottom: '32px' }}>
              <div style={{ background: 'rgba(16, 185, 129, 0.1)', padding: '24px', borderRadius: '12px', border: '1px solid rgba(16, 185, 129, 0.2)' }}>
                <div style={{ color: '#34d399', fontSize: '14px', fontWeight: '600', textTransform: 'uppercase' }}>Total Paid Revenue</div>
                <div style={{ fontSize: '32px', fontWeight: '800', color: '#10b981', marginTop: '8px' }}>${analytics.revenue_paid}</div>
              </div>
              <div style={{ background: 'rgba(245, 158, 11, 0.1)', padding: '24px', borderRadius: '12px', border: '1px solid rgba(245, 158, 11, 0.2)' }}>
                <div style={{ color: '#fcd34d', fontSize: '14px', fontWeight: '600', textTransform: 'uppercase' }}>Pending Revenue</div>
                <div style={{ fontSize: '32px', fontWeight: '800', color: '#f59e0b', marginTop: '8px' }}>${analytics.revenue_pending}</div>
              </div>
              <div style={{ background: 'rgba(239, 68, 68, 0.1)', padding: '24px', borderRadius: '12px', border: '1px solid rgba(239, 68, 68, 0.2)' }}>
                <div style={{ color: '#fca5a5', fontSize: '14px', fontWeight: '600', textTransform: 'uppercase' }}>Rejection Rate</div>
                <div style={{ fontSize: '32px', fontWeight: '800', color: '#ef4444', marginTop: '8px' }}>{analytics.rejection_rate}%</div>
              </div>
            </div>
            <div style={{ color: 'var(--text-secondary)' }}>
              <p>Total Claims Processed: <strong>{analytics.total_claims}</strong></p>
              <p>Advanced charting for Ontario MOH RA (Remittance Advice) reports would appear here.</p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
