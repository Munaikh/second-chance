/// All customer records are synthetic. Money is stored in integer pence.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.date,
    required this.label,
    required this.amountPence,
    required this.category,
    this.isEstimate = false,
  });

  final String id;
  final DateTime date;
  final String label;
  final int amountPence;
  final String category;
  final bool isEstimate;

  bool get isIncome => amountPence > 0;
  bool get isFlexible =>
      category == 'groceries' ||
      category == 'travel' ||
      category == 'household';

  LedgerEntry withAmount(int amount) => LedgerEntry(
    id: id,
    date: date,
    label: label,
    amountPence: amount,
    category: category,
    isEstimate: isEstimate,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'date': isoDate(date),
    'label': label,
    'amountPence': amountPence,
    'category': category,
    'isEstimate': isEstimate,
  };
}

class DemoProfile {
  const DemoProfile({
    required this.id,
    required this.name,
    required this.initials,
    required this.description,
    required this.household,
    required this.incomeLabel,
    required this.openingBalancePence,
    required this.historyOpeningBalancePence,
    required this.monthlyIncomePence,
    required this.monthlyEssentialsPence,
    required this.savingsPence,
    required this.debtBalancePence,
    required this.goalTitle,
    required this.goalTargetPence,
    required this.goalSavedPence,
    required this.creditTitle,
    required this.creditExplanation,
    required this.history,
    required this.upcoming,
  });

  final String id;
  final String name;
  final String initials;
  final String description;
  final String household;
  final String incomeLabel;
  final int openingBalancePence;
  final int historyOpeningBalancePence;
  final int monthlyIncomePence;
  final int monthlyEssentialsPence;
  final int savingsPence;
  final int debtBalancePence;
  final String goalTitle;
  final int goalTargetPence;
  final int goalSavedPence;
  final String creditTitle;
  final String creditExplanation;
  final List<LedgerEntry> history;
  final List<LedgerEntry> upcoming;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'household': household,
    'incomeLabel': incomeLabel,
    'openingBalancePence': openingBalancePence,
    'historyOpeningBalancePence': historyOpeningBalancePence,
    'monthlyIncomePence': monthlyIncomePence,
    'monthlyEssentialsPence': monthlyEssentialsPence,
    'savingsPence': savingsPence,
    'debtBalancePence': debtBalancePence,
    'goalTitle': goalTitle,
    'goalTargetPence': goalTargetPence,
    'goalSavedPence': goalSavedPence,
    'creditTitle': creditTitle,
    'creditExplanation': creditExplanation,
    'history': history.map((entry) => entry.toJson()).toList(),
    'upcoming': upcoming.map((entry) => entry.toJson()).toList(),
    'dataType': 'synthetic',
  };
}

class Scenario {
  const Scenario({
    this.incomePercentChange = 0,
    this.unexpectedExpensePence = 0,
    this.weeklySavingPence = 0,
  });

  final double incomePercentChange;
  final int unexpectedExpensePence;
  final int weeklySavingPence;

  bool get isBaseline =>
      incomePercentChange == 0 &&
      unexpectedExpensePence == 0 &&
      weeklySavingPence == 0;

  Map<String, Object?> toJson() => {
    'incomePercentChange': incomePercentChange,
    'unexpectedExpensePence': unexpectedExpensePence,
    'weeklySavingPence': weeklySavingPence,
    'unexpectedExpenseDate': isoDate(
      FinanceEngine.asOf.add(const Duration(days: 3)),
    ),
  };
}

class ForecastDay {
  const ForecastDay({
    required this.date,
    required this.balancePence,
    this.movements = const [],
  });

  final DateTime date;
  final int balancePence;
  final List<LedgerEntry> movements;

  Map<String, Object?> toJson() => {
    'date': isoDate(date),
    'balancePence': balancePence,
    'movements': movements.map((entry) => entry.toJson()).toList(),
  };
}

class Forecast {
  const Forecast({
    required this.days,
    required this.entries,
    required this.openingBalancePence,
    required this.endingBalancePence,
    required this.lowestDay,
    required this.firstShortfall,
    required this.pressureCauses,
  });

