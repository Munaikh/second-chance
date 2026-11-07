import 'package:second_chance/core/finance.dart';

class HistoryComparison {
  HistoryComparison._({required this.expected, required this.actual});

  static final DateTime _trainingStart = DateTime(2026, 9, 12);
  static final DateTime _start = DateTime(2026, 10, 10);
  static final DateTime _endExclusive = DateTime(2026, 11, 7);
  static const int windowDays = 28;

  final Forecast expected;
  final Forecast actual;
  // shortcut: these Forecasts are chart-only; add historical metadata before exporting them as JSON.
  DateTime get startDate => _start;
  DateTime get endDate => DateTime(2026, 11, 6);
  int get openingBalancePence => actual.openingBalancePence;
  int get endingVariancePence =>
      actual.endingBalancePence - expected.endingBalancePence;

  factory HistoryComparison.fromProfile(DemoProfile profile) {
    final prior = profile.history.where((entry) => entry.date.isBefore(_start));
    final opening =
        profile.historyOpeningBalancePence +
        prior.fold<int>(0, (sum, entry) => sum + entry.amountPence);
    final expectedEntries = prior
        .where((entry) => !entry.date.isBefore(_trainingStart))
        .map(
          (entry) => LedgerEntry(
            id: 'reconstructed-${entry.id}',
            date: DateTime(
              entry.date.year,
              entry.date.month,
              entry.date.day + windowDays,
            ),
            label: entry.label,
            amountPence: entry.amountPence,
            category: entry.category,
            isEstimate: true,
          ),
        )
        .toList();
    final actualEntries = profile.history
        .where(
          (entry) =>
              !entry.date.isBefore(_start) &&
              entry.date.isBefore(_endExclusive),
        )
        .toList();
    return HistoryComparison._(
      expected: _dailyBalances(opening, expectedEntries),
      actual: _dailyBalances(opening, actualEntries),
    );
  }

  static Forecast _dailyBalances(int opening, List<LedgerEntry> entries) {
    entries.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate == 0 ? a.id.compareTo(b.id) : byDate;
    });
    var balance = opening;
    final days = <ForecastDay>[];
    ForecastDay? firstShortfall;
    ForecastDay? lowest;
    for (var offset = 0; offset < windowDays; offset++) {
      final date = DateTime(_start.year, _start.month, _start.day + offset);
      final movements = entries
          .where((entry) => isoDate(entry.date) == isoDate(date))
          .toList();
      balance += movements.fold<int>(
        0,
        (sum, entry) => sum + entry.amountPence,
      );
      final day = ForecastDay(
        date: date,
        balancePence: balance,
        movements: List.unmodifiable(movements),
      );
      days.add(day);
      if (balance < 0) firstShortfall ??= day;
      if (lowest == null || balance < lowest.balancePence) lowest = day;
    }
    return Forecast(
      days: List.unmodifiable(days),
      entries: List.unmodifiable(entries),
      openingBalancePence: opening,
      endingBalancePence: balance,
      lowestDay: lowest!,
      firstShortfall: firstShortfall,
      pressureCauses: const [],
    );
  }
}
