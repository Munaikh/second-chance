import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_chance/core/app_state.dart';
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
    'Created goals, contributions and achievements survive a fresh state',
    () async {
      final state = createState();
      expect(state.goal, isNull);
      await state.createGoal('  Emergency travel fund  ', 30000);
      await state.recordSaving(1500);
      await state.recordAction('Reviewed my credit report');
      await state.recordAction('Reviewed my credit report');

      final restored = createState();
      expect(restored.profile.id, state.profile.id);
      expect(restored.goal!.title, 'Emergency travel fund');
      expect(restored.goal!.targetPence, 30000);
      expect(restored.goal!.savedPence, state.profile.goalSavedPence + 1500);
      expect(restored.goal!.progress, closeTo(5000 / 30000, 0.00001));
      expect(restored.actions.length, 3);
      expect(
        restored.actions
            .where((action) => action.amountPence == 1500)
            .single
            .label,
        'Set aside £15.00',
      );
      expect(restored.hasReviewedCredit, isTrue);
      expect(
        restored.actions.map((action) => action.date),
        state.actions.map((action) => action.date),
      );
      expect(restored.persistenceError, isNull);
    },
  );

  test(
    'Profiles retain separate goals, draft edits, circumstances and actions',
    () async {
      final state = createState();
      final firstId = state.profile.id;
      final secondId = DemoProfiles.all.last.id;
      await state.createGoal('Noor emergency buffer', 30000);
      await state.recordSaving(500);
      state.supportNote = 'My delivery hours changed.';
      state.hardship = 'income_drop';
      await state.saveDraft(
        subject: 'Noor request',
        body: 'Please review my payment timing.',
      );
      state.setScenario(const Scenario(unexpectedExpensePence: 5000));

      await state.selectProfile(secondId);
      expect(state.goal, isNull);
      expect(state.actions, isEmpty);
      expect(state.draftBody, isEmpty);
      expect(state.supportNote, isEmpty);
      expect(state.scenario.isBaseline, isTrue);
      await state.createGoal('Alex rainy-day fund', 500000);
      await state.recordAction('Reviewed my credit report');
      state.supportNote = 'Checking my household bills.';
      state.hardship = 'unexpected_expense';
      await state.saveDraft(subject: 'Alex request', body: 'Alex draft only.');

      await state.selectProfile(firstId);
      expect(state.goal!.title, 'Noor emergency buffer');
      expect(
        state.goal!.savedPence,
        DemoProfiles.all.first.goalSavedPence + 500,
      );
      expect(state.hasReviewedCredit, isFalse);
      expect(state.draftSubject, 'Noor request');
      expect(state.draftBody, 'Please review my payment timing.');
      expect(state.supportNote, 'My delivery hours changed.');
      expect(state.hardship, 'income_drop');
      expect(state.scenario.isBaseline, isTrue);

      await state.selectProfile(secondId);
      final restored = createState();
      expect(restored.profile.id, secondId);
      expect(restored.goal!.title, 'Alex rainy-day fund');
      expect(restored.hasReviewedCredit, isTrue);
      expect(restored.draftBody, 'Alex draft only.');
      expect(restored.supportNote, 'Checking my household bills.');
      expect(restored.hardship, 'unexpected_expense');
    },
  );

  test(
    'Reset removes progress and restores the reproducible baseline',
    () async {
      final state = createState();
      await state.createGoal('Temporary buffer', 30000);
      await state.recordSaving(1200);
      await state.saveDraft(body: 'Edited support draft');
      await state.selectProfile(DemoProfiles.all.last.id);
      await state.createGoal('Another goal', 500000);
      state.setScenario(const Scenario(incomePercentChange: -50));
      await state.resetDemo();

      expect(prefs.getString(AppState.storageKey), isNull);
      expect(state.profile.id, DemoProfiles.all.first.id);
      expect(state.goal, isNull);
      expect(state.actions, isEmpty);
      expect(state.recovery, isNull);
      expect(state.draftBody, isEmpty);
      expect(state.draftSubject, isEmpty);
      expect(state.supportNote, isEmpty);
      expect(state.scenario.isBaseline, isTrue);
      expect(state.shortfallPence, 18000);
      expect(state.forecast.firstShortfall!.date, DateTime(2026, 11, 12));

      final restored = createState();
      expect(restored.profile.id, DemoProfiles.all.first.id);
      expect(restored.goal, isNull);
      expect(restored.actions, isEmpty);
      await restored.selectProfile(DemoProfiles.all.last.id);
      expect(restored.goal, isNull);
      expect(restored.actions, isEmpty);
    },
  );

  test('Invalid amounts do not alter goals or record false progress', () async {
    final state = createState();
    await expectLater(state.recordSaving(100), throwsArgumentError);
    await expectLater(state.createGoal('', 30000), throwsArgumentError);
    await expectLater(state.createGoal('Buffer', 99), throwsArgumentError);
    expect(state.goal, isNull);
    expect(state.actions, isEmpty);
    await state.createGoal('Buffer', 30000);
    final saved = state.goal!.savedPence;
    for (final invalid in [0, -1, 1000001]) {
      await expectLater(state.recordSaving(invalid), throwsArgumentError);
    }
    expect(state.goal!.savedPence, saved);
    expect(state.actions.length, 1);
  });

  test('Failed support requests preserve edits and retry into a persisted live plan', () async {
    var attempts = 0;
    final requests = <Map<String, dynamic>>[];
    final state = createState(
      client: MockClient((request) async {
        attempts++;
        expect(request.method, 'POST');
        expect(request.url.path, '/api/recovery');
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return attempts == 1
            ? http.Response('Temporarily unavailable', 503)
            : http.Response(jsonEncode(_recoveryFixture), 200);
      }),
    );
    state.supportNote = '  My van needed a repair.  ';
    await state.saveDraft(
      subject: 'My own subject',
      body: 'Keep this editable draft.',
    );
    await state.generateRecovery();
    expect(state.isGenerating, isFalse);
    expect(state.recoveryError, contains('Try again'));
    expect(state.recovery, isNull);
    expect(state.draftSubject, 'My own subject');
    expect(state.draftBody, 'Keep this editable draft.');
    expect(state.supportNote, '  My van needed a repair.  ');
    expect(state.actions, isEmpty);

    await state.generateRecovery();
    expect(attempts, 2);
    expect(requests.last['note'], 'My van needed a repair.');
    expect((requests.last['profile'] as Map)['id'], state.profile.id);
    expect(state.isGenerating, isFalse);
    expect(state.recoveryError, isNull);
    expect(state.recovery!.executionId, 'test-execution-42');
    expect(
      state.draftBody,
      'Dear support team, please review my payment timing.',
    );
    expect(state.actions.single.label, 'Made a recovery plan');

    await state.saveDraft(body: 'I have reviewed and edited this request.');
    final restored = createState();
    expect(restored.recovery!.executionId, 'test-execution-42');
    expect(restored.recovery!.sources.single.title, 'MoneyHelper');
    expect(restored.draftBody, 'I have reviewed and edited this request.');
    expect(restored.actions.single.label, 'Made a recovery plan');
  });

  test('Recovery amount matches its stated first-shortfall date under income stress', () async {
    Map<String, dynamic>? payload;
    final state = createState(
      client: MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_recoveryFixture), 200);
      }),
    );
    state.setScenario(const Scenario(incomePercentChange: -100));
    final first = state.forecast.firstShortfall!;
    expect(first.balancePence, -33000);
    expect(state.forecast.lowestDay.balancePence, -100700);
    await state.generateRecovery();
    final requestedForecast = payload!['forecast'] as Map;
    expect(requestedForecast['shortfallDate'], first.date.toIso8601String());
    expect(requestedForecast['shortfallPence'], -first.balancePence);
  });

  test('Unreadable saved JSON gives a recoverable reset path', () async {
    await prefs.setString(AppState.storageKey, '{incomplete');
    final state = createState();
    expect(state.persistenceError, contains('reset'));
    expect(state.profile.id, DemoProfiles.all.first.id);
    expect(state.goal, isNull);
    await state.resetDemo();
    expect(state.persistenceError, isNull);
    expect(prefs.getString(AppState.storageKey), isNull);
  });

  final malformedProfiles = <String, Map<String, Object?>>{
    'zero goal target': {
      'goal': {'title': 'Buffer', 'targetPence': 0, 'savedPence': 100},
    },
    'negative goal target': {
      'goal': {'title': 'Buffer', 'targetPence': -100, 'savedPence': 100},
    },
    'non-numeric saved amount': {
      'goal': {'title': 'Buffer', 'targetPence': 30000, 'savedPence': '35'},
    },
    'malformed action record': {
      'actions': ['not an action object'],
    },
    'invalid action date': {
      'actions': [
        {'label': 'Reviewed a bill', 'date': 'not-a-date', 'amountPence': 0},
      ],
    },
    'incomplete saved recovery plan': {
      'recovery': {
        'mode': 'live_n8n',
        'draft': <String, Object?>{},
        'steps': <Object?>[],
      },
    },
  };
  for (final malformed in malformedProfiles.entries) {
    test(
      'Malformed nested storage (${malformed.key}) recovers without crashing',
      () async {
        await prefs.setString(
          AppState.storageKey,
          jsonEncode({
            'selectedProfile': DemoProfiles.all.first.id,
            'profiles': {DemoProfiles.all.first.id: malformed.value},
          }),
        );
        final state = createState();
        expect(state.persistenceError, isNotNull);
        expect(state.goal, isNull);
        expect(state.actions, isEmpty);
        expect(state.recovery, isNull);
        expect(state.draftBody, isEmpty);
        expect(state.forecast.shortfallPence, 18000);
        await state.resetDemo();
        expect(state.persistenceError, isNull);
        expect(prefs.getString(AppState.storageKey), isNull);
      },
    );
  }

  test(
    'Incomplete HTTP200 plan is recoverable and preserves an edited draft',
    () async {
      final state = createState(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'mode': 'live_n8n',
              'draft': <String, Object?>{},
              'steps': <Object?>[],
            }),
            200,
          ),
        ),
      );
      await state.saveDraft(
        subject: 'My subject',
        body: 'My reviewed request.',
      );
      await state.generateRecovery();
      expect(state.recoveryError, isNotNull);
      expect(state.isGenerating, isFalse);
      expect(state.recovery, isNull);
      expect(state.draftSubject, 'My subject');
      expect(state.draftBody, 'My reviewed request.');
      expect(state.actions, isEmpty);
      final restored = createState();
      expect(restored.draftBody, 'My reviewed request.');
    },
  );
}

const _recoveryFixture = <String, Object?>{
  'mode': 'live_n8n',
  'title': 'Your next practical step',
  'summary': 'Review the upcoming gap and ask your provider about support.',
  'steps': [
    {
      'id': 'review',
      'title': 'Check the dates',
      'detail': 'Confirm when income and bills are due.',
    },
  ],
  'sources': [
    {
      'title': 'MoneyHelper',
      'url': 'https://www.moneyhelper.org.uk/',
      'excerpt': 'Free, impartial money guidance.',
    },
  ],
  'evidence': ['Recent statements and income dates'],
  'knownFacts': ['Synthetic profile has a forecast shortfall.'],
  'assumptions': [
    'Support depends on the provider; approval is not guaranteed.',
  ],
  'draft': {
    'recipient': 'Provider support team',
    'subject': 'Request for payment support',
    'body': 'Dear support team, please review my payment timing.',
  },
  'workflow': {'engine': 'n8n', 'executionId': 'test-execution-42'},
};
