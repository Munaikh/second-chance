import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/app_state.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/forecast.dart';
import 'package:second_chance/ui/grow.dart';
import 'package:second_chance/ui/home.dart';
import 'package:second_chance/ui/support.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  AppState createState(WidgetTester tester) {
    final state = AppState(prefs);
    addTearDown(() async {
      final saved = state.persist();
      await tester.pump();
      await saved;
      await state.companion.endSession();
      state.dispose();
    });
    return state;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> usePhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  Future<void> reveal(
    WidgetTester tester,
    Finder target,
    Finder page, {
    double delta = 250,
  }) async {
    await tester.scrollUntilVisible(
      target,
      delta,
      scrollable: find
          .descendant(of: page, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'Prepare opens dated time travel and changing a bill updates the forecast',
    (tester) async {
      await usePhoneSize(tester);
      final state = createState(tester);
      await tester.pumpWidget(SecondChanceApp(state: state));
      await tester.pump(const Duration(milliseconds: 400));
      await reveal(
        tester,
        find.byKey(const ValueKey('open_forecast')),
        find.byType(PreparePage),
      );
      await tester.tap(find.byKey(const ValueKey('open_forecast')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ForecastPage), findsOneWidget);
      expect(state.forecast.shortfallPence, 18000);
      expect(state.forecast.firstShortfall!.date, DateTime(2026, 11, 12));

      await reveal(
        tester,
        find.byKey(const ValueKey('expense_slider')),
        find.byType(ForecastPage),
      );
      await tester.drag(
        find.byKey(const ValueKey('expense_slider')),
        const Offset(100, 0),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.scenario.unexpectedExpensePence, greaterThan(0));
      expect(state.forecast.shortfallPence, greaterThan(18000));
      expect(
        state.forecast.endingBalancePence,
        state.baseline.endingBalancePence -
            state.scenario.unexpectedExpensePence,
      );
      await reveal(
        tester,
        find.byKey(const ValueKey('reset_scenario')),
        find.byType(ForecastPage),
        delta: -250,
      );
      await tester.tap(find.byKey(const ValueKey('reset_scenario')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.scenario.isBaseline, isTrue);
      expect(state.forecast.shortfallPence, 18000);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Grow creates a goal and records a persistent contribution through mobile forms',
    (tester) async {
      await usePhoneSize(tester);
      final state = createState(tester);
      await tester.pumpWidget(SecondChanceApp(state: state));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('tab_2')));
      await tester.pump(const Duration(milliseconds: 300));
      await reveal(
        tester,
        find.byKey(const ValueKey('create_goal')),
        find.byType(GrowPage),
      );
      await tester.tap(find.byKey(const ValueKey('create_goal')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CreateGoalPage), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('goal_name')),
        'Work travel buffer',
      );
      await tester.enterText(find.byKey(const ValueKey('goal_target')), '300');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await reveal(
        tester,
        find.byKey(const ValueKey('save_goal')),
        find.byType(CreateGoalPage),
      );
      await tester.tap(find.byKey(const ValueKey('save_goal')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CreateGoalPage), findsNothing);
      expect(state.goal!.title, 'Work travel buffer');
      expect(state.goal!.targetPence, 30000);

      await reveal(
        tester,
        find.byKey(const ValueKey('record_saving')),
        find.byType(GrowPage),
      );
      await tester.tap(find.byKey(const ValueKey('record_saving')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
        find.byKey(const ValueKey('saving_amount')),
        '15.50',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await reveal(
        tester,
        find.byKey(const ValueKey('save_contribution')),
        find.byType(RecordSavingPage),
      );
      await tester.tap(find.byKey(const ValueKey('save_contribution')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(RecordSavingPage), findsNothing);
      expect(state.goal!.savedPence, state.profile.goalSavedPence + 1550);
      expect(state.actions.last.label, 'Set aside £15.50');
      final restored = createState(tester);
      expect(restored.goal!.title, 'Work travel buffer');
      expect(restored.goal!.savedPence, 5050);
      expect(restored.actions.length, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Key journeys fit 390px at twice normal text size', (
    tester,
  ) async {
    await usePhoneSize(tester);
    final state = createState(tester);
    final created = state.createGoal('My emergency buffer', 30000);
    await tester.pump();
    await created;
    final recorded = state.recordSaving(1500);
    await tester.pump();
    await recorded;
    final pages = <String, Widget>{
      'Prepare': PreparePage(onSupport: () {}, onGrow: () {}),
      'Forecast': const ForecastPage(),
      'Support': const SupportPage(),
      'Grow': const GrowPage(),
    };
    for (final page in pages.entries) {
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(body: page.value),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.takeException(),
        isNull,
        reason: '${page.key} must fit large text.',
      );
      final scrollables = find.descendant(
        of: find.byWidget(page.value),
        matching: find.byType(Scrollable),
      );
      for (var step = 0; step < 6; step++) {
        await tester.drag(scrollables.first, const Offset(0, -450));
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          tester.takeException(),
          isNull,
          reason: '${page.key} must scroll without large-text overflow.',
        );
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets(
    'A long edited draft autosaves and Copy stays visible while scrolling',
    (tester) async {
      await usePhoneSize(tester);
      final state = createState(tester);
      state.draftSubject = 'Request for payment support';
      state.draftBody = List.generate(
        25,
        (index) =>
            'Detail ${index + 1}: I would like to discuss a manageable payment date.',
      ).join('\n');
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': copiedText};
          if (call.method == 'Clipboard.hasStrings') {
            return {'value': copiedText != null};
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
            theme: appTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const DraftPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final copyButton = find.byKey(const ValueKey('copy_draft'));
      final fixedButtonRect = tester.getRect(copyButton);
      expect(copyButton.hitTestable(), findsOneWidget);
      expect(fixedButtonRect.bottom, lessThanOrEqualTo(844));
      await reveal(
        tester,
        find.byKey(const ValueKey('draft_subject')),
        find.byType(DraftPage),
      );
      const editedSubject = 'Reviewed request for a new payment date';
      await tester.enterText(
        find.byKey(const ValueKey('draft_subject')),
        editedSubject,
      );
      await reveal(
        tester,
        find.byKey(const ValueKey('draft_body')),
        find.byType(DraftPage),
      );
      final editedBody =
          '${state.draftBody}\nI have checked the figures and will attach my statements.';
      await tester.enterText(
        find.byKey(const ValueKey('draft_body')),
        editedBody,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final restored = createState(tester);
      expect(restored.draftSubject, editedSubject);
      expect(restored.draftBody, editedBody);
      expect(copiedText, isNull);

      await tester.dragFrom(const Offset(12, 400), const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));
      expect(copyButton.hitTestable(), findsOneWidget);
      expect(tester.getRect(copyButton), fixedButtonRect);
      await tester.tap(copyButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(copiedText, 'Subject: $editedSubject\n\n$editedBody');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
