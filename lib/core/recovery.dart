import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GuidanceSource {
  const GuidanceSource(this.title, this.url, this.excerpt);
  final String title;
  final String url;
  final String excerpt;
  factory GuidanceSource.fromJson(Map<String, dynamic> json) => GuidanceSource(
    json['title'] as String,
    json['url'] as String,
    json['excerpt'] as String? ?? '',
  );
}

class RecoveryStep {
  const RecoveryStep(this.id, this.title, this.detail);
  final String id;
  final String title;
  final String detail;
  factory RecoveryStep.fromJson(Map<String, dynamic> json) => RecoveryStep(
    json['id'].toString(),
    json['title'] as String,
    json['detail'] as String,
  );
}

class RecoveryPlan {
  RecoveryPlan(this.json) {
    if (json['mode'] != 'live_n8n' ||
        title.trim().isEmpty ||
        summary.trim().isEmpty ||
        steps.isEmpty ||
        draftBody.trim().isEmpty ||
        draftSubject.trim().isEmpty ||
        recipient.trim().isEmpty ||
        evidence.isEmpty ||
        knownFacts.isEmpty ||
        assumptions.isEmpty ||
        sources.isEmpty ||
        (json['workflow'] as Map)['engine'] != 'n8n' ||
        (json['workflow'] as Map)['executionId'] == null) {
      throw const FormatException('Incomplete recovery plan');
    }
    for (final source in sources) {
      final uri = Uri.tryParse(source.url);
      if (source.title.trim().isEmpty ||
          uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty) {
        throw const FormatException('Invalid guidance source');
      }
    }
  }
  final Map<String, dynamic> json;
  String get title => json['title'] as String;
  String get summary => json['summary'] as String;
  List<RecoveryStep> get steps => (json['steps'] as List)
      .map((e) => RecoveryStep.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  List<GuidanceSource> get sources => (json['sources'] as List)
      .map((e) => GuidanceSource.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  List<String> get evidence => List<String>.from(json['evidence'] as List);
  List<String> get knownFacts => List<String>.from(json['knownFacts'] as List);
  List<String> get assumptions =>
      List<String>.from(json['assumptions'] as List);
  String get draftBody => (json['draft'] as Map)['body'] as String;
  String get draftSubject => (json['draft'] as Map)['subject'] as String;
  String get recipient => (json['draft'] as Map)['recipient'] as String;
  String get executionId => (json['workflow'] as Map)['executionId'].toString();
}

class RecoveryService {
  RecoveryService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8787'
        : 'http://127.0.0.1:8787';
  }

  Future<RecoveryPlan> generate(Map<String, Object?> request) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/recovery'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request),
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) {
        throw const RecoveryException(
          'The support service is taking a break. Your details are safe here. Try again in a moment.',
        );
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['mode'] != 'live_n8n' ||
          json['draft'] is! Map ||
          json['steps'] is! List) {
        throw const RecoveryException(
          'We couldn’t read the plan. Please try again.',
        );
      }
      return RecoveryPlan(json);
    } on RecoveryException {
      rethrow;
    } on FormatException {
      throw const RecoveryException(
        'We couldn’t read the plan. Your note is still here. Please try again.',
      );
    } catch (_) {
      throw const RecoveryException(
        'The support service isn’t connected. You can keep exploring, then retry when it’s available.',
      );
    }
  }

  void dispose() => _client.close();
}

class RecoveryException implements Exception {
  const RecoveryException(this.message);
  final String message;
  @override
  String toString() => message;
}
