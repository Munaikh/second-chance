import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/companion_page.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/cloudy.dart';
import 'package:second_chance/ui/home.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const SafeArea(bottom: false, child: SupportContent(showHeader: true));
}

class SupportDetailPage extends StatelessWidget {
  const SupportDetailPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('A plan for right now')),
    body: const SupportContent(),
  );
}

class SupportContent extends StatelessWidget {
  const SupportContent({super.key, this.showHeader = false});
  final bool showHeader;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return ListView(
      key: PageStorageKey('support_${state.profile.id}'),
      padding: EdgeInsets.fromLTRB(24, 10, 24, showHeader ? 140 : 40),
      children: [
        if (showHeader) ...[
          const PageHeader(label: 'Support'),
          const SizedBox(height: 25),
        ],
        Text(
          'A setback is\njust one chapter.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'Let’s make the next step a little easier.',
          style: TextStyle(color: AppColors.muted(context)),
        ),
        const SizedBox(height: 26),
        Surface(
          child: Row(
            children: [
              const Cloudy(size: 84),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start where you are.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.forecast.firstShortfall == null
                          ? 'A plan can help you keep your breathing room.'
                          : 'Your forecast shows a ${formatPence(state.shortfallPence)} gap on ${formatDate(state.forecast.firstShortfall!.date)}.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Text(
          'What’s on your mind?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              ('income_drop', 'Less income'),
              ('unexpected_bill', 'An unexpected bill'),
              ('complaint', 'Something went wrong'),
            ])
              ChoiceChip(
                label: Text(item.$2),
                selected: state.hardship == item.$1,
                onSelected: state.isGenerating
                    ? null
                    : (_) {
                        state.hardship = item.$1;
                        state.persist();
                      },
              ),
          ],
        ),
        const SizedBox(height: 17),
        TextFormField(
          key: ValueKey('support_note_${state.profile.id}'),
          initialValue: state.supportNote,
          enabled: !state.isGenerating,
          maxLength: 1000,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Anything you’d like to add?',
            hintText: 'Optional · use fictional details for this demo',
            alignLabelWithHint: true,
          ),
          onChanged: (text) {
            state.supportNote = text;
            state.persist();
          },
        ),
        const SizedBox(height: 9),
        if (state.recoveryError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(CupertinoIcons.wifi_exclamationmark),
                  const SizedBox(height: 10),
                  Text(state.recoveryError!),
                  const SizedBox(height: 8),
                  Text(
                    'Your note and any existing plan are still here.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        if (state.recovery != null) ...[
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(
                  'Plan saved on this device',
                  icon: CupertinoIcons.checkmark_circle,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 14),
                Text(
                  state.recovery!.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(state.recovery!.summary),
                const SizedBox(height: 16),
                PrimaryButton(
                  key: const ValueKey('open_plan'),
                  label: 'Open my plan',
                  onPressed: () => openPage(context, const RecoveryPlanPage()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: state.isGenerating
                ? null
                : () async {
                    final replace = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Create a fresh plan?'),
                        content: const Text(
                          'This replaces your saved plan and draft with one using your current scenario.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Keep this plan'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Create plan'),
                          ),
                        ],
                      ),
                    );
                    if (replace == true) {
                      await state.generateRecovery();
                      if (context.mounted && state.recoveryError == null) {
                        openPage(context, const RecoveryPlanPage());
                      }
                    }
                  },
            child: const Text('Create a fresh plan'),
          ),
        ] else
          PrimaryButton(
            key: const ValueKey('generate_recovery'),
            label: state.isGenerating
                ? 'Finding your next steps…'
                : state.recoveryError != null
                ? 'Try creating my plan again'
                : 'Create my recovery plan',
            icon: CupertinoIcons.sparkles,
            loading: state.isGenerating,
            onPressed: () async {
              await state.generateRecovery();
              if (context.mounted &&
                  state.recovery != null &&
                  state.recoveryError == null) {
                openPage(context, const RecoveryPlanPage());
              }
            },
          ),
        const SizedBox(height: 14),
        Text(
          'Includes a practical plan, an editable support request and the evidence to gather. Nothing is sent for you.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 28),
        ActionRow(
          icon: CupertinoIcons.bubble_left_bubble_right,
          title: 'Prefer to talk first?',
          subtitle: 'Cloudy can help you put it into words',
          onTap: () => openPage(
            context,
            const CompanionPage(
              initialQuestion: 'I’m worried about keeping up with my bills. What’s a useful first step?',
            ),
          ),
        ),
        const SizedBox(height: 14),
        const GuidanceLink(
          title: 'Free, impartial money guidance',
          url: 'https://www.moneyhelper.org.uk/en/money-troubles/dealing-with-debt',
          detail: 'MoneyHelper · explore support at your own pace',
        ),
      ],
    );
  }
}

