import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/app_state.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/home.dart';
import 'package:second_chance/ui/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  AppState createState(WidgetTester tester) {
    final state = AppState(prefs, companion: CompanionController(agentId: ''));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      final saved = state.persist();
      await tester.pump();
      await saved;
      await state.companion.endSession();
      state.dispose();
    });
    return state;
  }

  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  Future<void> sendQuestion(WidgetTester tester, String question) async {
    await tester.enterText(find.byKey(const ValueKey('chat_input')), question);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send_message')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'Home presents Cloudy, voice and text input before opening a conversation',
    (tester) async {
      usePhoneSize(tester);
      final state = createState(tester);
      await tester.pumpWidget(SecondChanceApp(state: state));
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byKey(const ValueKey('home_mascot')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chat_input')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('start_voice')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('home_menu')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('financial_sheet_noor')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('conversation_messages')), findsNothing);
      expect(state.companion.messages, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Financial sheet expands, collapses, drags upward and scrolls its content',
    (tester) async {
      usePhoneSize(tester);
      final state = createState(tester);
      await tester.pumpWidget(SecondChanceApp(state: state));
      await tester.pump(const Duration(milliseconds: 350));
      final expand = find.byKey(const ValueKey('expand_overview'));
      final restingTop = tester.getTopLeft(expand).dy;
      await tester.tap(expand);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.getTopLeft(expand).dy, lessThan(restingTop - 100));
      expect(
        find.byKey(const ValueKey('chat_input')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(expand);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.getTopLeft(expand).dy, closeTo(restingTop, 2));

      await tester.dragFrom(
        Offset(195, restingTop + 70),
        const Offset(0, -400),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getTopLeft(expand).dy, lessThan(restingTop - 100));
      final financialScroll = find
          .descendant(
            of: find.byKey(const PageStorageKey('prepare_noor')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(financialScroll, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.state<ScrollableState>(financialScroll).position.pixels,
        greaterThan(0),
      );
      expect(
        find.byKey(const ValueKey('chat_input')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Inline chat uses the selected forecast and returns to the financial overview',
    (tester) async {
      usePhoneSize(tester);
      final state = createState(tester);
      await tester.pumpWidget(SecondChanceApp(state: state));
      await tester.pump(const Duration(milliseconds: 350));
      await sendQuestion(tester, 'Why might I run short?');
      expect(
        find.byKey(const ValueKey('conversation_messages')),
        findsOneWidget,
      );
      expect(state.companion.messages.length, 2);
      expect(state.companion.messages.last.isFallback, isTrue);
      expect(state.companion.messages.last.text, contains('£180'));
      expect(state.companion.messages.last.text, contains('2026-11-12'));
      expect(find.text('Calculated demo guidance'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('expand_overview')).hitTestable(),
        findsNothing,
      );
      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('chat_input')),
      );
      expect(input.controller!.text, isEmpty);
      await tester.tap(find.byKey(const ValueKey('home_menu')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const ValueKey('conversation_messages')), findsNothing);
      expect(
        find.byKey(const ValueKey('expand_overview')).hitTestable(),
        findsOneWidget,
      );
      expect(state.companion.messages.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Large text and keyboard insets keep the composer reachable', (
    tester,
  ) async {
    usePhoneSize(tester);
    final state = createState(tester);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          navigatorObservers: [appRouteObserver],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: PreparePage(onSupport: () {}, onGrow: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('chat_input')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester.getRect(find.byKey(const ValueKey('chat_input'))).bottom,
      lessThan(544),
    );
    expect(
      find.byKey(const ValueKey('start_voice')).hitTestable(),
      findsOneWidget,
    );
    await sendQuestion(tester, 'Help with my bills');
    expect(state.companion.messages.last.isFallback, isTrue);
    expect(
      find.byKey(const ValueKey('send_message')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const ValueKey('home_menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const ValueKey('expand_overview')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final financialScroll = find
        .descendant(
          of: find.byKey(const PageStorageKey('prepare_noor')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (var step = 0; step < 4; step++) {
      await tester.drag(financialScroll, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'Switching profiles clears the previous conversation and unsent input',
    (tester) async {
      usePhoneSize(tester);
      final state = createState(tester);
      await tester.pumpWidget(SecondChanceApp(state: state));
      await tester.pump(const Duration(milliseconds: 350));
      await sendQuestion(tester, 'Why might I run short?');
      await tester.enterText(
        find.byKey(const ValueKey('chat_input')),
        'Private unsent draft for Noor',
      );
      await tester.tap(find.byKey(const ValueKey('open_profiles')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile_alex')),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ProfilePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byKey(const ValueKey('profile_alex')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(state.profile.id, 'alex');
      expect(find.byType(ProfilePage), findsNothing);
      expect(state.companion.messages, isEmpty);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('chat_input')))
            .controller!
            .text,
        isEmpty,
      );
      expect(find.byKey(const ValueKey('conversation_messages')), findsNothing);
      expect(
        find.byKey(const ValueKey('financial_sheet_alex')),
        findsOneWidget,
      );
      expect(find.text('FOR YOU, ALEX'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
