import 'dart:async';

import 'package:elevenlabs_agents/elevenlabs_agents.dart' as eleven;
import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/companion.dart';

void main() {
  final context = <String, Object?>{
    'profile': {'id': 'maya', 'name': 'Maya'},
    'forecast': {
      'shortfallPence': 18000,
      'shortfallDate': '2026-11-12',
      'causes': ['Rent falls before invoice income'],
    },
    'goal': {'savedPence': 6500, 'targetPence': 50000},
  };

  test(
    'calculated fallback uses supplied forecast without inventing figures',
    () {
      final reply = calculatedCompanionReply('Why will I be short?', context);
      expect(reply, contains('£180'));
      expect(reply, contains('2026-11-12'));
      expect(reply, contains('Rent falls before invoice income'));
    },
  );

  test('fallback recovery action never claims submission or eligibility', () {
    final reply = calculatedCompanionReply('What is my next step?', context);
    expect(reply, contains('nothing is sent'));
    expect(reply, contains('not guaranteed'));
  });

  test('savings and credit guidance uses meaningful, affordable actions', () {
    expect(
      calculatedCompanionReply('My savings goal?', context),
      contains('£65 towards £500'),
    );
    expect(
      calculatedCompanionReply('Build credit?', context),
      contains('do not need to borrow'),
    );
  });

  test('no-config text is clearly identified as calculated fallback', () async {
    final controller = CompanionController(agentId: '');
    controller.updateContext(context);
    await controller.sendText('Why will I be short?');
    expect(controller.messages.length, 2);
    expect(controller.messages.last.isFallback, isTrue);
    expect(controller.modeLabel, 'Calculated demo guidance');
    expect(controller.messages.last.text, contains('£180'));
    controller.dispose();
  });
  test(
    'model receives exact GBP values while the ledger retains integer pence',
    () {
      final formatted = companionContextForModel(context) as Map;
      expect((formatted['forecast'] as Map)['shortfallGBP'], '£180');
      expect(
        (formatted['forecast'] as Map).containsKey('shortfallPence'),
        isFalse,
      );
      expect((context['forecast'] as Map)['shortfallPence'], 18000);
    },
  );

  test('flat app context and profile changes cannot leak another persona transcript', () async {
    final controller = CompanionController(agentId: '');
    controller.updateContext({
      'profile': {'id': 'maya', 'name': 'Maya'},
      'forecast': <String, Object?>{},
      'shortfallPence': 18000,
      'shortfallDate': '2026-11-12T00:00:00.000',
      'causes': ['Rent before invoice'],
    });
    await controller.sendText('Why am I short?');
    expect(controller.messages.last.text, contains('£180'));
    controller.updateContext({
      'profile': {'id': 'daniel', 'name': 'Daniel'},
      'forecast': <String, Object?>{},
      'shortfallPence': 0,
    });
    expect(controller.messages, isEmpty);
    controller.dispose();
  });

  test('first negative day is distinct from a later maximum gap', () {
    final reply = calculatedCompanionReply('Why am I short?', {
      'profile': {'name': 'Maya'},
      'shortfallPence': 10000,
      'maximumShortfallPence': 18000,
      'shortfallDate': '2026-11-12',
      'lowestDate': '2026-11-14',
    });
    expect(reply, contains('first falls below zero on 2026-11-12'));
    expect(reply, contains('largest projected gap is £180 on 2026-11-14'));
  });

  test(
    'microphone denial explains settings and preserves text alternative',
    () {
      final message = companionVoiceErrorMessage(
        'NotAllowedError: Permission denied',
      );
      expect(message, contains('Settings'));
      expect(message, contains('continue by text'));
      expect(
        companionVoiceErrorMessage(TimeoutException('')),
        contains('too long'),
      );
    },
  );
  test('actual phone DNS failure explains network and VPN for both voice and text', () {
    const failure =
        'ClientException with SocketException: Failed host lookup: api.elevenlabs.io (OS Error: nodename nor servname provided, errno = 8)';
    for (final message in [
      companionVoiceErrorMessage(failure),
      companionTextErrorMessage(failure),
    ]) {
      expect(message, contains('network'));
      expect(message, contains('ElevenLabs'));
      expect(message, contains('VPN DNS'));
      expect(message, isNot(contains('Microphone')));
      expect(message, isNot(contains('continue by text')));
    }
    expect(
      companionTextErrorMessage(failure),
      contains('calculated demo figures'),
    );
  });

  testWidgets(
    'voice failure is visible even when native disconnect never completes',
    (tester) async {
      final client = _FakeVoiceClient(
        failure: StateError('ICE connection failed token=secret'),
      );
      final controller = CompanionController(
        voiceClientFactory: (_) => client,
        requestMicrophonePermission: () async => true,
      );
      final startup = controller.startVoice();
      await tester.pump();
      expect(controller.phase, CompanionPhase.error);
      expect(controller.lastVoiceDiagnostic, contains('voice transport'));
      expect(controller.lastVoiceDiagnostic, isNot(contains('secret')));
      await tester.pump(const Duration(seconds: 3));
      await startup;
      expect(controller.isVoiceActive, isFalse);
      expect(client.disposeCalls, 1);
      controller.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'voice startup timeout returns despite a stuck native disconnect',
    (tester) async {
      final client = _FakeVoiceClient();
      final controller = CompanionController(
        voiceClientFactory: (_) => client,
        requestMicrophonePermission: () async => true,
      );
      final startup = controller.startVoice();
      await tester.pump();
      expect(controller.phase, CompanionPhase.connecting);
      await tester.pump(const Duration(seconds: 26));
      expect(controller.phase, CompanionPhase.error);
      expect(controller.error, contains('too long'));
      await tester.pump(const Duration(seconds: 3));
      await startup;
      expect(controller.isVoiceActive, isFalse);
      expect(client.disposeCalls, 1);
      controller.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'permission request also has a deadline and does not start voice',
    (tester) async {
      var clientsCreated = 0;
      final controller = CompanionController(
        voiceClientFactory: (_) {
          clientsCreated++;
          return _FakeVoiceClient();
        },
        requestMicrophonePermission: () => Completer<bool>().future,
      );
      final startup = controller.startVoice();
      await tester.pump();
      await tester.pump(const Duration(seconds: 21));
      await startup;
      expect(controller.phase, CompanionPhase.error);
      expect(clientsCreated, 0);
      expect(controller.lastVoiceDiagnostic, contains('microphone permission'));
      controller.dispose();
      await tester.pump();
    },
  );
}

class _FakeVoiceClient extends eleven.ConversationClient {
  _FakeVoiceClient({this.failure});
  final Object? failure;
  int disposeCalls = 0;

  @override
  eleven.ConversationStatus get status => eleven.ConversationStatus.connecting;

  @override
  Future<void> startSession({
    String? agentId,
    String? conversationToken,
    String? userId,
    String? environment,
    eleven.ConversationOverrides? overrides,
    Map<String, dynamic>? customLlmExtraBody,
    Map<String, dynamic>? dynamicVariables,
  }) => failure == null ? Completer<void>().future : Future.error(failure!);

  @override
  Future<void> endSession() => Completer<void>().future;

  @override
  void dispose() {
    disposeCalls++;
    super.dispose();
  }
}
