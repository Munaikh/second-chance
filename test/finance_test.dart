import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:second_chance/core/finance.dart';

void main() {
  final noor = DemoProfiles.all.first;
  final alex = DemoProfiles.all.last;

  test(
    'Noor has a dated £180 daily-closing shortfall before her next income',
    () {
      final result = FinanceEngine.forecast(noor);
      expect(result.firstShortfall?.date, DateTime(2026, 11, 12));
      expect(result.firstShortfall?.balancePence, -18000);
      expect(result.lowestDay.balancePence, -18000);
      expect(result.pressureCauses.join(' '), contains('Rent: £650 on 12 Nov'));
      expect(result.pressureCauses.join(' '), contains('£380 on 14 Nov'));
      expect(result.days.length, 30);
      expect(result.days.last.date, DateTime(2026, 12, 6));
    },
  );

  test('Every day and the closing total reconcile in integer pence', () {
    for (final profile in DemoProfiles.all) {
      for (final scenario in [
        const Scenario(),
        const Scenario(
          incomePercentChange: -17.5,
          unexpectedExpensePence: 12543,
          weeklySavingPence: 1700,
        ),
      ]) {
        final result = FinanceEngine.forecast(profile, scenario: scenario);
        var balance = profile.openingBalancePence;
        for (final day in result.days) {
          final movements = result.entries.where(
            (entry) => isoDate(entry.date) == isoDate(day.date),
          );
          balance += movements.fold<int>(
            0,
            (sum, entry) => sum + entry.amountPence,
          );
          expect(day.balancePence, balance);
        }
        expect(result.endingBalancePence, balance);
        expect(
          result.endingBalancePence,
          profile.openingBalancePence +
              result.totalIncomePence -
              result.totalOutgoingsPence,
        );
      }
    }
  });

  test(
    'Historical records cover eight weeks and reconcile to current cash',
    () {
      for (final profile in DemoProfiles.all) {
        expect(profile.history.first.date, DateTime(2026, 9, 12));
        expect(profile.history.last.date.isBefore(FinanceEngine.asOf), isTrue);
        expect(
          profile.history.last.date
              .difference(profile.history.first.date)
              .inDays,
          greaterThanOrEqualTo(49),
        );
        expect(
          profile.historyOpeningBalancePence +
              profile.history.fold<int>(
                0,
                (sum, entry) => sum + entry.amountPence,
              ),
          profile.openingBalancePence,
        );
        expect(profile.history.every((entry) => !entry.isEstimate), isTrue);
        var historicalBalance = profile.historyOpeningBalancePence;
        for (final entry in profile.history) {
          historicalBalance += entry.amountPence;
          expect(historicalBalance, greaterThanOrEqualTo(0));
          expect(entry.date.hour, 0);
        }
        expect(profile.upcoming.every((entry) => entry.isEstimate), isTrue);
        expect(
          profile.history.map((entry) => entry.id).toSet().length,
          profile.history.length,
        );
        final baseline = FinanceEngine.forecast(profile);
        expect(baseline.totalIncomePence, profile.monthlyIncomePence);
        expect(baseline.totalOutgoingsPence, profile.monthlyEssentialsPence);
      }
    },
  );

  test(
    'Contrasting profile stays above zero and changes personalised guidance',
    () {
      final result = FinanceEngine.forecast(alex);
      expect(result.firstShortfall, isNull);
      expect(result.lowestDay.balancePence, 41800);
      expect(alex.openingBalancePence, greaterThan(noor.openingBalancePence));
      expect(alex.creditTitle, isNot(noor.creditTitle));
      expect(alex.goalTargetPence, greaterThan(noor.goalTargetPence));
    },
  );

  test(
    'Income stress changes earnings with pence rounding, preserving benefits',
    () {
      final baseline = FinanceEngine.forecast(noor);
      final changed = FinanceEngine.forecast(
        noor,
        scenario: const Scenario(incomePercentChange: -20),
      );
      expect(changed.totalIncomePence, baseline.totalIncomePence - 31000);
      expect(
        changed.entries
            .singleWhere((entry) => entry.category == 'benefits')
            .amountPence,
        48000,
      );
      expect(changed.firstShortfall?.balancePence, -21000);
      expect(
        changed.entries
            .where((entry) => !entry.isIncome)
            .map((entry) => entry.amountPence),
        baseline.entries
            .where((entry) => !entry.isIncome)
            .map((entry) => entry.amountPence),
      );
    },
  );

  test('Unexpected expense occurs once on the stated date', () {
    final baseline = FinanceEngine.forecast(noor);
    final changed = FinanceEngine.forecast(
      noor,
      scenario: const Scenario(unexpectedExpensePence: 12000),
    );
    final expense = changed.entries.singleWhere(
      (entry) => entry.id == 'scenario-expense',
    );
    expect(expense.date, DateTime(2026, 11, 10));
    expect(changed.firstShortfall?.balancePence, -30000);
    expect(changed.endingBalancePence, baseline.endingBalancePence - 12000);
  });

  test(
    'Weekly saving is capped at flexible spending and cannot change bills',
    () {
      final baseline = FinanceEngine.forecast(noor);
      final changed = FinanceEngine.forecast(
        noor,
        scenario: const Scenario(weeklySavingPence: 999999),
      );
      final flexibleSpend = baseline.entries
          .where((entry) => entry.isFlexible)
          .fold<int>(0, (sum, entry) => sum - entry.amountPence);
      expect(
        changed.endingBalancePence,
        baseline.endingBalancePence + flexibleSpend,
      );
      expect(changed.entries.where((entry) => entry.isFlexible), isEmpty);
      final rent = changed.entries.singleWhere(
        (entry) => entry.category == 'rent',
      );
      expect(rent.amountPence, -65000);
      expect(changed.totalIncomePence, baseline.totalIncomePence);
    },
  );

  test(
    'Modest savings change the first week once without inventing income',
    () {
      final baseline = FinanceEngine.forecast(noor);
      final changed = FinanceEngine.forecast(
        noor,
        scenario: const Scenario(weeklySavingPence: 2500),
      );
      expect(changed.firstShortfall?.balancePence, -15500);
      expect(changed.totalIncomePence, baseline.totalIncomePence);
      expect(changed.totalOutgoingsPence, baseline.totalOutgoingsPence - 10000);
    },
  );

  test('Invalid scenario inputs fail explicitly', () {
    for (final scenario in [
      const Scenario(incomePercentChange: -101),
      const Scenario(incomePercentChange: 101),
      const Scenario(incomePercentChange: double.nan),
      const Scenario(unexpectedExpensePence: -1),
      const Scenario(weeklySavingPence: -1),
    ]) {
      expect(
        () => FinanceEngine.forecast(noor, scenario: scenario),
        throwsArgumentError,
      );
    }
  });

  test(
    'Summaries serialise and GBP formatting preserves pennies and signs',
    () {
      expect(() => jsonEncode(noor.toJson()), returnsNormally);
      expect(
        () => jsonEncode(FinanceEngine.forecast(noor).toJson()),
        returnsNormally,
      );
      expect(formatPence(-18000), '-£180');
      expect(formatPence(123456), '£1,234.56');
      expect(formatPence(100, decimals: true), '£1.00');
    },
  );
}
