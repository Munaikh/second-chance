import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/companion_page.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/home.dart';
import 'package:second_chance/ui/support.dart';

class ForecastPage extends StatelessWidget {
  const ForecastPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final forecast = state.forecast;
    final scenario = state.scenario;
    return Scaffold(
      appBar: AppBar(title: const Text('Financial time travel')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          const StatusPill(
            '7 Nov – 6 Dec 2026 · estimates',
            icon: CupertinoIcons.calendar,
          ),
          const SizedBox(height: 17),
          Text(
            'See a different\ntomorrow.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Try a change. See what it means for your money.',
            style: TextStyle(color: AppColors.muted(context)),
          ),
          const SizedBox(height: 24),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ForecastMetric(
                        label: 'Original low',
                        day: state.baseline.lowestDay,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ForecastMetric(
                        label: 'Scenario low',
                        day: forecast.lowestDay,
                        highlight: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ForecastChart(
                  forecast: forecast,
                  baseline: state.hasScenario ? state.baseline : null,
                ),
                const SizedBox(height: 12),
                Text(
                  forecast.firstShortfall == null
                      ? 'Your daily closing balance stays above £0 in this scenario.'
                      : 'First shortfall: ${formatPence(-forecast.firstShortfall!.balancePence)} on ${formatDate(forecast.firstShortfall!.date)}.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (state.hasScenario)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Lowest balance changes by ${formatPence(forecast.lowestDay.balancePence - state.baseline.lowestDay.balancePence, decimals: true)}.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'What if…',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                key: const ValueKey('reset_scenario'),
                onPressed: state.hasScenario
                    ? () => state.setScenario(const Scenario())
                    : null,
                child: const Text('Reset'),
              ),
            ],
          ),
          Surface(
            child: Column(
              children: [
                _ScenarioSlider(
                  label: 'My earnings change',
                  valueLabel:
                      '${scenario.incomePercentChange > 0 ? '+' : ''}${scenario.incomePercentChange.round()}%',
                  value: scenario.incomePercentChange,
                  min: -40,
                  max: 40,
                  divisions: 16,
                  sliderKey: 'income_slider',
                  onChanged: (v) => state.setScenario(
                    Scenario(
                      incomePercentChange: v,
                      unexpectedExpensePence: scenario.unexpectedExpensePence,
                      weeklySavingPence: scenario.weeklySavingPence,
                    ),
                  ),
                ),
                Divider(color: AppColors.line(context)),
                _ScenarioSlider(
                  label: 'An unexpected bill',
                  valueLabel: formatPence(scenario.unexpectedExpensePence),
                  value: scenario.unexpectedExpensePence / 100,
                  min: 0,
                  max: 400,
                  divisions: 16,
                  sliderKey: 'expense_slider',
                  onChanged: (v) => state.setScenario(
                    Scenario(
                      incomePercentChange: scenario.incomePercentChange,
                      unexpectedExpensePence: (v * 100).round(),
                      weeklySavingPence: scenario.weeklySavingPence,
                    ),
                  ),
                ),
                Divider(color: AppColors.line(context)),
                _ScenarioSlider(
                  label: 'Spend a little less each week',
                  valueLabel: formatPence(scenario.weeklySavingPence),
                  value: scenario.weeklySavingPence / 100,
                  min: 0,
                  max: 40,
                  divisions: 8,
                  sliderKey: 'saving_slider',
                  onChanged: (v) => state.setScenario(
                    Scenario(
                      incomePercentChange: scenario.incomePercentChange,
                      unexpectedExpensePence: scenario.unexpectedExpensePence,
                      weeklySavingPence: (v * 100).round(),
                    ),
                  ),
                ),
                Text(
                  'Extra bills land on 10 Nov. Spending reductions apply only to flexible costs, up to what’s planned.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What’s behind the dip?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...forecast.pressureCauses.map(
                  (cause) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          CupertinoIcons.circle_filled,
                          size: 5,
                          color: AppColors.accent(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(cause)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Talk through this scenario',
            icon: CupertinoIcons.bubble_left_bubble_right,
            onPressed: () => openPage(
              context,
              const CompanionPage(
                initialQuestion:
                    'Can you explain my forecast and the changes I’ve tried?',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const ValueKey('forecast_support'),
              onPressed: () => openPage(context, const SupportDetailPage()),
              child: const Text('Make a recovery plan'),
            ),
          ),
          const SizedBox(height: 18),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('How this is calculated'),
            children: [
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatPence(forecast.openingBalancePence)} opening\n+ ${formatPence(forecast.totalIncomePence)} expected income\n− ${formatPence(forecast.totalOutgoingsPence)} expected spending\n= ${formatPence(forecast.endingBalancePence)} on 6 Dec',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ...FinanceEngine.assumptions.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          a,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          openPage(context, const DailyBalancesPage()),
                      child: const Text('View every daily balance'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForecastMetric extends StatelessWidget {
  const _ForecastMetric({
    required this.label,
    required this.day,
    this.highlight = false,
  });
  final String label;
  final ForecastDay day;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      Text(
        formatPence(day.balancePence),
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(color: highlight ? AppColors.accent(context) : null),
      ),
      const SizedBox(height: 3),
      Text(formatDate(day.date), style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _ScenarioSlider extends StatelessWidget {
  const _ScenarioSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.sliderKey,
  });
  final String label, valueLabel, sliderKey;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              valueLabel,
              style: TextStyle(
                color: AppColors.accent(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          key: ValueKey(sliderKey),
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          semanticFormatterCallback: (v) =>
              '$label: ${sliderKey == 'income_slider' ? '${v.round()} percent' : '${v.round()} pounds'}',
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class ForecastChart extends StatefulWidget {
  const ForecastChart({
    super.key,
    required this.forecast,
    this.baseline,
    this.compact = false,
  });
  final Forecast forecast;
  final Forecast? baseline;
  final bool compact;
  @override
  State<ForecastChart> createState() => _ForecastChartState();
}

class _ForecastChartState extends State<ForecastChart> {
  int? _index;
  @override
  Widget build(BuildContext context) {
    final days = widget.forecast.days;
    final selected = _index ?? days.indexOf(widget.forecast.lowestDay);
    final index = selected.clamp(0, days.length - 1);
    final day = days[index];
    return Column(
      children: [
        if (!widget.compact)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.circle_fill,
                        color: AppColors.accent(context),
                        size: 8,
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'Your scenario',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (widget.baseline != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.minus,
                          color: AppColors.muted(context),
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        const Flexible(
                          child: Text(
                            'Original',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            onTapDown: widget.compact
                ? null
                : (details) => setState(
                    () => _index =
                        ((details.localPosition.dx / constraints.maxWidth) *
                                (days.length - 1))
                            .round()
                            .clamp(0, days.length - 1),
                  ),
            child: Semantics(
              label:
                  'Forecast chart. Lowest balance ${formatPence(widget.forecast.lowestDay.balancePence)} on ${formatDate(widget.forecast.lowestDay.date)}. Daily closing estimates.',
              image: true,
              child: CustomPaint(
                size: Size(constraints.maxWidth, widget.compact ? 100 : 160),
                painter: _ForecastPainter(
                  days,
                  widget.baseline?.days,
                  AppColors.accent(context),
                  AppColors.line(context),
                  AppColors.muted(context),
                  index,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('7 Nov', style: Theme.of(context).textTheme.bodySmall),
            Text('6 Dec', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        if (!widget.compact) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.canvas(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 5,
              children: [
                Text(
                  '${formatDate(day.date)} · closing',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  formatPence(day.balancePence, decimals: true),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Slider(
            value: index.toDouble(),
            min: 0,
            max: (days.length - 1).toDouble(),
            divisions: days.length - 1,
            semanticFormatterCallback: (v) =>
                '${formatDate(days[v.round()].date)}: ${formatPence(days[v.round()].balancePence)}',
            onChanged: (v) => setState(() => _index = v.round()),
          ),
        ],
      ],
    );
  }
}

class _ForecastPainter extends CustomPainter {
  const _ForecastPainter(
    this.days,
    this.baseline,
    this.color,
    this.grid,
    this.muted,
    this.index,
  );
  final List<ForecastDay> days;
  final List<ForecastDay>? baseline;
  final Color color, grid, muted;
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    final all = [...days, ...?baseline];
    final low = math
        .min(0, all.map((d) => d.balancePence).reduce(math.min))
        .toDouble();
    final high = math
        .max(10000, all.map((d) => d.balancePence).reduce(math.max))
        .toDouble();
    final span = high - low;
    double x(int i) => 5 + i / (days.length - 1) * (size.width - 10);
    double y(int amount) => 8 + (high - amount) / span * (size.height - 20);
    final zero = y(0);
    if (low < 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, zero, size.width, size.height),
        Paint()..color = const Color(0xFFAD6338).withValues(alpha: .06),
      );
    }
    for (var i = 0; i < 3; i++) {
      final dy = 8 + i * (size.height - 20) / 2;
      canvas.drawLine(
        Offset(0, dy),
        Offset(size.width, dy),
        Paint()
          ..color = grid
          ..strokeWidth = .7,
      );
    }
    for (double dx = 0; dx < size.width; dx += 7) {
      canvas.drawLine(
        Offset(dx, zero),
        Offset(math.min(dx + 3, size.width), zero),
        Paint()
          ..color = muted.withValues(alpha: .6)
          ..strokeWidth = 1,
      );
    }
    void drawLine(List<ForecastDay> values, Color line, double stroke) {
      final path = Path()..moveTo(x(0), y(values[0].balancePence));
      for (var i = 1; i < values.length; i++) {
        path.lineTo(x(i), y(values[i - 1].balancePence));
        path.lineTo(x(i), y(values[i].balancePence));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    if (baseline != null) {
      drawLine(baseline!, muted.withValues(alpha: .55), 1.5);
    }
    drawLine(days, color, 2.7);
    canvas.drawCircle(
      Offset(x(index), y(days[index].balancePence)),
      7,
      Paint()..color = color.withValues(alpha: .14),
    );
    canvas.drawCircle(
      Offset(x(index), y(days[index].balancePence)),
      3.5,
      Paint()..color = color,
    );
    final text = TextPainter(
      text: TextSpan(
        text: '£0',
        style: TextStyle(fontSize: 10, color: muted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(size.width - text.width, (zero - 14).clamp(0, size.height - 12)),
    );
  }

  @override
  bool shouldRepaint(_ForecastPainter old) =>
      days != old.days ||
      baseline != old.baseline ||
      color != old.color ||
      index != old.index;
}

class DailyBalancesPage extends StatelessWidget {
  const DailyBalancesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final forecast = AppScope.of(context).forecast;
    return Scaffold(
      appBar: AppBar(title: const Text('Daily balances')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Estimated closing balances',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Opening: ${formatPence(forecast.openingBalancePence)} · 7 Nov 2026',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ...forecast.days.map(
            (day) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Surface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          formatDate(day.date),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          formatPence(day.balancePence, decimals: true),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: day.balancePence < 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                      ],
                    ),
                    ...day.movements.map((e) => LedgerRow(e)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});
  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  bool _history = false;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final entries = _history
        ? state.profile.history.reversed.toList()
        : state.forecast.entries;
    return Scaffold(
      appBar: AppBar(title: const Text('Your money, in detail')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Coming up')),
              ButtonSegment(value: true, label: Text('Past 8 weeks')),
            ],
            selected: {_history},
            onSelectionChanged: (s) => setState(() => _history = s.first),
          ),
          const SizedBox(height: 20),
          Text(
            _history
                ? 'Synthetic history · reconciled to ${formatPence(state.profile.openingBalancePence)}'
                : 'Estimates · current scenario',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          ...entries.map((e) => LedgerRow(e)),
        ],
      ),
    );
  }
}
