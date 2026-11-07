import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/ui/home_motion.dart';

void main() {
  testWidgets(
    'Spring moves continuously and reverses from its current position',
    (tester) async {
      var open = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ConversationMotion(
                open: open,
                builder: (context, progress, child) => Align(
                  alignment: Alignment.topLeft,
                  child: Transform.translate(
                    offset: Offset(200 * progress, 0),
                    child: child,
                  ),
                ),
                child: const SizedBox(
                  key: ValueKey('traveller'),
                  width: 50,
                  height: 50,
                ),
              );
            },
          ),
        ),
      );
      final traveller = find.byKey(const ValueKey('traveller'));
      final start = tester.getTopLeft(traveller).dx;
      update(() => open = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final moving = tester.getTopLeft(traveller).dx;
      expect(moving, greaterThan(start));
      expect(moving, lessThan(start + 200));
      update(() => open = false);
      await tester.pump();
      expect(tester.getTopLeft(traveller).dx, closeTo(moving, .01));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(traveller).dx, closeTo(start, .1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reduced motion reaches the target immediately, including midflight',
    (tester) async {
      var open = false;
      var reduced = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reduced),
                child: ConversationMotion(
                  open: open,
                  builder: (context, progress, child) => Text('$progress'),
                  child: const SizedBox(),
                ),
              );
            },
          ),
        ),
      );
      update(() => open = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('1.0'), findsNothing);
      update(() => reduced = true);
      await tester.pump();
      expect(find.text('1.0'), findsOneWidget);
      update(() => open = false);
      await tester.pump();
      expect(find.text('0.0'), findsOneWidget);
    },
  );

  testWidgets(
    'The shared child and its unsent input survive both transitions',
    (tester) async {
      var open = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return ConversationMotion(
                  open: open,
                  builder: (context, progress, child) => Transform.translate(
                    offset: Offset(0, progress * 50),
                    child: child,
                  ),
                  child: const TextField(key: ValueKey('draft')),
                );
              },
            ),
          ),
        ),
      );
      final field = find.byKey(const ValueKey('draft'));
      await tester.enterText(field, 'Keep this draft');
      final original = tester.state(field);
      update(() => open = true);
      await tester.pumpAndSettle();
      update(() => open = false);
      await tester.pumpAndSettle();
      expect(tester.state(field), same(original));
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
