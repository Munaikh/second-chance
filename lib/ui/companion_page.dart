import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/support.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({super.key, this.initialQuestion});
  final String? initialQuestion;
  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  CompanionController? _companion;
  bool _initialised = false;
  int _messageCount = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (!_initialised) {
      _initialised = true;
      _companion = state.companion;
      _companion!.addListener(_onUpdate);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          state.updateCompanionContext();
          if (widget.initialQuestion != null) {
            _companion!.sendText(widget.initialQuestion!);
          }
        }
      });
    }
  }

  void _onUpdate() {
    if (!mounted) return;
    final count = _companion!.messages.length;
    if (count != _messageCount) {
      _messageCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_companion?.endSession());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _companion?.removeListener(_onUpdate);
    unawaited(_companion?.endSession());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    await _companion!.sendText(text);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final companion = _companion!;
    final busy =
        companion.phase == CompanionPhase.connecting ||
        companion.phase == CompanionPhase.thinking;
    return Scaffold(
      appBar: AppBar(
        title: const Text('A moment with Pip'),
        actions: [
          IconButton(
            tooltip: 'Create a support plan',
            onPressed: () async {
              await companion.endSession();
              if (context.mounted) openPage(context, const SupportDetailPage());
            },
            icon: const Icon(CupertinoIcons.doc_text),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  Pip(
                    size: 76,
                    speaking: companion.phase == CompanionPhase.speaking,
                    listening: companion.phase == CompanionPhase.listening,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _phaseLabel(companion.phase),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          companion.modeLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${state.profile.name.split(' ').first}’s synthetic demo',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: AppColors.line(context), height: 1),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(24),
                children: [
                  if (companion.messages.isEmpty) ...[
                    Text(
                      'There’s a way\nthrough this.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ask anything about your forecast, bills or next step. We’ll take it one thing at a time.',
                      style: TextStyle(color: AppColors.muted(context)),
                    ),
                    const SizedBox(height: 23),
                    for (final prompt in [
                      'Why might I run short?',
                      'What can I do before my next bill?',
                      'How can I start a small buffer?',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => companion.sendText(prompt),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(prompt),
                          ),
                        ),
                      ),
                  ],
                  ...companion.messages.map((m) => _ChatMessage(m)),
                  if (busy)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            companion.phase == CompanionPhase.connecting
                                ? 'Connecting to Pip…'
                                : 'Pip is thinking…',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  if (companion.error != null)
                    Surface(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(companion.error!),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () async {
                              await companion.endSession();
                              if (context.mounted) {
                                showNotice(
                                  context,
                                  'Ready to retry. Send a message or start voice.',
                                );
                              }
                            },
                            child: const Text('Reconnect'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  Text(
                    'General guidance using your demo context. Check source details and your circumstances before acting.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                border: Border(top: BorderSide(color: AppColors.line(context))),
              ),
              child: Column(
                children: [
                  if (companion.isVoiceActive) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: companion.toggleMute,
                            icon: Icon(
                              companion.isMuted
                                  ? CupertinoIcons.mic_slash
                                  : CupertinoIcons.mic,
                            ),
                            label: Text(
                              companion.isMuted ? 'Unmute mic' : 'Mute mic',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('stop_voice'),
                            onPressed: companion.stopSpeaking,
                            icon: const Icon(
                              CupertinoIcons.stop_fill,
                              size: 17,
                            ),
                            label: const Text('Stop voice'),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('start_voice'),
                        onPressed: busy
                            ? null
                            : () async {
                                FocusManager.instance.primaryFocus?.unfocus();
                                await companion.startVoice();
                              },
                        icon: const Icon(CupertinoIcons.mic, size: 20),
                        label: const Text('Talk with Pip'),
                      ),
                    ),
                  const SizedBox(height: 11),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('chat_input'),
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          textInputAction: TextInputAction.send,
                          onSubmitted: busy ? null : (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Or type what’s on your mind…',
                            counterText: '',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: const ValueKey('send_message'),
                        onPressed: busy ? null : _send,
                        tooltip: 'Send message',
                        icon: const Icon(CupertinoIcons.arrow_up),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _phaseLabel(CompanionPhase phase) => switch (phase) {
    CompanionPhase.connecting => 'Finding a quiet moment…',
    CompanionPhase.listening => 'I’m listening',
    CompanionPhase.thinking => 'Let’s work it out',
    CompanionPhase.speaking => 'Pip is speaking',
    CompanionPhase.error => 'Let’s reconnect',
    CompanionPhase.idle => 'Here for you',
  };
}

class _ChatMessage extends StatelessWidget {
  const _ChatMessage(this.message);
  final CompanionMessage message;
  @override
  Widget build(BuildContext context) {
    final user = message.role == 'user';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, top: 3),
        padding: const EdgeInsets.all(17),
        constraints: const BoxConstraints(maxWidth: 490),
        decoration: BoxDecoration(
          color: user ? AppColors.accent(context) : AppColors.surface(context),
          borderRadius: BorderRadius.circular(22),
          border: user ? null : Border.all(color: AppColors.line(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!user)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  message.isFallback ? 'PIP · CALCULATED DEMO GUIDANCE' : 'PIP',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontSize: 10),
                ),
              ),
            SelectableText(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: user ? Theme.of(context).colorScheme.onPrimary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
