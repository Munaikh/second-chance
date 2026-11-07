import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/app_state.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/core/recovery.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/companion_action_card.dart';
import 'package:second_chance/ui/design.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'A calculated action displays exact results in chat at large text',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        await SharedPreferences.getInstance(),
        companion: CompanionController(agentId: ''),
      );
      final result = await state.performCompanionAction('update_scenario', {
        'unexpected_expense_gbp': 150,
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(children: [CompanionActionCard(result: result)]),
            ),
          ),
        ),
      );
      expect(find.text('Projected low: £-330'), findsOneWidget);
      expect(find.text('What-if estimate · no money moved'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets(
    'The draft is editable and copyable inside chat, preserving older snapshots',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final state = AppState(
        prefs,
        companion: CompanionController(agentId: ''),
      );
      state.recovery = RecoveryPlan(Map<String, dynamic>.from(_plan));
      state.draftSubject = 'Support request';
      state.draftBody = 'Please review my payment date.';
      final artifact = <String, Object?>{
        'profileId': 'noor',
        'executionId': 'inline-test',
        'draft': {'subject': state.draftSubject, 'body': state.draftBody},
      };
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [InlineRecoveryDraft(artifact: artifact)],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Review and edit your draft'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('chat_draft_subject')),
        'My reviewed request',
      );
      await tester.enterText(
        find.byKey(const ValueKey('chat_draft_body')),
        'Please discuss an affordable payment date.',
      );
      await tester.pump();
      expect(state.draftSubject, 'My reviewed request');
      expect(state.draftBody, 'Please discuss an affordable payment date.');
      await tester.ensureVisible(find.byKey(const ValueKey('copy_chat_draft')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('copy_chat_draft')));
      await tester.pump();
      expect(copied, contains('My reviewed request'));
      expect(copied, contains('Please discuss an affordable payment date.'));
      final save = state.persist();
      await tester.pump();
      await save;
      expect(
        jsonDecode(
          prefs.getString(AppState.storageKey)!,
        )['profiles']['noor']['draftBody'],
        state.draftBody,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}

const _plan = <String, Object?>{
  'mode': 'live_n8n',
  'title': 'Your plan',
  'summary': 'Contact your provider.',
  'steps': [
    {'id': 'review', 'title': 'Review dates', 'detail': 'Check bill timing.'},
  ],
  'sources': [
    {
      'title': 'MoneyHelper',
      'url': 'https://www.moneyhelper.org.uk/',
      'excerpt': 'Free guidance.',
    },
  ],
  'evidence': ['Statements'],
  'knownFacts': ['Synthetic forecast.'],
  'assumptions': ['Dates may change.'],
  'draft': {
    'subject': 'Support request',
    'body': 'Please review my payment date.',
    'recipient': 'Provider',
  },
  'workflow': {'engine': 'n8n', 'executionId': 'inline-test'},
};
