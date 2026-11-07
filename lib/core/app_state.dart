import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/core/recovery.dart';

class ResilienceGoal {
  ResilienceGoal({
    required this.title,
    required this.targetPence,
    this.savedPence = 0,
  }) {
    if (title.trim().isEmpty || targetPence < 100 || savedPence < 0) {
      throw const FormatException('Invalid saved goal');
    }
  }
  final String title;
  final int targetPence;
  int savedPence;
  double get progress => (savedPence / targetPence).clamp(0, 1);
  Map<String, Object?> toJson() => {
    'title': title,
    'targetPence': targetPence,
    'savedPence': savedPence,
  };
  factory ResilienceGoal.fromJson(Map<String, dynamic> json) => ResilienceGoal(
    title: json['title'] as String,
    targetPence: json['targetPence'] as int,
    savedPence: json['savedPence'] as int,
  );
}

class PositiveAction {
  const PositiveAction(this.label, this.date, {this.amountPence = 0});
  final String label;
  final DateTime date;
  final int amountPence;
  Map<String, Object?> toJson() => {
    'label': label,
    'date': date.toIso8601String(),
    'amountPence': amountPence,
  };
  factory PositiveAction.fromJson(Map<String, dynamic> json) => PositiveAction(
    json['label'] as String,
    DateTime.parse(json['date'] as String),
    amountPence: json['amountPence'] as int,
  );
}

