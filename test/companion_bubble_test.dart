import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/ui/assistant_widgets.dart';

void main() {
  testWidgets(
    'Voice style tags stay out of assistant text while draft details remain',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CompanionBubble(
              CompanionMessage(
                role: 'assistant',
                text:
                    '[calm] Contact [provider name] for a [slow] payment plan.',
              ),
            ),
          ),
        ),
      );
      expect(
        find.text('Contact [provider name] for a payment plan.'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CompanionBubble(
              CompanionMessage(
                role: 'user',
                text: '[calm] Keep my original wording.',
              ),
            ),
          ),
        ),
      );
      expect(find.text('[calm] Keep my original wording.'), findsOneWidget);
    },
  );
}
