import React, { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import { Calendar, Clock, MapPin, Video, Users, CheckCircle2, AlertCircle, Loader2, Activity, ChevronLeft, ChevronRight, Plus, X, Mic } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

export default function SmartCalendarWithErrorBoundary() {
  return (
    <ErrorBoundary>
      <SmartCalendar />
    </ErrorBoundary>
  );
}

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }
  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }
  render() {
    if (this.state.hasError) {
      return <div style={{ color: 'red', padding: '50px' }}>
        <h2>Something went wrong.</h2>
        <pre>{this.state.error?.toString()}</pre>
        <pre>{this.state.error?.stack}</pre>
      </div>;
    }
    return this.props.children;
  }
}

function SmartCalendar() {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [currentDate, setCurrentDate] = useState(new Date());
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  
  // NEW: State for the selected event to view details
  const [selectedEvent, setSelectedEvent] = useState(null);

  // Form State
  const [newEvent, setNewEvent] = useState({
    summary: '',
    description: '',
    date: new Date().toISOString().split('T')[0],
    startTime: '09:00',
    endTime: '10:00',
    location: ''
  });

  useEffect(() => {
    fetchCalendarEvents();
  }, [currentDate]);

  const fetchCalendarEvents = async () => {
    try {
      setLoading(true);
      setError(null);
      const token = localStorage.getItem('google_calendar_token');
      
      if (!token) {
        throw new Error('No token found');
      }

      // Calculate start and end of the visible calendar grid
      const year = currentDate.getFullYear();
      const month = currentDate.getMonth();
      const firstDayOfMonth = new Date(year, month, 1);
      const lastDayOfMonth = new Date(year, month + 1, 0);
      
      const startDate = new Date(firstDayOfMonth);
      startDate.setDate(startDate.getDate() - startDate.getDay()); // Go back to Sunday
      
      const endDate = new Date(lastDayOfMonth);
      endDate.setDate(endDate.getDate() + (6 - endDate.getDay())); // Go forward to Saturday

      const response = await axios.get('https://www.googleapis.com/calendar/v3/calendars/primary/events', {
        headers: { Authorization: `Bearer ${token}` },
        params: {
          timeMin: startDate.toISOString(),
          timeMax: endDate.toISOString(),
          singleEvents: true,
          orderBy: 'startTime',
          maxResults: 200
        }
      });

      setEvents(response.data.items || []);
    } catch (err) {
      console.warn('Real calendar failed, falling back to mock schedule.', err);
      // Fallback mock events for the current month
      const y = currentDate.getFullYear();
      const m = currentDate.getMonth();
      const mockEvents = [
        {
          id: 'mock1',
          summary: 'Patient Triage Review',
          start: { dateTime: new Date(y, m, 15, 9, 0).toISOString() },
          end: { dateTime: new Date(y, m, 15, 10, 0).toISOString() },
          location: 'Room 304 - ER Wing',
          description: 'Reviewing recent influx of respiratory cases.'
        },
        {
          id: 'mock2',
          summary: 'Telehealth Consult',
          start: { dateTime: new Date(y, m, 18, 14, 0).toISOString() },
          end: { dateTime: new Date(y, m, 18, 15, 0).toISOString() },
          hangoutLink: 'https://meet.google.com/mock',
          description: 'Follow-up with patient recovering from appendectomy.'
        }
      ];
      setEvents(mockEvents);
    } finally {
      setLoading(false);
    }
  };

  const handleAddEvent = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      const token = localStorage.getItem('google_calendar_token');
      if (!token) throw new Error('No token found');

      // Create proper RFC3339 DateTime strings
      const startDateTime = new Date(`${newEvent.date}T${newEvent.startTime}:00`).toISOString();
      const endDateTime = new Date(`${newEvent.date}T${newEvent.endTime}:00`).toISOString();

      const eventPayload = {
        summary: newEvent.summary,
        description: newEvent.description,
        location: newEvent.location,
        start: { dateTime: startDateTime, timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone },
        end: { dateTime: endDateTime, timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone }
      };

      await axios.post('https://www.googleapis.com/calendar/v3/calendars/primary/events', eventPayload, {
        headers: { Authorization: `Bearer ${token}` }
      });

      // Close modal and refresh events
      setIsModalOpen(false);
      setNewEvent({ ...newEvent, summary: '', description: '', location: '' }); // reset some fields
      await fetchCalendarEvents();
    } catch (err) {
      console.error(err);
      if (err.response?.status === 403) {
         setError("Failed to create event. You may need to log out and log back in to grant 'Write' permissions to your calendar.");
      } else {
         setError(err.message || 'Failed to create event.');
      }
    } finally {
      setSaving(false);
    }
  };

  // Calendar Grid Generation
  const daysInMonth = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0).getDate();
  const firstDayIndex = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1).getDay();
  const prevMonthDays = new Date(currentDate.getFullYear(), currentDate.getMonth(), 0).getDate();

  // Voice Dictation State for Modal
  const [isDictating, setIsDictating] = useState(false);
  const recognitionRef = useRef(null);

  useEffect(() => {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (SpeechRecognition) {
      const recognition = new SpeechRecognition();
      recognition.continuous = true;
      recognition.interimResults = true;
      
      recognition.onresult = (event) => {
        let currentTranscript = '';
        for (let i = event.resultIndex; i < event.results.length; i++) {
          currentTranscript += event.results[i][0].transcript;
        }
        setNewEvent(prev => ({
           ...prev,
           description: prev.description + ' ' + currentTranscript.trim()
        }));
      };

      recognition.onerror = () => setIsDictating(false);
      recognition.onend = () => setIsDictating(false);
      recognitionRef.current = recognition;
    }
    return () => {
      if (recognitionRef.current) recognitionRef.current.stop();
    };
  }, []);

  const toggleDictation = () => {
    if (isDictating) {
      recognitionRef.current?.stop();
      setIsDictating(false);
    } else {
      if (!recognitionRef.current) {
         alert("Speech Recognition not supported in this browser.");
         return;
      }
      setNewEvent(prev => ({ ...prev, description: prev.description ? prev.description + ' ' : '' }));
      recognitionRef.current.start();
      setIsDictating(true);
    }
  };

  const getCalendarDays = () => {
    let days = [];
    
    // Previous month padding
    for (let i = firstDayIndex; i > 0; i--) {
      days.push({ day: prevMonthDays - i + 1, isCurrentMonth: false, date: new Date(currentDate.getFullYear(), currentDate.getMonth() - 1, prevMonthDays - i + 1) });
    }
    
    // Current month days
    for (let i = 1; i <= daysInMonth; i++) {
      days.push({ day: i, isCurrentMonth: true, isToday: new Date().toDateString() === new Date(currentDate.getFullYear(), currentDate.getMonth(), i).toDateString(), date: new Date(currentDate.getFullYear(), currentDate.getMonth(), i) });
    }
    
    // Next month padding (to complete 42 cells = 6 rows)
    const remaining = 42 - days.length;
    for (let i = 1; i <= remaining; i++) {
      days.push({ day: i, isCurrentMonth: false, date: new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, i) });
    }
    return days;
  };

  const getEventsForDay = (dateObj) => {
    return events.filter(e => {
      const eDateStr = e.start.dateTime || e.start.date;
      if (!eDateStr) return false;
      const eDate = new Date(eDateStr);
      return eDate.toDateString() === dateObj.toDateString();
    });
  };

  const nextMonth = () => setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 1));
  const prevMonth = () => setCurrentDate(new Date(currentDate.getFullYear(), currentDate.getMonth() - 1, 1));
  const today = () => setCurrentDate(new Date());

  const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

  return (
    <div className="calendar-main-view" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      
      {/* Header */}
      <div className="calendar-header-bar" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px', flexWrap: 'wrap', gap: '12px' }}>
        <div>
          <h2 style={{ fontSize: '24px', fontWeight: '800', margin: '0 0 8px 0', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <Calendar color="#3b82f6" />
            Smart Schedule Sync
          </h2>
          <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '14px' }}>
            Two-Way Synchronization with Google Workspace
          </p>
        </div>
        <div style={{ display: 'flex', gap: '12px' }}>
          <button 
            onClick={() => {
              setIsModalOpen(true);
              if (!isDictating && recognitionRef.current) {
                setNewEvent({ summary: '', description: '', location: '', date: new Date().toISOString().split('T')[0], startTime: '09:00', endTime: '10:00' });
                recognitionRef.current.start();
                setIsDictating(true);
              }
            }} 
            style={{ background: isDictating ? 'rgba(239, 68, 68, 0.15)' : 'rgba(16, 185, 129, 0.1)', border: isDictating ? '1px solid #ef4444' : '1px solid rgba(16, 185, 129, 0.3)', padding: '8px 16px', borderRadius: '20px', color: isDictating ? '#fca5a5' : '#34d399', fontWeight: '700', fontSize: '13px', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '6px', transition: 'all 0.3s' }}
          >
            <Mic size={16} className={isDictating ? 'animate-pulse' : ''} /> {isDictating ? 'Listening...' : 'Voice Schedule'}
          </button>
          <button onClick={() => setIsModalOpen(true)} style={{ background: '#3b82f6', border: 'none', padding: '8px 16px', borderRadius: '20px', color: 'white', fontWeight: '600', fontSize: '13px', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '6px', boxShadow: '0 4px 15px rgba(59, 130, 246, 0.4)' }}>
            <Plus size={16} /> New Event
          </button>
          <button onClick={fetchCalendarEvents} style={{ background: 'rgba(59, 130, 246, 0.1)', border: '1px solid rgba(59, 130, 246, 0.3)', padding: '8px 16px', borderRadius: '20px', color: '#60a5fa', fontWeight: '600', fontSize: '13px', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '6px' }}>
            {loading ? <Loader2 size={16} className="animate-spin" /> : <Activity size={16} />} Sync
          </button>
        </div>
      </div>

      {error && (
        <div style={{ background: 'rgba(239, 68, 68, 0.15)', border: '1px solid #ef4444', padding: '14px', borderRadius: '10px', color: '#fca5a5', fontSize: '13px', fontWeight: '600', marginBottom: '20px', display: 'flex', alignItems: 'center', gap: '10px' }}>
          <AlertCircle size={18} /> {error}
        </div>
      )}

      {/* Calendar Controls */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px', padding: '0 10px' }}>
        <h3 style={{ fontSize: '20px', fontWeight: '700', margin: 0 }}>{monthNames[currentDate.getMonth()]} {currentDate.getFullYear()}</h3>
        <div style={{ display: 'flex', gap: '8px' }}>
          <button onClick={today} style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', padding: '6px 14px', borderRadius: '8px', color: 'var(--text-primary)', cursor: 'pointer', fontSize: '13px', fontWeight: '600' }}>Today</button>
          <button onClick={prevMonth} style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', padding: '6px 10px', borderRadius: '8px', color: 'var(--text-primary)', cursor: 'pointer', display: 'flex', alignItems: 'center' }}><ChevronLeft size={18} /></button>
          <button onClick={nextMonth} style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)', padding: '6px 10px', borderRadius: '8px', color: 'var(--text-primary)', cursor: 'pointer', display: 'flex', alignItems: 'center' }}><ChevronRight size={18} /></button>
        </div>
      </div>

      {/* Calendar Grid */}
      <div className="glass-panel" style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', overflowY: 'auto' }}>
        <div className="desktop-only" style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', borderBottom: '1px solid rgba(255,255,255,0.1)', background: 'rgba(0,0,0,0.2)' }}>
          {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(day => (
            <div key={day} style={{ padding: '12px', textAlign: 'center', fontSize: '12px', fontWeight: '700', color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: '1px' }}>{day}</div>
          ))}
        </div>
        
        <div className="calendar-grid-mobile" style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gridTemplateRows: 'repeat(6, 1fr)', flex: 1 }}>
          {getCalendarDays().map((d, i) => (
            <div key={i} className={!d.isCurrentMonth || getEventsForDay(d.date).length === 0 ? "mobile-hide" : ""} style={{ 
              borderRight: '1px solid var(--border)', 
              borderBottom: '1px solid var(--border)', 
              padding: '12px', 
              background: d.isCurrentMonth ? 'transparent' : 'var(--bg-tertiary)',
              opacity: d.isCurrentMonth ? 1 : 0.6,
              display: 'flex', flexDirection: 'column', gap: '8px',
              overflow: 'hidden', minHeight: '100px'
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <div style={{ 
                  display: 'flex', justifyContent: 'center', alignItems: 'center',
                  width: '28px', height: '28px', borderRadius: '50%',
                  background: d.isToday ? 'var(--primary)' : 'transparent',
                  color: d.isToday ? 'white' : 'var(--text-primary)',
                  fontWeight: d.isToday ? 'bold' : '600',
                  fontSize: '14px'
                }}>
                  {d.day}
                </div>
                <div className="mobile-only" style={{ fontSize: '13px', fontWeight: '600', color: 'var(--text-secondary)' }}>
                  {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d.date.getDay()]}
                </div>
              </div>
              
              <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                {getEventsForDay(d.date).map(ev => {
                  const time = ev.start.dateTime ? new Date(ev.start.dateTime).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : 'All Day';
                  return (
                    <div 
                      key={ev.id} 
                      onClick={() => setSelectedEvent(ev)}
                      style={{ 
                        fontSize: '12px', 
                        background: 'rgba(59, 130, 246, 0.15)', 
                        borderLeft: '3px solid var(--primary)', 
                        padding: '6px 8px', 
                        borderRadius: '6px',
                        whiteSpace: 'nowrap',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        color: 'var(--text-primary)',
                        cursor: 'pointer',
                        transition: 'background 0.2s',
                        boxShadow: '0 1px 2px rgba(0,0,0,0.05)'
                      }}
                      onMouseOver={(e) => e.currentTarget.style.background = 'rgba(59, 130, 246, 0.25)'}
                      onMouseOut={(e) => e.currentTarget.style.background = 'rgba(59, 130, 246, 0.15)'}
                    >
                      <span style={{ fontWeight: 'bold' }}>{time}</span> {ev.summary}
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Add Event Modal */}
      <AnimatePresence>
        {isModalOpen && (
          <motion.div 
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(8px)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px' }}
          >
            <motion.div 
              initial={{ scale: 0.95, y: 20 }} animate={{ scale: 1, y: 0 }} exit={{ scale: 0.95, y: 20 }}
              style={{ background: '#0f172a', border: '1px solid rgba(59, 130, 246, 0.3)', borderRadius: '16px', width: '100%', maxWidth: '500px', boxShadow: '0 25px 50px rgba(0,0,0,0.5)', overflow: 'hidden' }}
            >
              <div style={{ padding: '20px', borderBottom: '1px solid rgba(255,255,255,0.1)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'rgba(255,255,255,0.02)' }}>
                <h3 style={{ margin: 0, fontSize: '18px', display: 'flex', alignItems: 'center', gap: '8px' }}><Calendar size={18} color="#3b82f6"/> Schedule New Event</h3>
                <button onClick={() => setIsModalOpen(false)} style={{ background: 'transparent', border: 'none', color: 'var(--text-secondary)', cursor: 'pointer' }}><X size={20} /></button>
              </div>
              
              <form onSubmit={handleAddEvent} style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '6px' }}>Event Title</label>
                  <input required type="text" value={newEvent.summary} onChange={e => setNewEvent({...newEvent, summary: e.target.value})} placeholder="e.g. Patient Consultation" style={{ width: '100%', padding: '10px 12px', background: 'rgba(0,0,0,0.3)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: 'white', fontSize: '14px' }} />
                </div>
                
                <div style={{ display: 'flex', gap: '16px' }}>
                  <div style={{ flex: 1 }}>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '6px' }}>Date</label>
                    <input required type="date" value={newEvent.date} onChange={e => setNewEvent({...newEvent, date: e.target.value})} style={{ width: '100%', padding: '10px 12px', background: 'rgba(0,0,0,0.3)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: 'white', fontSize: '14px' }} />
                  </div>
                  <div style={{ flex: 1, display: 'flex', gap: '8px' }}>
                    <div style={{ flex: 1 }}>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '6px' }}>Start</label>
                      <input required type="time" value={newEvent.startTime} onChange={e => setNewEvent({...newEvent, startTime: e.target.value})} style={{ width: '100%', padding: '10px', background: 'rgba(0,0,0,0.3)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: 'white', fontSize: '14px' }} />
                    </div>
                    <div style={{ flex: 1 }}>
                      <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '6px' }}>End</label>
                      <input required type="time" value={newEvent.endTime} onChange={e => setNewEvent({...newEvent, endTime: e.target.value})} style={{ width: '100%', padding: '10px', background: 'rgba(0,0,0,0.3)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: 'white', fontSize: '14px' }} />
                    </div>
                  </div>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '6px' }}>Location (Optional)</label>
                  <input type="text" value={newEvent.location} onChange={e => setNewEvent({...newEvent, location: e.target.value})} placeholder="Room 402 or Zoom Link" style={{ width: '100%', padding: '10px 12px', background: 'rgba(0,0,0,0.3)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: 'white', fontSize: '14px' }} />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '12px', fontWeight: '600', color: 'var(--text-secondary)', marginBottom: '6px' }}>Description (Optional)</label>
                  <textarea value={newEvent.description} onChange={e => setNewEvent({...newEvent, description: e.target.value})} placeholder="Notes for this event..." rows={3} style={{ width: '100%', padding: '10px 12px', background: 'rgba(0,0,0,0.3)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '8px', color: 'white', fontSize: '14px', resize: 'none' }} />
                </div>

                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '8px' }}>
                  <button type="button" onClick={() => setIsModalOpen(false)} style={{ background: 'transparent', border: '1px solid rgba(255,255,255,0.2)', padding: '10px 20px', borderRadius: '8px', color: 'white', cursor: 'pointer', fontWeight: '600' }}>Cancel</button>
                  <button type="submit" disabled={saving} style={{ background: '#3b82f6', border: 'none', padding: '10px 24px', borderRadius: '8px', color: 'white', cursor: saving ? 'not-allowed' : 'pointer', fontWeight: '600', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    {saving ? <Loader2 size={16} className="animate-spin" /> : <CheckCircle2 size={16} />} 
                    Save to Google Calendar
                  </button>
                </div>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* View Event Details Modal */}
      <AnimatePresence>
        {selectedEvent && (
          <motion.div 
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(8px)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px' }}
            onClick={() => setSelectedEvent(null)}
          >
            <motion.div 
              initial={{ scale: 0.95, y: 20 }} animate={{ scale: 1, y: 0 }} exit={{ scale: 0.95, y: 20 }}
              style={{ background: '#0f172a', border: '1px solid rgba(16, 185, 129, 0.3)', borderRadius: '16px', width: '100%', maxWidth: '450px', boxShadow: '0 25px 50px rgba(0,0,0,0.5)', overflow: 'hidden' }}
              onClick={e => e.stopPropagation()}
            >
              <div style={{ padding: '20px', borderBottom: '1px solid rgba(255,255,255,0.1)', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', background: 'rgba(16, 185, 129, 0.05)' }}>
                <div>
                  <h3 style={{ margin: '0 0 8px 0', fontSize: '20px', fontWeight: '700', color: 'white' }}>{selectedEvent.summary || '(No title)'}</h3>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#10b981', fontSize: '13px', fontWeight: '600' }}>
                    <Calendar size={14} />
                    {selectedEvent.start.dateTime 
                      ? new Date(selectedEvent.start.dateTime).toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' })
                      : new Date(selectedEvent.start.date).toLocaleDateString([], { weekday: 'long', month: 'long', day: 'numeric' })}
                  </div>
                </div>
                <button onClick={() => setSelectedEvent(null)} style={{ background: 'rgba(255,255,255,0.1)', border: 'none', borderRadius: '50%', width: '32px', height: '32px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-secondary)', cursor: 'pointer' }}><X size={16} /></button>
              </div>
              
              <div style={{ padding: '24px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: '12px' }}>
                  <Clock size={18} color="#94a3b8" style={{ marginTop: '2px' }} />
                  <div style={{ color: 'var(--text-primary)', fontSize: '14px' }}>
                    {selectedEvent.start.dateTime ? (
                      <>
                        <div>{new Date(selectedEvent.start.dateTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })} to {new Date(selectedEvent.end.dateTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div>
                      </>
                    ) : 'All Day Event'}
                  </div>
                </div>

                {selectedEvent.location && (
                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: '12px' }}>
                    <MapPin size={18} color="#94a3b8" style={{ marginTop: '2px' }} />
                    <div style={{ color: 'var(--text-primary)', fontSize: '14px' }}>{selectedEvent.location}</div>
                  </div>
                )}

                {selectedEvent.hangoutLink && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <Video size={18} color="#60a5fa" />
                    <a href={selectedEvent.hangoutLink} target="_blank" rel="noopener noreferrer" style={{ color: '#60a5fa', textDecoration: 'none', fontSize: '14px', fontWeight: '600' }}>
                      Join Google Meet Video Call
                    </a>
                  </div>
                )}

                {selectedEvent.description && (
                  <div style={{ marginTop: '8px', padding: '16px', background: 'rgba(255,255,255,0.03)', borderRadius: '8px', border: '1px solid rgba(255,255,255,0.05)' }}>
                    <div style={{ fontSize: '12px', fontWeight: '700', color: 'var(--text-secondary)', marginBottom: '8px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Description</div>
                    <div style={{ fontSize: '13px', color: '#cbd5e1', lineHeight: '1.6' }} dangerouslySetInnerHTML={{ __html: selectedEvent.description }} />
                  </div>
                )}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

    </div>
  );
}
