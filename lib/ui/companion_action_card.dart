import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/support.dart';

class CompanionActionCard extends StatelessWidget {
  const CompanionActionCard({super.key, required this.result});
  final Map<String, Object?> result;

  @override
  Widget build(BuildContext context) {
    final artifact = Map<String, Object?>.from(
      result['artifact'] as Map? ?? {},
    );
    final forecast = artifact['forecast'] as Map? ?? {};
    final type = artifact['type'];
    final title = switch (type) {
      'forecast' => 'Forecast updated',
      'recovery_plan' => 'Your plan is ready',
      'goal' => 'Your savings goal',
      'history_comparison' => 'Expected vs actual',
      _ => 'Action completed',
    };
    Widget fact(String label, Object? value) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text('$label: ${value ?? '—'}'),
    );
    return Column(
      key: ValueKey('action_${result['action']}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(result['summary']?.toString() ?? ''),
        if (type == 'forecast') ...[
          fact('Projected low', (forecast['lowestDay'] as Map?)?['balanceGBP']),
          fact('Closing balance', forecast['endingBalanceGBP']),
          Text(
            'What-if estimate · no money moved',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (type == 'history_comparison') ...[
          fact('Expected ending balance', artifact['expectedEndingBalanceGBP']),
          fact('Actual ending balance', artifact['actualEndingBalanceGBP']),
          fact('Difference', artifact['varianceGBP']),
          const SizedBox(height: 8),
          Text(
            artifact['disclosure']?.toString() ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (type == 'goal') ...[
          fact('Goal', artifact['title']),
          fact('Target', artifact['targetGBP']),
          fact('Already recorded', artifact['savedGBP']),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (artifact['progress'] as num? ?? 0).toDouble().clamp(0, 1),
            minHeight: 7,
            semanticsLabel: 'Recorded savings progress',
          ),
          const SizedBox(height: 8),
          Text(
            'Goal saved · no money transferred',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (type == 'recovery_plan') ...[
          const SizedBox(height: 8),
          for (final step in (artifact['steps'] as List? ?? []).take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• ${(step as Map)['title']}'),
            ),
          InlineRecoveryDraft(
            key: ValueKey('inline_draft_${artifact['executionId']}'),
            artifact: artifact,
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Evidence and sources'),
            children: [
              for (final item in artifact['evidence'] as List? ?? [])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $item'),
                ),
              for (final source in artifact['sources'] as List? ?? [])
                GuidanceLink(
                  title: (source as Map)['title'].toString(),
                  url: source['url'].toString(),
                  detail: source['excerpt']?.toString() ?? '',
                ),
            ],
          ),
          Text(
            'Draft only · nothing has been sent',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class InlineRecoveryDraft extends StatefulWidget {
  const InlineRecoveryDraft({super.key, required this.artifact});
  final Map<String, Object?> artifact;
  @override
  State<InlineRecoveryDraft> createState() => _InlineRecoveryDraftState();
}

class _InlineRecoveryDraftState extends State<InlineRecoveryDraft> {
  TextEditingController? _subject, _body;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    final current =
        state.profile.id == widget.artifact['profileId'] &&
        state.recovery?.executionId == widget.artifact['executionId'];
    final draft = widget.artifact['draft'] as Map? ?? {};
    _subject ??= TextEditingController(
      text: current ? state.draftSubject : draft['subject']?.toString() ?? '',
    );
    _body ??= TextEditingController(
      text: current ? state.draftBody : draft['body']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _subject?.dispose();
    _body?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final current =
        state.profile.id == widget.artifact['profileId'] &&
        state.recovery?.executionId == widget.artifact['executionId'];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        current ? 'Review and edit your draft' : 'Earlier draft · read only',
      ),
      children: [
        TextField(
          key: const ValueKey('chat_draft_subject'),
          controller: _subject,
          readOnly: !current,
          decoration: const InputDecoration(labelText: 'Subject'),
          onChanged: current
              ? (value) => unawaited(state.saveDraft(subject: value))
              : null,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('chat_draft_body'),
          controller: _body,
          readOnly: !current,
          minLines: 6,
          maxLines: 10,
          decoration: const InputDecoration(labelText: 'Your draft'),
          onChanged: current
              ? (value) => unawaited(state.saveDraft(body: value))
              : null,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('copy_chat_draft'),
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(
                text: 'Subject: ${_subject!.text}\n\n${_body!.text}',
              ),
            );
            if (context.mounted) showNotice(context, 'Draft copied');
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy draft'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
