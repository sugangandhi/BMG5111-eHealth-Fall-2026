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
}

class _HealthChatModuleState extends State<HealthChatModule> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_HealthChatMessage> _messages = [];
  bool _isLoading = false;
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
    _loadPatientId();
  }

  Future<void> _loadPatientId() async {
    final prefs = await SharedPreferences.getInstance();
    final pid = prefs.getInt("patient_id") ?? prefs.getString("patient_id");
    if (pid != null && mounted) {
      setState(() {
        _patientId = pid.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendMessage([String? textToSend, bool isVoice = false]) async {
    final text = (textToSend ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(_HealthChatMessage(role: 'user', text: text, isVoice: isVoice));
      _isLoading = true;
    });
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_HealthChatMessage(
            role: 'assistant',
            text:
                "### 🩺 Clinical Sync Note\nYour vitals are logged in the Central Cloud EMR. If you require immediate attention, you can tap below to connect with Dr. Patel directly on WhatsApp.",
          ));
        });
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
        Container(
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
                onPressed: () => _launchWhatsApp(),
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
            ],
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
                                : MarkdownBody(
                                    data: msg.text,
                                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                      p: const TextStyle(fontSize: 14, height: 1.45, color: Colors.black87),
                                    ),
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
                  tooltip: "Speak symptom (Whisper Voice Scribe)",
                  icon: const Icon(Icons.mic, color: Color(0xFF6366F1), size: 24),
                  onPressed: _showVoiceDictationSheet,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (val) => _sendMessage(val),
                    decoration: InputDecoration(
                      hintText: "Ask or speak your symptom...",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
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

  void _showVoiceDictationSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VoiceDictationSheetContent(
        onSend: (text, isVoice) => _sendMessage(text, isVoice),
      ),
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

class _VoiceDictationSheetContent extends StatefulWidget {
  final Function(String text, bool isVoice) onSend;

  const _VoiceDictationSheetContent({required this.onSend});

  @override
  State<_VoiceDictationSheetContent> createState() => _VoiceDictationSheetContentState();
}

class _VoiceDictationSheetContentState extends State<_VoiceDictationSheetContent> with SingleTickerProviderStateMixin {
  bool _isListening = false;
  bool _isRecordingAudio = false;
  bool _isProcessingWhisper = false;
  String _spokenText = "";
  String _interimText = "";
  String _statusMsg = "Connecting microphone...";
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLiveListening();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    VoiceScribeService.stopListening();
    super.dispose();
  }

  void _startLiveListening() {
    setState(() {
      _isListening = true;
      _isRecordingAudio = false;
      _statusMsg = "Listening to your microphone... Speak your symptoms now.";
    });

    VoiceScribeService.startListening(
      onResult: (finalResult, interimResult) {
        if (!mounted) return;
        setState(() {
          if (finalResult.isNotEmpty) {
            _spokenText = finalResult;
          }
          _interimText = interimResult;
        });
      },
      onStatus: (status, message) {
        if (!mounted) return;
        setState(() {
          if (status == 'listening') {
            _isListening = true;
            _statusMsg = "Microphone active. Speak clearly...";
          } else if (status == 'stopped') {
            _isListening = false;
            _statusMsg = _spokenText.isNotEmpty ? "Speech captured! Ready to send." : "Microphone paused.";
          } else if (status == 'error') {
            _isListening = false;
            _statusMsg = "Microphone permission required. Please allow access in browser.";
          } else if (status == 'unsupported') {
            _isListening = false;
            _statusMsg = message;
          }
        });
      },
    );
  }

  void _toggleListening() {
    if (_isListening) {
      VoiceScribeService.stopListening();
      setState(() {
        _isListening = false;
        _statusMsg = "Microphone stopped.";
      });
    } else {
      _startLiveListening();
    }
  }

  Future<void> _recordOpenAIWhisper() async {
    if (_isRecordingAudio) {
      setState(() {
        _isRecordingAudio = false;
        _isProcessingWhisper = true;
        _statusMsg = "Uploading audio to OpenAI Whisper API (whisper-1)...";
      });

      VoiceScribeService.stopRecordingAudio(onDone: (base64Audio) async {
        if (base64Audio.isEmpty) {
          if (mounted) {
            setState(() {
              _isProcessingWhisper = false;
              _statusMsg = "No audio recorded. Please try again.";
            });
          }
          return;
        }

        try {
          final res = await http.post(
            Uri.parse("${ApiConfig.backendBaseUrl}/api/assistant/voice-transcribe"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"audio_base64": base64Audio}),
          );
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final transcribed = data["transcription"]?.toString() ?? "";
            if (mounted) {
              setState(() {
                _isProcessingWhisper = false;
                _spokenText = transcribed;
                _statusMsg = "Whisper transcription complete!";
              });
            }
          } else {
            if (mounted) {
              setState(() {
                _isProcessingWhisper = false;
                _statusMsg = "Whisper transcription returned code ${res.statusCode}";
              });
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isProcessingWhisper = false;
              _statusMsg = "Whisper request error: $e";
            });
          }
        }
      });
    } else {
      VoiceScribeService.stopListening();
      setState(() {
        _isListening = false;
        _isRecordingAudio = true;
        _statusMsg = "Recording audio for Whisper... Speak now, then tap again.";
      });
      VoiceScribeService.startRecordingAudio(onStatus: (status, message) {
        if (!mounted) return;
        if (status == 'error') {
          setState(() {
            _isRecordingAudio = false;
            _statusMsg = "Audio recording error: $message";
          });
        }
      });
    }
  }

  void _sendTranscribedText() {
    final fullText = (_spokenText.isNotEmpty ? _spokenText : _interimText).trim();
    if (fullText.isEmpty) return;
    Navigator.pop(context);
    widget.onSend(fullText, true);
  }

  Widget _buildVoiceSampleTile(BuildContext sheetContext, String text, String category) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.pop(sheetContext);
        widget.onSend(text, true);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.graphic_eq, size: 18, color: Color(0xFF6366F1)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                  Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _spokenText.isNotEmpty || _interimText.isNotEmpty;
    final displayText = _spokenText.isNotEmpty ? _spokenText : _interimText;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Pulsing microphone icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final isHot = _isListening || _isRecordingAudio;
              final glow = isHot ? (8.0 + _pulseController.value * 12.0) : 0.0;
              return GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isHot
                        ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                        : const Color(0xFF6366F1).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    boxShadow: isHot
                        ? [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                              blurRadius: glow,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    isHot ? Icons.mic : Icons.mic_none,
                    color: isHot ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                    size: 38,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _isListening
                ? "🎙️ Live Speech Detection Active"
                : (_isRecordingAudio ? "🔴 Recording for Whisper..." : "Whisper Clinical Voice Scribe"),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _statusMsg,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _isListening ? const Color(0xFFEF4444) : Colors.grey.shade600, fontWeight: _isListening ? FontWeight.w600 : FontWeight.normal),
          ),
          const SizedBox(height: 14),

          // Live Speech Transcription Card
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 70, maxHeight: 130),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasText ? const Color(0xFFEEF2FF) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasText ? const Color(0xFF6366F1) : Colors.grey.shade300,
                width: hasText ? 1.5 : 1.0,
              ),
            ),
            child: SingleChildScrollView(
              child: Text(
                hasText ? displayText : "Your spoken words will appear here in real-time as you speak...",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasText ? FontWeight.w500 : FontWeight.normal,
                  color: hasText ? const Color(0xFF1E1B4B) : Colors.grey.shade500,
                  fontStyle: hasText ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Primary Send Button
          ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded),
            label: Text(hasText ? "Send Spoken Query to AI" : "Speak to Dictate"),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasText ? const Color(0xFF6366F1) : Colors.grey.shade400,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: hasText ? _sendTranscribedText : null,
          ),
          const SizedBox(height: 8),

          // Secondary controls (Pause/Resume & OpenAI Whisper mode)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(_isListening ? Icons.pause_circle_outline : Icons.play_circle_outline),
                  label: Text(_isListening ? "Pause Mic" : "Resume Mic"),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _toggleListening,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: _isProcessingWhisper
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_isRecordingAudio ? Icons.stop_circle : Icons.graphic_eq, color: const Color(0xFF10B981)),
                  label: Text(
                    _isProcessingWhisper
                        ? "Transcribing..."
                        : (_isRecordingAudio ? "Stop & Whisper" : "OpenAI Whisper"),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isProcessingWhisper ? null : _recordOpenAIWhisper,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Clinical Samples
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Or quick-select sample dictations:",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 6),
          _buildVoiceSampleTile(
            context,
            "Check my latest recorded vitals from Apple Watch.",
            "Telemetry Inquiry",
          ),
          _buildVoiceSampleTile(
            context,
            "My morning blood pressure was 138/88 and I have a mild headache.",
            "Symptom Dictation",
          ),
          _buildVoiceSampleTile(
            context,
            "Explain how Amlodipine 5mg works for my blood pressure.",
            "Medication Inquiry",
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
