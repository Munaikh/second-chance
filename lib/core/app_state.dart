import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/core/history_comparison.dart';
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
    this.companion.onToolCall = performCompanionAction;
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
  bool _companionActionRunning = false;
  bool _disposed = false;
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
    if (_disposed) return;
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
    if (id == profile.id || isGenerating || _companionActionRunning) return;
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
    final previousGoal = goal;
    goal = ResilienceGoal(
      title: title.trim(),
      targetPence: targetPence,
      savedPence: previousGoal?.savedPence ?? profile.goalSavedPence,
    );
    if (previousGoal == null) {
      actions.add(
        PositiveAction('Created my emergency buffer', DateTime.now()),
      );
    }
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
    if (isGenerating || _disposed) return;
    final originatingProfile = profile.id;
    final originalBody = draftBody;
    final originalSubject = draftSubject;
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
      if (_disposed || profile.id != originatingProfile) return;
      if (draftBody != originalBody || draftSubject != originalSubject) {
        recoveryError = 'Your draft changed while the plan was being prepared. Your edits are safe; review them before trying again.';
        return;
      }
      recovery = result;
      draftBody = result.draftBody;
      draftSubject = result.draftSubject;
      await recordAction('Made a recovery plan');
      updateCompanionContext();
      await persist();
    } on RecoveryException catch (error) {
      if (!_disposed && profile.id == originatingProfile) {
        recoveryError = error.message;
      }
    } finally {
      isGenerating = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<Map<String, Object?>> performCompanionAction(
    String name,
    Map<String, dynamic> parameters,
  ) async {
    if (_disposed) {
      return _actionFailure(name, 'unavailable', 'This session has ended.');
    }
    if (_companionActionRunning || isGenerating) {
      return _actionFailure(
        name,
        'busy',
        'Another action is still running. Please wait for its result.',
      );
    }
    _companionActionRunning = true;
    final originatingProfile = profile.id;
    try {
      final Map<String, Object?> result;
      switch (name) {
        case 'update_scenario':
          _validateKeys(parameters, const {
            'income_change_percent',
            'unexpected_expense_gbp',
            'weekly_spending_reduction_gbp',
            'reset',
          });
          final reset = _boolean(parameters, 'reset');
          final income = parameters.containsKey('income_change_percent')
              ? _number(
                  parameters['income_change_percent'],
                  'income_change_percent',
                  -40,
                  40,
                ).toDouble()
              : scenario.incomePercentChange;
          final expense = parameters.containsKey('unexpected_expense_gbp')
              ? _money(
                  parameters['unexpected_expense_gbp'],
                  'unexpected_expense_gbp',
                  0,
                  400,
                )
              : scenario.unexpectedExpensePence;
          final saving = parameters.containsKey('weekly_spending_reduction_gbp')
              ? _money(
                  parameters['weekly_spending_reduction_gbp'],
                  'weekly_spending_reduction_gbp',
                  0,
                  40,
                )
              : scenario.weeklySavingPence;
          if (parameters.isNotEmpty) {
            setScenario(
              reset
                  ? const Scenario()
                  : Scenario(
                      incomePercentChange: income,
                      unexpectedExpensePence: expense,
                      weeklySavingPence: saving,
                    ),
            );
          }
          final calculated = forecast;
          final lead = parameters.isEmpty
              ? 'Here is your current scenario.'
              : 'I updated your scenario.';
          result = _actionSuccess(
            name,
            calculated.firstShortfall == null
                ? '$lead No negative daily closing balance is projected.'
                : '$lead The first projected shortfall is ${formatPence(calculated.shortfallPence)} on ${formatDate(calculated.firstShortfall!.date)}.',
            {
              'type': 'forecast',
              'scenario': scenario.toJson(),
              'forecast': calculated.toJson(),
              'unexpectedExpenseDate': '2026-11-10',
              'assumptions': FinanceEngine.assumptions,
            },
          );
        case 'compare_history':
          _validateKeys(parameters, const {});
          final comparison = HistoryComparison.fromProfile(profile);
          const disclosure =
              'The estimate is reconstructed from the prior four demo weeks. Actuals are synthetic records, not real customer data or forecast accuracy evidence.';
          result = _actionSuccess(
            name,
            'From 10 October to 6 November, the reconstructed estimate ends at ${formatPence(comparison.expected.endingBalancePence)} and synthetic actuals end at ${formatPence(comparison.actual.endingBalancePence)}. $disclosure',
            {
              'type': 'history_comparison',
              'startDate': isoDate(comparison.startDate),
              'endDate': isoDate(comparison.endDate),
              'openingBalancePence': comparison.openingBalancePence,
              'expectedEndingBalancePence':
                  comparison.expected.endingBalancePence,
              'actualEndingBalancePence': comparison.actual.endingBalancePence,
              'variancePence': comparison.endingVariancePence,
              'disclosure': disclosure,
              'futureActualsAvailable': false,
            },
          );
        case 'build_recovery_plan':
          _validateKeys(parameters, const {
            'hardship',
            'note',
            'replace_existing',
          });
          final replace = _boolean(parameters, 'replace_existing');
          final requestedHardship = parameters.containsKey('hardship')
              ? parameters['hardship']
              : hardship;
          if (requestedHardship is! String ||
              !const {
                'income_drop',
                'unexpected_bill',
                'complaint',
              }.contains(requestedHardship)) {
            throw const FormatException(
              'Choose income_drop, unexpected_bill or complaint.',
            );
          }
          final note = parameters.containsKey('note')
              ? parameters['note']
              : supportNote;
          if (note is! String || note.length > 500) {
            throw const FormatException(
              'Keep the support note to 500 characters.',
            );
          }
          if (!replace &&
              (recovery != null ||
                  draftBody.trim().isNotEmpty ||
                  draftSubject.trim().isNotEmpty)) {
            return _actionFailure(
              name,
              'needs_confirmation',
              'You already have a plan or draft. Confirm that you want to replace it; your existing draft is unchanged.',
            );
          }
          hardship = requestedHardship;
          supportNote = note.trim();
          await persist();
          final requestedBody = draftBody;
          final requestedSubject = draftSubject;
          await generateRecovery();
          if (_disposed) {
            return _actionFailure(
              name,
              'unavailable',
              'This session has ended.',
            );
          }
          if (profile.id != originatingProfile) {
            return _actionFailure(
              name,
              'profile_changed',
              'The profile changed. No plan was applied to the new profile.',
            );
          }
          if (recoveryError != null || recovery == null) {
            return _actionFailure(
              name,
              draftBody != requestedBody || draftSubject != requestedSubject
                  ? 'draft_changed'
                  : 'service_unavailable',
              recoveryError ??
                  'The recovery plan could not be prepared. Please try again.',
            );
          }
          final plan = recovery!;
          result = _actionSuccess(name, plan.summary, {
            'type': 'recovery_plan',
            'title': plan.title,
            'summary': plan.summary,
            'executionId': plan.executionId,
            'steps': plan.steps
                .map(
                  (step) => {
                    'id': step.id,
                    'title': step.title,
                    'detail': step.detail,
                  },
                )
                .toList(),
            'sources': plan.sources
                .map(
                  (source) => {
                    'title': source.title,
                    'url': source.url,
                    'excerpt': source.excerpt,
                  },
                )
                .toList(),
            'evidence': plan.evidence,
            'knownFacts': plan.knownFacts,
            'assumptions': plan.assumptions,
            'draft': {
              'subject': draftSubject,
              'body': draftBody,
              'recipient': plan.recipient,
            },
            'draftSubject': draftSubject,
            'draftBody': draftBody,
            'nothingSent': true,
          });
        case 'set_emergency_goal':
          _validateKeys(parameters, const {
            'title',
            'target_gbp',
            'replace_existing',
          });
          final replace = _boolean(parameters, 'replace_existing');
          final title = parameters['title'];
          if (title is! String ||
              title.trim().isEmpty ||
              title.trim().length > 60) {
            throw const FormatException(
              'Choose a goal name from 1 to 60 characters.',
            );
          }
          final target = _money(
            parameters['target_gbp'],
            'target_gbp',
            1,
            100000,
          );
          final unchanged =
              goal?.title == title.trim() && goal?.targetPence == target;
          if (goal != null && !unchanged && !replace) {
            return _actionFailure(
              name,
              'needs_confirmation',
              'You already have a savings goal. Confirm the change; your recorded savings will be kept.',
            );
          }
          if (!unchanged) await createGoal(title.trim(), target);
          result = _actionSuccess(
            name,
            '${goal!.title} is set to ${formatPence(goal!.targetPence)}. Your recorded ${formatPence(goal!.savedPence)} is kept. No money has moved.',
            {
              'type': 'goal',
              ...goal!.toJson(),
              'progress': goal!.progress,
              'nothingTransferred': true,
            },
          );
        default:
          return _actionFailure(
            name,
            'unsupported_action',
            'That action is not available.',
          );
      }
      return result;
    } on FormatException catch (error) {
      return _actionFailure(name, 'invalid_arguments', error.message);
    } on ArgumentError catch (error) {
      return _actionFailure(
        name,
        'invalid_arguments',
        error.message.toString(),
      );
    } finally {
      _companionActionRunning = false;
    }
  }

  Map<String, Object?> _actionSuccess(
    String name,
    String summary,
    Map<String, Object?> artifact,
  ) => companionContextForModel({
    'ok': true,
    'action': name,
    'profileId': profile.id,
    'summary': summary,
    'artifact': {'profileId': profile.id, ...artifact},
    if (name != 'update_scenario') 'persisted': persistenceError == null,
    if (persistenceError != null) 'warning': persistenceError,
  }) as Map<String, Object?>;

  Map<String, Object?> _actionFailure(
    String name,
    String reason,
    String message,
  ) => {
    'ok': false,
    'action': name,
    'profileId': profile.id,
    'reason': reason,
    'message': message,
    'summary': message,
    if (reason == 'needs_confirmation') 'needs_confirmation': true,
  };

  static void _validateKeys(
    Map<String, dynamic> parameters,
    Set<String> allowed,
  ) {
    if (parameters.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException(
        'Unsupported parameters. Scenario extra costs use the fixed demo date, 10 November 2026.',
      );
    }
  }

  static bool _boolean(Map<String, dynamic> parameters, String key) {
    if (!parameters.containsKey(key)) return false;
    final value = parameters[key];
    if (value is! bool) throw FormatException('$key must be true or false.');
    return value;
  }

  static num _number(Object? value, String field, num min, num max) {
    if (value is! num || !value.isFinite || value < min || value > max) {
      throw FormatException(
        '$field must be a finite number from $min to $max.',
      );
    }
    return value;
  }

  static int _money(Object? value, String field, int min, int max) {
    final number = _number(value, field, min, max);
    final parts = number.toString().toLowerCase().split('e');
    final decimal = parts.first.split('.');
    final scale =
        (decimal.length == 2 ? decimal.last.length : 0) -
        (parts.length == 2 ? int.parse(parts.last) : 0);
    final digits = BigInt.parse(decimal.join()) * BigInt.from(100);
    if (scale <= 0) return (digits * BigInt.from(10).pow(-scale)).toInt();
    final divisor = BigInt.from(10).pow(scale);
    return ((digits + divisor ~/ BigInt.two) ~/ divisor).toInt();
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
      if (!_disposed) notifyListeners();
    });
    return _saveQueue;
  }

  Future<void> resetDemo() async {
    if (isGenerating || _companionActionRunning) return;
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
    _disposed = true;
    companion.dispose();
    _recoveryService.dispose();
    super.dispose();
  }
}
