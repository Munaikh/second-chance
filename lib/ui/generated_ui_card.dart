import 'package:flutter/material.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/core/history_comparison.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/forecast.dart';
import 'package:second_chance/ui/history_comparison.dart';

class GeneratedUiCard extends StatefulWidget {
  const GeneratedUiCard({super.key, required this.artifact});
  final Map<String, Object?> artifact;

  @override
  State<GeneratedUiCard> createState() => _GeneratedUiCardState();
}

class _GeneratedUiCardState extends State<GeneratedUiCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _goalName = TextEditingController();
  final _goalTarget = TextEditingController();
  final _checked = <String>{};
  bool _initialized = false, _busy = false;
  double _income = 0, _expense = 0, _saving = 0;
  String? _error;

  List<Map<String, dynamic>> get _components =>
      (widget.artifact['components'] as List? ?? [])
          .take(8)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  bool get _current =>
      AppScope.of(context).profile.id == widget.artifact['profileId'];
  bool get _enabled {
    final state = AppScope.of(context);
    return _current &&
        !_busy &&
        !state.isGenerating &&
        state.companion.phase != CompanionPhase.connecting &&
        state.companion.phase != CompanionPhase.thinking;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final state = AppScope.of(context);
    _income = state.scenario.incomePercentChange.clamp(-40, 40);
    _expense = (state.scenario.unexpectedExpensePence / 100).clamp(0, 400);
    _saving = (state.scenario.weeklySavingPence / 100).clamp(0, 40);
    final form = _components.where((item) => item['type'] == 'goal_form');
    final values = form.isEmpty ? <String, dynamic>{} : form.first;
    _goalName.text = values['title']?.toString() ?? state.goal?.title ?? '';
    _goalTarget.text =
        values['target_gbp']?.toString() ??
        (state.goal == null ? '' : (state.goal!.targetPence / 100).toString());
  }

  @override
  void dispose() {
    _goalName.dispose();
    _goalTarget.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_enabled) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _perform(String name, Map<String, dynamic> parameters) async {
    if (!mounted || !_current) return;
    final result = await AppScope.of(context).companion
        .performAction(name, parameters);
    if (result['ok'] != true && mounted) {
      setState(
        () => _error =
            result['message']?.toString() ??
            result['summary']?.toString() ??
            'Please try again.',
      );
    }
  }

  Future<void> _saveGoal() => _run(() async {
    final title = _goalName.text.trim();
    final input = _goalTarget.text.trim();
    final target = double.tryParse(input);
    if (title.isEmpty ||
        title.length > 60 ||
        !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(input) ||
        target == null ||
        !target.isFinite ||
        target < 1 ||
        target > 100000) {
      setState(
        () => _error = 'Enter a goal name and an amount from £1 to £100,000, with up to 2 decimal places.',
      );
      return;
    }
    final goal = AppScope.of(context).goal;
    final replacing =
        goal != null &&
        (goal.title != title || goal.targetPence != (target * 100).round());
    if (replacing) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update your savings goal?'),
          content: Text(
            'Your recorded ${formatPence(goal.savedPence)} will be kept. No money will move.',
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep current goal'),
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update goal'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || !_current) return;
    }
    await _perform('set_emergency_goal', {
      'title': title,
      'target_gbp': target,
      if (replacing) 'replace_existing': true,
    });
  });

  Widget _metric(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );

  Widget _metrics(String source) {
    final state = AppScope.of(context);
    if (source == 'history') {
      final history = HistoryComparison.fromProfile(state.profile);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metric(
            'Reconstructed ending estimate',
            formatPence(history.expected.endingBalancePence),
          ),
          _metric(
            'Synthetic actual ending balance',
            formatPence(history.actual.endingBalancePence),
          ),
          _metric('Difference', formatPence(history.endingVariancePence)),
          const Text('10 Oct–6 Nov 2026 · synthetic demo records'),
        ],
      );
    }
    if (source == 'goal') {
      final goal = state.goal;
      if (goal == null) return const Text('No savings goal saved yet.');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(goal.title, style: Theme.of(context).textTheme.titleMedium),
          _metric(
            'Recorded savings',
            '${formatPence(goal.savedPence)} of ${formatPence(goal.targetPence)}',
          ),
          LinearProgressIndicator(
            value: goal.progress,
            minHeight: 7,
            semanticsLabel: 'Recorded savings progress',
          ),
        ],
      );
    }
    final forecast = state.forecast;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metric(
          'Projected low · ${formatDate(forecast.lowestDay.date)}',
          formatPence(forecast.lowestDay.balancePence),
        ),
        _metric(
          'Closing balance · ${formatDate(forecast.days.last.date)}',
          formatPence(forecast.endingBalancePence),
        ),
        _metric(
          'First projected shortfall',
          forecast.firstShortfall == null
              ? 'None in the next 30 days'
              : '${formatPence(forecast.shortfallPence)} · ${formatDate(forecast.firstShortfall!.date)}',
        ),
        const Text('Future amounts and dates are estimates.'),
      ],
    );
  }

  Widget _slider(
    String label,
    String key,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> changed, {
    bool percent = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label · ${percent ? '${value.round()}%' : formatPence((value * 100).round())}',
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Slider(
          key: ValueKey(key),
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: _enabled ? changed : null,
          semanticFormatterCallback: (value) =>
              percent ? '${value.round()} percent' : '${value.round()} pounds',
        ),
      ),
    ],
  );

  Widget _component(Map<String, dynamic> item, int index) {
    final state = AppScope.of(context);
    switch (item['type']) {
      case 'text':
        return Text(item['text']?.toString() ?? '');
      case 'metrics':
        return _metrics(item['source']?.toString() ?? 'forecast');
      case 'chart':
        return item['source'] == 'history'
            ? ExpectedActualComparison(profile: state.profile)
            : ForecastChart(
                forecast: state.forecast,
                baseline: state.hasScenario ? state.baseline : null,
              );
      case 'scenario_controls':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _slider(
              'Earnings change',
              'gen_ui_income',
              _income,
              -40,
              40,
              16,
              (value) => setState(() => _income = value),
              percent: true,
            ),
            _slider(
              'Unexpected bill',
              'gen_ui_expense',
              _expense,
              0,
              400,
              16,
              (value) => setState(() => _expense = value),
            ),
            _slider(
              'Spend less each week',
              'gen_ui_saving',
              _saving,
              0,
              40,
              8,
              (value) => setState(() => _saving = value),
            ),
            Text(
              'Extra bills land on 10 Nov. Reductions apply to planned flexible costs.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('gen_ui_apply_scenario'),
              onPressed: _enabled
                  ? () => _run(
                      () => _perform('update_scenario', {
                        'income_change_percent': _income,
                        'unexpected_expense_gbp': _expense,
                        'weekly_spending_reduction_gbp': _saving,
                      }),
                    )
                  : null,
              child: const Text('Apply scenario'),
            ),
          ],
        );
      case 'goal_form':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('gen_ui_goal_title'),
              controller: _goalName,
              enabled: _enabled,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Goal name'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('gen_ui_goal_target'),
              controller: _goalTarget,
              enabled: _enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Target amount',
                prefixText: '£ ',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('gen_ui_goal_save'),
              onPressed: _enabled ? _saveGoal : null,
              child: const Text('Save savings goal'),
            ),
          ],
        );
      case 'checklist':
        final items = item['items'] as List? ?? [];
        return Column(
          children: [
            for (var n = 0; n < items.length; n++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(items[n].toString()),
                value: _checked.contains('$index:$n'),
                onChanged: _enabled
                    ? (checked) => setState(() {
                        checked == true
                            ? _checked.add('$index:$n')
                            : _checked.remove('$index:$n');
                      })
                    : null,
              ),
          ],
        );
      case 'choices':
        final choices = (item['options'] as List? ?? [])
            .whereType<Map>()
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var n = 0; n < choices.length; n++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  key: ValueKey('gen_ui_choice_$n'),
                  onPressed: _enabled
                      ? () => _run(
                          () => state.companion.sendText(
                            choices[n]['prompt'].toString(),
                          ),
                        )
                      : null,
                  child: Text(
                    choices[n]['label'].toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      case 'action':
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: ValueKey('gen_ui_action_$index'),
            onPressed: _enabled
                ? () => _run(
                    () => state.companion.sendText(item['prompt'].toString()),
                  )
                : null,
            child: Text(item['label'].toString(), textAlign: TextAlign.center),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListenableBuilder(
      listenable: AppScope.of(context).companion,
      builder: (context, _) {
        final components = _components;
        return Column(
          key: const ValueKey('gen_ui_card'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.artifact['title']?.toString() ?? 'Your money',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!_current)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'This panel belongs to an earlier profile. Ask Cloudy for a new one.',
                ),
              )
            else ...[
              if (widget.artifact['description'] case final String description)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(description),
                ),
              for (var n = 0; n < components.length; n++)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _component(components[n], n),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Working…',
                    semanticsLabel: 'Cloudy is completing your action',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Synthetic demo · calculated from your selected profile',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }
}
