import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/app_state.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/forecast.dart';
import 'package:second_chance/ui/history_comparison.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Time travel switches to historical actuals without changing the future scenario',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        await SharedPreferences.getInstance(),
        companion: CompanionController(agentId: ''),
      );
      state.setScenario(const Scenario(weeklySavingPence: 2500));
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
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const ForecastPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Expected vs actual'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExpectedActualComparison), findsOneWidget);
      expect(find.byKey(const ValueKey('income_slider')), findsNothing);
      expect(state.scenario.weeklySavingPence, 2500);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Look ahead'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ExpectedActualComparison), findsNothing);
      expect(state.forecast.shortfallPence, 15500);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await state.companion.endSession();
      state.dispose();
    },
  );
}
