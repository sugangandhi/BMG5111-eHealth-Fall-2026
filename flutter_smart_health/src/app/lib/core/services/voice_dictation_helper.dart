import 'package:flutter/material.dart';

import 'voice_scribe_service.dart';

/// Coordinates single-session voice recording, OpenAI Whisper transcription,
/// and live input-field updates without duplicated words across taps.
class VoiceDictationController {
  VoiceDictationController({
    required this.textController,
    required this.isMounted,
    required this.onListeningChanged,
    required this.onStatusMessage,
    this.onTranscribingChanged,
  });

  final TextEditingController textController;
  final bool Function() isMounted;
  final ValueChanged<bool> onListeningChanged;
  final ValueChanged<String> onStatusMessage;
  final ValueChanged<bool>? onTranscribingChanged;

  bool _listening = false;
  bool _transcribing = false;
  int _sessionId = 0;
  String _prefixBeforeListening = '';
  String _lastAppliedText = '';

  bool get isListening => _listening;
  bool get isTranscribing => _transcribing;

  void toggle() {
    if (_transcribing) return;
    if (_listening) {
      stop();
      return;
    }

    final sessionId = ++_sessionId;
    _prefixBeforeListening = textController.text;
    _lastAppliedText = textController.text;
    _setTranscribing(false);
    _setListening(true);

    VoiceScribeService.startListening(
      onResult: (finalResult, interimResult) {
        if (!isMounted() || sessionId != _sessionId) return;
        final recognized = _combineSegments(finalResult, interimResult);
        if (recognized.isEmpty) return;

        final prefix = _prefixBeforeListening.trim();
        final updated = prefix.isEmpty ? recognized : '$prefix $recognized';
        if (updated == _lastAppliedText && updated == textController.text) {
          return;
        }
        _lastAppliedText = updated;
        textController.value = TextEditingValue(
          text: updated,
          selection: TextSelection.collapsed(offset: updated.length),
        );
      },
      onStatus: (status, message) {
        if (!isMounted() || sessionId != _sessionId) return;
        if (status == 'listening' || status == 'recording') {
          _setTranscribing(false);
          _setListening(true);
        } else if (status == 'transcribing') {
          _setListening(false);
          _setTranscribing(true);
          onStatusMessage('Transcribing voice with OpenAI Whisper...');
        } else if (status == 'stopped') {
          _setListening(false);
          _setTranscribing(false);
        } else if (status == 'error' || status == 'unsupported') {
          _setListening(false);
          _setTranscribing(false);
          final detail = message.trim().isNotEmpty
              ? message.trim()
              : 'Please allow microphone access in app or browser settings.';
          onStatusMessage(detail);
        }
      },
    );
  }

  /// Combines finalized and interim speech strings without duplicating overlap.
  static String _combineSegments(String finalResult, String interimResult) {
    final finalClean = finalResult.trim();
    final interimClean = interimResult.trim();
    if (finalClean.isEmpty) return interimClean;
    if (interimClean.isEmpty) return finalClean;
    if (interimClean.toLowerCase().startsWith(finalClean.toLowerCase())) {
      return interimClean;
    }
    if (finalClean.toLowerCase().endsWith(interimClean.toLowerCase())) {
      return finalClean;
    }
    return '$finalClean $interimClean';
  }

  void stop() {
    VoiceScribeService.stopListening();
    _setListening(false);
  }

  /// Stops active recording and invalidates any in-flight session callbacks
  /// during widget teardown without triggering state callbacks.
  void dispose() {
    _sessionId++;
    final wasListening = _listening;
    _listening = false;
    _transcribing = false;
    if (wasListening) {
      VoiceScribeService.stopListening();
    }
  }

  void _setListening(bool value) {
    if (_listening == value) return;
    _listening = value;
    if (isMounted()) {
      onListeningChanged(value);
    }
  }

  void _setTranscribing(bool value) {
    if (_transcribing == value) return;
    _transcribing = value;
    if (isMounted()) {
      onTranscribingChanged?.call(value);
    }
  }
}

/// Shared microphone button displaying recording and OpenAI Whisper
/// transcribing states consistently across chat modules.
class VoiceDictationMicButton extends StatelessWidget {
  const VoiceDictationMicButton({
    super.key,
    required this.isListening,
    required this.isTranscribing,
    required this.onPressed,
    required this.idleIconColor,
    this.idleBgColor = Colors.transparent,
    required this.idleTooltip,
  });

  final bool isListening;
  final bool isTranscribing;
  final VoidCallback onPressed;
  final Color idleIconColor;
  final Color idleBgColor;
  final String idleTooltip;

  @override
  Widget build(BuildContext context) {
    final bgColor = isListening
        ? const Color(0xFFEF4444).withValues(alpha: 0.15)
        : (isTranscribing
            ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
            : idleBgColor);
    final tooltip = isTranscribing
        ? 'Transcribing with OpenAI Whisper...'
        : (isListening ? 'Recording audio... Tap to transcribe' : idleTooltip);

    return IconButton(
      tooltip: tooltip,
      onPressed: isTranscribing ? null : onPressed,
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: isTranscribing
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: idleIconColor,
                ),
              )
            : Icon(
                isListening ? Icons.stop_rounded : Icons.mic_none,
                color: isListening ? const Color(0xFFEF4444) : idleIconColor,
                size: 24,
              ),
      ),
    );
  }
}

/// Shared composer InputDecoration styling for voice recording and Whisper
/// transcription states across chat and messaging inputs.
InputDecoration buildVoiceComposerDecoration({
  required bool isListening,
  required bool isTranscribing,
  required String idleHint,
  required Color focusedIdleColor,
}) {
  final activeBorder = isListening
      ? const BorderSide(color: Color(0xFFEF4444), width: 1.5)
      : (isTranscribing
          ? const BorderSide(color: Color(0xFF3B82F6), width: 1.5)
          : BorderSide.none);
  final focusedBorder = isListening
      ? const BorderSide(color: Color(0xFFEF4444), width: 2.0)
      : (isTranscribing
          ? const BorderSide(color: Color(0xFF3B82F6), width: 2.0)
          : BorderSide(color: focusedIdleColor, width: 1.5));

  return InputDecoration(
    hintText: isTranscribing
        ? 'Transcribing with OpenAI Whisper...'
        : (isListening ? '🔴 Recording... Tap mic when done' : idleHint),
    hintStyle: TextStyle(
      color: isListening
          ? const Color(0xFFEF4444)
          : (isTranscribing ? const Color(0xFF2563EB) : Colors.grey.shade500),
      fontWeight:
          (isListening || isTranscribing) ? FontWeight.w500 : FontWeight.normal,
    ),
    filled: true,
    fillColor: isListening
        ? const Color(0xFFFEF2F2)
        : (isTranscribing ? const Color(0xFFEFF6FF) : Colors.grey.shade100),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: activeBorder,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: activeBorder,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: focusedBorder,
    ),
  );
}
