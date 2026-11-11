import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_health_app/core/services/voice_dictation_helper.dart';
import 'package:smart_health_app/core/services/voice_scribe_service_io.dart';
import 'package:smart_health_app/core/services/voice_transcription_client.dart';

Future<void> _simulateNativeCallback(String method, Map<String, dynamic> args) async {
  const codec = StandardMethodCodec();
  final data = codec.encodeMethodCall(MethodCall(method, args));
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'com.example.smart_health_app/voice_scribe',
    data,
    (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.smart_health_app/voice_scribe');
  final recordedMethodCalls = <String>[];

  setUp(() {
    recordedMethodCalls.clear();
    VoiceScribeService.setTranscriptionClientForTesting(
      VoiceTranscriptionClient(
        client: MockClient((_) async => http.Response('{"transcription":""}', 200)),
        baseUrlOverride: 'https://example.test',
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      recordedMethodCalls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('VoiceTranscriptionClient', () {
    test('posts audio_base64 and filename and returns trimmed transcription', () async {
      late Map<String, dynamic> sentBody;
      final client = VoiceTranscriptionClient(
        baseUrlOverride: 'https://api.clinic.test',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://api.clinic.test/api/assistant/voice-transcribe',
          );
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'transcription': '  My blood pressure is 120 over 80  '}),
            200,
          );
        }),
      );

      final transcript = await client.transcribeBase64Audio(
        base64Audio: 'AAAA',
        filename: 'voice_note.m4a',
      );

      expect(sentBody['audio_base64'], 'AAAA');
      expect(sentBody['filename'], 'voice_note.m4a');
      expect(sentBody['transcribe_only'], isTrue);
      expect(transcript, 'My blood pressure is 120 over 80');
    });

    test('skips request on empty audio and throws StateError on HTTP failure', () async {
      var calls = 0;
      final client = VoiceTranscriptionClient(
        baseUrlOverride: 'https://api.clinic.test',
        client: MockClient((_) async {
          calls++;
          return http.Response('Server Error', 500);
        }),
      );

      expect(await client.transcribeBase64Audio(base64Audio: '   '), isEmpty);
      expect(calls, 0);

      await expectLater(
        () => client.transcribeBase64Audio(base64Audio: 'QUJD'),
        throwsStateError,
      );
      expect(calls, 1);
    });
  });

  group('VoiceScribeService (IO MethodChannel)', () {
    test('streams interim/final native results and stops cleanly', () async {
      final results = <List<String>>[];
      final statuses = <List<String>>[];

      VoiceScribeService.startListening(
        onResult: (finalText, interimText) => results.add([finalText, interimText]),
        onStatus: (status, message) => statuses.add([status, message]),
      );

      await pumpEventQueue();
      expect(recordedMethodCalls, contains('startListening'));

      await _simulateNativeCallback('onSpeechStatus', {
        'status': 'listening',
        'message': '',
      });
      await _simulateNativeCallback('onSpeechResult', {
        'finalResult': '',
        'interimResult': 'heart rate',
      });
      await _simulateNativeCallback('onSpeechResult', {
        'finalResult': 'heart rate is 72',
        'interimResult': '',
      });
      await _simulateNativeCallback('onSpeechStatus', {
        'status': 'stopped',
        'message': '',
      });

      expect(statuses, [
        ['listening', ''],
        ['stopped', ''],
      ]);
      expect(results, [
        ['', 'heart rate'],
        ['heart rate is 72', ''],
      ]);

      VoiceScribeService.stopListening();
      await pumpEventQueue();
      expect(recordedMethodCalls, contains('stopListening'));
    });

    test('transcribes captured m4a fallback audio via Whisper client', () async {
      VoiceScribeService.setTranscriptionClientForTesting(
        VoiceTranscriptionClient(
          baseUrlOverride: 'https://api.clinic.test',
          client: MockClient((request) async {
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            expect(payload['filename'], 'voice_note.m4a');
            return http.Response(
              jsonEncode({'transcription': 'Check my afternoon vitals'}),
              200,
            );
          }),
        ),
      );

      final results = <String>[];
      final statuses = <String>[];

      VoiceScribeService.startListening(
        onResult: (finalText, interimText) => results.add(finalText),
        onStatus: (status, _) => statuses.add(status),
      );
      await pumpEventQueue();

      await _simulateNativeCallback('onSpeechStatus', {
        'status': 'transcribing',
        'message': '',
      });
      await _simulateNativeCallback('onAudioCaptured', {
        'base64': 'QUJDRA==',
        'filename': 'voice_note.m4a',
      });
      await pumpEventQueue();

      expect(results, ['Check my afternoon vitals']);
      expect(statuses, ['transcribing', 'stopped']);
    });
  });

  group('VoiceDictationController', () {
    test('merges prefix without duplication, locks during transcribing, and ignores stale callbacks', () async {
      final textController = TextEditingController(text: 'Notes:');
      addTearDown(textController.dispose);

      var mounted = true;
      final listeningStates = <bool>[];
      final transcribingStates = <bool>[];
      final statusMessages = <String>[];

      final controller = VoiceDictationController(
        textController: textController,
        isMounted: () => mounted,
        onListeningChanged: listeningStates.add,
        onTranscribingChanged: transcribingStates.add,
        onStatusMessage: statusMessages.add,
      );

      controller.toggle();
      await pumpEventQueue();
      expect(controller.isListening, isTrue);
      expect(listeningStates, [true]);

      // Overlapping final + interim or duplicate repeats must not repeat words.
      await _simulateNativeCallback('onSpeechResult', {
        'finalResult': 'blood pressure',
        'interimResult': 'blood pressure 118 over 76',
      });
      await _simulateNativeCallback('onSpeechResult', {
        'finalResult': 'blood pressure 118 over 76',
        'interimResult': '',
      });

      expect(textController.text, 'Notes: blood pressure 118 over 76');
      expect(
        textController.selection,
        TextSelection.collapsed(offset: textController.text.length),
      );

      await _simulateNativeCallback('onSpeechStatus', {
        'status': 'transcribing',
        'message': '',
      });
      expect(controller.isListening, isFalse);
      expect(controller.isTranscribing, isTrue);
      expect(transcribingStates, [true]);
      expect(statusMessages, ['Transcribing voice with OpenAI Whisper...']);

      // Tapping toggle while transcribing must not start a parallel session.
      final callsWhileBusy = recordedMethodCalls.length;
      controller.toggle();
      await pumpEventQueue();
      expect(recordedMethodCalls.length, callsWhileBusy);

      await _simulateNativeCallback('onSpeechStatus', {
        'status': 'unsupported',
        'message': '',
      });
      expect(controller.isTranscribing, isFalse);
      expect(
        statusMessages.last,
        isNot(contains('supported in Google Chrome or Edge')),
      );
      expect(
        statusMessages.last,
        'Please allow microphone access in app or browser settings.',
      );

      controller.toggle();
      await pumpEventQueue();
      expect(controller.isListening, isTrue);

      final countBeforeDispose = listeningStates.length;
      controller.dispose();
      await pumpEventQueue();
      expect(controller.isListening, isFalse);
      expect(listeningStates.length, countBeforeDispose);
      expect(recordedMethodCalls, contains('stopListening'));

      // Stale callbacks after dispose must be ignored.
      await _simulateNativeCallback('onSpeechResult', {
        'finalResult': 'should not append',
        'interimResult': '',
      });
      expect(textController.text, 'Notes: blood pressure 118 over 76');

      mounted = false;
    });

    testWidgets('VoiceDictationMicButton renders idle, recording, and Whisper busy states', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                VoiceDictationMicButton(
                  isListening: false,
                  isTranscribing: false,
                  onPressed: () => taps++,
                  idleIconColor: Colors.indigo,
                  idleTooltip: 'Record voice',
                ),
                VoiceDictationMicButton(
                  isListening: true,
                  isTranscribing: false,
                  onPressed: () => taps++,
                  idleIconColor: Colors.indigo,
                  idleTooltip: 'Record voice',
                ),
                VoiceDictationMicButton(
                  isListening: false,
                  isTranscribing: true,
                  onPressed: () => taps++,
                  idleIconColor: Colors.indigo,
                  idleTooltip: 'Record voice',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.tap(find.byType(CircularProgressIndicator));
      expect(taps, 2);
    });
  });
}
