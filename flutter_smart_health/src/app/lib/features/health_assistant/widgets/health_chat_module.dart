import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/api_config.dart';
import '../../../core/services/voice_dictation_helper.dart';
import '../../../data/models/assistant_models.dart';
import '../../../services/backend_api_service.dart';
import '../../../services/e_hospital_auth_service.dart';
import '../../../services/whatsapp_launcher_service.dart';

class HealthChatModule extends StatefulWidget {
  final VoidCallback? onBack;
  const HealthChatModule({super.key, this.onBack});

  @override
  State<HealthChatModule> createState() => _HealthChatModuleState();
}

class _HealthChatMessage {
  final String? id;
  final String role; // 'user' | 'assistant' | 'doctor'
  final String text;
  final bool isVoice;
  final String status; // 'sending' | 'sent' | 'delivered'
  final DateTime timestamp;

  _HealthChatMessage({
    this.id,
    required this.role,
    required this.text,
    this.isVoice = false,
    this.status = 'delivered',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'text': text,
        'isVoice': isVoice,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
      };

  factory _HealthChatMessage.fromJson(Map<String, dynamic> json) => _HealthChatMessage(
        id: json['id']?.toString(),
        role: json['role'] as String? ?? 'user',
        text: json['text'] as String? ?? '',
        isVoice: json['isVoice'] == true,
        status: json['status']?.toString() ?? 'delivered',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'].toString())
            : null,
      );
}

class _HealthChatModuleState extends State<HealthChatModule> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_HealthChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  bool _isTranscribing = false;
  late final VoiceDictationController _voiceController;
  String _patientId = "1";
  bool _isWhatsAppVerified = false;
  bool _doctorWhatsAppVerified = false;
  String _doctorClinicWhatsApp = "";
  String _deviceOwnerId = "";
  String _userPhone = "";
  bool _isDoctor = false;
  String _doctorName = "Dr. Sugan";
  String _selectedPatientName = "Sugan";
  String _selectedPatientId = "6132616383";
  String _selectedPatientPhone = "6132616383";
  bool _doctorSendViaWhatsApp = true;
  bool _showTasksMode = false;
  List<Map<String, dynamic>> _scheduledTasks = [];
  bool _loadingTasks = false;
  Timer? _liveSyncTimer;
  bool _isLiveSyncing = false;

  String _sanitizeName(String text) {
    return text
        .replaceAll("Dr. Patel", "Dr. Sugan")
        .replaceAll("Dr Patel", "Dr. Sugan")
        .replaceAll("Patel", "Sugan");
  }

  static final List<Map<String, String>> _defaultPatients = [];

  late List<Map<String, String>> _doctorPatients = [];

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

    var doctorName = prefs.getString("doctor_custom_name_v1") ??
        prefs.getString("patient_username") ??
        "Dr. Sugan";
    if (doctorName.toLowerCase().contains("ava") ||
        doctorName.toLowerCase() == "patient" ||
        doctorName.trim().isEmpty) {
      doctorName = "Dr. Sugan";
    }
    if (!doctorName.startsWith("Dr.") && !doctorName.startsWith("Dr ")) {
      doctorName = "Dr. $doctorName";
    }

    // Persistent standalone per-device owner ID (isolates each phone's contacts & chat history)
    var deviceOwnerId = prefs.getString("maxassist_device_owner_id_v1") ?? "";
    if (deviceOwnerId.isEmpty) {
      final nowMs = DateTime.now().microsecondsSinceEpoch;
      final hash = (nowMs ^ identity.hashCode ^ email.hashCode).abs().toRadixString(36);
      deviceOwnerId = "dev_${nowMs.toRadixString(36)}_$hash";
      await prefs.setString("maxassist_device_owner_id_v1", deviceOwnerId);
    }
    _deviceOwnerId = deviceOwnerId;

