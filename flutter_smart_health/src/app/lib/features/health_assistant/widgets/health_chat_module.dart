import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/api_config.dart';
import '../../../core/services/voice_dictation_helper.dart';
import '../../../data/models/assistant_models.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/e_hospital_auth_service.dart';
import '../../../services/whatsapp_launcher_service.dart';

class HealthChatModule extends StatefulWidget {
  const HealthChatModule({super.key});

  @override
  State<HealthChatModule> createState() => _HealthChatModuleState();
}

class _HealthChatMessage {
  final String role; // 'user' | 'assistant' | 'doctor'
  final String text;
  final bool isVoice;
  final DateTime timestamp;

  _HealthChatMessage({
    required this.role,
    required this.text,
    this.isVoice = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'isVoice': isVoice,
        'timestamp': timestamp.toIso8601String(),
      };

  factory _HealthChatMessage.fromJson(Map<String, dynamic> json) => _HealthChatMessage(
        role: json['role'] as String? ?? 'user',
        text: json['text'] as String? ?? '',
        isVoice: json['isVoice'] == true,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'].toString())
            : null,
      );
}

class _HealthChatModuleState extends State<HealthChatModule> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_HealthChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  bool _isTranscribing = false;
  late final VoiceDictationController _voiceController;
  String _patientId = "1";
  bool _isWhatsAppVerified = false;
  String _userPhone = "";
  bool _isDoctor = false;
  String _doctorName = "Dr. Sugan";
  String _selectedPatientName = "Sugan";
  String _selectedPatientId = "6132616383";
  String _selectedPatientPhone = "6132616383";
  bool _doctorSendViaWhatsApp = true;
  Timer? _liveSyncTimer;
  bool _isLiveSyncing = false;

  static final List<Map<String, String>> _defaultPatients = [
    {
      "name": "Sugan",
      "patient_id": "6132616383",
      "phone": "6132616383",
      "info": "Pt #99211 • Essential HTN",
    },
    {
      "name": "Patient 391",
      "patient_id": "391",
      "phone": "6132616383",
      "info": "Pt #391 • Type 2 Diabetes",
    },
    {
      "name": "Patient 1",
      "patient_id": "1",
      "phone": "6132616383",
      "info": "Pt #1 • AFib Monitor",
    },
  ];

  late List<Map<String, String>> _doctorPatients = List.from(_defaultPatients);

  static const List<String> _suggestedPrompts = [
    "What are my recorded vitals?",
    "How is my heart rate today?",
    "Explain my blood pressure trend",
    "How did I sleep last night?",
  ];

  List<String> get _currentPrompts => _isDoctor
      ? [
          "Review $_selectedPatientName's blood pressure telemetry",
          "Draft clinical follow-up for $_selectedPatientName",
          "Check $_selectedPatientName against Hypertension Canada CPG",
          "Schedule follow-up appointment with $_selectedPatientName",
        ]
      : _suggestedPrompts;

  String _historyKeyFor(String phoneOrId) {
    final clean = phoneOrId.replaceAll(RegExp(r'\D'), '');
    final idPart = clean.isNotEmpty ? clean : phoneOrId.trim();
    if (_isDoctor) {
      return "doctor_chat_history_$idPart";
    } else {
      return "patient_chat_history_$idPart";
    }
  }

  String get _currentChatHistoryKey {
    if (_isDoctor) {
      return _historyKeyFor(_selectedPatientPhone.isNotEmpty ? _selectedPatientPhone : _selectedPatientId);
    } else {
      return _historyKeyFor(_userPhone.isNotEmpty ? _userPhone : _patientId);
    }
  }

  @override
  void initState() {
    super.initState();
    _voiceController = VoiceDictationController(
      textController: _controller,
      isMounted: () => mounted,
      onListeningChanged: (listening) => setState(() => _isListening = listening),
      onTranscribingChanged: (transcribing) =>
          setState(() => _isTranscribing = transcribing),
      onStatusMessage: _showVoiceStatus,
    );
    _loadPatientAndHistory();
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

  Future<void> _loadPatientAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final identity = prefs.getString("patient_identity") ?? "Patient";
    final email = prefs.getString("patient_email") ?? "";
    final isDoctor = identity.toLowerCase() == "doctor" ||
        email.toLowerCase().contains("doctor") ||
        email.toLowerCase().contains("sugan");

    final pid = prefs.getInt("patient_id") ?? prefs.getString("patient_id");
    final verified = prefs.getBool("is_whatsapp_verified") ?? false;
    final savedPhone = prefs.getString("patient_phone") ?? "";

    var doctorName = prefs.getString("patient_username") ?? "Dr. Sugan";
    if (doctorName.toLowerCase().contains("ava") ||
        doctorName.toLowerCase().contains("patient") ||
        doctorName.trim().isEmpty) {
      doctorName = "Dr. Sugan";
    }
    if (!doctorName.startsWith("Dr.") && !doctorName.startsWith("Dr ")) {
      doctorName = "Dr. $doctorName";
    }

    // Always load persisted contacts so they are NEVER lost on refresh
    final savedContactsJson = prefs.getString("doctor_persisted_contacts_v2");
    List<Map<String, String>> combinedContacts = List.from(_defaultPatients);
    if (savedContactsJson != null && savedContactsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(savedContactsJson);
        final List<Map<String, String>> loaded = [];
        for (final item in decoded) {
          if (item is Map) {
            loaded.add(item.map((k, v) => MapEntry(k.toString(), v.toString())));
          }
        }
        if (loaded.isNotEmpty) {
          final Set<String> seenPhones = {};
          final List<Map<String, String>> merged = [];
          for (final c in loaded) {
            final p = c["phone"] ?? "";
            if (p.isNotEmpty && seenPhones.add(p)) {
              merged.add(c);
            }
          }
          for (final def in _defaultPatients) {
            final p = def["phone"] ?? "";
            if (seenPhones.add(p)) {
              merged.add(def);
            }
          }
          combinedContacts = merged;
        }
      } catch (e) {
        debugPrint("[HealthChat] Error loading persisted contacts: $e");
      }
    }

