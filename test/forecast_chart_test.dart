import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/forecast.dart';

void main() {
  test('Smooth cash-flow curves never overshoot their daily endpoints', () {
    for (final endY in [-180.0, 0.0, 900.0]) {
      final path = smoothCashflowPath([
        const Offset(0, 100),
        Offset(100, endY),
      ]);
      final metric = path.computeMetrics().single;
      for (var i = 0; i <= 100; i++) {
        final point = metric
            .getTangentForOffset(metric.length * i / 100)!
            .position;
        expect(point.dx, inInclusiveRange(-.001, 100.001));
        expect(
          point.dy,
          inInclusiveRange(
            endY < 100 ? endY - .001 : 99.999,
            endY > 100 ? endY + .001 : 100.001,
          ),
        );
      }
      final last = metric.getTangentForOffset(metric.length)!.position;
      expect(last.dx, closeTo(100, .001));
      expect(last.dy, closeTo(endY, .001));
    }
    expect(smoothCashflowPath([]).computeMetrics(), isEmpty);
  });

  testWidgets('Selecting a day compares exact primary and baseline balances', (
    tester,
  ) async {
    Forecast series(List<int> balances) {
      final days = [
        for (var i = 0; i < balances.length; i++)
          ForecastDay(
            date: DateTime(2026, 10, 10 + i),
            balancePence: balances[i],
          ),
      ];
      return Forecast(
        days: days,
        entries: const [],
        openingBalancePence: 9000,
        endingBalancePence: balances.last,
        lowestDay: days.reduce(
          (a, b) => a.balancePence < b.balancePence ? a : b,
        ),
        firstShortfall: null,
        pressureCauses: const [],
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(
          body: ForecastChart(
            forecast: series([8000, -18000, 20000]),
            baseline: series([9000, 10000, 12000]),
            primaryLabel: 'Actual',
            baselineLabel: 'Expected',
          ),
        ),
      ),
    );
    expect(find.text('Actual: -£180.00'), findsOneWidget);
    expect(find.text('Expected: £100.00'), findsOneWidget);
    expect(find.text('Difference: -£280.00'), findsOneWidget);
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('forecast_date_slider')),
    );
    slider.onChanged!(2);
    await tester.pump();
    expect(find.text('Actual: £200.00'), findsOneWidget);
    expect(find.text('Expected: £120.00'), findsOneWidget);
    expect(find.text('Difference: £80.00'), findsOneWidget);
    expect(find.text('10 Oct'), findsOneWidget);
    expect(find.text('12 Oct'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
