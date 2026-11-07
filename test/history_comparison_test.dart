import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/core/history_comparison.dart';

void main() {
  test(
    'Both profiles reconcile each historical day and end at current cash',
    () {
      for (final profile in DemoProfiles.all) {
        final comparison = HistoryComparison.fromProfile(profile);
        final opening =
            profile.historyOpeningBalancePence +
            profile.history
                .where((entry) => entry.date.isBefore(DateTime(2026, 10, 10)))
                .fold<int>(0, (sum, entry) => sum + entry.amountPence);
        expect(comparison.openingBalancePence, opening);
        expect(
          comparison.actual.openingBalancePence,
          comparison.expected.openingBalancePence,
        );
        expect(
          comparison.actual.endingBalancePence,
          profile.openingBalancePence,
        );
        for (final series in [comparison.expected, comparison.actual]) {
          expect(series.days.length, 28);
          expect(series.days.first.date, DateTime(2026, 10, 10));
          expect(series.days.last.date, DateTime(2026, 11, 6));
          var balance = opening;
          for (final day in series.days) {
            balance += day.movements.fold<int>(
              0,
              (sum, entry) => sum + entry.amountPence,
            );
            expect(day.balancePence, balance);
            expect(day.date.hour, 0);
            expect(day.date.isBefore(FinanceEngine.asOf), isTrue);
          }
          expect(series.endingBalancePence, balance);
          expect(
            series.endingBalancePence,
            opening + series.totalIncomePence - series.totalOutgoingsPence,
          );
        }
        expect(
          comparison.endingVariancePence,
          comparison.actual.endingBalancePence -
              comparison.expected.endingBalancePence,
        );
      }
    },
  );

  test(
    'Expected pattern uses only the preceding four weeks, not held-out records',
    () {
      for (final profile in DemoProfiles.all) {
        final original = HistoryComparison.fromProfile(profile);
        final changed = HistoryComparison.fromProfile(
          _withHistory(profile, [
            ...profile.history,
            LedgerEntry(
              id: 'held-out-change',
              date: DateTime(2026, 10, 31),
              label: 'Different recorded bill',
              amountPence: -12345,
              category: 'unexpected',
            ),
          ]),
        );
        expect(changed.openingBalancePence, original.openingBalancePence);
        expect(
          changed.expected.days.map((day) => day.balancePence),
          original.expected.days.map((day) => day.balancePence),
        );
        expect(
          changed.actual.endingBalancePence,
          original.actual.endingBalancePence - 12345,
        );
        expect(
          original.expected.entries.every((entry) => entry.isEstimate),
          isTrue,
        );
        expect(
          original.actual.entries.every((entry) => !entry.isEstimate),
          isTrue,
        );
      }
      final noor = HistoryComparison.fromProfile(DemoProfiles.all.first);
      expect(
        noor.expected.entries.any(
          (entry) => entry.label == 'Unexpected van repair',
        ),
        isFalse,
      );
      expect(
        noor.actual.entries.any(
          (entry) => entry.label == 'Unexpected van repair',
        ),
        isTrue,
      );
      expect(noor.expected.endingBalancePence, 169500);
      expect(noor.actual.endingBalancePence, 48500);
      expect(noor.endingVariancePence, -121000);
    },
  );

  test('Training pattern shifts 28 civil days and future records never become actuals', () {
    final profile = DemoProfiles.all.first;
    final original = HistoryComparison.fromProfile(profile);
    final changed = HistoryComparison.fromProfile(
      _withHistory(profile, [
        ...profile.history,
        LedgerEntry(
          id: 'future',
          date: DateTime(2026, 11, 7),
          label: 'Not yet recorded',
          amountPence: 999999,
          category: 'income',
        ),
      ]),
    );
    expect(
      changed.actual.endingBalancePence,
      original.actual.endingBalancePence,
    );
    expect(
      changed.expected.endingBalancePence,
      original.expected.endingBalancePence,
    );
    for (final expected in original.expected.entries) {
      final sourceId = expected.id.replaceFirst('reconstructed-', '');
      final source = profile.history.singleWhere(
        (entry) => entry.id == sourceId,
      );
      expect(source.date.isBefore(DateTime(2026, 10, 10)), isTrue);
      expect(
        expected.date,
        DateTime(source.date.year, source.date.month, source.date.day + 28),
      );
      expect(expected.amountPence, source.amountPence);
    }
    expect(
      original.actual.entries.any((entry) => entry.id == 'future'),
      isFalse,
    );
  });
}

DemoProfile _withHistory(DemoProfile source, List<LedgerEntry> history) =>
    DemoProfile(
      id: source.id,
      name: source.name,
      initials: source.initials,
      description: source.description,
      household: source.household,
      incomeLabel: source.incomeLabel,
      openingBalancePence: source.openingBalancePence,
      historyOpeningBalancePence: source.historyOpeningBalancePence,
      monthlyIncomePence: source.monthlyIncomePence,
      monthlyEssentialsPence: source.monthlyEssentialsPence,
      savingsPence: source.savingsPence,
      debtBalancePence: source.debtBalancePence,
      goalTitle: source.goalTitle,
      goalTargetPence: source.goalTargetPence,
      goalSavedPence: source.goalSavedPence,
      creditTitle: source.creditTitle,
      creditExplanation: source.creditExplanation,
      history: history,
      upcoming: source.upcoming,
    );