class AppState extends ChangeNotifier {
  AppState(
    this._prefs, {
    RecoveryService? recoveryService,
    CompanionController? companion,
  }) : _recoveryService = recoveryService ?? RecoveryService(),
       companion = companion ?? CompanionController() {
    final raw = _prefs.getString(storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _profileId =
            decoded['selectedProfile'] as String? ?? DemoProfiles.all.first.id;
        _saved.addAll(Map<String, dynamic>.from(decoded['profiles'] as Map));
      } catch (_) {
        persistenceError = 'Saved demo progress couldn’t be read. You can reset it in Demo settings.';
      }
    }
    _loadProfile();
  }
  static const storageKey = 'second_chance.demo.v1';
  final SharedPreferences _prefs;
  final RecoveryService _recoveryService;
  final CompanionController companion;
  final Map<String, dynamic> _saved = {};
  String _profileId = DemoProfiles.all.first.id;
  DemoProfile get profile => DemoProfiles.all.firstWhere(
    (p) => p.id == _profileId,
    orElse: () => DemoProfiles.all.first,
  );
  Scenario scenario = const Scenario();
  ResilienceGoal? goal;
  List<PositiveAction> actions = [];
  RecoveryPlan? recovery;
  String draftBody = '';
  String draftSubject = '';
  String hardship = 'income_drop';
  String supportNote = '';
  String? recoveryError;
  String? persistenceError;
  bool isGenerating = false;
  Future<void> _saveQueue = Future.value();
  Forecast get baseline => FinanceEngine.forecast(profile);
  Forecast get forecast => FinanceEngine.forecast(profile, scenario: scenario);
  bool get hasScenario =>
      scenario.incomePercentChange != 0 ||
      scenario.unexpectedExpensePence != 0 ||
      scenario.weeklySavingPence != 0;
  int get shortfallPence => forecast.shortfallPence;
  bool get hasReviewedCredit =>
      actions.any((a) => a.label == 'Reviewed my credit report');

  void _loadProfile() {
    try {
      _restoreProfile();
    } catch (_) {
      _saved.remove(profile.id);
      _restoreProfile();
      persistenceError = 'Saved demo progress couldn’t be read. You can reset it in Demo settings.';
    }
  }

  void _restoreProfile() {
    final value = _saved[profile.id];
    final data = value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
    goal = data['goal'] is Map
        ? ResilienceGoal.fromJson(
            Map<String, dynamic>.from(data['goal'] as Map),
          )
        : null;
    actions = (data['actions'] as List? ?? [])
        .map(
          (a) => PositiveAction.fromJson(Map<String, dynamic>.from(a as Map)),
        )
        .toList();
    recovery = data['recovery'] is Map
        ? RecoveryPlan(Map<String, dynamic>.from(data['recovery'] as Map))
        : null;
    draftBody = data['draftBody'] as String? ?? recovery?.draftBody ?? '';
    draftSubject =
        data['draftSubject'] as String? ?? recovery?.draftSubject ?? '';
    supportNote = data['supportNote'] as String? ?? '';
    hardship = data['hardship'] as String? ?? 'income_drop';
    scenario = const Scenario();
    recoveryError = null;
    updateCompanionContext();
  }

  void updateCompanionContext() {
    companion.updateContext({
      'profile': profile.toJson(),
      'forecast': forecast.toJson(),
      'baselineForecast': baseline.toJson(),
      'profileName': profile.name,
      'cashBalance': formatPence(profile.openingBalancePence, decimals: true),
      'shortfallPence': shortfallPence,
      'shortfallDate': forecast.firstShortfall?.date.toIso8601String(),
      'lowestBalancePence': forecast.lowestDay.balancePence,
      'lowestDate': forecast.lowestDay.date.toIso8601String(),
      'maximumShortfallPence': math.max(0, -forecast.lowestDay.balancePence),
      'causes': forecast.pressureCauses,
      'scenario': {
        'incomePercentChange': scenario.incomePercentChange,
        'unexpectedExpensePence': scenario.unexpectedExpensePence,
        'weeklySavingPence': scenario.weeklySavingPence,
      },
      'goal': goal?.toJson(),
      'recoveryAvailable': recovery != null,
      'dataStatus': 'Synthetic UK demo. Forecast as of 7 November 2026; closing daily balances, not guarantees.',
      'summary': forecast.firstShortfall == null
          ? '${profile.name}: no closing shortfall in the next 30 days. Lowest balance ${formatPence(forecast.lowestDay.balancePence)} on ${formatDate(forecast.lowestDay.date)}.'
          : '${profile.name}: first shortfall ${formatPence(forecast.shortfallPence)} on ${formatDate(forecast.firstShortfall!.date)}. Lowest balance ${formatPence(forecast.lowestDay.balancePence)} on ${formatDate(forecast.lowestDay.date)}. These dates and amounts can differ.',
    });
  }

  Future<void> selectProfile(String id) async {
    if (id == profile.id || isGenerating) return;
    await persist();
    await companion.endSession();
    _profileId = id;
    _loadProfile();
    notifyListeners();
    await persist();
  }

  void setScenario(Scenario value) {
    scenario = value;
    updateCompanionContext();
    notifyListeners();
  }

  Future<void> createGoal(String title, int targetPence) async {
    if (targetPence < 100 || title.trim().isEmpty) {
      throw ArgumentError('Choose a name and a target of at least £1.');
    }
    goal = ResilienceGoal(
      title: title.trim(),
      targetPence: targetPence,
      savedPence: profile.goalSavedPence,
    );
    actions.add(PositiveAction('Created my emergency buffer', DateTime.now()));
    updateCompanionContext();
    notifyListeners();
    await persist();
  }

  Future<void> recordSaving(int pence) async {
    if (goal == null || pence <= 0 || pence > 1000000) {
      throw ArgumentError('Enter an amount between £0.01 and £10,000.');
    }
    goal!.savedPence += pence;
    actions.add(
      PositiveAction(
        'Set aside ${formatPence(pence, decimals: true)}',
        DateTime.now(),
        amountPence: pence,
      ),
    );
    updateCompanionContext();
    notifyListeners();
    await persist();
  }

  Future<void> recordAction(String label) async {
    if (actions.any((a) => a.label == label)) return;
    actions.add(PositiveAction(label, DateTime.now()));
    notifyListeners();
    await persist();
  }

  Future<void> generateRecovery() async {
    if (isGenerating) return;
    isGenerating = true;
    recoveryError = null;
    notifyListeners();
    try {
      final result = await _recoveryService.generate({
        'profile': profile.toJson(),
        'forecast': {
          'shortfallPence': shortfallPence,
          'shortfallDate': forecast.firstShortfall?.date.toIso8601String(),
          'lowestBalancePence': forecast.lowestDay.balancePence,
          'causes': forecast.pressureCauses,
        },
        'hardship': hardship,
        'note': supportNote.trim(),
      });
      recovery = result;
      draftBody = result.draftBody;
      draftSubject = result.draftSubject;
      await recordAction('Made a recovery plan');
      updateCompanionContext();
      await persist();
    } on RecoveryException catch (error) {
      recoveryError = error.message;
    } finally {
      isGenerating = false;
      notifyListeners();
    }
  }

  Future<void> saveDraft({String? body, String? subject}) async {
    draftBody = body ?? draftBody;
    draftSubject = subject ?? draftSubject;
    await persist();
  }

  Future<void> persist() {
    _saved[profile.id] = {
      'goal': goal?.toJson(),
      'actions': actions.map((a) => a.toJson()).toList(),
      'recovery': recovery?.json,
      'draftBody': draftBody,
      'draftSubject': draftSubject,
      'supportNote': supportNote,
      'hardship': hardship,
    };
    final snapshot = jsonEncode({
      'selectedProfile': profile.id,
      'profiles': _saved,
    });
    _saveQueue = _saveQueue.then((_) async {
      try {
        final saved = await _prefs.setString(storageKey, snapshot);
        persistenceError = saved
            ? null
            : 'Progress couldn’t be saved. Tap Retry before closing the app.';
      } catch (_) {
        persistenceError =
            'Progress couldn’t be saved. Tap Retry before closing the app.';
      }
      notifyListeners();
    });
    return _saveQueue;
  }

  Future<void> resetDemo() async {
    if (isGenerating) return;
    await companion.endSession();
    await _saveQueue;
    await _prefs.remove(storageKey);
    _saved.clear();
    _profileId = DemoProfiles.all.first.id;
    _loadProfile();
    persistenceError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    companion.dispose();
    _recoveryService.dispose();
    super.dispose();
  }
}