  final List<ForecastDay> days;
  final List<LedgerEntry> entries;
  final int openingBalancePence;
  final int endingBalancePence;
  final ForecastDay lowestDay;
  final ForecastDay? firstShortfall;
  final List<String> pressureCauses;

  int get shortfallPence => -(firstShortfall?.balancePence ?? 0);
  int get totalIncomePence => entries
      .where((entry) => entry.amountPence > 0)
      .fold(0, (total, entry) => total + entry.amountPence);
  int get totalOutgoingsPence => -entries
      .where((entry) => entry.amountPence < 0)
      .fold(0, (total, entry) => total + entry.amountPence);

  Map<String, Object?> toJson() => {
    'asOf': isoDate(FinanceEngine.asOf),
    'horizonDays': FinanceEngine.horizonDays,
    'openingBalancePence': openingBalancePence,
    'endingBalancePence': endingBalancePence,
    'lowestDay': lowestDay.toJson(),
    'firstShortfall': firstShortfall?.toJson(),
    'shortfallPence': shortfallPence,
    'pressureCauses': pressureCauses,
    'days': days.map((day) => day.toJson()).toList(),
    'entries': entries.map((entry) => entry.toJson()).toList(),
    'calculation': 'Opening balance plus signed dated cash movements; daily closing balance.',
    'assumptions': FinanceEngine.assumptions,
  };
}

abstract final class FinanceEngine {
  static final DateTime asOf = DateTime(2026, 11, 7);
  static const int horizonDays = 30;
  static const List<String> assumptions = [
    'Synthetic customer data. The demo clock is fixed at 7 November 2026.',
    'Daily closing balances for 7 November–6 December; payment order within a day is unknown.',
    'Expected income and future spending may change. No overdraft, interest or lending is assumed.',
    'Income changes affect expected earnings, not benefits. Extra costs occur on 10 November.',
    'Weekly savings reduce modelled groceries, travel and household spending, capped at that spending.',
  ];

  static Forecast forecast(
    DemoProfile profile, {
    Scenario scenario = const Scenario(),
  }) {
    if (!scenario.incomePercentChange.isFinite ||
        scenario.incomePercentChange < -100 ||
        scenario.incomePercentChange > 100 ||
        scenario.unexpectedExpensePence < 0 ||
        scenario.weeklySavingPence < 0) {
      throw ArgumentError(
        'Use an income change from -100% to 100% and non-negative costs/savings.',
      );
    }
    final end = asOf.add(const Duration(days: horizonDays));
    final entries = profile.upcoming
        .where(
          (entry) => !entry.date.isBefore(asOf) && entry.date.isBefore(end),
        )
        .map((entry) {
          if (entry.category == 'income' &&
              entry.isEstimate &&
              entry.isIncome) {
            return entry.withAmount(
              (entry.amountPence * (1 + scenario.incomePercentChange / 100))
                  .round(),
            );
          }
          return entry;
        })
        .toList();
    if (scenario.unexpectedExpensePence > 0) {
      entries.add(
        LedgerEntry(
          id: 'scenario-expense',
          date: asOf.add(const Duration(days: 3)),
          label: 'Unexpected expense (what if)',
          amountPence: -scenario.unexpectedExpensePence,
          category: 'unexpected',
          isEstimate: true,
        ),
      );
    }
    entries.sort(_compareEntries);
    final remainingSavings = <int, int>{};
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      if (entry.amountPence >= 0 || !entry.isFlexible) continue;
      final week = entry.date.difference(asOf).inDays ~/ 7;
      final available = remainingSavings.putIfAbsent(
        week,
        () => scenario.weeklySavingPence,
      );
      final reduction = available < -entry.amountPence
          ? available
          : -entry.amountPence;
      entries[index] = entry.withAmount(entry.amountPence + reduction);
      remainingSavings[week] = available - reduction;
    }
    entries.removeWhere((entry) => entry.amountPence == 0);
    var balance = profile.openingBalancePence;
    final days = <ForecastDay>[];
    ForecastDay? firstShortfall;
    ForecastDay? lowestDay;
    for (var offset = 0; offset < horizonDays; offset++) {
      final date = asOf.add(Duration(days: offset));
      final movements = entries
          .where((entry) => _sameDay(entry.date, date))
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
      if (lowestDay == null || balance < lowestDay.balancePence) {
        lowestDay = day;
      }
    }
    final pressure = <String>[];
    if (firstShortfall != null) {
      for (final entry in firstShortfall.movements.where(
        (entry) => entry.amountPence < 0,
      )) {
        pressure.add(
          '${entry.label}: ${formatPence(-entry.amountPence)} on ${formatDate(entry.date)}.',
        );
      }
      final nextIncome = entries.where(
        (entry) => entry.isIncome && entry.date.isAfter(firstShortfall!.date),
      );
      if (nextIncome.isNotEmpty) {
        pressure.add(
          'Next expected income: ${formatPence(nextIncome.first.amountPence)} on ${formatDate(nextIncome.first.date)}.',
        );
      }
    } else {
      pressure.add(
        'Lowest projected daily balance: ${formatPence(lowestDay!.balancePence)} on ${formatDate(lowestDay.date)}.',
      );
      pressure.add(
        'Keep essential bills covered before moving money into savings.',
      );
    }
    return Forecast(
      days: List.unmodifiable(days),
      entries: List.unmodifiable(entries),
      openingBalancePence: profile.openingBalancePence,
      endingBalancePence: balance,
      lowestDay: lowestDay!,
      firstShortfall: firstShortfall,
      pressureCauses: List.unmodifiable(pressure),
    );
  }
}

