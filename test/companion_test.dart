import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/companion.dart';

void main() {
  final context = <String, Object?>{
    'profile': {'id': 'maya', 'name': 'Maya'},
    'forecast': {
      'shortfallPence': 18000,
      'shortfallDate': '2026-11-12',
      'causes': ['Rent falls before invoice income'],
    },
    'goal': {'savedPence': 6500, 'targetPence': 50000},
  };

  test(
    'calculated fallback uses supplied forecast without inventing figures',
    () {
      final reply = calculatedCompanionReply('Why will I be short?', context);
      expect(reply, contains('£180'));
      expect(reply, contains('2026-11-12'));
      expect(reply, contains('Rent falls before invoice income'));
    },
  );

  test('fallback recovery action never claims submission or eligibility', () {
    final reply = calculatedCompanionReply('What is my next step?', context);
    expect(reply, contains('nothing is sent'));
    expect(reply, contains('not guaranteed'));
  });

  test('savings and credit guidance uses meaningful, affordable actions', () {
    expect(
      calculatedCompanionReply('My savings goal?', context),
      contains('£65 towards £500'),
    );
    expect(
      calculatedCompanionReply('Build credit?', context),
      contains('do not need to borrow'),
    );
  });

  test('no-config text is clearly identified as calculated fallback', () async {
    final controller = CompanionController(agentId: '');
    controller.updateContext(context);
    await controller.sendText('Why will I be short?');
    expect(controller.messages.length, 2);
    expect(controller.messages.last.isFallback, isTrue);
    expect(controller.modeLabel, 'Calculated demo guidance');
    expect(controller.messages.last.text, contains('£180'));
    controller.dispose();
  });
  test(
    'model receives exact GBP values while the ledger retains integer pence',
    () {
      final formatted = companionContextForModel(context) as Map;
      expect((formatted['forecast'] as Map)['shortfallGBP'], '£180');
      expect(
        (formatted['forecast'] as Map).containsKey('shortfallPence'),
        isFalse,
      );
      expect((context['forecast'] as Map)['shortfallPence'], 18000);
    },
  );

  test('flat app context and profile changes cannot leak another persona transcript', () async {
    final controller = CompanionController(agentId: '');
    controller.updateContext({
      'profile': {'id': 'maya', 'name': 'Maya'},
      'forecast': <String, Object?>{},
      'shortfallPence': 18000,
      'shortfallDate': '2026-11-12T00:00:00.000',
      'causes': ['Rent before invoice'],
    });
    await controller.sendText('Why am I short?');
    expect(controller.messages.last.text, contains('£180'));
    controller.updateContext({
      'profile': {'id': 'daniel', 'name': 'Daniel'},
      'forecast': <String, Object?>{},
      'shortfallPence': 0,
    });
    expect(controller.messages, isEmpty);
    controller.dispose();
  });

  test('first negative day is distinct from a later maximum gap', () {
    final reply = calculatedCompanionReply('Why am I short?', {
      'profile': {'name': 'Maya'},
      'shortfallPence': 10000,
      'maximumShortfallPence': 18000,
      'shortfallDate': '2026-11-12',
      'lowestDate': '2026-11-14',
    });
    expect(reply, contains('first falls below zero on 2026-11-12'));
    expect(reply, contains('largest projected gap is £180 on 2026-11-14'));
  });

  test(
    'microphone denial explains settings and preserves text alternative',
    () {
      final message = companionVoiceErrorMessage(
        'NotAllowedError: Permission denied',
      );
      expect(message, contains('Settings'));
      expect(message, contains('continue by text'));
      expect(
        companionVoiceErrorMessage(TimeoutException('')),
        contains('too long'),
      );
    },
  );
}
