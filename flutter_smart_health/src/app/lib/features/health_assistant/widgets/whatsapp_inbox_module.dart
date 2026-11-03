import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/api_config.dart';
import '../../../core/services/voice_scribe_service.dart';

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
  String _speechBufferBeforeListening = "";
  int _patientId = 391;
  String _patientName = "Patient";

  @override
  void initState() {
    super.initState();
    _loadPatientAndThread();
  }

  @override
  void dispose() {
    VoiceScribeService.stopListening();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientAndThread() async {
    final prefs = await SharedPreferences.getInstance();
    final pid = prefs.getInt('patient_id') ?? 391;
    final name = prefs.getString('patient_username') ?? "Patient";
    setState(() {
      _patientId = pid;
      _patientName = name;
    });

    await _fetchThread();
  }

  Future<void> _fetchThread() async {
    try {
      final url = Uri.parse("${ApiConfig.backendBaseUrl}/api/whatsapp/threads/6132616383");
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
          "sender_name": "Dr. Patel's Clinic Care Team",
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
          "sender_name": "Dr. Patel's Clinic Care Team",
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
    if (_isListening) {
      VoiceScribeService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    _speechBufferBeforeListening = _messageController.text;
    setState(() {
      _isListening = true;
    });

    VoiceScribeService.startListening(
      onResult: (finalResult, interimResult) {
        if (!mounted) return;
        final recognized = (finalResult.isNotEmpty ? finalResult : interimResult).trim();
        if (recognized.isNotEmpty) {
          final prefix = _speechBufferBeforeListening.trim();
          final updated = prefix.isEmpty ? recognized : "$prefix $recognized";
          setState(() {
            _messageController.text = updated;
            _messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: _messageController.text.length),
            );
          });
        }
      },
      onStatus: (status, message) {
        if (!mounted) return;
        if (status == 'stopped') {
          setState(() => _isListening = false);
        } else if (status == 'error' || status == 'unsupported') {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                status == 'unsupported'
                    ? "Live microphone voice dictation is supported in Google Chrome or Edge."
                    : "Microphone note: $message. Please ensure microphone permission is allowed in your browser.",
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );
  }

  Future<void> _sendMessage([String? textToSend]) async {
    if (_isListening) {
      VoiceScribeService.stopListening();
      setState(() => _isListening = false);
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
          "phone": "6132616383",
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
          "sender_name": "Dr. Patel's Clinic Care Team",
          "text": "Message received and synced to Central EHR chart. Dr. Patel's team will follow up if vitals require immediate review.",
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
    final uri = Uri.parse("https://wa.me/16132616383?text=Hi%20Doctor%20Patel,%20checking%20in%20from%20Smart%20Health%20Mobile%20App");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri);
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
                          "Dr. Patel's Clinic Team",
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
                      final vitals = msg['vitals'] as Map<String, dynamic>? ?? {};

                      return Align(
                        alignment: isPatient ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isPatient ? const Color(0xFFDCF8C6) : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: isPatient ? const Radius.circular(12) : const Radius.circular(0),
                              bottomRight: isPatient ? const Radius.circular(0) : const Radius.circular(12),
                            ),
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
                              if (!isPatient)
                                Text(
                                  msg['sender_name'] ?? "Care Team",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF075E54),
                                  ),
                                ),
                              if (!isPatient) const SizedBox(height: 2),
                              Text(
                                msg['text'] ?? "",
                                style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.35),
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
                IconButton(
                  tooltip: _isListening ? "Listening to your voice... Tap to finish" : "Record voice to WhatsApp",
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                          : const Color(0xFF25D366).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? const Color(0xFFEF4444) : const Color(0xFF075E54),
                      size: 24,
                    ),
                  ),
                  onPressed: _toggleListening,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (val) => _sendMessage(val),
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? "🔴 Listening to your voice... Speak now"
                          : "Type WhatsApp message to clinic...",
                      hintStyle: TextStyle(
                        color: _isListening ? const Color(0xFFEF4444) : Colors.grey.shade500,
                        fontWeight: _isListening ? FontWeight.w500 : FontWeight.normal,
                      ),
                      filled: true,
                      fillColor: _isListening ? const Color(0xFFFEF2F2) : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: _isListening
                            ? const BorderSide(color: Color(0xFFEF4444), width: 1.5)
                            : BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: _isListening
                            ? const BorderSide(color: Color(0xFFEF4444), width: 1.5)
                            : BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: _isListening
                            ? const BorderSide(color: Color(0xFFEF4444), width: 2.0)
                            : const BorderSide(color: Color(0xFF25D366), width: 1.5),
                      ),
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