    // Always load persisted contacts from THIS device's local cache
    final savedContactsJson = prefs.getString("doctor_persisted_contacts_v2");
    List<Map<String, String>> combinedContacts = [];
    if (savedContactsJson != null && savedContactsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(savedContactsJson);
        for (final item in decoded) {
          if (item is Map) {
            combinedContacts.add(item.map((k, v) => MapEntry(k.toString(), v.toString())));
          }
        }
      } catch (e) {
        debugPrint("[HealthChat] Error loading persisted contacts: $e");
      }
    }

    // Real-time synchronization from persistent Central Database (STRICTLY scoped to this device!)
    if (isDoctor) {
      try {
        final remotePatients = await BackendApiService.getDoctorPatients(ownerId: _deviceOwnerId);
        if (remotePatients.isNotEmpty) {
          final List<Map<String, String>> loadedRemote = [];
          for (final rp in remotePatients) {
            final pPhone = (rp["phone"] ?? rp["patient_id"] ?? "").toString();
            final pName = (rp["name"] ?? "").toString();
            final pCond = (rp["condition"] ?? rp["notes"] ?? "").toString();
            if (pPhone.isNotEmpty) {
              loadedRemote.add({
                "name": pName.isNotEmpty ? pName : "Patient $pPhone",
                "patient_id": pPhone,
                "phone": pPhone,
                "info": pCond,
              });
            }
          }
          if (loadedRemote.isNotEmpty) {
            combinedContacts = loadedRemote;
            await prefs.setString("doctor_persisted_contacts_v2", jsonEncode(combinedContacts));
          }
        }
      } catch (e) {
        debugPrint("[HealthChat] Error syncing doctor patients from DB: $e");
      }
    }

    final lastSelectedId = prefs.getString("doctor_selected_patient_id");
    Map<String, String> selected = combinedContacts.isNotEmpty
        ? combinedContacts.first
        : {
            "name": "Select Patient",
            "patient_id": "",
            "phone": "",
            "info": "",
          };
    if (lastSelectedId != null && lastSelectedId.isNotEmpty && combinedContacts.isNotEmpty) {
      final match = combinedContacts.firstWhere(
        (c) => c["patient_id"] == lastSelectedId || c["phone"] == lastSelectedId,
        orElse: () => combinedContacts.first,
      );
      selected = match;
    }

    final bool doctorWaVerified = prefs.getBool("doctor_whatsapp_verified_v1") ?? false;
    final String doctorWaPhone = prefs.getString("doctor_whatsapp_phone_v1") ?? "";

    if (mounted) {
      setState(() {
        _isDoctor = isDoctor;
        _doctorName = doctorName;
        _doctorPatients = combinedContacts;
        _selectedPatientId = selected["patient_id"] ?? "";
        _selectedPatientName = selected["name"] ?? "Select Patient";
        _selectedPatientPhone = selected["phone"] ?? "";
        if (isDoctor) {
          _patientId = _selectedPatientPhone.isNotEmpty ? _selectedPatientPhone : _selectedPatientId;
        } else if (pid != null) {
          _patientId = pid.toString();
        }
        _isWhatsAppVerified = verified;
        _doctorWhatsAppVerified = doctorWaVerified;
        _doctorClinicWhatsApp = doctorWaPhone.isNotEmpty ? doctorWaPhone : "16134045586";
        _userPhone = isDoctor
            ? (doctorWaPhone.isNotEmpty ? doctorWaPhone : (savedPhone.isNotEmpty ? savedPhone : "16134045586"))
            : savedPhone;
      });
    }

    // Prompt one-time WhatsApp verification on first launch per device
    final bool isRunningInTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isDoctor && !doctorWaVerified && !isRunningInTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_doctorWhatsAppVerified) {
          _showDoctorWhatsAppOnboardingModal(allowCancel: false);
        }
      });
    } else if (!isDoctor && !verified && !isRunningInTest) {
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
      _loadScheduledTasks();
    }
  }

  String _extractCoreMessageText(String raw) {
    var s = raw.trim();
    // Strip decorated prefixes from user, bot, doctor, outreach
    s = s.replaceAll(RegExp(r'^🎙️\s*(\*\*.*?\*\*:|\[Voice Note\]:?)\s*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'^(💬|🩺|🤖|📢)\s*\*\*.*?\*\*:\s*', caseSensitive: false), '');
    // Strip markdown formatting symbols and punctuation
    s = s.replaceAll(RegExp(r'[\*\#\_\"\`\n\r]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    return s;
  }

  Future<void> _loadMessagesForCurrentPatient() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _currentChatHistoryKey;
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(cached);
        final List<_HealthChatMessage> deduplicatedCache = [];
        final Set<String> seenCacheIds = {};
        final Set<String> seenCacheCores = {};
        for (final m in decoded) {
          if (m is Map) {
            final raw = _HealthChatMessage.fromJson(Map<String, dynamic>.from(m));
            final core = _extractCoreMessageText(raw.text);
            final msgId = raw.id;
            if (msgId != null && msgId.isNotEmpty && seenCacheIds.contains(msgId)) {
              continue;
            }
            if (core.isNotEmpty && seenCacheCores.contains(core)) {
              continue;
            }
            if (msgId != null && msgId.isNotEmpty) seenCacheIds.add(msgId);
            if (core.isNotEmpty) seenCacheCores.add(core);

            deduplicatedCache.add(_HealthChatMessage(
              id: msgId,
              role: raw.role,
              text: _sanitizeName(raw.text),
              isVoice: raw.isVoice,
              timestamp: raw.timestamp,
            ));
          }
        }
        if (mounted) {
          setState(() {
            _messages.clear();
            _messages.addAll(deduplicatedCache);
          });
          _scrollToBottom();
          await _persistMessagesLocally();
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

    // Also pull from persistent Central Database if doctor
    if (_isDoctor && _selectedPatientPhone.isNotEmpty) {
      try {
        final serverMsgs = await BackendApiService.getDoctorChatHistory(
          _selectedPatientPhone,
          ownerId: _deviceOwnerId,
        );
        if (serverMsgs.isNotEmpty && mounted) {
          final List<_HealthChatMessage> loaded = [];
          final Set<String> seenServerIds = {};
          final Set<String> seenServerCores = {};
          for (final item in serverMsgs) {
            final rawRole = item['role']?.toString().toLowerCase() ?? 'patient';
            final text = _sanitizeName(item['text']?.toString() ?? '');
            final rawMsgId = (item['message_id'] ?? item['id'] ?? '').toString().trim();
            final isVoice = item['isVoice'] == true || text.startsWith("🎙️ [Voice Note]");
            if (text.isEmpty) continue;

            final core = _extractCoreMessageText(text);
            if (rawMsgId.isNotEmpty && seenServerIds.contains(rawMsgId)) continue;
            if (core.isNotEmpty && seenServerCores.contains(core)) continue;
            if (rawMsgId.isNotEmpty) seenServerIds.add(rawMsgId);
            if (core.isNotEmpty) seenServerCores.add(core);

            String mappedRole = 'assistant';
            if (rawRole == 'patient' || rawRole == 'user') {
              mappedRole = 'user';
            } else if (rawRole == 'doctor') {
              mappedRole = 'doctor';
            }
            String formattedText = text;
            if (text.startsWith("🎙️ [Voice Note]")) {
              formattedText = "🎙️ ${text.replaceFirst(RegExp(r'^🎙️\s*\[Voice Note\]:?\s*'), '').trim()}";
            }
            loaded.add(_HealthChatMessage(
              id: rawMsgId.isNotEmpty ? rawMsgId : null,
              role: mappedRole,
              text: formattedText,
              isVoice: isVoice,
              status: (item['status']?.toString().isNotEmpty == true) ? item['status'].toString() : 'delivered',
              timestamp: DateTime.tryParse(item['created_at']?.toString() ?? ''),
            ));
          }
          if (loaded.isNotEmpty && mounted) {
            setState(() {
              _messages.clear();
              _messages.addAll(loaded);
            });
            await _persistMessagesLocally();
            _scrollToBottom();
          }
        }
      } catch (e) {
        debugPrint("[HealthChat] Server history load error: $e");
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

      final url = Uri.parse(
        "${ApiConfig.backendBaseUrl}/api/whatsapp/threads/$cleanPhone?owner_id=${Uri.encodeComponent(_deviceOwnerId)}",
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map && data['messages'] is List) {
          final List<dynamic> serverMsgs = data['messages'];
          bool hasNew = false;

          for (final item in serverMsgs) {
            if (item is Map) {
              final rawRole = item['role']?.toString().toLowerCase() ?? 'patient';
              final rawText = item['text']?.toString() ?? '';
              final text = _sanitizeName(rawText);
              final rawMsgId = (item['message_id'] ?? item['id'] ?? '').toString().trim();
              if (text.isEmpty) continue;

              final String mappedRole = (rawRole == 'patient' || rawRole == 'user')
                  ? 'user'
                  : (rawRole == 'doctor' ? 'doctor' : 'assistant');

              final coreIncoming = _extractCoreMessageText(text);

              // Deduplicate by comparing message ID or core text content
              final bool exists = (rawMsgId.isNotEmpty && _messages.any((m) => m.id != null && m.id == rawMsgId)) ||
                  _messages.any((m) {
                    final coreExisting = _extractCoreMessageText(m.text);
                    return coreExisting.isNotEmpty &&
                        (coreExisting == coreIncoming ||
                         coreExisting.contains(coreIncoming) ||
                         coreIncoming.contains(coreExisting));
                  });

              if (!exists) {
                hasNew = true;
                String formattedText = text;
                if (text.startsWith("🎙️ [Voice Note]")) {
                  formattedText = "🎙️ ${text.replaceFirst(RegExp(r'^🎙️\s*\[Voice Note\]:?\s*'), '').trim()}";
                }

                _messages.add(_HealthChatMessage(
                  id: rawMsgId.isNotEmpty ? rawMsgId : null,
                  role: mappedRole,
                  text: formattedText,
                  isVoice: text.startsWith("🎙️ [Voice Note]") || item['isVoice'] == true,
                  status: (item['status']?.toString().isNotEmpty == true) ? item['status'].toString() : 'delivered',
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
    } catch (e) {
      debugPrint("[HealthChat] Live WhatsApp polling sync error: $e");
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
        if (_doctorPatients.isNotEmpty) {
          final fallback = _doctorPatients.first;
          _selectedPatientId = fallback["patient_id"] ?? "";
          _selectedPatientName = fallback["name"] ?? "Select Patient";
          _selectedPatientPhone = fallback["phone"] ?? "";
          _patientId = _selectedPatientPhone;
        } else {
          _selectedPatientId = "";
          _selectedPatientName = "Select Patient";
          _selectedPatientPhone = "";
          _patientId = "";
        }
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

        // Permanently record to Central Database
        BackendApiService.createDoctorPatient(
          name: name,
          phone: phone,
          notes: "Phone Contact • $rawPhone",
          doctorName: _doctorName,
          ownerId: _deviceOwnerId,
        );

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
    final tempId = "local_${DateTime.now().microsecondsSinceEpoch}";
    final optimisticMsg = _HealthChatMessage(
      id: tempId,
      role: 'doctor',
      text: text,
      status: 'sending',
    );
    setState(() {
      _messages.add(optimisticMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final res = await BackendApiService.doctorDispatchPatientMessage(
        patientPhone: _selectedPatientPhone,
        message: text,
        patientName: _selectedPatientName,
        patientId: int.tryParse(_selectedPatientPhone) ?? (int.tryParse(_selectedPatientId) ?? 99211),
        doctorName: _doctorName,
        ownerId: _deviceOwnerId,
      );

      final liveSent = res['delivered_live'] == true;
      final finalStatus = liveSent ? 'delivered' : 'sent';

      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == tempId);
          if (idx != -1) {
            _messages[idx] = _HealthChatMessage(
              id: tempId,
              role: 'doctor',
              text: text,
              status: finalStatus,
              timestamp: optimisticMsg.timestamp,
            );
          }
        });
        await _persistMessagesLocally();
        _syncWhatsAppThreadSilently();
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
    // Intentionally left blank: composer starts completely empty with no prefilled text.
  }

  Future<void> _launchWhatsAppToPatient() async {
    final cleanPhone = _selectedPatientPhone.replaceAll(RegExp(r'\D'), '');
    final msg = _controller.text.trim().isNotEmpty
        ? _controller.text.trim()
        : "Hello $_selectedPatientName, this is $_doctorName from MaxAssist Clinic.";
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

    final hasSentOutreach = _messages.any(
      (m) => m.role == 'doctor' || m.text.contains("Template Dispatched") || m.text.contains("Outreach Template"),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasSentOutreach ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSentOutreach ? const Color(0xFF93C5FD) : const Color(0x80F59E0B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasSentOutreach ? Icons.hourglass_top_rounded : Icons.mark_chat_unread_rounded,
                size: 16,
                color: hasSentOutreach ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasSentOutreach
                      ? "Awaiting Patient's Reply ('Hi') from $_selectedPatientName"
                      : "Meta 24h Window Notice for $_selectedPatientName",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: hasSentOutreach ? const Color(0xFF1E40AF) : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasSentOutreach
                ? "Meta WhatsApp Cloud API policy requires the recipient to reply once (e.g. text 'Hi') to open the 24-hour window. Once they reply, all your custom doctor messages deliver immediately."
                : "WhatsApp requires an official registered template to open the 24-hour service window before regular text messages can be delivered to recipients who haven't messaged the clinic first.",
            style: TextStyle(
              fontSize: 11,
              color: hasSentOutreach ? const Color(0xFF1E3A8A) : const Color(0xFF78350F),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (!hasSentOutreach)
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
      final isScheduleIntent = _showTasksMode ||
          RegExp(
            r'\b(schedule|remind|reminder|tomorrow|tmrw|next\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)|in\s+\d+\s*(min|minute|minutes|hr|hour|hours)|at\s+\d{1,2}(:\d{2})?\s*(am|pm))\b',
            caseSensitive: false,
          ).hasMatch(text);

      if (isScheduleIntent) {
        await _handleNaturalLanguageSchedule(text);
        return;
      }

      if (_selectedPatientPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ Please select or add a patient contact before sending."),
            backgroundColor: Color(0xFFB91C1C),
          ),
        );
        return;
      }
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

              // Permanently persist to SharedPreferences & Central Database
              await _saveDoctorContactsToPrefs();
              BackendApiService.createDoctorPatient(
                name: cleanName,
                phone: phone,
                notes: "Saved Contact • $rawPhone",
                doctorName: _doctorName,
                ownerId: _deviceOwnerId,
              );

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

  Widget _buildGeminiTopBar() {
    final initials = (_doctorPatients.isEmpty ? "M" : _selectedPatientName)
        .trim()
        .isNotEmpty
        ? (_doctorPatients.isEmpty ? "M" : _selectedPatientName).trim()[0].toUpperCase()
        : "P";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF075E54),
        boxShadow: [
          BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Left: Back to Dashboard + Drawer Menu
          if (widget.onBack != null)
            IconButton(
              tooltip: "Back",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.arrow_back_rounded, size: 22, color: Colors.white),
              onPressed: widget.onBack,
            ),
          IconButton(
            tooltip: "Chats & Contacts",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.menu_rounded, size: 22, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 4),

          // Center: WhatsApp-style Avatar + Patient Name + Phone Subtitle (Tappable Selector)
          Expanded(
            child: PopupMenuButton<String>(
              initialValue: _selectedPatientId,
              onSelected: (val) => _onDoctorPatientChanged(val),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              offset: const Offset(0, 44),
              itemBuilder: (ctx) => _doctorPatients.isEmpty
                  ? [
                      const PopupMenuItem<String>(
                        enabled: false,
                        value: '',
                        child: Text("No patients added yet. Tap + on right to add."),
                      ),
                    ]
                  : _doctorPatients.map((p) {
                      final isSelected = p["patient_id"] == _selectedPatientId || p["phone"] == _selectedPatientPhone;
                      return PopupMenuItem<String>(
                        value: p["patient_id"],
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: isSelected ? const Color(0xFF075E54) : const Color(0xFFE2E8F0),
                              foregroundColor: isSelected ? Colors.white : const Color(0xFF1E293B),
                              child: Text(
                                (p["name"] ?? "P").substring(0, 1).toUpperCase(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    p["name"] ?? "Patient",
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? const Color(0xFF075E54) : const Color(0xFF0F172A),
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  Text(
                                    "+${p["phone"] ?? p["patient_id"]}",
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF166534)),
                          ],
                        ),
                      );
                    }).toList(),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xFF128C7E),
                    child: Text(
                      initials,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _doctorPatients.isEmpty ? "MaxAssist Chat" : _selectedPatientName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_drop_down_rounded, size: 20, color: Colors.white70),
                          ],
                        ),
                        Text(
                          _selectedPatientPhone.isNotEmpty
                              ? "+$_selectedPatientPhone • $_doctorName"
                              : "$_doctorName • Tap + to add contact",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFFD1FAE5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right: Add Contact (+) & Sync Icons
          IconButton(
            tooltip: "Add Contact",
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 22, color: Colors.white),
            onPressed: _showAddContactModalSheet,
          ),
          IconButton(
            tooltip: "Sync WhatsApp",
            icon: const Icon(Icons.sync_rounded, size: 21, color: Colors.white),
            onPressed: () => _syncWhatsAppThreadSilently(showToast: true),
          ),
        ],
      ),
    );
  }

  void _showAddContactModalSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.person_add_rounded, color: Color(0xFF075E54), size: 22),
                  SizedBox(width: 10),
                  Text(
                    "Add or Select Contact",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                "Create a new patient record or import directly from your phone's address book.",
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              // Option 1: Create New Contact
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                tileColor: const Color(0xFFF8FAFC),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF075E54).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF075E54)),
                ),
                title: const Text("Create New Contact", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text("Enter patient name, phone number, and clinical info", style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showAddCustomContactDialog();
                },
              ),
              const SizedBox(height: 10),
              // Option 2: Import from Phone Contacts
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                tileColor: const Color(0xFFF8FAFC),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.contacts_rounded, color: Color(0xFF0284C7)),
                ),
                title: const Text("Select from Phone Contacts", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text("Import a contact directly from your Android address book", style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickContactFromDevice();
                },
              ),
              const SizedBox(height: 10),
              // Option 3: Manage Contacts Directory
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                tileColor: const Color(0xFFF8FAFC),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64748B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF475569)),
                ),
                title: const Text("Contacts Directory", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text("Search, switch, or manage saved patient contacts", style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showManageContactsModal();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGeminiHistoryDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF6F61),
                                  Color(0xFFFFA000),
                                  Color(0xFF4285F4),
                                  Color(0xFF9C27B0),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Patient History",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: "Close",
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Physician: $_doctorName • MaxAssist",
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),
                  // Linked WhatsApp Agent Line Card with intentional Change option
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF15803D)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "AI Agent WhatsApp Line",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                              ),
                              Text(
                                _doctorClinicWhatsApp.isNotEmpty ? "+$_doctorClinicWhatsApp" : "Not Linked",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showDoctorWhatsAppOnboardingModal(allowCancel: true);
                          },
                          child: const Text(
                            "Change",
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF075E54)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // New Conversation Button (Gemini Style)
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF075E54),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        "New Patient Outreach",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showAddContactModalSheet();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Section Title
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Text(
                "RECENT CONVERSATIONS (BY PATIENT ID)",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
            // Patient History List (patient ID as name)
            Expanded(
              child: _doctorPatients.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            const Text(
                              "No Patient Chats Yet",
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Tap '+ New Patient Outreach' above to add a contact or select from your phone book.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                itemCount: _doctorPatients.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, idx) {
                  final p = _doctorPatients[idx];
                  final isSelected = p["patient_id"] == _selectedPatientId ||
                      p["phone"] == _selectedPatientPhone;
                  final patientIdDisplay = p["patient_id"] ?? p["phone"] ?? "6132616383";

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (p["patient_id"] != null) {
                        _onDoctorPatientChanged(p["patient_id"]!);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF0FDF4) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF86EFAC) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isSelected ? const Color(0xFF075E54) : const Color(0xFFE2E8F0),
                            foregroundColor: isSelected ? Colors.white : const Color(0xFF334155),
                            child: Text(
                              (p["name"] ?? "P").substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Patient #$patientIdDisplay",
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                          fontSize: 13,
                                          color: isSelected ? const Color(0xFF075E54) : const Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          "Active",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF166534),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${p["name"]} • ${p["info"] ?? 'Patient Record'}",
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Bottom Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  if (widget.onBack != null)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onBack?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.dashboard_customize_rounded, size: 16, color: Color(0xFF0F172A)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Back to Dashboard",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    "MaxAssist Clinical Suite • $_doctorName",
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeminiEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Colorful Google Gemini Sparkle Star Icon
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFF6F61),
                      Color(0xFFFFA000),
                      Color(0xFF4285F4),
                      Color(0xFF9C27B0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Ready when you are",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  "$_doctorName's Clinical Copilot & WhatsApp Gateway",
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                if (_isDoctor && _doctorPatients.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.person_add_alt_1_rounded, size: 36, color: Color(0xFF075E54)),
                        const SizedBox(height: 10),
                        const Text(
                          "No Patients in Clinical Database",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Add a patient contact or import from your phone to start real-time two-way WhatsApp clinical outreach.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  side: const BorderSide(color: Color(0xFF0284C7)),
                                  foregroundColor: const Color(0xFF0284C7),
                                ),
                                icon: const Icon(Icons.contacts_rounded, size: 16),
                                label: const Text("Phone Book", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                onPressed: _pickContactFromDevice,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  backgroundColor: const Color(0xFF075E54),
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text("Add Contact", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                onPressed: _showAddCustomContactDialog,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Action Suggestions Cards (matching Gemini format)
                  Column(
                    children: _currentPrompts.map((prompt) {
                      IconData icon = Icons.chat_bubble_outline_rounded;
                      if (prompt.contains("blood pressure") || prompt.contains("vital") || prompt.contains("heart")) {
                        icon = Icons.favorite_outline_rounded;
                      } else if (prompt.contains("follow-up") || prompt.contains("care") || prompt.contains("sleep")) {
                        icon = Icons.assignment_outlined;
                      } else if (prompt.contains("CPG") || prompt.contains("trend")) {
                        icon = Icons.verified_outlined;
                      }
                      return _buildGeminiPromptTile(
                        icon: icon,
                        text: prompt,
                        onTap: () => _sendMessage(prompt),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGeminiPromptTile({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF0F172A)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeminiComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      color: const Color(0xFFECE5DD),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // WhatsApp-style Rounded White Input Pill
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: "Add Contact",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: const Icon(Icons.add_rounded, size: 24, color: Color(0xFF54656F)),
                      onPressed: _showAddContactModalSheet,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !_isTranscribing,
                        maxLines: 4,
                        minLines: 1,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF111B21)),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            _sendMessage();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: _isDoctor
                              ? (_showTasksMode
                                  ? "Schedule task (e.g. Remind Sugan at 10 AM)..."
                                  : "Message")
                              : "Message MaxAssist...",
                          hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF667781)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _isListening ? "Listening..." : "Voice Dictation",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: Icon(
                        _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        size: 22,
                        color: _isListening ? Colors.redAccent : const Color(0xFF54656F),
                      ),
                      onPressed: _toggleListening,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Classic WhatsApp Circular Green Send Button
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFF00A884),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color(0x28000000), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: "Send",
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                onPressed: _isLoading ? null : () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBubbleTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return "$h:$m $ampm";
  }

  String _cleanDisplayBubbleText(String raw) {
    var s = _sanitizeName(raw).trim();
    s = s.replaceFirst(RegExp(r'^(💬|🩺|🤖)\s*\*\*.*?\*\*:\s*\n*', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'^🎙️\s*\*\*.*?\*\*:\s*\n*', caseSensitive: false), '🎙️ ');
    s = s.replaceAll(RegExp(r'\n*\*\(Dispatched to WhatsApp.*?\)\*$'), '');
    return s.trim();
  }

  Widget _buildWhatsAppTickIcon(String status) {
    if (status == 'sending') {
      return const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF667781));
    }
    if (status == 'sent') {
      return const Icon(Icons.done_rounded, size: 15, color: Color(0xFF667781));
    }
    return const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF53BDEB));
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg.role == 'user';
        final isDoctor = msg.role == 'doctor';
        final isOutgoing = _isDoctor ? isDoctor : isUser;
        final displayText = _cleanDisplayBubbleText(msg.text);

        return Align(
          alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.80,
            ),
            decoration: BoxDecoration(
              color: isOutgoing ? const Color(0xFFD9FDD3) : Colors.white,
              borderRadius: BorderRadius.circular(12).copyWith(
                topRight: isOutgoing ? const Radius.circular(2) : const Radius.circular(12),
                topLeft: !isOutgoing ? const Radius.circular(2) : const Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1.0,
                  child: MarkdownBody(
                    data: displayText,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(fontSize: 15, height: 1.35, color: Color(0xFF111B21)),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatBubbleTime(msg.timestamp),
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF667781)),
                    ),
                    if (isOutgoing) ...[
                      const SizedBox(width: 4),
                      _buildWhatsAppTickIcon(msg.status),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDoctorWhatsAppOnboardingModal({bool allowCancel = false}) async {
    final phoneCtrl = TextEditingController(
      text: allowCancel && _doctorClinicWhatsApp.isNotEmpty ? "+$_doctorClinicWhatsApp" : "",
    );
    final codeCtrl = TextEditingController();
    bool otpSent = false;
    bool busy = false;
    String? errorMsg;
    String? infoMsg;
    String? fallbackCode;

    await showDialog<void>(
      context: context,
      barrierDismissible: allowCancel,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return PopScope(
              canPop: allowCancel,
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.chat_rounded, color: Color(0xFF075E54), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            allowCancel ? "Change Agent WhatsApp" : "Link MaxAssist WhatsApp",
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const Text(
                            "One-time setup for this device",
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Enter the WhatsApp number you want MaxAssist AI Agent to operate on your behalf. It can be your clinic phone or any other mobile number.",
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: phoneCtrl,
                        enabled: !otpSent && !busy,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: "WhatsApp Number (with country code)",
                          hintText: "+1 613-404-5586",
                          prefixIcon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF075E54)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      if (otpSent) ...[
                        const SizedBox(height: 12),
                        if (infoMsg != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  infoMsg!,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.35),
                                ),
                                if (fallbackCode != null && fallbackCode!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Text(
                                        "Confirmation Code: ",
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF22C55E)),
                                        ),
                                        child: Text(
                                          fallbackCode!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                            color: Color(0xFF075E54),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: codeCtrl,
                          enabled: !busy,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: "6-Digit Verification Code",
                            hintText: "123456",
                            counterText: "",
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF075E54)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ],
                      if (errorMsg != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          errorMsg!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                actions: [
                  if (allowCancel)
                    TextButton(
                      onPressed: busy ? null : () => Navigator.of(ctx).pop(),
                      child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  if (otpSent)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              setModalState(() {
                                otpSent = false;
                                codeCtrl.clear();
                                errorMsg = null;
                                infoMsg = null;
                                fallbackCode = null;
                              });
                            },
                      child: const Text("Edit Number", style: TextStyle(color: Color(0xFF075E54))),
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF075E54),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    onPressed: busy
                        ? null
                        : () async {
                            final rawPhone = phoneCtrl.text.trim();
                            final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
                            if (digits.length < 10) {
                              setModalState(() => errorMsg = "Enter a valid number with country code (e.g. +1 613-404-5586).");
                              return;
                            }

                            if (!otpSent) {
                              setModalState(() {
                                busy = true;
                                errorMsg = null;
                              });
                              final res = await BackendApiService.requestDoctorWhatsAppOtp(
                                phone: rawPhone,
                                doctorId: _doctorName,
                              );
                              if (!ctx.mounted) return;
                              if (res['success'] == true) {
                                setModalState(() {
                                  busy = false;
                                  otpSent = true;
                                  infoMsg = res['message']?.toString() ?? "Verification code sent.";
                                  fallbackCode = res['fallback_code']?.toString();
                                });
                              } else {
                                setModalState(() {
                                  busy = false;
                                  errorMsg = res['error']?.toString() ?? "Could not send verification code.";
                                });
                              }
                            } else {
                              final code = codeCtrl.text.trim();
                              if (code.length != 6) {
                                setModalState(() => errorMsg = "Please enter the 6-digit verification code.");
                                return;
                              }
                              setModalState(() {
                                busy = true;
                                errorMsg = null;
                              });
                              final res = await BackendApiService.verifyDoctorWhatsAppOtp(
                                phone: rawPhone,
                                code: code,
                                doctorId: _doctorName,
                              );
                              if (!ctx.mounted) return;
                              if (res['verified'] == true) {
                                final verifiedPhone = (res['whatsapp_phone'] ?? digits).toString();
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool("doctor_whatsapp_verified_v1", true);
                                await prefs.setString("doctor_whatsapp_phone_v1", verifiedPhone);
                                if (mounted) {
                                  setState(() {
                                    _doctorWhatsAppVerified = true;
                                    _doctorClinicWhatsApp = verifiedPhone;
                                    _userPhone = verifiedPhone;
                                  });
                                }
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("✅ MaxAssist AI Agent activated on +$verifiedPhone"),
                                      backgroundColor: const Color(0xFF166534),
                                    ),
                                  );
                                }
                              } else {
                                setModalState(() {
                                  busy = false;
                                  errorMsg = res['error']?.toString() ?? "Invalid code. Please try again.";
                                });
                              }
                            }
                          },
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            otpSent ? "Verify & Activate Agent" : "Send Verification Code",
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadScheduledTasks() async {
    if (!mounted) return;
    setState(() => _loadingTasks = true);
    try {
      final tasks = await BackendApiService.getDoctorScheduledTasks(ownerId: _deviceOwnerId);
      if (mounted) {
        setState(() {
          _scheduledTasks = tasks;
          _loadingTasks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTasks = false);
    }
  }

  Future<void> _handleNaturalLanguageSchedule(String instruction) async {
    _controller.clear();
    setState(() => _isLoading = true);
    try {
      final res = await BackendApiService.parseAndScheduleDoctorTask(
        instruction: instruction,
        doctorName: _doctorName,
        defaultPatientPhone: _selectedPatientPhone,
        defaultPatientName: _selectedPatientName,
        ownerId: _deviceOwnerId,
      );
      if (res['success'] == true && res['task'] is Map) {
        final t = Map<String, dynamic>.from(res['task'] as Map);
        await _loadScheduledTasks();
        if (mounted) {
          setState(() {
            _messages.add(_HealthChatMessage(
              role: 'assistant',
              text: "⏰ **Scheduled WhatsApp Task Confirmed**\n\n"
                  "• **Recipient**: ${t['patient_name']} (`+${t['patient_phone']}`)\n"
                  "• **Scheduled For**: ${t['scheduled_display']}\n"
                  "• **Message**: \"${t['message_text']}\"\n"
                  "• **Physician**: $_doctorName\n\n"
                  "*(MaxAssist will automatically dispatch this WhatsApp message at the scheduled time.)*",
            ));
          });
          await _persistMessagesLocally();
          _scrollToBottom();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("⏰ Task scheduled for ${t['patient_name']} (${t['scheduled_display']})"),
              backgroundColor: const Color(0xFF166534),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error']?.toString() ?? "Could not schedule task."),
              backgroundColor: const Color(0xFFB91C1C),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showManualScheduleTaskDialog() async {
    String targetPhone = _selectedPatientPhone;
    String targetName = _selectedPatientName;
    final msgCtrl = TextEditingController();
    DateTime pickedDate = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay pickedTime = TimeOfDay.fromDateTime(pickedDate);
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final combined = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          final displayStr =
              "${combined.year}-${combined.month.toString().padLeft(2, '0')}-${combined.day.toString().padLeft(2, '0')} ${pickedTime.format(ctx)}";

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.schedule_send_rounded, color: Color(0xFF075E54)),
                SizedBox(width: 8),
                Text("Schedule WhatsApp Task", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_doctorPatients.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _doctorPatients.any((p) => p['phone'] == targetPhone)
                          ? targetPhone
                          : _doctorPatients.first['phone'],
                      decoration: InputDecoration(
                        labelText: "Patient",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _doctorPatients.map((p) {
                        final ph = p['phone'] ?? '';
                        final nm = p['name'] ?? ph;
                        return DropdownMenuItem(value: ph, child: Text("$nm (+$ph)"));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          final match = _doctorPatients.firstWhere((p) => p['phone'] == v);
                          setModalState(() {
                            targetPhone = v;
                            targetName = match['name'] ?? v;
                          });
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded, size: 15),
                          label: Text("${pickedDate.month}/${pickedDate.day}/${pickedDate.year}"),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: pickedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d != null) setModalState(() => pickedDate = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time_rounded, size: 15),
                          label: Text(pickedTime.format(ctx)),
                          onPressed: () async {
                            final t = await showTimePicker(context: ctx, initialTime: pickedTime);
                            if (t != null) setModalState(() => pickedTime = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: msgCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: "Message to send on WhatsApp",
                      hintText: "e.g. Reminder: Appointment tomorrow at 10 AM.",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF075E54),
                  foregroundColor: Colors.white,
                ),
                onPressed: saving
                    ? null
                    : () async {
                        if (targetPhone.isEmpty || msgCtrl.text.trim().isEmpty) return;
                        setModalState(() => saving = true);
                        final res = await BackendApiService.createDoctorScheduledTask(
                          patientPhone: targetPhone,
                          patientName: targetName.isNotEmpty ? targetName : targetPhone,
                          messageText: msgCtrl.text.trim(),
                          scheduledForUtc: combined.toUtc().toIso8601String(),
                          scheduledDisplay: displayStr,
                          doctorName: _doctorName,
                          ownerId: _deviceOwnerId,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (res['success'] == true) {
                          await _loadScheduledTasks();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("⏰ Scheduled for $targetName at $displayStr"),
                                backgroundColor: const Color(0xFF166534),
                              ),
                            );
                          }
                        }
                      },
                child: const Text("Schedule"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChatTaskToggle() {
    final pendingCount = _scheduledTasks.where((t) => t['status'] == 'pending').length;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => setState(() => _showTasksMode = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: !_showTasksMode ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    "Chat",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: !_showTasksMode ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _showTasksMode = true);
                  _loadScheduledTasks();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: _showTasksMode ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Task",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _showTasksMode ? const Color(0xFF075E54) : const Color(0xFF64748B),
                        ),
                      ),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF075E54),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            "$pendingCount",
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduledTasksView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Scheduled WhatsApp Tasks",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      "Type below (e.g. 'Remind Sugan tomorrow at 10 AM') or tap + Schedule",
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF075E54),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_alarm_rounded, size: 16),
                label: const Text("Schedule", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: _showManualScheduleTaskDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingTasks
              ? const Center(child: CircularProgressIndicator())
              : _scheduledTasks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_available_rounded, size: 46, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            const Text(
                              "No Scheduled Tasks Yet",
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF475569)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Ask MaxAssist to remind any patient at any time, or tap + Schedule above.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: _scheduledTasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final t = _scheduledTasks[idx];
                        final status = (t['status'] ?? 'pending').toString();
                        final isPending = status == 'pending';
                        final badgeBg = isPending
                            ? const Color(0xFFFEF3C7)
                            : (status == 'sent' ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9));
                        final badgeFg = isPending
                            ? const Color(0xFFB45309)
                            : (status == 'sent' ? const Color(0xFF15803D) : const Color(0xFF64748B));

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "${t['patient_name']} (+${t['patient_phone']})",
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeFg),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (t['message_text'] ?? '').toString(),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      (t['scheduled_display'] ?? t['scheduled_for_utc'] ?? '').toString(),
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (isPending && t['id'] != null)
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () async {
                                        final id = int.tryParse(t['id'].toString());
                                        if (id != null) {
                                          await BackendApiService.cancelDoctorScheduledTask(id);
                                          await _loadScheduledTasks();
                                        }
                                      },
                                      child: const Text(
                                        "Cancel",
                                        style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFECE5DD),
      drawer: _isDoctor ? _buildGeminiHistoryDrawer() : null,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: Custom Gemini-style Doctor Header or Patient Header
            _isDoctor ? _buildGeminiTopBar() : _buildPatientHeader(),

            // Meta 24-Hour Outreach Notice & Template Initialization for Doctors
            if (_isDoctor && !_showTasksMode) _buildDoctorOutreachBanner(),

            // Chat Message Feed, Scheduled Tasks View, or Gemini Hero Empty State
            Expanded(
              child: _isDoctor && _showTasksMode
                  ? _buildScheduledTasksView()
                  : (_messages.isEmpty
                      ? _buildGeminiEmptyState()
                      : _buildMessageList()),
            ),

            // Loading indicator
            if (_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          _isDoctor && _doctorSendViaWhatsApp
                              ? const Color(0xFF075E54)
                              : Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isDoctor && _doctorSendViaWhatsApp
                          ? (_showTasksMode
                              ? "Scheduling WhatsApp task..."
                              : "Dispatching to $_selectedPatientName's WhatsApp via Meta...")
                          : "Analyzing clinical telemetry...",
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

            // Gemini-style Chat / Task Mode Switcher for Doctors
            if (_isDoctor) _buildChatTaskToggle(),

            // Gemini-Style Bottom Composer
            _buildGeminiComposer(),
          ],
        ),
      ),
    );
  }
}
