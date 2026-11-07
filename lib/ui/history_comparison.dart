import 'package:flutter/material.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/core/history_comparison.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/forecast.dart';

class ExpectedActualComparison extends StatelessWidget {
  const ExpectedActualComparison({super.key, required this.profile});
  final DemoProfile profile;

  @override
  Widget build(BuildContext context) {
    final comparison = HistoryComparison.fromProfile(profile);
    final variance = comparison.endingVariancePence;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final expected = _EndingAmount(
      'Reconstructed estimate',
      comparison.expected.endingBalancePence,
    );
    final actual = _EndingAmount(
      'Synthetic actual',
      comparison.actual.endingBalancePence,
    );
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expected vs actual',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '10 Oct–6 Nov 2026 · GBP',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const Text(
            'Reconstructed from the prior 4 demo weeks. Actuals are synthetic records.',
          ),
          const SizedBox(height: 18),
          ForecastChart(
            forecast: comparison.actual,
            baseline: comparison.expected,
            primaryLabel: 'Actual',
            baselineLabel: 'Expected',
          ),
          const SizedBox(height: 18),
          Text(
            'Ending balances · 6 Nov',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (largeText)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [expected, const SizedBox(height: 16), actual],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: expected),
                const SizedBox(width: 16),
                Expanded(child: actual),
              ],
            ),
          const SizedBox(height: 18),
          Text(
            variance == 0
                ? '£0 difference in ending balance'
                : '${formatPence(variance.abs())} ${variance < 0 ? 'below' : 'above'} the reconstructed estimate',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Both start at ${formatPence(comparison.openingBalancePence)} on 10 Oct. This simple 28-day replay can shift monthly payment dates. It is not a saved forecast or a measure of prediction accuracy.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Future actuals aren’t available in this demo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _EndingAmount extends StatelessWidget {
  const _EndingAmount(this.label, this.pence);
  final String label;
  final int pence;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6),
      Text(
        formatPence(pence),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    ],
  );
}
