import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/ui/cloudy.dart';

void main() {
  testWidgets(
    'Cloudy loads the real animation, changes expression ranges and honours reduced motion',
    (tester) async {
      final composition = await tester.runAsync(
        () => AssetLottie('assets/raise_cloud.json').load(),
      );
      expect(composition, isNotNull);
      expect(composition!.layers, isNotEmpty);
      expect(composition.frameRate, 60);
      expect(composition.endFrame, closeTo(120, .02));

      Future<void> showPhase(
        CompanionPhase phase, {
        bool reducedMotion = false,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reducedMotion),
                child: Center(
                  child: Cloudy(key: const ValueKey('cloudy'), phase: phase),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await showPhase(CompanionPhase.idle);
      final animation = tester.widget<Lottie>(find.byType(Lottie));
      expect(animation.composition, same(composition));
      final controller = animation.controller! as AnimationController;
      expect(controller.isAnimating, isTrue);
      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.value, inExclusiveRange(0, .5));

      await showPhase(CompanionPhase.listening);
      expect(
        tester.widget<Lottie>(find.byType(Lottie)).controller,
        same(controller),
      );
      expect(controller.value, inInclusiveRange(.5, .749));
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.value, inExclusiveRange(.5, .75));

      await showPhase(CompanionPhase.speaking);
      expect(controller.value, inInclusiveRange(.75, .999));
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.value, inExclusiveRange(.75, 1));

      await showPhase(CompanionPhase.speaking, reducedMotion: true);
      expect(controller.isAnimating, isFalse);
      expect(controller.value, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(controller.value, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