class RecoveryPlanPage extends StatelessWidget {
  const RecoveryPlanPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final plan = state.recovery;
    if (plan == null) return const SupportDetailPage();
    return Scaffold(
      appBar: AppBar(title: const Text('Your way forward')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 40),
        children: [
          StatusPill(
            'Personalised for ${state.profile.name.split(' ').first}',
            icon: CupertinoIcons.heart,
          ),
          const SizedBox(height: 18),
          Text(plan.title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 12),
          Text(plan.summary, style: TextStyle(color: AppColors.muted(context))),
          const SizedBox(height: 24),
          ...plan.steps.indexed.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 29,
                          height: 29,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.accent(context),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${item.$1 + 1}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.$2.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(item.$2.detail),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            key: const ValueKey('review_draft'),
            label: 'Review my support request',
            icon: CupertinoIcons.doc_text,
            onPressed: () => openPage(context, const DraftPage()),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await state.recordAction('Reviewed my recovery steps');
              if (context.mounted) {
                showNotice(
                  context,
                  'A useful step forward. Your progress is recorded.',
                );
              }
            },
            icon: Icon(
              state.actions.any((a) => a.label == 'Reviewed my recovery steps')
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.checkmark_circle,
            ),
            label: const Text('I’ve reviewed my next steps'),
          ),
          const SizedBox(height: 22),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Facts and things to check'),
            children: [
              Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From your demo profile',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    ...plan.knownFacts.map((f) => _Bullet(f)),
                    const SizedBox(height: 14),
                    Text(
                      'Confirm before you act',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    ...plan.assumptions.map((f) => _Bullet(f)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const SectionHeading('Where the guidance comes from'),
          const SizedBox(height: 12),
          ...plan.sources.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GuidanceLink(
                title: s.title,
                url: s.url,
                detail: s.excerpt,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'n8n workflow · run ${plan.executionId}\nPersonalised from your inputs and curated guidance. This is general support; eligibility and outcomes need confirmation.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class DraftPage extends StatefulWidget {
  const DraftPage({super.key});
  @override
  State<DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<DraftPage> {
  TextEditingController? _body;
  TextEditingController? _subject;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    _body ??= TextEditingController(text: state.draftBody);
    _subject ??= TextEditingController(text: state.draftSubject);
  }

  @override
  void dispose() {
    _body?.dispose();
    _subject?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final plan = state.recovery;
    return Scaffold(
      appBar: AppBar(title: const Text('Your support request')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryButton(
                key: const ValueKey('copy_draft'),
                label: 'Copy my draft',
                icon: CupertinoIcons.doc_on_doc,
                onPressed: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  await state.persist();
                  await Clipboard.setData(
                    ClipboardData(
                      text: 'Subject: ${_subject!.text}\n\n${_body!.text}',
                    ),
                  );
                  if (context.mounted) {
                    showNotice(
                      context,
                      'Draft copied. Review your details before sharing.',
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'You review it. Nothing is sent.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 40),
        children: [
          const StatusPill(
            'Editable draft · saved as you type',
            icon: CupertinoIcons.doc_text,
          ),
          const SizedBox(height: 19),
          Text(
            'Your words.\nYour next step.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Check every detail and replace the brackets before you share it.',
            style: TextStyle(color: AppColors.muted(context)),
          ),
          const SizedBox(height: 22),
          if (plan != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Text(
                'To: ${plan.recipient}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          TextField(
            key: const ValueKey('draft_subject'),
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Subject'),
            maxLength: 250,
            onChanged: (value) => state.saveDraft(subject: value),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('draft_body'),
            controller: _body,
            minLines: 12,
            maxLines: null,
            maxLength: 10000,
            decoration: const InputDecoration(
              labelText: 'Your draft',
              alignLabelWithHint: true,
            ),
            onChanged: (value) => state.saveDraft(body: value),
          ),
          const SizedBox(height: 15),
          Text(
            'Nothing is sent. You choose when and how to contact the organisation.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 27),
          const SectionHeading('What to have ready'),
          const SizedBox(height: 14),
          if (plan != null)
            Surface(
              child: Column(
                children: plan.evidence.map((e) => _Bullet(e)).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Icon(
            CupertinoIcons.circle_filled,
            size: 5,
            color: AppColors.muted(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class GuidanceLink extends StatelessWidget {
  const GuidanceLink({
    super.key,
    required this.title,
    required this.url,
    required this.detail,
  });
  final String title, url, detail;
  @override
  Widget build(BuildContext context) => Surface(
    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
    child: ActionRow(
      icon: CupertinoIcons.arrow_up_right_square,
      title: title,
      subtitle: detail,
      onTap: () async {
        try {
          final opened = await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
          if (!opened && context.mounted) {
            showNotice(
              context,
              'Couldn’t open this source. Try again when you’re online.',
            );
          }
        } catch (_) {
          if (context.mounted) {
            showNotice(
              context,
              'Couldn’t open this source. Try again when you’re online.',
            );
          }
        }
      },
    ),
  );
}