abstract final class DemoProfiles {
  static final List<DemoProfile> all = List.unmodifiable([_noor(), _alex()]);

  static DemoProfile _noor() {
    final history = _history('noor', irregular: true);
    final upcoming = <LedgerEntry>[
      _entry('n01', 11, 7, 'Groceries', -4500, 'groceries'),
      _entry('n02', 11, 7, 'Work travel', -1500, 'travel'),
      _entry('n03', 11, 9, 'Delivery payment', 15000, 'income'),
      _entry('n04', 11, 10, 'Childcare', -6000, 'childcare'),
      _entry('n05', 11, 12, 'Rent', -65000, 'rent'),
      _entry('n06', 11, 12, 'Energy instalment', -4500, 'energy'),
      _entry('n07', 11, 14, 'Delivery payment', 38000, 'income'),
      _entry('n08', 11, 14, 'Groceries', -5500, 'groceries'),
      _entry('n09', 11, 16, 'Childcare', -11000, 'childcare'),
      _entry('n10', 11, 17, 'Broadband', -2900, 'broadband'),
      _entry('n11', 11, 20, 'Delivery payment', 48000, 'income'),
      _entry('n12', 11, 20, 'Groceries', -5500, 'groceries'),
      _entry('n13', 11, 22, 'Council tax', -9800, 'councilTax'),
      _entry('n14', 11, 22, 'Card minimum payment', -4500, 'debt'),
      _entry('n15', 11, 23, 'Work travel', -1800, 'travel'),
      _entry('n16', 11, 23, 'Mobile', -1800, 'phone'),
      _entry('n17', 11, 24, 'Childcare', -11000, 'childcare'),
      _entry('n18', 11, 27, 'Delivery payment', 30000, 'income'),
      _entry('n19', 11, 27, 'Groceries', -5500, 'groceries'),
      _entry('n20', 11, 28, 'Contents insurance', -2400, 'insurance'),
      _entry('n21', 12, 1, 'Energy instalment', -4500, 'energy'),
      _entry('n22', 12, 1, 'Work travel', -1500, 'travel'),
      _entry('n23', 12, 3, 'Household benefit payment', 48000, 'benefits'),
      _entry('n24', 12, 4, 'Delivery payment', 24000, 'income'),
      _entry('n25', 12, 4, 'Groceries', -5500, 'groceries'),
    ]..sort(_compareEntries);
    return DemoProfile(
      id: 'noor',
      name: 'Noor',
      initials: 'NH',
      description:
          'Delivery driver and parent. A recent van repair used up the buffer.',
      household: 'Single parent with one child; renting in Leeds.',
      incomeLabel: 'Variable delivery income + household benefits',
      openingBalancePence: 48500,
      historyOpeningBalancePence: 48500 - _sum(history),
      monthlyIncomePence: _income(upcoming),
      monthlyEssentialsPence: -_expenses(upcoming),
      savingsPence: 3500,
      debtBalancePence: 78000,
      goalTitle: 'A little breathing room',
      goalTargetPence: 30000,
      goalSavedPence: 3500,
      creditTitle: 'Check your credit report for errors',
      creditExplanation: 'A free statutory credit report can help you spot incorrect balances or missed-payment records. Ask the credit reference agency to correct errors. Checking your own report does not affect your score.',
      history: List.unmodifiable(history),
      upcoming: List.unmodifiable(upcoming),
    );
  }

