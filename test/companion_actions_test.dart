import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_chance/core/app_state.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/core/recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  final states = <AppState>[];
  AppState createState({MockClient? client}) {
    final state = AppState(
      prefs,
      companion: CompanionController(agentId: ''),
      recoveryService: client == null ? null : RecoveryService(client: client),
    );
    states.add(state);
    return state;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() async {
    for (final state in states) {
      await state.persist();
      await state.companion.endSession();
      state.dispose();
    }
    states.clear();
  });

  test(
    'Tool callback updates the calculated scenario with exact rounded pence',
    () async {
      final state = createState();
      final result = await state.companion.onToolCall!('update_scenario', {
        'income_change_percent': -10,
        'unexpected_expense_gbp': 12.345,
        'weekly_spending_reduction_gbp': 1.005,
      });
      expect(result['ok'], isTrue);
      expect(state.scenario.unexpectedExpensePence, 1235);
      expect(state.scenario.weeklySavingPence, 101);
      expect(state.scenario.incomePercentChange, -10);
      expect(state.forecast.firstShortfall!.balancePence, -20634);
      final artifact = result['artifact'] as Map;
      expect(artifact['type'], 'forecast');
      expect(artifact['unexpectedExpenseDate'], '2026-11-10');
      expect((artifact['forecast'] as Map)['shortfallGBP'], '£206.34');
      expect((artifact['scenario'] as Map)['unexpectedExpenseGBP'], '£12.35');
      expect(jsonEncode(result), isNot(contains('Pence"')));

      await state.performCompanionAction('update_scenario', {
        'unexpected_expense_gbp': 30.01,
      });
      expect(state.scenario.unexpectedExpensePence, 3001);
      expect(state.scenario.incomePercentChange, -10);
      expect(state.scenario.weeklySavingPence, 101);
      final scenario = state.scenario;
      final query = await state.performCompanionAction('update_scenario', {});
      expect(query['ok'], isTrue);
      expect(state.scenario, same(scenario));
      await state.performCompanionAction('update_scenario', {'reset': true});
      expect(state.scenario.isBaseline, isTrue);
    },
  );

  test('Invalid untrusted arguments reject the complete action before any mutation', () async {
    final state = createState();
    state.setScenario(const Scenario(unexpectedExpensePence: 1000));
    final initial = _snapshot(state);
    final invalid = <(String, Map<String, dynamic>)>[
      ('update_scenario', {'income_change_percent': -41}),
      ('update_scenario', {'income_change_percent': 41}),
      (
        'update_scenario',
        {
          'income_change_percent': -20,
          'weekly_spending_reduction_gbp': double.nan,
        },
      ),
      ('update_scenario', {'unexpected_expense_gbp': double.infinity}),
      ('update_scenario', {'unexpected_expense_gbp': '25'}),
      ('update_scenario', {'unexpected_expense_gbp': -1}),
      ('update_scenario', {'unexpected_expense_gbp': 400.01}),
      ('update_scenario', {'weekly_spending_reduction_gbp': 40.01}),
      ('update_scenario', {'reset': 'true'}),
      (
        'update_scenario',
        {'unexpected_expense_gbp': 25, 'expense_date': '2026-11-18'},
      ),
      ('build_recovery_plan', {'hardship': 'not_a_hardship'}),
      (
        'build_recovery_plan',
        {'hardship': 'complaint', 'note': List.filled(501, 'a').join()},
      ),
      ('build_recovery_plan', {'note': 123}),
      ('build_recovery_plan', {'replace_existing': 'yes'}),
      ('set_emergency_goal', {'title': '', 'target_gbp': 300}),
      ('set_emergency_goal', {'title': 'Buffer'}),
      ('set_emergency_goal', {'title': 'Buffer', 'target_gbp': .99}),
      ('set_emergency_goal', {'title': 'Buffer', 'target_gbp': 100000.01}),
      (
        'set_emergency_goal',
        {'title': 'Buffer', 'target_gbp': 300, 'replace_existing': 1},
      ),
      ('compare_history', {'include_future': true}),
    ];
    for (final (name, arguments) in invalid) {
      final result = await state.performCompanionAction(name, arguments);
      expect(result['ok'], isFalse, reason: '$name $arguments');
      expect(result['reason'], 'invalid_arguments');
      expect(_snapshot(state), initial);
    }
    final unsupported = await state.performCompanionAction('record_saving', {
      'amount_gbp': 10,
    });
    expect(unsupported['reason'], 'unsupported_action');
    expect(_snapshot(state), initial);
  });

  test('Goal creation and confirmed updates retain savings without duplicate progress', () async {
    final state = createState();
    final created = await state.performCompanionAction('set_emergency_goal', {
      'title': 'Rainy day',
      'target_gbp': 300,
    });
    expect(created['ok'], isTrue);
    expect(state.goal!.savedPence, 3500);
    await state.recordSaving(1500);
    final actionCount = state.actions.length;
    final denied = await state.performCompanionAction('set_emergency_goal', {
      'title': 'Emergency travel',
      'target_gbp': 400,
    });
    expect(denied['reason'], 'needs_confirmation');
    expect(state.goal!.title, 'Rainy day');
    final updated = await state.performCompanionAction('set_emergency_goal', {
      'title': 'Emergency travel',
      'target_gbp': 400,
      'replace_existing': true,
    });
    expect(updated['ok'], isTrue);
    expect(state.goal!.savedPence, 5000);
    expect((updated['artifact'] as Map)['savedGBP'], '£50');
    expect((updated['artifact'] as Map)['nothingTransferred'], isTrue);
    expect(state.actions.length, actionCount);
    await state.performCompanionAction('set_emergency_goal', {
      'title': 'Emergency travel',
      'target_gbp': 400,
    });
    expect(state.actions.length, actionCount);
    expect(state.profile.openingBalancePence, 48500);
    final restored = createState();
    expect(restored.goal!.title, 'Emergency travel');
    expect(restored.goal!.savedPence, 5000);
  });

  test('Actions remain scoped to the selected profile', () async {
    final state = createState();
    await state.performCompanionAction('set_emergency_goal', {
      'title': 'Noor buffer',
      'target_gbp': 300,
    });
    await state.performCompanionAction('update_scenario', {
      'unexpected_expense_gbp': 25,
    });
    await state.selectProfile('alex');
    expect(state.goal, isNull);
    expect(state.scenario.isBaseline, isTrue);
    final alex = await state.performCompanionAction('set_emergency_goal', {
      'title': 'Alex buffer',
      'target_gbp': 5000,
    });
    expect(alex['profileId'], 'alex');
    expect((alex['artifact'] as Map)['savedGBP'], '£1250');
    await state.selectProfile('noor');
    expect(state.goal!.title, 'Noor buffer');
    expect(state.goal!.savedPence, 3500);
    expect(state.actions.length, 1);
  });

  test('Recovery executes the service and returns sourced editable output, requiring replacement confirmation', () async {
    var requests = 0;
    Map<String, dynamic>? sent;
    final state = createState(
      client: MockClient((request) async {
        requests++;
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_plan), 200);
      }),
    );
    final result = await state.performCompanionAction('build_recovery_plan', {
      'hardship': 'unexpected_bill',
      'note': 'My van needed a repair.',
    });
    expect(result['ok'], isTrue);
    expect(requests, 1);
    expect(sent!['hardship'], 'unexpected_bill');
    expect(sent!['note'], 'My van needed a repair.');
    expect((sent!['profile'] as Map)['id'], 'noor');
    final artifact = result['artifact'] as Map;
    expect(artifact['executionId'], 'action-execution-1');
    expect(
      (artifact['sources'] as List).single['url'],
      'https://www.moneyhelper.org.uk/',
    );
    expect(
      artifact['draftBody'],
      'Dear support team, please review my payment date.',
    );
    expect(artifact['nothingSent'], isTrue);
    await state.saveDraft(body: 'My own reviewed edits.');
    final denied = await state.performCompanionAction('build_recovery_plan', {
      'hardship': 'complaint',
    });
    expect(denied['reason'], 'needs_confirmation');
    expect(requests, 1);
    expect(state.draftBody, 'My own reviewed edits.');
    final replaced = await state.performCompanionAction('build_recovery_plan', {
      'hardship': 'complaint',
      'replace_existing': true,
    });
    expect(replaced['ok'], isTrue);
    expect(requests, 2);
    expect(
      state.actions
          .where((action) => action.label == 'Made a recovery plan')
          .length,
      1,
    );
  });

  test('Service failure preserves the previous plan and edited draft without claiming success', () async {
    final state = createState(
      client: MockClient((_) async => http.Response('Unavailable', 503)),
    );
    state.recovery = RecoveryPlan(Map<String, dynamic>.from(_plan));
    await state.saveDraft(
      subject: 'Edited subject',
      body: 'My edits stay here.',
    );
    final result = await state.performCompanionAction('build_recovery_plan', {
      'hardship': 'income_drop',
      'note': 'Keep this new note.',
      'replace_existing': true,
    });
    expect(result['ok'], isFalse);
    expect(result['reason'], 'service_unavailable');
    expect(state.recovery!.executionId, 'action-execution-1');
    expect(state.draftSubject, 'Edited subject');
    expect(state.draftBody, 'My edits stay here.');
    expect(state.actions, isEmpty);
    expect(createState().supportNote, 'Keep this new note.');
  });

  test(
    'Pending recovery locks the profile and rejects overlapping actions',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final state = createState(
        client: MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      final pending = state.performCompanionAction('build_recovery_plan', {
        'hardship': 'income_drop',
      });
      await started.future;
      await state.selectProfile('alex');
      expect(state.profile.id, 'noor');
      final overlapping = await state.performCompanionAction(
        'update_scenario',
        {'unexpected_expense_gbp': 30},
      );
      expect(overlapping['reason'], 'busy');
      expect(state.scenario.isBaseline, isTrue);
      response.complete(http.Response(jsonEncode(_plan), 200));
      expect((await pending)['ok'], isTrue);
      await state.selectProfile('alex');
      expect(state.recovery, isNull);
      expect(state.draftBody, isEmpty);
      expect(state.actions, isEmpty);
    },
  );

  test('Edits made while a recovery request runs are not overwritten by its response', () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    final state = createState(
      client: MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    final pending = state.performCompanionAction('build_recovery_plan', {});
    await started.future;
    await state.saveDraft(body: 'New edits while waiting.');
    response.complete(http.Response(jsonEncode(_plan), 200));
    final result = await pending;
    expect(result['ok'], isFalse);
    expect(result['reason'], 'draft_changed');
    expect(state.draftBody, 'New edits while waiting.');
    expect(state.recovery, isNull);
    expect(state.actions, isEmpty);
  });

  test('History comparison returns honest formatted evidence without changing money', () async {
    final state = createState();
    final initial = _snapshot(state);
    final result = await state.performCompanionAction('compare_history', {});
    expect(result['ok'], isTrue);
    final artifact = result['artifact'] as Map;
    expect(artifact['type'], 'history_comparison');
    expect(artifact['startDate'], '2026-10-10');
    expect(artifact['endDate'], '2026-11-06');
    expect(artifact['expectedEndingBalanceGBP'], '£1695');
    expect(artifact['actualEndingBalanceGBP'], '£485');
    expect(artifact['varianceGBP'], '£-1210');
    expect(artifact['disclosure'], contains('synthetic'));
    expect(artifact['futureActualsAvailable'], isFalse);
    expect(_snapshot(state), initial);
  });
}

String _snapshot(AppState state) => jsonEncode({
  'profile': state.profile.id,
  'scenario': state.scenario.toJson(),
  'goal': state.goal?.toJson(),
  'actions': state.actions.map((action) => action.toJson()).toList(),
  'draftBody': state.draftBody,
  'draftSubject': state.draftSubject,
  'hardship': state.hardship,
  'note': state.supportNote,
});

const _plan = <String, Object?>{
  'mode': 'live_n8n',
  'title': 'A practical next step',
  'summary': 'Check the dates and ask your provider about support.',
  'steps': [
    {
      'id': 'review',
      'title': 'Check the dates',
      'detail': 'Confirm income and bill dates.',
    },
  ],
  'sources': [
    {
      'title': 'MoneyHelper',
      'url': 'https://www.moneyhelper.org.uk/',
      'excerpt': 'Free money guidance.',
    },
  ],
  'evidence': ['Recent statements'],
  'knownFacts': ['Synthetic budget shortfall.'],
  'assumptions': ['Support is not guaranteed.'],
  'draft': {
    'subject': 'Request for support',
    'body': 'Dear support team, please review my payment date.',
    'recipient': 'Provider support team',
  },
  'workflow': {'engine': 'n8n', 'executionId': 'action-execution-1'},
};
