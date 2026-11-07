import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/app_state.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/forecast.dart';
import 'package:second_chance/ui/grow.dart';
import 'package:second_chance/ui/history_comparison.dart';
import 'package:second_chance/ui/home.dart';
import 'package:second_chance/ui/support.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<AppState> mountOverview(
    WidgetTester tester, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(prefs, companion: CompanionController(agentId: ''));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await state.companion.endSession();
      state.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: appTheme(brightness),
          navigatorObservers: [appRouteObserver],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const MainShell(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const ValueKey('expand_overview')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    return state;
  }

  Future<void> revealTask(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(
      find.byKey(ValueKey(key)),
      180,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('prepare_noor')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('All four overview tasks open their named destination', (
    tester,
  ) async {
    await mountOverview(tester);
    for (final task in const [
      ('open_forecast', ForecastPage),
      ('open_comparison', ExpectedActualComparison),
      ('open_support', SupportDetailPage),
      ('open_savings', GrowPage),
    ]) {
      await revealTask(tester, task.$1);
      await tester.tap(find.byKey(ValueKey(task.$1)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(task.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(task.$2))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('Overview tasks remain usable at 2x text in $brightness', (
      tester,
    ) async {
      final state = await mountOverview(
        tester,
        textScale: 2,
        brightness: brightness,
      );
      expect(find.text('£485'), findsOneWidget);
      expect(find.text('£180 gap'), findsOneWidget);
      expect(state.forecast.firstShortfall!.date, DateTime(2026, 11, 12));
      expect(tester.takeException(), isNull);
      for (final key in const [
        'open_forecast',
        'open_comparison',
        'open_support',
        'open_savings',
      ]) {
        await revealTask(tester, key);
        final target = find.byKey(ValueKey(key));
        expect(target.hitTestable(), findsOneWidget);
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(PreparePage), findsOneWidget);
    });
  }
}
