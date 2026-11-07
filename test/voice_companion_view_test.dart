import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/app_state.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/voice_companion_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Voice extends CompanionController {
  _Voice() : super(agentId: '');
  bool active = false;
  bool muted = false;
  int starts = 0;
  int ends = 0;
  @override
  bool get isVoiceActive => active;
  @override
  bool get isMuted => muted;
  @override
  Future<void> startVoice() async {
    starts++;
    active = true;
    phase = CompanionPhase.listening;
    notifyListeners();
  }

  @override
  Future<void> toggleMute() async {
    muted = !muted;
    notifyListeners();
  }

  @override
  Future<void> endSession({bool preparingVoice = false}) async {
    ends++;
    active = false;
    phase = CompanionPhase.idle;
    notifyListeners();
  }
}

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('Voice controls and transcript fit phone at ${scale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final voice = _Voice()
        ..active = true
        ..phase = CompanionPhase.listening;
      var muted = 0, ended = 0, chatted = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 281,
                  child: VoiceCompanionPanel(
                    companion: voice,
                    onMute: () => muted++,
                    onEnd: () => ended++,
                    onChat: () => chatted++,
                    transcript: ListView(
                      children: const [Text('Your transcript stays here')],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (final key in ['voice_mute', 'voice_end', 'voice_chat']) {
        final button = find.byKey(ValueKey(key));
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        await tester.tap(button);
      }
      expect([muted, ended, chatted], [1, 1, 1]);
      expect(find.text('Your transcript stays here'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      voice.dispose();
    });
  }

  testWidgets('Connecting disables mute but keeps End and Chat available', (
    tester,
  ) async {
    final voice = _Voice()..phase = CompanionPhase.connecting;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceCompanionPanel(
            companion: voice,
            transcript: const SizedBox(),
            onMute: () {},
            onEnd: () {},
            onChat: () {},
          ),
        ),
      ),
    );
    final mute = find.descendant(
      of: find.byKey(const ValueKey('voice_mute')),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(mute).onPressed, isNull);
    expect(find.text('Connecting to Cloudy…'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('voice_chat')).hitTestable(),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    voice.dispose();
  });

  testWidgets(
    'Voice and chat share one session and preserve the unsent draft',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      SharedPreferences.setMockInitialValues({});
      final voice = _Voice();
      final state = AppState(
        await SharedPreferences.getInstance(),
        companion: voice,
      );
      await voice.sendText('Help with my bills');
      final conversationLength = voice.messages.length;
      expect(conversationLength, greaterThan(0));
      await tester.pumpWidget(SecondChanceApp(state: state));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('chat_input')),
        'My unsent thought',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('start_voice')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('voice_companion_panel')),
        findsOneWidget,
      );
      expect(voice.starts, 1);
      final endedBeforeChat = voice.ends;
      await tester.tap(find.byKey(const ValueKey('voice_chat')));
      await tester.pump();
      expect(find.byKey(const ValueKey('voice_companion_panel')), findsNothing);
      expect(find.text('My unsent thought'), findsOneWidget);
      expect(voice.ends, endedBeforeChat);
      await tester.tap(find.byKey(const ValueKey('start_voice')));
      await tester.pump();
      expect(voice.starts, 1);
      expect(voice.messages.length, conversationLength);
      await tester.tap(find.byKey(const ValueKey('voice_mute')));
      await tester.pump();
      expect(voice.muted, isTrue);
      await tester.tap(find.byKey(const ValueKey('voice_end')));
      await tester.pump();
      expect(voice.active, isFalse);
      expect(find.byKey(const ValueKey('voice_companion_panel')), findsNothing);
      expect(find.text('My unsent thought'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      final save = state.persist();
      await tester.pump();
      await save;
      state.dispose();
    },
  );
}
