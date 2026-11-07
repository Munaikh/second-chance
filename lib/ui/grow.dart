import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/cloudy.dart';
import 'package:second_chance/ui/home.dart';
import 'package:second_chance/ui/support.dart';

class GrowPage extends StatelessWidget {
  const GrowPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final goal = state.goal;
    final actionCount = state.actions.length;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: PageStorageKey('grow_${state.profile.id}'),
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 140),
        children: [
          const PageHeader(label: 'Grow'),
          const SizedBox(height: 26),
          Text(
            'Small steps.\nStronger roots.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Build a buffer at a pace that works for you.',
            style: TextStyle(color: AppColors.muted(context)),
          ),
          const SizedBox(height: 26),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal?.title ?? 'A little breathing room',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Cloudy(size: 80, celebrating: actionCount > 0),
                  ],
                ),
                const SizedBox(height: 10),
                if (goal == null) ...[
                  const Text(
                    'Choose an emergency buffer. Even £1 is a start, when you can afford it.',
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    key: const ValueKey('create_goal'),
                    label: 'Create my buffer',
                    icon: CupertinoIcons.plus,
                    onPressed: () => openPage(context, const CreateGoalPage()),
                  ),
                ] else ...[
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 8,
                    runSpacing: 5,
                    children: [
                      Text(
                        formatPence(goal.savedPence),
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          'of ${formatPence(goal.targetPence)}',
                          style: TextStyle(color: AppColors.muted(context)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: goal.progress),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 9,
                      semanticsLabel: 'Recorded emergency savings',
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    goal.progress >= 1
                        ? 'Your buffer is ready. A little more peace of mind.'
                        : 'Next milestone: ${formatPence(_nextMilestone(goal.savedPence, goal.targetPence))}',
                    style: TextStyle(color: AppColors.muted(context)),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    key: const ValueKey('record_saving'),
                    label: 'Record money set aside',
                    icon: CupertinoIcons.plus,
                    onPressed: () =>
                        openPage(context, const RecordSavingPage()),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A personal record. No money moves in this demo.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Surface(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.canvas(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    actionCount >= 3
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.sparkles,
                    color: AppColors.accent(context),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actionCount == 0
                            ? 'Your next chapter starts here'
                            : actionCount >= 3
                            ? 'Stronger foundations'
                            : 'You’ve taken the first step',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$actionCount positive ${actionCount == 1 ? 'action' : 'actions'} recorded',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const SectionHeading('A healthy relationship with credit'),
          const SizedBox(height: 13),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  CupertinoIcons.doc_text_search,
                  color: AppColors.accent(context),
                  size: 26,
                ),
                const SizedBox(height: 14),
                Text(
                  state.profile.creditTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(state.profile.creditExplanation),
                const SizedBox(height: 16),
                const GuidanceLink(
                  title: 'Check your credit report',
                  url: 'https://www.moneyhelper.org.uk/en/everyday-money/credit/how-to-check-your-credit-report',
                  detail: 'MoneyHelper · free access and correcting errors',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('record_credit'),
                    onPressed: state.hasReviewedCredit
                        ? null
                        : () async {
                            await state.recordAction(
                              'Reviewed my credit report',
                            );
                            if (context.mounted) {
                              showNotice(
                                context,
                                'Recorded. Understanding your credit is a positive step.',
                              );
                            }
                          },
                    icon: Icon(
                      state.hasReviewedCredit
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.checkmark_circle,
                    ),
                    label: Text(
                      state.hasReviewedCredit
                          ? 'Review recorded'
                          : 'I’ve reviewed my report',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'No need to borrow or spend to earn progress here. Checking your own report does not reduce your credit score.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const SectionHeading('Your progress'),
          const SizedBox(height: 12),
          if (state.actions.isEmpty)
            Surface(
              child: Text(
                'Your first useful step will appear here.',
                style: TextStyle(color: AppColors.muted(context)),
              ),
            )
          else
            Surface(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Column(
                children: state.actions.reversed
                    .take(12)
                    .map(
                      (a) => ActionRow(
                        icon: CupertinoIcons.checkmark,
                        title: a.label,
                        subtitle:
                            '${a.date.day}/${a.date.month}/${a.date.year}',
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  int _nextMilestone(int saved, int target) {
    for (final value in [1000, 2500, 5000, 10000, 25000, target]) {
      if (value > saved && value <= target) return value;
    }
    return target;
  }
}

int? parsePounds(String text) {
  final value = text.trim();
  if (!RegExp(r'^\d{1,6}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
}

class CreateGoalPage extends StatefulWidget {
  const CreateGoalPage({super.key});
  @override
  State<CreateGoalPage> createState() => _CreateGoalPageState();
}

class _CreateGoalPageState extends State<CreateGoalPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'My emergency buffer');
  final _target = TextEditingController(text: '500');
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create a buffer')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Center(child: Cloudy(size: 130)),
        const SizedBox(height: 22),
        Text(
          'Make room for\nlife’s surprises.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          'Start with a small, reachable target. You can build from there.',
        ),
        const SizedBox(height: 26),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                key: const ValueKey('goal_name'),
                controller: _name,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Give it a name'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Choose a name for your buffer.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('goal_target'),
                controller: _target,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Your target',
                  prefixText: '£ ',
                ),
                validator: (v) {
                  final amount = parsePounds(v ?? '');
                  return amount == null || amount < 100 || amount > 10000000
                      ? 'Choose a target from £1 to £100,000.'
                      : null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        PrimaryButton(
          key: const ValueKey('save_goal'),
          label: 'Start my buffer',
          loading: _saving,
          onPressed: () async {
            if (!_form.currentState!.validate()) return;
            setState(() => _saving = true);
            final state = AppScope.of(context);
            await state.createGoal(_name.text, parsePounds(_target.text)!);
            if (context.mounted) {
              Navigator.pop(context);
              showNotice(context, 'Your buffer is started. One step forward.');
            }
          },
        ),
      ],
    ),
  );
}

class RecordSavingPage extends StatefulWidget {
  const RecordSavingPage({super.key});
  @override
  State<RecordSavingPage> createState() => _RecordSavingPageState();
}

class _RecordSavingPageState extends State<RecordSavingPage> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(text: '5');
  bool _saving = false;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('A little more breathing room')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Center(child: Cloudy(size: 145, celebrating: true)),
        const SizedBox(height: 22),
        Text(
          'Every little bit\nis a step forward.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 14),
        const Text(
          'Record money you’ve already set aside. Prioritise essential bills and choose what feels manageable.',
        ),
        const SizedBox(height: 27),
        Form(
          key: _form,
          child: TextFormField(
            key: const ValueKey('saving_amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Amount set aside',
              prefixText: '£ ',
            ),
            validator: (v) {
              final amount = parsePounds(v ?? '');
              return amount == null || amount < 1 || amount > 1000000
                  ? 'Enter an amount from £0.01 to £10,000.'
                  : null;
            },
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 10,
          children: [
            for (final pounds in [1, 5, 10, 20])
              ActionChip(
                label: Text('£$pounds'),
                onPressed: () => _amount.text = pounds.toString(),
              ),
          ],
        ),
        const SizedBox(height: 25),
        PrimaryButton(
          key: const ValueKey('save_contribution'),
          label: 'Record my progress',
          loading: _saving,
          onPressed: () async {
            if (!_form.currentState!.validate()) return;
            setState(() => _saving = true);
            await AppScope.of(context).recordSaving(parsePounds(_amount.text)!);
            if (context.mounted) {
              Navigator.pop(context);
              showNotice(
                context,
                'Progress recorded. Your future self will thank you.',
              );
            }
          },
        ),
        const SizedBox(height: 16),
        Text(
          'This records your progress only. It does not transfer money or change the demo account forecast.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
