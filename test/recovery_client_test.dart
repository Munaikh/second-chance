import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:second_chance/core/recovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<RecoveryException> failWith(Object error, String expectedCode) async {
    final service = RecoveryService(
      client: MockClient((_) async => throw error),
    );
    addTearDown(service.dispose);
    try {
      await service.generate({'note': 'private hardship note'});
      fail('A transport failure must not produce a plan');
    } on RecoveryException catch (failure) {
      expect(failure.code, expectedCode);
      expect(service.lastDiagnostic, contains('code=$expectedCode'));
      expect(
        service.lastDiagnostic,
        contains('host=${Uri.parse(RecoveryService.baseUrl).host}'),
      );
      expect(service.lastDiagnostic, isNot(contains('private hardship note')));
      expect(service.lastDiagnostic, isNot(contains('secret_marker')));
      expect(failure.message, isNot(contains('secret_marker')));
      return failure;
    }
  }

  test(
    'DNS failures have an actionable message and a redacted diagnostic',
    () async {
      final failure = await failWith(
        http.ClientException("Failed host lookup: 'secret_marker'"),
        'dns',
      );
      expect(failure.message, contains('support address'));
      expect(
        failure.message.contains('Tailscale'),
        Uri.parse(RecoveryService.baseUrl).host.endsWith('.ts.net'),
      );
    },
  );

  test('Connection refusal is distinct from DNS failure', () async {
    final failure = await failWith(
      http.ClientException('Connection refused: secret_marker'),
      'unreachable',
    );
    expect(failure.message, contains('reach support'));
  });

  test('TLS errors do not suggest bypassing certificate checks', () async {
    final failure = await failWith(
      Exception('HandshakeException: CERTIFICATE_VERIFY_FAILED secret_marker'),
      'tls',
    );
    expect(failure.message, contains('secure connection'));
    expect(failure.message, isNot(contains('disable')));
  });

  test(
    'Timeouts are identified without exposing the underlying error',
    () async {
      final failure = await failWith(
        TimeoutException('secret_marker'),
        'timeout',
      );
      expect(failure.message, contains('too long'));
    },
  );

  test(
    'HTTP failures record only the status and host, never the body',
    () async {
      final service = RecoveryService(
        client: MockClient((_) async => http.Response('secret_marker', 503)),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.generate({}),
        throwsA(isA<RecoveryException>().having((e) => e.code, 'code', 'http')),
      );
      expect(service.lastDiagnostic, contains('status=503'));
      expect(service.lastDiagnostic, isNot(contains('secret_marker')));
    },
  );

  for (final body in [
    'not JSON',
    jsonEncode({'mode': 'live_n8n'}),
  ]) {
    test(
      'Malformed responses are distinguished from connection failures: $body',
      () async {
        final service = RecoveryService(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        addTearDown(service.dispose);
        await expectLater(
          service.generate({}),
          throwsA(
            isA<RecoveryException>().having(
              (e) => e.code,
              'code',
              'invalid_response',
            ),
          ),
        );
        expect(service.lastDiagnostic, contains('code=invalid_response'));
      },
    );
  }

  test(
    'A successful retry clears the previous diagnostic and returns a live plan',
    () async {
      var attempts = 0;
      final service = RecoveryService(
        client: MockClient((_) async {
          if (attempts++ == 0) throw http.ClientException('Failed host lookup');
          return http.Response(jsonEncode(_plan), 200);
        }),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.generate({}),
        throwsA(isA<RecoveryException>()),
      );
      expect(service.lastDiagnostic, contains('code=dns'));
      expect((await service.generate({})).executionId, 'test-42');
      expect(service.lastDiagnostic, isNull);
    },
  );
}

const _plan = {
  'mode': 'live_n8n',
  'workflow': {'engine': 'n8n', 'executionId': 'test-42'},
  'title': 'Your recovery plan',
  'summary': 'Check the payment dates and request support.',
  'steps': [
    {
      'id': 'check',
      'title': 'Check your budget',
      'detail': 'Confirm upcoming bills.',
    },
  ],
  'draft': {
    'subject': 'Request for support',
    'recipient': 'Support team',
    'body': 'Please review my payment timing.',
  },
  'evidence': ['Recent statements'],
  'knownFacts': ['This is synthetic demo data.'],
  'assumptions': ['Income may change.'],
  'sources': [
    {
      'title': 'MoneyHelper',
      'url': 'https://www.moneyhelper.org.uk/',
      'excerpt': 'Contact your provider early.',
    },
  ],
};
