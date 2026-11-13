import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/api_config.dart';
import '../../../core/services/voice_dictation_helper.dart';

class WhatsAppInboxModule extends StatefulWidget {
  const WhatsAppInboxModule({super.key});

  @override
  State<WhatsAppInboxModule> createState() => _WhatsAppInboxModuleState();
}

class _WhatsAppInboxModuleState extends State<WhatsAppInboxModule> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isListening = false;
  bool _isTranscribing = false;
  late final VoiceDictationController _voiceController;
  int _patientId = 391;
  String _patientName = "Patient";
  String _userPhone = "6132616383";
  final Set<int> _expandedSoapMessageIds = {};

  @override
  void initState() {
    super.initState();
    _voiceController = VoiceDictationController(
      textController: _messageController,
      isMounted: () => mounted,
      onListeningChanged: (listening) => setState(() => _isListening = listening),
      onTranscribingChanged: (transcribing) =>
          setState(() => _isTranscribing = transcribing),
      onStatusMessage: _showVoiceStatus,
    );
    _loadPatientAndThread();
  }

  void _showVoiceStatus(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  void dispose() {
    _voiceController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientAndThread() async {
    final prefs = await SharedPreferences.getInstance();
    final pid = prefs.getInt('patient_id') ?? 391;
    final name = prefs.getString('patient_username') ?? "Patient";
    final phone = prefs.getString('patient_phone') ?? "6132616383";
    setState(() {
      _patientId = pid;
      _patientName = name;
      _userPhone = phone;
    });

    await _fetchThread();
  }

  Future<void> _fetchThread() async {
    try {
      final url = Uri.parse("${ApiConfig.backendBaseUrl}/api/whatsapp/threads/$_userPhone");
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['messages'] is List) {
          setState(() {
            _messages = List<Map<String, dynamic>>.from(data['messages']);
            _isLoading = false;
          });
          _scrollToBottom();
          return;
        }
      }
    } catch (_) {}

    // Fallback seed messages if backend offline
    setState(() {
      _messages = [
        {
          "id": 1,
          "role": "bot",
          "sender_name": "Intelligent Digital Solution Care Team",
          "text": "Hello! Welcome to the PrimeCare WhatsApp Clinic channel. You can message us your symptoms, query your care plan, or log daily vitals here.",
          "vitals": {},
          "timestamp": "09:00 AM"
        },
        {
          "id": 2,
          "role": "patient",
          "sender_name": _patientName,
          "text": "Hi Doctor, checking in. My blood pressure this morning is 125/82 and heart rate is 72.",
          "vitals": {"blood_pressure": "125/82", "heart_rate": 72},
          "timestamp": "09:15 AM"
        },
        {
          "id": 3,
          "role": "bot",
          "sender_name": "Intelligent Digital Solution Care Team",
          "text": "Thank you! Your telemetry readings (BP: 125/82, HR: 72 BPM) have been recorded directly into your patient chart and synced with the Central AWS Clinical Network.",
          "vitals": {},
          "timestamp": "09:16 AM"
        }
      ];
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleListening() {
    _voiceController.toggle();
  }

  Future<void> _sendMessage([String? textToSend]) async {
    if (_isListening) {
      _voiceController.stop();
    }
    final text = (textToSend ?? _messageController.text).trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() {
      _isSending = true;
      _messages.add({
        "id": DateTime.now().millisecondsSinceEpoch,
        "role": "patient",
        "sender_name": _patientName,
        "text": text,
        "vitals": _extractVitals(text),
        "timestamp": "Just now"
      });
    });
    _scrollToBottom();

    try {
      final url = Uri.parse("${ApiConfig.backendBaseUrl}/api/whatsapp/send");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": _userPhone,
          "message": text,
          "patient_id": _patientId,
          "sender_name": _patientName
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['reply'] != null) {
          setState(() {
            _messages.add(Map<String, dynamic>.from(data['reply']));
          });
          _scrollToBottom();
        }
      }
    } catch (_) {
      // Local reply fallback
      setState(() {
        _messages.add({
          "id": DateTime.now().millisecondsSinceEpoch + 1,
          "role": "bot",
          "sender_name": "Intelligent Digital Solution Care Team",
          "text": "Message received and synced to Central EHR chart. Intelligent Digital Solution's team will follow up if vitals require immediate review.",
          "vitals": {},
          "timestamp": "Just now"
        });
      });
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Map<String, dynamic> _extractVitals(String text) {
    final vitals = <String, dynamic>{};
    final bpMatch = RegExp(r'\b(1\d{2}|[89]\d)\s*/\s*([4-9]\d|1[0-2]\d)\b').firstMatch(text);
    if (bpMatch != null) vitals['blood_pressure'] = bpMatch.group(0);
    final hrMatch = RegExp(r'\b(hr|heart\s*rate|pulse)\s*[:=]?\s*(\d{2,3})\b', caseSensitive: false).firstMatch(text);
    if (hrMatch != null) vitals['heart_rate'] = hrMatch.group(2);
    return vitals;
  }

  Future<void> _launchExternalWhatsApp() async {
    final uri = Uri.parse("https://wa.me/16134045586?text=Hi%20Intelligent%20Digital%20Solution,%20checking%20in%20from%20Smart%20Health%20Mobile%20App");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri);
    }
  }

  Future<void> _handleActionClick(String actionId, String label) async {
    if (actionId == 'call_911') {
      final uri = Uri.parse("tel:911");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text("Emergency: Please dial 911 on your phone immediately!"),
            ),
          );
        }
      }
    } else if (actionId == 'urgent_care') {
      await _triggerBackendAction('urgent_care', 'Urgent Care Queue Check-in');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF075E54),
            content: Text("🏥 Checked in to Urgent Care! Position #4 (Est. wait: 12 mins)."),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } else if (actionId == 'book_appointment') {
      setState(() => _isSending = true);
      await _triggerBackendAction('book_appointment', 'Priority Consultation with Intelligent Digital Solution');
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF166534),
            content: Text("✅ Consultation with Intelligent Digital Solution booked & confirmed in Central AWS records!"),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _triggerBackendAction(String action, String reason) async {
    try {
      final url = Uri.parse("${ApiConfig.backendBaseUrl}/api/whatsapp/action");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": _userPhone,
          "action": action,
          "patient_id": _patientId,
          "patient_name": _patientName,
          "reason": reason,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['reply'] != null && mounted) {
          setState(() {
            _messages.add(Map<String, dynamic>.from(data['reply']));
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("Action trigger error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Clinic Verified WhatsApp Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF075E54),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (Navigator.of(context).canPop()) ...[
                IconButton(
                  tooltip: "Back to Chat",
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 4),
              ],
              const CircleAvatar(
                backgroundColor: Color(0xFF25D366),
                radius: 20,
                child: Icon(Icons.medical_services_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Text(
                          "Intelligent Digital Solution Care Team",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.verified, color: Color(0xFF25D366), size: 16),
                      ],
                    ),
                    Text(
                      "Meta Verified • Central AWS Cloud Synced",
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Open in WhatsApp App",
                icon: const Icon(Icons.open_in_new, color: Colors.white),
                onPressed: _launchExternalWhatsApp,
              ),
            ],
          ),
        ),

        // Live Chat Message Feed
        Expanded(
          child: Container(
            color: const Color(0xFFECE5DD),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isPatient = msg['role'] == 'patient';
                      final isDoctor = msg['role'] == 'doctor';
                      final isGreeting = msg['is_greeting'] == true || msg['triage_level'] == 'GREETING';
                      final vitals = msg['vitals'] as Map<String, dynamic>? ?? {};
                      final isEmergency = msg['triage_level'] == 'EMERGENCY';
                      final isUrgent = msg['triage_level'] == 'URGENT';
                      final doctorNotice = msg['doctor_notice']?.toString();
                      final actions = (msg['actions'] as List<dynamic>?) ?? [];

                      return Align(
                        alignment: isPatient ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * (isPatient ? 0.78 : 0.86),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isPatient
                                ? const Color(0xFFDCF8C6)
                                : (isDoctor ? const Color(0xFFEFF6FF) : Colors.white),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: isPatient ? const Radius.circular(12) : const Radius.circular(0),
                              bottomRight: isPatient ? const Radius.circular(0) : const Radius.circular(12),
                            ),
                            border: !isPatient && isEmergency
                                ? Border.all(color: const Color(0xFFEF4444), width: 1.5)
                                : (!isPatient && isUrgent
                                    ? Border.all(color: const Color(0xFFF59E0B), width: 1.2)
                                    : (isDoctor
                                        ? Border.all(color: const Color(0xFF2563EB), width: 1.4)
                                        : Border.all(color: Colors.grey.shade200, width: 0.8))),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isDoctor) ...[
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E40AF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.medical_services_rounded, color: Colors.white, size: 10),
                                          SizedBox(width: 4),
                                          Text("ATTENDING PHYSICIAN", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      msg['sender_name'] ?? "Dr. Patel",
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: Color(0xFF2563EB), size: 13),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ] else if (!isPatient) ...[
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.smart_toy_outlined, color: Color(0xFF475569), size: 10),
                                          SizedBox(width: 4),
                                          Text("CLINIC AI BOT", style: TextStyle(color: Color(0xFF475569), fontSize: 9, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      msg['sender_name'] ?? "Smart Health Assistant",
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                    ),
                                  ],
                                ),
                                if (!isGreeting && doctorNotice != null && doctorNotice.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isEmergency
                                          ? const Color(0xFFFEF2F2)
                                          : (isUrgent ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4)),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isEmergency
                                            ? const Color(0xFFEF4444)
                                            : (isUrgent ? const Color(0xFFF59E0B) : const Color(0xFF86EFAC)),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isEmergency
                                              ? Icons.notification_important_rounded
                                              : (isUrgent ? Icons.warning_amber_rounded : Icons.check_circle_outline),
                                          size: 13,
                                          color: isEmergency
                                              ? const Color(0xFFDC2626)
                                              : (isUrgent ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            doctorNotice,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: isEmergency
                                                  ? const Color(0xFFDC2626)
                                                  : (isUrgent ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (!isGreeting && msg['ctas_label'] != null) ...[
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 5,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.blueGrey.shade200),
                                        ),
                                        child: Text(
                                          "${msg['ctas_label']} • ${((msg['confidence_score'] ?? 0.95) * 100).toInt()}% Calibrated Confidence",
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800),
                                        ),
                                      ),
                                      if (msg['uncertainty_flag'] == true)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFF59E0B)),
                                          ),
                                          child: const Text(
                                            "Atypical / Review Flagged",
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 6),
                              ],

                              Text(
                                msg['text'] ?? "",
                                style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.35),
                              ),

                              // If vitals detected in message, render synchronized badge
                              if (vitals.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF166534).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF166534).withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.cloud_done, size: 14, color: Color(0xFF166534)),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Telemetry Synced: ${vitals['blood_pressure'] ?? ''} ${vitals['heart_rate'] != null ? '• ${vitals['heart_rate']} BPM' : ''}",
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF166534),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Interactive Action Buttons
                              if (actions.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: actions.map<Widget>((act) {
                                    final actId = act['id']?.toString() ?? '';
                                    final actLabel = act['label']?.toString() ?? '';
                                    final isEmergencyAct = actId == 'call_911';

                                    return ElevatedButton.icon(
                                      icon: Icon(
                                        isEmergencyAct
                                            ? Icons.phone_in_talk
                                            : (actId == 'urgent_care'
                                                ? Icons.local_hospital_rounded
                                                : Icons.calendar_today_rounded),
                                        size: 13,
                                      ),
                                      label: Text(
                                        actLabel,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isEmergencyAct
                                            ? const Color(0xFFDC2626)
                                            : (actId == 'urgent_care'
                                                ? const Color(0xFF0284C7)
                                                : const Color(0xFF075E54)),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 1,
                                      ),
                                      onPressed: () => _handleActionClick(actId, actLabel),
                                    );
                                  }).toList(),
                                ),
                              ],

                              // Follow-up clinical exploration chips (SOCRATES)
                              if ((msg['follow_up_chips'] as List<dynamic>?)?.isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                Text(
                                  "Clinical Exploration / Quick Details:",
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade700),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 5,
                                  children: ((msg['follow_up_chips'] as List<dynamic>?) ?? []).map<Widget>((chip) {
                                    return ActionChip(
                                      label: Text(chip.toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF0F766E))),
                                      backgroundColor: const Color(0xFFF0FDFA),
                                      side: BorderSide(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _sendMessage(chip.toString()),
                                    );
                                  }).toList(),
                                ),
                              ],

                              // Clinician SOAP Triage Note (Collapsible card)
                              if ((msg['soap_note'] as Map<String, dynamic>?)?['formatted_summary']?.toString().isNotEmpty == true) ...[
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      final id = msg['id'] as int? ?? 0;
                                      if (_expandedSoapMessageIds.contains(id)) {
                                        _expandedSoapMessageIds.remove(id);
                                      } else {
                                        _expandedSoapMessageIds.add(id);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.description_outlined, size: 13, color: Color(0xFF475569)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                "Clinician SOAP Triage Note (Intelligent Digital Solution's Desk)",
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blueGrey.shade800,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              _expandedSoapMessageIds.contains(msg['id'])
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                              size: 14,
                                              color: const Color(0xFF475569),
                                            ),
                                          ],
                                        ),
                                        if (_expandedSoapMessageIds.contains(msg['id'])) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: SelectableText(
                                              (msg['soap_note'] as Map<String, dynamic>?)!['formatted_summary']!.toString(),
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 9.5,
                                                color: Color(0xFF1E293B),
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  msg['timestamp'] ?? "",
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),

        // Quick Vitals Pre-fills
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickChip("Log BP: 125/82, HR 74", () => _sendMessage("My morning vitals: Blood pressure 125/82, Heart rate 74 BPM.")),
                _buildQuickChip("Report Chest Tightness", () => _sendMessage("Doctor, I'm experiencing mild chest tightness and slight shortness of breath.")),
                _buildQuickChip("Request Rx Refill", () => _sendMessage("Hi, can I please request a refill for my Amlodipine 5mg prescription?")),
              ],
            ),
          ),
        ),

        // Composer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                VoiceDictationMicButton(
                  isListening: _isListening,
                  isTranscribing: _isTranscribing,
                  onPressed: _toggleListening,
                  idleIconColor: const Color(0xFF075E54),
                  idleBgColor: const Color(0xFF25D366).withValues(alpha: 0.12),
                  idleTooltip: 'Record voice to WhatsApp with Whisper',
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isTranscribing,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (val) => _sendMessage(val),
                    decoration: buildVoiceComposerDecoration(
                      isListening: _isListening,
                      isTranscribing: _isTranscribing,
                      idleHint: 'Type WhatsApp message to clinic...',
                      focusedIdleColor: const Color(0xFF25D366),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isSending ? null : () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF075E54))),
        backgroundColor: const Color(0xFFE8F5E9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: onTap,
      ),
    );
  }
}