  static DemoProfile _alex() {
    final history = _history('alex', irregular: false);
    final upcoming = <LedgerEntry>[
      _entry('a01', 11, 8, 'Groceries', -6500, 'groceries'),
      _entry('a02', 11, 10, 'Rent share', -85000, 'rent'),
      _entry('a03', 11, 12, 'Energy and water', -9000, 'energy'),
      _entry('a04', 11, 14, 'Groceries', -6500, 'groceries'),
      _entry('a05', 11, 16, 'Council tax share', -13500, 'councilTax'),
      _entry('a06', 11, 18, 'Card minimum payment', -4500, 'debt'),
      _entry('a07', 11, 20, 'Broadband', -3200, 'broadband'),
      _entry('a08', 11, 20, 'Travel pass', -8500, 'travel'),
      _entry('a09', 11, 21, 'Groceries', -6500, 'groceries'),
      _entry('a10', 11, 25, 'Monthly salary', 270000, 'income'),
      _entry('a11', 11, 26, 'Mobile', -2000, 'phone'),
      _entry('a12', 11, 28, 'Groceries', -6500, 'groceries'),
      _entry('a13', 12, 1, 'Contents insurance', -2800, 'insurance'),
      _entry('a14', 12, 5, 'Groceries', -6500, 'groceries'),
    ]..sort(_compareEntries);
    return DemoProfile(
      id: 'alex',
      name: 'Alex',
      initials: 'AM',
      description: 'Steady monthly pay. Building a stronger rainy-day fund.',
      household: 'Shares a rented home with a partner in Manchester.',
      incomeLabel: 'Monthly take-home salary',
      openingBalancePence: 185000,
      historyOpeningBalancePence: 185000 - _sum(history),
      monthlyIncomePence: _income(upcoming),
      monthlyEssentialsPence: -_expenses(upcoming),
      savingsPence: 420000,
      debtBalancePence: 62000,
      goalTitle: 'My emergency fund',
      goalTargetPence: 500000,
      goalSavedPence: 125000,
      creditTitle: 'Make card payments predictable',
      creditExplanation: 'A Direct Debit for at least the minimum can help avoid missed payments when the account has enough money. Paying more reduces the balance faster; check the card terms and your essential bills first. No score improvement is guaranteed.',
      history: List.unmodifiable(history),
      upcoming: List.unmodifiable(upcoming),
    );
  }