    final lastSelectedId = prefs.getString("doctor_selected_patient_id");
    Map<String, String> selected = combinedContacts.first;
    if (lastSelectedId != null && lastSelectedId.isNotEmpty) {
      final match = combinedContacts.firstWhere(
        (c) => c["patient_id"] == lastSelectedId || c["phone"] == lastSelectedId,
        orElse: () => combinedContacts.first,
      );
      selected = match;
    }

    if (mounted) {
      setState(() {
        _isDoctor = isDoctor;
        _doctorName = doctorName;
        _doctorPatients = combinedContacts;
        _selectedPatientId = selected["patient_id"] ?? "6132616383";
        _selectedPatientName = selected["name"] ?? "Patient";
        _selectedPatientPhone = selected["phone"] ?? "6132616383";
        if (isDoctor) {
          _patientId = _selectedPatientPhone.isNotEmpty ? _selectedPatientPhone : _selectedPatientId;
        } else if (pid != null) {
          _patientId = pid.toString();
        }
        _isWhatsAppVerified = verified;
        _userPhone = savedPhone;
      });
    }

    // Prompt WhatsApp phone verification on first launch ONLY for patients, NOT doctors
    final bool isRunningInTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isDoctor && !verified && !isRunningInTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isWhatsAppVerified) {
          _showWhatsAppVerificationModal();
        }
      });
    }

    // Load messages from local cache for this specific patient
    await _loadMessagesForCurrentPatient();
    _prefillDoctorWelcomeMessageIfApplicable();

    // Start 2-way real-time WhatsApp sync timer for doctors
    if (isDoctor && !isRunningInTest) {
      _startLiveSyncTimer();
      _syncWhatsAppThreadSilently();
    }
  }

  Future<void> _loadMessagesForCurrentPatient() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _currentChatHistoryKey;
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(cached);
        final cachedList = decoded
            .map((m) => _HealthChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();
        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(cachedList);
          });
          _scrollToBottom();
          return;
        }
      } catch (e) {
        debugPrint("[HealthChat] Local history decode error: $e");
      }
    } else {
      if (mounted) {
        setState(() {
          _messages.clear();
        });
      }
    }
  }

  void _startLiveSyncTimer() {
    final bool isRunningInTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isRunningInTest) return;
    _liveSyncTimer?.cancel();
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _isDoctor && _doctorSendViaWhatsApp && !_isLoading) {
        _syncWhatsAppThreadSilently();
      }
    });
  }

  Future<void> _syncWhatsAppThreadSilently({bool showToast = false}) async {
    if (_isLiveSyncing) return;
    _isLiveSyncing = true;
    try {
      final cleanPhone = _selectedPatientPhone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.isEmpty) return;

      final url = Uri.parse("${ApiConfig.backendBaseUrl}/api/whatsapp/threads/$cleanPhone");
      final resp = await http.get(url).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map && data['messages'] is List) {
          final List<dynamic> serverMsgs = data['messages'];
          bool hasNew = false;

          for (final item in serverMsgs) {
            if (item is Map) {
              final rawRole = item['role']?.toString().toLowerCase() ?? 'patient';
              final text = item['text']?.toString() ?? '';
              final senderName = item['sender_name']?.toString() ?? '';
              if (text.isEmpty) continue;

              final String mappedRole = (rawRole == 'patient' || rawRole == 'user')
                  ? 'user'
                  : (rawRole == 'doctor' ? 'doctor' : 'assistant');

              // Deduplicate by comparing trimmed message body text
              final bool exists = _messages.any((m) {
                final cleanedExisting = m.text.replaceAll(RegExp(r'[\*\#\_]'), '').trim();
                final cleanedIncoming = text.replaceAll(RegExp(r'[\*\#\_]'), '').trim();
                return cleanedExisting.contains(cleanedIncoming) || cleanedIncoming.contains(cleanedExisting);
              });

              if (!exists) {
                hasNew = true;
                String formattedText;
                if (mappedRole == 'user') {
                  final name = senderName.isNotEmpty ? senderName : _selectedPatientName;
                  formattedText = "💬 **$name (via WhatsApp)**:\n\n$text";
                } else if (mappedRole == 'doctor') {
                  formattedText = "🩺 **$_doctorName (Outbound)**:\n\n$text";
                } else {
                  formattedText = "🤖 **Clinic Assistant**:\n\n$text";
                }

                _messages.add(_HealthChatMessage(
                  role: mappedRole,
                  text: formattedText,
                ));
              }
            }
          }

          if (hasNew && mounted) {
            setState(() {});
            await _persistMessagesLocally();
            _scrollToBottom();
          }

          if (showToast && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("✅ Synced latest WhatsApp messages for $_selectedPatientName"),
                backgroundColor: const Color(0xFF166534),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (_) {
      // Non-blocking silent background sync
    } finally {
      if (mounted) {
        setState(() {
          _isLiveSyncing = false;
        });
      } else {
        _isLiveSyncing = false;
      }
    }
  }

  Future<void> _persistMessagesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _messages.map((m) => m.toJson()).toList();
      await prefs.setString(_currentChatHistoryKey, jsonEncode(list));
    } catch (e) {
      debugPrint("[HealthChat] Error saving cache: $e");
    }
  }

  Future<void> _saveDoctorContactsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("doctor_persisted_contacts_v2", jsonEncode(_doctorPatients));
      await prefs.setString("doctor_selected_patient_id", _selectedPatientId);
    } catch (e) {
      debugPrint("[HealthChat] Error saving contacts: $e");
    }
  }

  Future<void> _deleteDoctorContact(String phone) async {
    setState(() {
      _doctorPatients.removeWhere((p) => p["phone"] == phone);
      if (_selectedPatientPhone == phone) {
        final fallback = _doctorPatients.first;
        _selectedPatientId = fallback["patient_id"] ?? "6132616383";
        _selectedPatientName = fallback["name"] ?? "Patient";
        _selectedPatientPhone = fallback["phone"] ?? "6132616383";
        _patientId = _selectedPatientPhone;
      }
    });
    await _saveDoctorContactsToPrefs();
  }

  Future<void> _pickContactFromDevice() async {
    try {
      final contact = await WhatsAppLauncherService.pickDeviceContact();
      if (contact != null) {
        final name = contact['name'] ?? 'Contact';
        final rawPhone = contact['rawPhone'] ?? contact['phone'] ?? '';
        final phone = contact['phone'] ?? '';
        if (phone.isEmpty) return;

        await _persistMessagesLocally();

        final newContact = {
          "name": name,
          "patient_id": phone,
          "phone": phone,
          "info": "Phone Contact • $rawPhone",
        };

        setState(() {
          _doctorPatients.removeWhere((p) => p["phone"] == phone);
          _doctorPatients.insert(0, newContact);
          _selectedPatientId = phone;
          _selectedPatientName = name;
          _selectedPatientPhone = phone;
          _patientId = phone;
        });

        await _saveDoctorContactsToPrefs();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ Added & Selected $name ($rawPhone)"),
              backgroundColor: const Color(0xFF166534),
            ),
          );
        }

        await _loadMessagesForCurrentPatient();
        _prefillDoctorWelcomeMessageIfApplicable();
        await _syncWhatsAppThreadSilently();
        return;
      }
    } catch (e) {
      debugPrint("[HealthChat] Pick contact error: $e");
    }

    if (mounted) {
      _showManageContactsModal();
    }
  }

  void _showManageContactsModal() {
    final searchController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final query = searchController.text.trim().toLowerCase();
            final filtered = _doctorPatients.where((p) {
              final name = (p["name"] ?? "").toLowerCase();
              final phone = (p["phone"] ?? "").toLowerCase();
              final info = (p["info"] ?? "").toLowerCase();
              return name.contains(query) || phone.contains(query) || info.contains(query);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.72,
              minChildSize: 0.45,
              maxChildSize: 0.94,
              expand: false,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.contacts_rounded, color: Color(0xFF075E54)),
                              SizedBox(width: 8),
                              Text(
                                "Contacts Book",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF075E54),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.contacts_outlined, size: 16),
                                label: const Text("Phone", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _pickContactFromDevice();
                                },
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF075E54),
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.add, size: 15),
                                label: const Text("Add", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showAddCustomContactDialog();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: searchController,
                        onChanged: (_) => setModalState(() {}),
                        decoration: InputDecoration(
                          hintText: "Search contacts by name or phone...",
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  "No contacts found. Tap '+ Add' to save one.",
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, idx) {
                                  final contact = filtered[idx];
                                  final isSelected = contact["patient_id"] == _selectedPatientId ||
                                      contact["phone"] == _selectedPatientPhone;
                                  final isDefault = _defaultPatients.any((d) => d["patient_id"] == contact["patient_id"]);

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    leading: CircleAvatar(
                                      backgroundColor: isSelected ? const Color(0xFF075E54) : const Color(0xFFE2E8F0),
                                      foregroundColor: isSelected ? Colors.white : const Color(0xFF1E293B),
                                      child: Text(
                                        (contact["name"] ?? "P").substring(0, 1).toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            contact["name"] ?? "Patient",
                                            style: TextStyle(
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              color: isSelected ? const Color(0xFF075E54) : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Text(
                                            "Active",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF166534),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      "${contact["phone"]} • ${contact["info"] ?? ''}",
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                    ),
                                    trailing: !isDefault
                                        ? IconButton(
                                            tooltip: "Delete Contact",
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                            onPressed: () async {
                                              await _deleteDoctorContact(contact["phone"] ?? "");
                                              setModalState(() {});
                                            },
                                          )
                                        : null,
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      if (contact["patient_id"] != null) {
                                        _onDoctorPatientChanged(contact["patient_id"]!);
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _clearChatHistory() async {
    setState(() {
      _messages.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentChatHistoryKey);
  }

  Future<void> _onDoctorPatientChanged(String newPatientId) async {
    // 1. Persist current messages for previous patient
    await _persistMessagesLocally();

    final match = _doctorPatients.firstWhere(
      (p) => p["patient_id"] == newPatientId || p["phone"] == newPatientId,
      orElse: () => _doctorPatients.first,
    );

    setState(() {
      _selectedPatientId = match["patient_id"] ?? newPatientId;
      _selectedPatientName = match["name"] ?? "Patient";
      _selectedPatientPhone = match["phone"] ?? "6132616383";
      _patientId = _selectedPatientPhone; // Keep ID as phone number itself
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("doctor_selected_patient_id", _selectedPatientId);

    // 2. Load conversation history for newly selected patient
    await _loadMessagesForCurrentPatient();
    _prefillDoctorWelcomeMessageIfApplicable();

    // 3. Immediately pull latest WhatsApp messages from backend
    await _syncWhatsAppThreadSilently();
  }

  @override
  void dispose() {
    _liveSyncTimer?.cancel();
    _voiceController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openInternalWhatsApp() {
    if (_isWhatsAppVerified) {
      _launchWhatsApp("Hello Doctor, I am chatting from the eHospital mobile app.");
    } else {
      _showWhatsAppVerificationModal();
    }
  }

  void _showWhatsAppVerificationModal() {
    final phoneController = TextEditingController(text: _userPhone);
    final otpController = TextEditingController();
    bool otpSent = false;
    bool isLoading = false;
    String? errorMessage;
    String? successMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final bottomInset = MediaQuery.of(modalContext).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, bottomInset + 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF25D366),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_person_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Connect WhatsApp Care Team",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Sync AI Telemetry & Doctor Messaging",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      otpSent
                          ? "Enter the 6-digit verification code sent to your WhatsApp (${phoneController.text.trim()}):"
                          : "Verify your mobile number to link your health telemetry directly with our clinic's WhatsApp Care Team:",
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                        ),
                      ),
                    if (successMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          successMessage!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (!otpSent) ...[
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: "WhatsApp Mobile Number",
                          hintText: "Enter your phone with country code (e.g. +1... or +91...)",
                          prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0xFF25D366)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF166534)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "First time? Message clinic 'Hi' on WhatsApp first to activate delivery:",
                                style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w500),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _launchWhatsApp("Hi"),
                              child: const Text("Say Hi 💬", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(isLoading ? "Sending Code..." : "Send Code via WhatsApp"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final phone = phoneController.text.trim();
                                final digits = phone.replaceAll(RegExp(r'\D'), '');
                                if (digits.length < 10) {
                                  setModalState(() {
                                    errorMessage = "Please enter a valid 10-digit mobile number.";
                                  });
                                  return;
                                }
                                setModalState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                  successMessage = null;
                                });
                                try {
                                  final res = await EHospitalAuthService.sendWhatsAppOtp(phone);
                                  if (res['success'] == true) {
                                    setModalState(() {
                                      otpSent = true;
                                      isLoading = false;
                                      successMessage = res['message']?.toString() ?? "Code sent to your WhatsApp!";
                                    });
                                  } else {
                                    setModalState(() {
                                      isLoading = false;
                                      errorMessage = res['error']?.toString() ?? "Could not send WhatsApp code.";
                                    });
                                  }
                                } on ApiException catch (e) {
                                  setModalState(() {
                                    isLoading = false;
                                    errorMessage = e.message;
                                  });
                                } catch (e) {
                                  setModalState(() {
                                    isLoading = false;
                                    errorMessage = "Connection error: $e";
                                  });
                                }
                              },
                      ),
                    ] else ...[
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                        decoration: InputDecoration(
                          labelText: "6-Digit Verification Code",
                          hintText: "••••••",
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF25D366)),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          counterText: "",
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.verified_user_rounded, size: 18),
                        label: Text(isLoading ? "Verifying..." : "Verify & Activate WhatsApp"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F5C9C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final code = otpController.text.trim();
                                if (code.length < 4) {
                                  setModalState(() {
                                    errorMessage = "Please enter the 6-digit code received on WhatsApp.";
                                  });
                                  return;
                                }
                                setModalState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                });
                                final phone = phoneController.text.trim();
                                try {
                                  final result = await EHospitalAuthService.loginWithWhatsAppOtp(
                                    phone,
                                    code,
                                    selectedOption: "Patient",
                                  );
                                  if (result.authenticated) {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setBool("is_whatsapp_verified", true);
                                    await prefs.setString("patient_phone", phone);
                                    if (mounted) {
                                      setState(() {
                                        _isWhatsAppVerified = true;
                                        _userPhone = phone;
                                      });
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("✅ WhatsApp Care Team connected! Telemetry and messages are now synced."),
                                          backgroundColor: Color(0xFF166534),
                                        ),
                                      );
                                    }
                                  } else {
                                    setModalState(() {
                                      isLoading = false;
                                      errorMessage = "Invalid verification code. Check your WhatsApp and try again.";
                                    });
                                  }
                                } on ApiException catch (e) {
                                  setModalState(() {
                                    isLoading = false;
                                    errorMessage = e.message;
                                  });
                                } catch (e) {
                                  setModalState(() {
                                    isLoading = false;
                                    errorMessage = "Verification error: $e";
                                  });
                                }
                              },
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            otpSent = false;
                            errorMessage = null;
                            successMessage = null;
                          });
                        },
                        child: const Text("Resend code or change number"),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        "Later / Continue as Guest",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _launchWhatsApp([String? customMessage]) async {
    final defaultMsg = customMessage ??
        "Hi Doctor, this is patient #$_patientId. I have a question about my recent mobile health vitals.";
    await WhatsAppLauncherService.launchWhatsApp(
      context: context,
      phone: "16134045586",
      message: defaultMsg,
    );
  }

  void _toggleListening() {
    _voiceController.toggle();
  }

  Future<void> _sendDoctorWhatsAppMessage(String text) async {
    _controller.clear();
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await BackendApiService.doctorDispatchPatientMessage(
        patientPhone: _selectedPatientPhone,
        message: text,
        patientName: _selectedPatientName,
        patientId: int.tryParse(_selectedPatientPhone) ?? (int.tryParse(_selectedPatientId) ?? 99211),
        doctorName: _doctorName,
      );

      final liveSent = res['delivered_live'] == true;
      if (mounted) {
        setState(() {
          _messages.add(_HealthChatMessage(
            role: 'doctor',
            text: "🩺 **$_doctorName's Message to $_selectedPatientName**:\n\n$text\n\n*(Dispatched to WhatsApp `+$_selectedPatientPhone` • ${liveSent ? 'Delivered Live via Meta' : 'Recorded in Chart'})*",
          ));
        });
        await _persistMessagesLocally();
        _syncWhatsAppThreadSilently();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text("✅ Dispatched message to $_selectedPatientName via WhatsApp"),
            backgroundColor: const Color(0xFF166534),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text("Dispatch error: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _prefillDoctorWelcomeMessageIfApplicable() {
    if (!_isDoctor) return;
    final current = _controller.text.trim();
    final defaultPattern = RegExp(
      r'^Hello .*, this is .* from e-Hospital PrimeCare Clinic following up on your care plan\.$',
    );
    final hasNoPatientMessage = !_messages.any((m) => m.role == 'user');

    if (current.isEmpty || defaultPattern.hasMatch(current)) {
      if (hasNoPatientMessage) {
        _controller.text =
            "Hello $_selectedPatientName, this is $_doctorName from e-Hospital PrimeCare Clinic following up on your care plan.";
      }
    }
  }

  Future<void> _launchWhatsAppToPatient() async {
    final cleanPhone = _selectedPatientPhone.replaceAll(RegExp(r'\D'), '');
    final msg = _controller.text.trim().isNotEmpty
        ? _controller.text.trim()
        : "Hello $_selectedPatientName, this is $_doctorName from e-Hospital PrimeCare Clinic.";
    await WhatsAppLauncherService.launchWhatsApp(
      context: context,
      phone: cleanPhone.isNotEmpty ? cleanPhone : "16134045586",
      message: msg,
    );
  }

  Future<void> _sendOfficialWelcomeTemplate() async {
    setState(() => _isLoading = true);
    try {
      final welcomeText = _controller.text.trim().isNotEmpty ? _controller.text.trim() : null;
      final res = await BackendApiService.initializeWhatsAppChannel(
        patientPhone: _selectedPatientPhone,
        patientName: _selectedPatientName,
        doctorName: _doctorName,
        welcomeMessage: welcomeText,
      );

      final liveSent = res['delivered_live'] == true;
      if (mounted) {
        setState(() {
          _messages.add(_HealthChatMessage(
            role: 'bot',
            text: "📢 **Official Meta Outreach Template Dispatched to +$_selectedPatientPhone**\n\n"
                "• **Recipient**: $_selectedPatientName\n"
                "• **Physician**: $_doctorName\n"
                "• **Channel Status**: ${liveSent ? '✅ Delivered Live to WhatsApp (24h Window Open)' : 'Queued for Delivery'}\n\n"
                "*(An official registered clinic notification was dispatched from `+1 (613) 404-5586` to open the direct messaging window)*",
          ));
          if (welcomeText != null && welcomeText.isNotEmpty) {
            _messages.add(_HealthChatMessage(
              role: 'doctor',
              text: "🩺 **$_doctorName's Welcome Note to $_selectedPatientName**:\n\n$welcomeText",
            ));
            _controller.clear();
          }
        });
        await _persistMessagesLocally();
        _syncWhatsAppThreadSilently();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              liveSent
                  ? "✅ Welcome template delivered live to $_selectedPatientName! 24h window active."
                  : "✅ Welcome template queued for $_selectedPatientName.",
            ),
            backgroundColor: const Color(0xFF166534),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text("Template dispatch error: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  Widget _buildDoctorOutreachBanner() {
    final hasPatientReply = _messages.any((m) => m.role == 'user');
    if (hasPatientReply) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x80F59E0B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_chat_unread_rounded, size: 16, color: Color(0xFFB45309)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Meta 24h Window Notice for $_selectedPatientName",
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "WhatsApp requires an official registered template to open the 24-hour service window before regular text messages can be delivered to recipients who haven't messaged the clinic first.",
            style: TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.3),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF075E54),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.send_rounded, size: 14),
                label: const Text(
                  "📢 Send Welcome Template",
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                onPressed: _isLoading ? null : _sendOfficialWelcomeTemplate,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF166534),
                  side: const BorderSide(color: Color(0xFF166534)),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text(
                  "📱 Open in App",
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
                onPressed: _launchWhatsAppToPatient,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage([String? textToSend, bool isVoice = false]) async {
    if (_isListening) {
      _voiceController.stop();
    }
    final text = (textToSend ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

    if (_isDoctor && _doctorSendViaWhatsApp) {
      await _sendDoctorWhatsAppMessage(text);
      return;
    }

    _controller.clear();
    setState(() {
      _messages.add(_HealthChatMessage(role: 'user', text: text, isVoice: isVoice));
      _isLoading = true;
    });
    _persistMessagesLocally();
    _scrollToBottom();

    try {
      // Build conversation history for context
      final history = _messages
          .where((m) => m.text.isNotEmpty)
          .map((m) => AssistantConversationMessage(
                role: m.role,
                content: m.text,
              ))
          .toList();

      final reply = await BackendApiService.assistantChat(
        patientId: _patientId,
        message: text,
        history: history.length > 6 ? history.sublist(history.length - 6) : history,
      );

      if (mounted) {
        setState(() {
          _messages.add(_HealthChatMessage(
            role: 'assistant',
            text: reply.reply.isNotEmpty
                ? reply.reply
                : "Your health records are synchronized with your EHR chart.",
          ));
        });
        _persistMessagesLocally();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_HealthChatMessage(
            role: 'assistant',
            text:
                "### 🩺 Clinical Sync Note\nYour vitals are logged in the Central Cloud EMR. If you require immediate attention, you can tap below to connect with Intelligent Digital Solution directly on WhatsApp.",
          ));
        });
        _persistMessagesLocally();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
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

  Future<void> _confirmClearChatHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Chat History?"),
        content: const Text("Are you sure you want to clear your current conversation history?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Clear")),
        ],
      ),
    );
    if (confirm == true) {
      await _clearChatHistory();
    }
  }

  Widget _buildPatientHeader() {
    return InkWell(
      onTap: _isWhatsAppVerified ? () => _launchWhatsApp() : _showWhatsAppVerificationModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _isWhatsAppVerified ? const Color(0xFFF0FDF4) : const Color(0xFFF0F9FF),
          border: Border(bottom: BorderSide(color: _isWhatsAppVerified ? Colors.green.shade200 : Colors.blue.shade200)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _isWhatsAppVerified ? const Color(0xFF25D366) : const Color(0xFF0F5C9C),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isWhatsAppVerified ? Icons.check_circle_rounded : Icons.chat_bubble_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isWhatsAppVerified
                    ? "Care Team WhatsApp Synced (${_userPhone.isNotEmpty ? _userPhone : 'Connected'}) • Tap to open chat"
                    : "Need doctor advice? Connect WhatsApp to sync with Care Team",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _isWhatsAppVerified ? const Color(0xFF166534) : const Color(0xFF0C4A6E),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _isWhatsAppVerified ? () => _launchWhatsApp() : _showWhatsAppVerificationModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isWhatsAppVerified ? const Color(0xFF25D366) : const Color(0xFF0F5C9C),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(60, 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                _isWhatsAppVerified ? "Open WhatsApp" : "Connect",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            if (_messages.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Clear Chat History",
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFF166534)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _confirmClearChatHistory,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddCustomContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF075E54)),
            SizedBox(width: 8),
            Text(
              "Add Contact / Patient",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter any contact or patient phone number to permanently save and enable 2-way live WhatsApp messaging:",
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Contact / Patient Name",
                hintText: "e.g. Sarah / Caregiver",
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "Phone Number",
                hintText: "e.g. 613-261-6383 or 1613...",
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF075E54),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              final rawPhone = phoneController.text.trim();
              final phone = rawPhone.replaceAll(RegExp(r'\D'), '');
              if (phone.isEmpty) return;
              final cleanName = name.isEmpty ? "Contact ($rawPhone)" : name;
              // User requirement: keep ID as phone number itself
              final newId = phone;

              await _persistMessagesLocally();

              final newContact = {
                "name": cleanName,
                "patient_id": newId,
                "phone": phone,
                "info": "Saved Contact • $rawPhone",
              };

              setState(() {
                _doctorPatients.removeWhere((p) => p["phone"] == phone);
                _doctorPatients.insert(0, newContact);
                _selectedPatientId = newId;
                _selectedPatientName = cleanName;
                _selectedPatientPhone = phone;
                _patientId = phone;
              });

              // Permanently persist to SharedPreferences
              await _saveDoctorContactsToPrefs();

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("✅ Permanently saved $cleanName ($rawPhone)"),
                  backgroundColor: const Color(0xFF166534),
                ),
              );

              // Load history and sync live WhatsApp for newly added contact
              await _loadMessagesForCurrentPatient();
              await _syncWhatsAppThreadSilently();
            },
            child: const Text("Save & Select"),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border(bottom: BorderSide(color: Colors.green.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF075E54),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      "$_doctorName — Live WhatsApp Hub",
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF075E54),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "🟢 2-Way Live Sync",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: "Sync WhatsApp Now",
                icon: const Icon(Icons.sync_rounded, size: 18, color: Color(0xFF075E54)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _syncWhatsAppThreadSilently(showToast: true),
              ),
              const SizedBox(width: 8),
              if (_messages.isNotEmpty)
                IconButton(
                  tooltip: "Clear History for $_selectedPatientName",
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _confirmClearChatHistory,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                "Patient: ",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPatientId,
                      isDense: true,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      items: _doctorPatients.map((p) {
                        return DropdownMenuItem<String>(
                          value: p["patient_id"],
                          child: Text(
                            "${p["name"]} (${p["info"]})",
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _onDoctorPatientChanged(val);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _pickContactFromDevice,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF075E54),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.contacts_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        "Phone",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _showManageContactsModal,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 13, color: Color(0xFF0F172A)),
                      SizedBox(width: 4),
                      Text(
                        "Book",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _showAddCustomContactDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF075E54)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: Color(0xFF075E54)),
                      SizedBox(width: 2),
                      Text(
                        "Add",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF075E54),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorComposerModeToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => setState(() => _doctorSendViaWhatsApp = true),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _doctorSendViaWhatsApp ? const Color(0xFF25D366) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _doctorSendViaWhatsApp ? const Color(0xFF166534) : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_rounded,
                    size: 13,
                    color: _doctorSendViaWhatsApp ? Colors.white : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "WhatsApp $_selectedPatientName",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _doctorSendViaWhatsApp ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => setState(() => _doctorSendViaWhatsApp = false),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: !_doctorSendViaWhatsApp ? Theme.of(context).primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: !_doctorSendViaWhatsApp ? Theme.of(context).primaryColor : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology_rounded,
                    size: 13,
                    color: !_doctorSendViaWhatsApp ? Colors.white : Colors.grey.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Consult Clinical AI",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: !_doctorSendViaWhatsApp ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () {
              WhatsAppLauncherService.launchWhatsApp(
                context: context,
                phone: _selectedPatientPhone,
                message: "Hello $_selectedPatientName, this is $_doctorName following up on your health.",
              );
            },
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF25D366)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF166534)),
                  SizedBox(width: 4),
                  Text(
                    "Open WhatsApp App",
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Header: Custom Doctor Header or Patient WhatsApp Connect Banner
        _isDoctor ? _buildDoctorHeader() : _buildPatientHeader(),

        // Meta 24-Hour Outreach Notice & Template Initialization for Doctors
        if (_isDoctor) _buildDoctorOutreachBanner(),

        // Chat Message Feed or Empty State
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg.role == 'user';
                    final isDoctor = msg.role == 'doctor';
                    final isOutgoing = _isDoctor ? isDoctor : isUser;

                    return Align(
                      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.82,
                        ),
                        decoration: BoxDecoration(
                          color: isOutgoing
                              ? (_isDoctor ? const Color(0xFFF0FDF4) : Theme.of(context).primaryColor)
                              : (isUser && _isDoctor ? const Color(0xFFF8FAFC) : Colors.white),
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isOutgoing ? const Radius.circular(0) : const Radius.circular(16),
                            bottomLeft: !isOutgoing ? const Radius.circular(0) : const Radius.circular(16),
                          ),
                          border: Border.all(
                            color: isOutgoing
                                ? (_isDoctor ? const Color(0xFF86EFAC) : Theme.of(context).primaryColor)
                                : (isUser && _isDoctor ? const Color(0xFFCBD5E1) : Colors.grey.shade300),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDoctor
                                      ? Icons.medical_services_rounded
                                      : (isUser
                                          ? (_isDoctor ? Icons.chat_bubble_rounded : (msg.isVoice ? Icons.mic : Icons.person))
                                          : Icons.smart_toy),
                                  size: 14,
                                  color: isOutgoing
                                      ? (_isDoctor ? const Color(0xFF166534) : Colors.white70)
                                      : (_isDoctor && isUser ? const Color(0xFF0284C7) : Colors.blue.shade700),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isDoctor
                                      ? "$_doctorName (Attending Physician)"
                                      : (isUser
                                          ? (_isDoctor ? "$_selectedPatientName (WhatsApp)" : (msg.isVoice ? "You (Voice Scribe)" : "You"))
                                          : "PrimeCare AI"),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isOutgoing
                                        ? (_isDoctor ? const Color(0xFF166534) : Colors.white70)
                                        : (_isDoctor && isUser ? const Color(0xFF0369A1) : Colors.blue.shade700),
                                  ),
                                ),
                                if (msg.isVoice) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "Whisper",
                                      style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            isOutgoing && !_isDoctor
                                ? Text(
                                    msg.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      height: 1.4,
                                    ),
                                  )
                                : isDoctor
                                    ? MarkdownBody(
                                        data: msg.text,
                                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                          p: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF0F172A)),
                                        ),
                                      )
                                    : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      MarkdownBody(
                                        data: msg.text,
                                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                          p: const TextStyle(fontSize: 14, height: 1.45, color: Colors.black87),
                                        ),
                                      ),
                                      if (msg.text.contains("INTELLIGENT DIGITAL SOLUTION") || msg.text.contains("Intelligent Digital Solution") || msg.text.contains("STAT") || msg.text.contains("chest pain") || msg.text.contains("911")) ...[
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            ElevatedButton.icon(
                                              icon: const Icon(Icons.chat_bubble, size: 13),
                                              label: const Text("Open Intelligent Digital Solution's WhatsApp Triage", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF075E54),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                              ),
                                              onPressed: _openInternalWhatsApp,
                                            ),
                                            if (msg.text.contains("911") || msg.text.contains("STAT") || msg.text.contains("severe")) ...[
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.phone_in_talk, size: 13),
                                                label: const Text("Call 911", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFDC2626),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                ),
                                                onPressed: () async {
                                                  final uri = Uri.parse("tel:911");
                                                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Loading indicator
        if (_isLoading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      _isDoctor && _doctorSendViaWhatsApp
                          ? const Color(0xFF25D366)
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isDoctor && _doctorSendViaWhatsApp
                      ? "Dispatching to $_selectedPatientName's WhatsApp via Meta..."
                      : "Analyzing clinical database...",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

        // Input field & Send button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isDoctor) ...[
                  _buildDoctorComposerModeToggle(),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    VoiceDictationMicButton(
                      isListening: _isListening,
                      isTranscribing: _isTranscribing,
                      onPressed: _toggleListening,
                      idleIconColor: _isDoctor && _doctorSendViaWhatsApp
                          ? const Color(0xFF25D366)
                          : const Color(0xFF6366F1),
                      idleTooltip: 'Record voice with Whisper (Tap to speak)',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !_isTranscribing,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (val) => _sendMessage(val),
                        decoration: buildVoiceComposerDecoration(
                          isListening: _isListening,
                          isTranscribing: _isTranscribing,
                          idleHint: _isDoctor
                              ? (_doctorSendViaWhatsApp
                                  ? 'Message $_selectedPatientName on WhatsApp...'
                                  : 'Ask clinical AI about $_selectedPatientName...')
                              : 'Ask about your health...',
                          focusedIdleColor: _isDoctor && _doctorSendViaWhatsApp
                              ? const Color(0xFF25D366)
                              : Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: _isDoctor && _doctorSendViaWhatsApp
                            ? const Color(0xFF25D366)
                            : Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isDoctor && _doctorSendViaWhatsApp
                              ? Icons.send_rounded
                              : Icons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _isLoading ? null : () => _sendMessage(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isDoctor
                        ? const Color(0xFF075E54).withOpacity(0.1)
                        : Theme.of(context).primaryColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isDoctor ? Icons.medical_services_rounded : Icons.favorite_rounded,
                    size: 48,
                    color: _isDoctor ? const Color(0xFF075E54) : Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isDoctor ? "$_doctorName's Clinical Copilot" : "Ask about your wellness data",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isDoctor
                      ? "Send clinical instructions directly to $_selectedPatientName's WhatsApp, review continuous Apple Watch & health telemetry, or consult Canadian CPG guidelines."
                      : "Real-time clinical AI assistant connected to your wearable & mobile health telemetry, appointments, and care team.",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _currentPrompts.map((prompt) {
                    return ActionChip(
                      label: Text(prompt, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide(color: Colors.grey.shade300),
                      onPressed: () => _sendMessage(prompt),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
