import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/history_comparison.dart';

void main() {
  testWidgets(
    'Historical comparison labels synthetic evidence and remains usable with large text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ExpectedActualComparison(profile: DemoProfiles.all.first),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Expected vs actual'), findsOneWidget);
      expect(find.text('Actual'), findsOneWidget);
      expect(find.text('Expected'), findsOneWidget);
      expect(
        find.text(
          'Reconstructed from the prior 4 demo weeks. Actuals are synthetic records.',
        ),
        findsOneWidget,
      );
      expect(find.text('7 Nov'), findsNothing);
      expect(find.text('6 Dec'), findsNothing);
      expect(tester.takeException(), isNull);
      for (var step = 0; step < 5; step++) {
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -400),
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(tester.takeException(), isNull);
      }
      expect(
        find.text('£1,210 below the reconstructed estimate'),
        findsOneWidget,
      );
      expect(
        find.text('Future actuals aren’t available in this demo.'),
        findsOneWidget,
      );
    },
  );
}
