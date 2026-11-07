import 'dart:async';
import 'dart:convert';

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
        voiceClientFactory: (_, _) => client,
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
        voiceClientFactory: (_, _) => client,
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
        voiceClientFactory: (_, _) {
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
  test(
    'text tool result uses real app result and dedupes concurrent call IDs',
    () async {
      final controller = CompanionController(agentId: '');
      controller.updateContext({
        'profile': {'id': 'noor'},
      });
      final completed = Completer<Map<String, Object?>>();
      var calls = 0;
      controller.onToolCall = (name, parameters) {
        calls++;
        expect(name, 'update_scenario');
        expect(parameters['weeklySavingPence'], 1000);
        controller.updateContext({
          'profile': {'id': 'noor'},
          'scenario': {'weeklySavingPence': 1000},
        });
        return completed.future;
      };
      final frame = <String, Object?>{
        'type': 'client_tool_call',
        'client_tool_call': {
          'tool_call_id': 'same-call',
          'tool_name': 'update_scenario',
          'parameters': {'weeklySavingPence': 1000},
        },
      };
      final first = controller.handleClientToolCall(frame);
      final duplicate = controller.handleClientToolCall(frame);
      expect(calls, 1);
      final result = <String, Object?>{
        'ok': true,
        'summary': 'Weekly spending reduced by £10 in this scenario.',
        'artifact': {'type': 'forecast', 'lowestBalancePence': -17000},
      };
      completed.complete(result);
      final reply = await first;
      expect(await duplicate, reply);
      expect(reply['type'], 'client_tool_result');
      expect(reply['tool_call_id'], 'same-call');
      expect(reply['is_error'], isFalse);
      expect(jsonDecode(reply['result'] as String), result);
      expect(controller.messages.single.actionName, 'update_scenario');
      expect(controller.messages.single.actionResult, result);
      expect(controller.messages.single.text, result['summary']);
      controller.dispose();
    },
  );

  test(
    'unknown, malformed and unavailable text tools fail without mutation',
    () async {
      final controller = CompanionController(agentId: '');
      var calls = 0;
      controller.onToolCall = (_, _) async {
        calls++;
        return {'ok': true};
      };
      for (final entry in <String, Object?>{
        'unknown': {'tool_name': 'send_money', 'parameters': {}},
        'malformed': {'tool_name': 'update_scenario', 'parameters': []},
      }.entries) {
        final call = Map<String, Object?>.from(entry.value as Map)
          ..['tool_call_id'] = entry.key;
        final reply = await controller.handleClientToolCall({
          'client_tool_call': call,
        });
        expect(reply['is_error'], isTrue);
        expect((jsonDecode(reply['result'] as String) as Map)['ok'], isFalse);
      }
      expect(calls, 0);
      controller.onToolCall = null;
      final missing = await controller.handleClientToolCall({
        'client_tool_call': {
          'tool_call_id': 'unavailable',
          'tool_name': 'build_recovery_plan',
          'parameters': {},
        },
      });
      expect(missing['is_error'], isTrue);
      expect(controller.messages, isEmpty);
      controller.dispose();
    },
  );

  testWidgets(
    'official voice client receives all action tools and preserves session on context change',
    (tester) async {
      final client = _FakeVoiceClient(isReady: true);
      Map<String, eleven.ClientTool>? registry;
      final controller = CompanionController(
        voiceClientFactory: (_, tools) {
          registry = tools;
          return client;
        },
        requestMicrophonePermission: () async => true,
      );
      controller.updateContext({
        'profile': {'id': 'noor'},
      });
      controller.onToolCall = (name, parameters) async {
        controller.updateContext({
          'profile': {'id': 'noor'},
          'goal': {'targetPence': parameters['targetPence']},
        });
        return {
          'ok': true,
          'summary': 'Your £500 emergency buffer is ready.',
          'artifact': {'type': 'goal', 'targetPence': 50000},
        };
      };
      await controller.startVoice();
      expect(registry!.keys.toSet(), {
        'update_scenario',
        'build_recovery_plan',
        'set_emergency_goal',
        'compare_history',
      });
      final result = await registry!['set_emergency_goal']!.execute({
        'targetPence': 50000,
      });
      expect(result!.success, isTrue);
      expect((result.data as Map)['artifact']['targetPence'], 50000);
      expect(controller.isVoiceActive, isTrue);
      expect(controller.messages.single.actionName, 'set_emergency_goal');
      controller.onToolCall = null;
      final unavailable = await registry!['build_recovery_plan']!.execute({});
      expect(unavailable!.success, isFalse);
      expect((jsonDecode(unavailable.error!) as Map)['reason'], 'unavailable');
      controller.dispose();
      await tester.pump();
    },
  );

  test(
    'read-only history action accepts an omitted empty parameter object',
    () async {
      final controller = CompanionController(agentId: '');
      controller.onToolCall = (name, parameters) async {
        expect(name, 'compare_history');
        expect(parameters, isEmpty);
        return {
          'ok': true,
          'summary':
              'Your latest period ended £20 above its reconstructed plan.',
          'artifact': {'type': 'history_comparison'},
        };
      };
      final reply = await controller.handleClientToolCall({
        'client_tool_call': {
          'tool_call_id': 'history-1',
          'tool_name': 'compare_history',
        },
      });
      expect(reply['is_error'], isFalse);
      expect(controller.messages.single.actionResult!['artifact'], {
        'type': 'history_comparison',
      });
      controller.dispose();
    },
  );
  testWidgets(
    'slow tool pauses the text reply timer and gets a fresh deadline after completion',
    (tester) async {
      final client = _FakeVoiceClient(isReady: true);
      final controller = CompanionController(
        voiceClientFactory: (_, _) => client,
        requestMicrophonePermission: () async => true,
      );
      final completed = Completer<Map<String, Object?>>();
      controller.onToolCall = (_, _) => completed.future;
      await controller.startVoice();
      await controller.sendText('Make a recovery plan for me');
      final action = controller.handleClientToolCall({
        'client_tool_call': {
          'tool_call_id': 'slow-plan',
          'tool_name': 'build_recovery_plan',
          'parameters': {},
        },
      });
      await tester.pump(const Duration(seconds: 60));
      expect(controller.messages.any((message) => message.isFallback), isFalse);
      expect(controller.error, isNull);
      expect(controller.isVoiceActive, isTrue);
      completed.complete({
        'ok': true,
        'summary': 'Your recovery plan is ready.',
      });
      await tester.pump();
      await action;
      await tester.pump(const Duration(seconds: 34));
      expect(controller.messages.any((message) => message.isFallback), isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(
        controller.messages.where((message) => message.isFallback).length,
        1,
      );
      controller.dispose();
      await tester.pump();
    },
  );

  testWidgets('a spoken tool call does not create a text reply deadline', (
    tester,
  ) async {
    final controller = CompanionController(agentId: '');
    controller.onToolCall = (_, _) async => {
      'ok': true,
      'summary': 'Your comparison is ready.',
    };
    await controller.voiceClientTools['compare_history']!.execute({});
    await tester.pump(const Duration(seconds: 60));
    expect(controller.messages.any((message) => message.isFallback), isFalse);
    expect(controller.error, isNull);
    controller.dispose();
    await tester.pump();
  });
}

class _FakeVoiceClient extends eleven.ConversationClient {
  _FakeVoiceClient({this.failure, this.isReady = false});
  final Object? failure;
  final bool isReady;
  int disposeCalls = 0;

  @override
  eleven.ConversationStatus get status => isReady
      ? eleven.ConversationStatus.connected
      : eleven.ConversationStatus.connecting;

  @override
  Future<void> startSession({
    String? agentId,
    String? conversationToken,
    String? userId,
    String? environment,
    eleven.ConversationOverrides? overrides,
    Map<String, dynamic>? customLlmExtraBody,
    Map<String, dynamic>? dynamicVariables,
  }) => isReady
      ? Future.value()
      : failure == null
      ? Completer<void>().future
      : Future.error(failure!);

  @override
  Future<void> endSession() =>
      isReady ? Future.value() : Completer<void>().future;

  @override
  void sendContextualUpdate(String text) {}

  @override
  void sendUserMessage(String text) {}

  @override
  void dispose() {
    disposeCalls++;
    super.dispose();
  }
}