  static List<LedgerEntry> _history(String id, {required bool irregular}) {
    final result = <LedgerEntry>[];
    final start = DateTime(2026, 9, 12);
    const wages = [34000, 39000, 31000, 42000, 36500, 39500, 29000, 40000];
    for (var week = 0; week < 8; week++) {
      final saturday = DateTime(start.year, start.month, start.day + week * 7);
      result.add(
        LedgerEntry(
          id: '$id-h-groceries-$week',
          date: saturday,
          label: 'Groceries',
          amountPence: irregular ? -6000 : -6500,
          category: 'groceries',
        ),
      );
      if (irregular) {
        result.addAll([
          LedgerEntry(
            id: '$id-h-childcare-$week',
            date: DateTime(saturday.year, saturday.month, saturday.day + 2),
            label: 'Childcare',
            amountPence: -7000,
            category: 'childcare',
          ),
          LedgerEntry(
            id: '$id-h-travel-$week',
            date: DateTime(saturday.year, saturday.month, saturday.day + 3),
            label: 'Work travel',
            amountPence: -2400,
            category: 'travel',
          ),
          LedgerEntry(
            id: '$id-h-household-$week',
            date: DateTime(saturday.year, saturday.month, saturday.day + 5),
            label: 'Household essentials',
            amountPence: -1400,
            category: 'household',
          ),
          LedgerEntry(
            id: '$id-h-pay-$week',
            date: DateTime(saturday.year, saturday.month, saturday.day + 6),
            label: 'Delivery payment',
            amountPence: wages[week],
            category: 'income',
          ),
        ]);
      }
    }
    for (final month in [9, 10]) {
      final amounts = irregular
          ? <String, (int, int)>{
              'rent': (12, -65000),
              'energy': (16, -9000),
              'councilTax': (22, -9800),
              'broadband': (17, -2900),
              'debt': (18, -4500),
              'phone': (23, -1800),
              'insurance': (28, -2400),
              'benefits': (26, 48000),
            }
          : <String, (int, int)>{
              'rent': (15, -85000),
              'energy': (16, -9000),
              'councilTax': (22, -13500),
              'broadband': (20, -3200),
              'debt': (18, -4500),
              'phone': (23, -2000),
              'insurance': (28, -2800),
              'travel': (20, -8500),
              'income': (25, 270000),
              'savings': (26, -100000),
            };
      const labels = {
        'rent': 'Rent',
        'energy': 'Energy',
        'councilTax': 'Council tax',
        'broadband': 'Broadband',
        'debt': 'Card minimum payment',
        'phone': 'Mobile',
        'insurance': 'Contents insurance',
        'benefits': 'Household benefit payment',
        'travel': 'Travel pass',
        'income': 'Monthly salary',
        'savings': 'Transfer to savings',
      };
      for (final item in amounts.entries) {
        result.add(
          LedgerEntry(
            id: '$id-h-${item.key}-$month',
            date: DateTime(2026, month, item.value.$1),
            label: labels[item.key]!,
            amountPence: item.value.$2,
            category: item.key,
          ),
        );
      }
    }
    if (irregular) {
      result.add(
        LedgerEntry(
          id: '$id-h-repair',
          date: DateTime(2026, 10, 31),
          label: 'Unexpected van repair',
          amountPence: -120000,
          category: 'unexpected',
        ),
      );
    }
    return result..sort(_compareEntries);
  }
}

LedgerEntry _entry(
  String id,
  int month,
  int day,
  String label,
  int amount,
  String category,
) => LedgerEntry(
  id: id,
  date: DateTime(2026, month, day),
  label: label,
  amountPence: amount,
  category: category,
  isEstimate: true,
);
int _sum(List<LedgerEntry> entries) =>
    entries.fold(0, (sum, entry) => sum + entry.amountPence);
int _income(List<LedgerEntry> entries) =>
    _sum(entries.where((entry) => entry.amountPence > 0).toList());
int _expenses(List<LedgerEntry> entries) =>
    _sum(entries.where((entry) => entry.amountPence < 0).toList());
int _compareEntries(LedgerEntry a, LedgerEntry b) {
  final byDate = a.date.compareTo(b.date);
  return byDate == 0 ? a.id.compareTo(b.id) : byDate;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String formatDate(DateTime date) =>
    '${date.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]}';
String formatPence(int pence, {bool decimals = false}) {
  final absolute = pence.abs();
  final pounds = (absolute ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  final pennies = absolute % 100;
  final fraction = decimals || pennies != 0
      ? '.${pennies.toString().padLeft(2, '0')}'
      : '';
  return '${pence < 0 ? '-' : ''}£$pounds$fraction';
}
