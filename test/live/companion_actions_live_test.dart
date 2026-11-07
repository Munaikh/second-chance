import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/app_state.dart';
import 'package:second_chance/core/companion.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Explicit live integration check; excluded from the normal offline test suite.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Live Cloudy performs the four app actions using the real app state',
    () async {
      final oldOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      final companion = CompanionController();
      final state = AppState(
        await SharedPreferences.getInstance(),
        companion: companion,
      );
      final evidence = <String, Object?>{
        'checkedAt': DateTime.now().toUtc().toIso8601String(),
        'agentId': companion.agentId,
        'model': 'gemini-3.8-flash',
        'synthetic': true,
        'realAppState': true,
        'realN8n': true,
        'actions': <Object?>[],
      };
      try {
        Future<Map<String, Object?>> ask(String text, String action) async {
          final before = companion.messages.length;
          await companion.sendText(text);
          final deadline = DateTime.now().add(const Duration(seconds: 75));
          while (DateTime.now().isBefore(deadline)) {
            final later = companion.messages.skip(before).toList();
            final cards = later.where((m) => m.actionName == action).toList();
            final replies = later
                .where(
                  (m) =>
                      m.role == 'assistant' &&
                      m.actionName == null &&
                      !m.isFallback,
                )
                .toList();
            if (cards.isNotEmpty &&
                replies.isNotEmpty &&
                companion.phase == CompanionPhase.idle) {
              final result = cards.last.actionResult!;
              (evidence['actions'] as List).add({
                'request': text,
                'action': action,
                'reply': replies.last.text,
                'result': result,
              });
              return result;
            }
            if (later.any((m) => m.isFallback)) {
              fail('Unexpected calculated fallback: ${companion.error}');
            }
            await Future<void>.delayed(const Duration(milliseconds: 150));
          }
          fail(
            'Cloudy did not complete $action. Replies: ${companion.messages.skip(before).map((m) => m.text).join(' | ')}',
          );
        }

        await ask(
          'Please calculate what an extra £150 car repair bill would do to my forecast, using the demo date.',
          'update_scenario',
        );
        expect(state.scenario.unexpectedExpensePence, 15000);
        expect(state.forecast.shortfallPence, 33000);
        await ask(
          'Please create a recovery plan and an editable support request for this unexpected bill.',
          'build_recovery_plan',
        );
        expect(state.recovery, isNotNull);
        expect(state.recovery!.executionId, isNotEmpty);
        expect(state.draftBody, contains('330'));
        await ask(
          'Please create a savings goal called Road trip buffer with a target of £500.',
          'set_emergency_goal',
        );
        expect(state.goal!.title, 'Road trip buffer');
        expect(state.goal!.targetPence, 50000);
        expect(state.goal!.savedPence, 3500);
        await ask(
          'Please compare my historical expected and actual balances and tell me the difference.',
          'compare_history',
        );
        evidence['conversationId'] = companion.conversationId;
        evidence['passed'] = true;
        await File('integrations/elevenlabs/app-actions-verification.json')
            .writeAsString(
              '${const JsonEncoder.withIndent('  ').convert(evidence)}\n',
            );
      } finally {
        await companion.endSession();
        state.dispose();
        HttpOverrides.global = oldOverrides;
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: !const bool.fromEnvironment('RUN_LIVE_AGENT_TESTS'),
  );
}
