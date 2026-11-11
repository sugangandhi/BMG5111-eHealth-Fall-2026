import 'package:flutter/material.dart';

import 'voice_scribe_service.dart';

/// Coordinates voice dictation toggling, live transcript merging, and status
/// messaging for chat and messaging text inputs.
class VoiceDictationController {
  VoiceDictationController({
    required this.textController,
    required this.isMounted,
    required this.onListeningChanged,
    required this.onStatusMessage,
  });

  final TextEditingController textController;
  final bool Function() isMounted;
  final ValueChanged<bool> onListeningChanged;
  final ValueChanged<String> onStatusMessage;

  bool _listening = false;
  String _prefixBeforeListening = '';

  bool get isListening => _listening;

  void toggle() {
    if (_listening) {
      stop();
      return;
    }

    _prefixBeforeListening = textController.text;
    _setListening(true);

    VoiceScribeService.startListening(
      onResult: (finalResult, interimResult) {
        if (!isMounted()) return;
        final recognized =
            (finalResult.isNotEmpty ? finalResult : interimResult).trim();
        if (recognized.isEmpty) return;

        final prefix = _prefixBeforeListening.trim();
        final updated = prefix.isEmpty ? recognized : '$prefix $recognized';
        textController.value = TextEditingValue(
          text: updated,
          selection: TextSelection.collapsed(offset: updated.length),
        );
      },
      onStatus: (status, message) {
        if (!isMounted()) return;
        if (status == 'listening' || status == 'recording') {
          _setListening(true);
        } else if (status == 'transcribing') {
          _setListening(false);
          onStatusMessage('Transcribing voice note...');
        } else if (status == 'stopped') {
          _setListening(false);
        } else if (status == 'error' || status == 'unsupported') {
          _setListening(false);
          final detail = message.trim().isNotEmpty
              ? message.trim()
              : 'Please allow microphone access in app or browser settings.';
          onStatusMessage(detail);
        }
      },
    );
  }

  void stop() {
    VoiceScribeService.stopListening();
    _setListening(false);
  }

  /// Stops active dictation cleanly during widget teardown without triggering
  /// state callbacks.
  void dispose() {
    if (_listening) {
      _listening = false;
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
}
