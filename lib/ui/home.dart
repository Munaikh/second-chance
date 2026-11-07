import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/companion_page.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/forecast.dart';
import 'package:second_chance/ui/profile.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Row(
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: AppColors.accent(context),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            CupertinoIcons.arrow_turn_up_right,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 22,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'second chance',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(letterSpacing: -.6),
          ),
        ),
        TextButton(
          key: const ValueKey('open_profiles'),
          onPressed: () => openPage(context, const ProfilePage()),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: AppColors.ink(context),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.line(context),
                child: Text(
                  state.profile.initials,
                  style: TextStyle(
                    color: AppColors.ink(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.chevron_down, size: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class PreparePage extends StatelessWidget {
  const PreparePage({super.key, required this.onSupport, required this.onGrow});
  final VoidCallback onSupport;
  final VoidCallback onGrow;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final profile = state.profile;
    final forecast = state.forecast;
    final pressure = forecast.firstShortfall;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: PageStorageKey('prepare_${profile.id}'),
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 140),
        children: [
          const PageHeader(label: 'Prepare'),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'HELLO, ${profile.name.split(' ').first.toUpperCase()}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const StatusPill('Demo · 7 Nov 2026'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'A little clarity.\nA stronger tomorrow.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 28),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your everyday balance',
                        style: TextStyle(color: AppColors.muted(context)),
                      ),
                    ),
                    Icon(
                      CupertinoIcons.creditcard,
                      color: AppColors.muted(context),
                      size: 21,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  formatPence(profile.openingBalancePence, decimals: true),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 18),
                Divider(color: AppColors.line(context), height: 1),
                const SizedBox(height: 17),
                Row(
                  children: [
                    Expanded(
                      child: _MoneyMetric(
                        'Expected income',
                        profile.monthlyIncomePence,
                      ),
                    ),
                    Expanded(
                      child: _MoneyMetric(
                        'Planned essentials',
                        profile.monthlyEssentialsPence,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  'Next 30 days · synthetic UK profile',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'A look ahead',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const StatusPill('30 days', icon: CupertinoIcons.calendar),
                  ],
                ),
                const SizedBox(height: 19),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pressure == null
                                ? 'Room to breathe'
                                : '${formatPence(-pressure.balancePence)} short',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            pressure == null
                                ? 'Your forecast stays above £0.'
                                : 'Expected on ${formatDate(pressure.date)}',
                            style: TextStyle(color: AppColors.muted(context)),
                          ),
                        ],
                      ),
                    ),
                    const Pip(size: 76),
                  ],
                ),
                const SizedBox(height: 5),
                ForecastChart(forecast: forecast, compact: true),
                const SizedBox(height: 14),
                if (pressure != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          CupertinoIcons.clock,
                          size: 18,
                          color: AppColors.accent(context),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Bills arrive before your next income. There’s time to make a plan.',
                          ),
                        ),
                      ],
                    ),
                  ),
                PrimaryButton(
                  key: const ValueKey('open_forecast'),
                  label: 'Explore your future',
                  icon: CupertinoIcons.arrow_up_right,
                  onPressed: () => openPage(context, const ForecastPage()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Surface(
            child: Column(
              children: [
                Row(
                  children: [
                    const Pip(size: 63),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You don’t have to figure it out alone.',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Talk it through with Pip.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('open_companion'),
                    onPressed: () => openPage(context, const CompanionPage()),
                    icon: const Icon(
                      CupertinoIcons.bubble_left_bubble_right,
                      size: 20,
                    ),
                    label: const Text('Let’s talk'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const SectionHeading('One step at a time'),
          const SizedBox(height: 8),
          ActionRow(
            icon: CupertinoIcons.heart,
            title: 'Make a support plan',
            subtitle: 'Practical help for a difficult month',
            onTap: onSupport,
          ),
          ActionRow(
            icon: CupertinoIcons.leaf_arrow_circlepath,
            title: state.goal == null
                ? 'Start your emergency buffer'
                : state.goal!.title,
            subtitle: state.goal == null
                ? 'Small amounts. More peace of mind.'
                : '${formatPence(state.goal!.savedPence)} of ${formatPence(state.goal!.targetPence)} recorded',
            onTap: onGrow,
          ),
          const SizedBox(height: 20),
          SectionHeading(
            'Money coming and going',
            action: 'See all',
            onAction: () => openPage(context, const LedgerPage()),
          ),
          const SizedBox(height: 5),
          Surface(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: profile.upcoming
                  .take(3)
                  .map((e) => LedgerRow(e))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyMetric extends StatelessWidget {
  const _MoneyMetric(this.label, this.amount);
  final String label;
  final int amount;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(formatPence(amount), style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class LedgerRow extends StatelessWidget {
  const LedgerRow(this.entry, {super.key});
  final LedgerEntry entry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: AppColors.canvas(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            entry.isIncome
                ? CupertinoIcons.arrow_down_left
                : CupertinoIcons.arrow_up_right,
            size: 17,
            color: AppColors.muted(context),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${formatDate(entry.date)}${entry.isEstimate ? ' · expected' : ' · synthetic record'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${entry.isIncome ? '+' : '−'}${formatPence(entry.amountPence.abs(), decimals: entry.amountPence % 100 != 0)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: entry.isIncome
                ? Theme.of(context).colorScheme.secondary
                : AppColors.ink(context),
          ),
        ),
      ],
    ),
  );
}
