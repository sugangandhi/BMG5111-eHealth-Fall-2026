import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/api_config.dart';
import '../../../core/services/voice_scribe_service.dart';
import '../../../data/models/assistant_models.dart';
import '../../../services/backend_api_service.dart';
import 'whatsapp_inbox_module.dart';

class HealthChatModule extends StatefulWidget {
  const HealthChatModule({super.key});

  @override
  State<HealthChatModule> createState() => _HealthChatModuleState();
}

class _HealthChatMessage {
  final String role; // 'user' | 'assistant'
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
  String _speechBufferBeforeListening = "";
  String _patientId = "1";

  static const List<String> _suggestedPrompts = [
    "What are my recorded vitals?",
    "How is my heart rate today?",
    "Explain my blood pressure trend",
    "How did I sleep last night?",
  ];

  @override
  void initState() {
    super.initState();
    _loadPatientAndHistory();
  }

  Future<void> _loadPatientAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final pid = prefs.getInt("patient_id") ?? prefs.getString("patient_id");
    if (pid != null && mounted) {
      setState(() {
        _patientId = pid.toString();
      });
    }

    // 1. First load from local SharedPreferences cache for instantaneous display
    final cached = prefs.getString("ai_chat_cache_$_patientId");
    if (cached != null && cached.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(cached);
        final cachedList = decoded
            .map((m) => _HealthChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();
        if (mounted && cachedList.isNotEmpty) {
          setState(() {
            _messages.clear();
            _messages.addAll(cachedList);
          });
          _scrollToBottom();
        }
      } catch (e) {
        debugPrint("[HealthChat] Cache decode error: $e");
      }
    }

    // 2. Sync from backend history endpoint
    try {
      final backendHistory = await BackendApiService.getAssistantHistory(_patientId);
      if (backendHistory.isNotEmpty && mounted) {
        final serverMessages = backendHistory
            .map((m) => _HealthChatMessage(
                  role: m['role']?.toString() ?? 'user',
                  text: m['text']?.toString() ?? '',
                  isVoice: m['isVoice'] == true,
                  timestamp: m['timestamp'] != null
                      ? DateTime.tryParse(m['timestamp'].toString())
                      : null,
                ))
            .toList();

        setState(() {
          _messages.clear();
          _messages.addAll(serverMessages);
        });
        _persistMessagesLocally();
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("[HealthChat] Backend history sync error: $e");
    }
  }

  Future<void> _persistMessagesLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _messages.map((m) => m.toJson()).toList();
      await prefs.setString("ai_chat_cache_$_patientId", jsonEncode(list));
    } catch (e) {
      debugPrint("[HealthChat] Error saving cache: $e");
    }
  }

  Future<void> _clearChatHistory() async {
    setState(() {
      _messages.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("ai_chat_cache_$_patientId");
    try {
      await BackendApiService.clearAssistantHistory(_patientId);
    } catch (e) {
      debugPrint("[HealthChat] Error clearing backend history: $e");
    }
  }

  @override
  void dispose() {
    VoiceScribeService.stopListening();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openInternalWhatsApp() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: SafeArea(
            child: WhatsAppInboxModule(),
          ),
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp([String? customMessage]) async {
    final defaultMsg = customMessage ??
        "Hi Doctor, this is patient #$_patientId. I have a question about my recent vitals recorded on Apple Health.";
    final url = Uri.parse(
      "https://wa.me/16132616383?text=${Uri.encodeComponent(defaultMsg)}",
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not launch WhatsApp: $e")),
        );
      }
    }
  }

  void _toggleListening() {
    if (_isListening) {
      VoiceScribeService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    _speechBufferBeforeListening = _controller.text;
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
            _controller.text = updated;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
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
                    : "Microphone note: $message. Please make sure microphone permission is granted.",
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );
  }

  Future<void> _sendMessage([String? textToSend, bool isVoice = false]) async {
    if (_isListening) {
      VoiceScribeService.stopListening();
      setState(() => _isListening = false);
    }
    final text = (textToSend ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top WhatsApp Quick Connect Banner
        InkWell(
          onTap: _openInternalWhatsApp,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              border: Border(bottom: BorderSide(color: Colors.green.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Need doctor advice? Chat with Clinic Care Team on WhatsApp",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                  ),
                ),
                ElevatedButton(
                  onPressed: _openInternalWhatsApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(60, 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("WhatsApp", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                if (_messages.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: "Clear Chat History",
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF166534)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
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
                    },
                  ),
                ],
              ],
            ),
          ),
        ),

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
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.82,
                        ),
                        decoration: BoxDecoration(
                          color: isUser ? Theme.of(context).primaryColor : Colors.white,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                            bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
                          ),
                          border: Border.all(
                            color: isUser ? Theme.of(context).primaryColor : Colors.grey.shade300,
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
                                  isUser ? (msg.isVoice ? Icons.mic : Icons.person) : Icons.smart_toy,
                                  size: 14,
                                  color: isUser ? Colors.white70 : Colors.blue.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isUser ? (msg.isVoice ? "You (Voice Scribe)" : "You") : "PrimeCare AI",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isUser ? Colors.white70 : Colors.blue.shade700,
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
                            isUser
                                ? Text(
                                    msg.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      height: 1.4,
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
                    valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Analyzing clinical database...",
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
            child: Row(
              children: [
                IconButton(
                  tooltip: _isListening ? "Listening to your voice... Tap to finish" : "Record voice (Tap to speak)",
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                      size: 24,
                    ),
                  ),
                  onPressed: _toggleListening,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (val) => _sendMessage(val),
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? "🔴 Listening to your voice... Speak now"
                          : "Ask or speak your symptom...",
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
                            : BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isLoading ? null : () => _sendMessage(),
                  ),
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
                    color: Theme.of(context).primaryColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 48,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Ask about your wellness data",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "Real-time clinical AI assistant connected to your Apple Watch telemetry, appointments, and care team.",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _suggestedPrompts.map((prompt) {
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
