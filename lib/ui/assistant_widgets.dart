import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/ui/companion_action_card.dart';

abstract final class AssistantColors {
  static const ink = Color(0xFF173D52);
  static const accent = Color(0xFF267D9F);
  static const composer = Color(0xFF141C2B);
  static const onComposer = Color(0xFFF5F7FB);
  static List<Color> sky(bool dark) => dark
      ? const [Color(0xFF173B53), Color(0xFF1C3549), Color(0xFF151E2A)]
      : const [Color(0xFF80C9E7), Color(0xFFC7E6F2), Color(0xFFF5F9FB)];
}

class AssistantIconButton extends StatelessWidget {
  const AssistantIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.child,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor:
              (dark ? const Color(0xFFEDF7FC) : const Color(0xFFFAFDFE))
                  .withValues(alpha: dark ? .12 : .38),
          foregroundColor: dark ? const Color(0xFFF2F7FB) : AssistantColors.ink,
        ),
        icon: child ?? Icon(icon, size: 21),
      ),
    );
  }
}

class CompanionComposer extends StatelessWidget {
  const CompanionComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.companion,
    required this.onSend,
    required this.onVoice,
    required this.onStop,
    required this.onPrompt,
    this.showSuggestions = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final CompanionController companion;
  final VoidCallback onSend, onVoice, onStop;
  final ValueChanged<String> onPrompt;
  final bool showSuggestions;
  @override
  Widget build(BuildContext context) {
    final busy =
        companion.phase == CompanionPhase.connecting ||
        companion.phase == CompanionPhase.thinking;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSuggestions) ...[
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final prompt in const [
                      ('Explain my forecast', 'Why might I run short?'),
                      (
                        'Plan a little buffer',
                        'How can I start a small emergency buffer?',
                      ),
                      (
                        'Help with my bills',
                        'What can I do before my next bill?',
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextButton(
                          onPressed: () => onPrompt(prompt.$2),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            minimumSize: const Size(44, 44),
                            backgroundColor: dark
                                ? const Color(0xFF273849)
                                : const Color(0xFFFDFDFE),
                            foregroundColor: dark
                                ? const Color(0xFFE3EDF5)
                                : AssistantColors.ink,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: Text(prompt.$1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (companion.isVoiceActive ||
                companion.phase == CompanionPhase.connecting) ...[
              Row(
                children: [
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.circle_fill,
                    size: 7,
                    color: dark
                        ? const Color(0xFF98D4EA)
                        : AssistantColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      companion.phase == CompanionPhase.connecting
                          ? 'Connecting to Cloudy…'
                          : companion.phase == CompanionPhase.speaking
                          ? 'Cloudy is speaking'
                          : companion.isMuted
                          ? 'Microphone muted'
                          : 'Cloudy is listening',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('stop_voice'),
                    onPressed: onStop,
                    child: const Text('Stop voice'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Container(
              decoration: BoxDecoration(
                color: AssistantColors.composer,
                borderRadius: BorderRadius.circular(34),
              ),
              padding: const EdgeInsets.fromLTRB(19, 7, 7, 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chat_input'),
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      style: const TextStyle(
                        color: AssistantColors.onComposer,
                        fontSize: 16,
                        height: 1.4,
                      ),
                      cursorColor: const Color(0xFF8DD7F5),
                      textInputAction: TextInputAction.send,
                      onSubmitted: busy ? null : (_) => onSend(),
                      decoration: const InputDecoration(
                        hintText: 'What’s on your mind?',
                        hintStyle: TextStyle(
                          color: Color(0xFFB5BBC8),
                          fontSize: 15,
                        ),
                        counterText: '',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('start_voice'),
                    tooltip: companion.isVoiceActive
                        ? 'Voice controls'
                        : 'Talk with Cloudy',
                    onPressed:
                        companion.phase == CompanionPhase.connecting ||
                            (busy && !companion.isVoiceActive)
                        ? null
                        : onVoice,
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFFD2D8E3),
                      disabledForegroundColor: const Color(0xFF747E90),
                      minimumSize: const Size(44, 48),
                    ),
                    icon: Icon(
                      companion.isVoiceActive && companion.isMuted
                          ? CupertinoIcons.mic_slash
                          : CupertinoIcons.mic,
                      size: 21,
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => IconButton.filled(
                      key: const ValueKey('send_message'),
                      tooltip: 'Send message',
                      onPressed: !busy && value.text.trim().isNotEmpty
                          ? onSend
                          : null,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF348AB0),
                        foregroundColor: const Color(0xFFF5FCFF),
                        disabledBackgroundColor: const Color(0xFF28384A),
                        disabledForegroundColor: const Color(0xFFA6B8C9),
                        minimumSize: const Size(44, 48),
                      ),
                      icon: const Icon(CupertinoIcons.arrow_up, size: 21),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CompanionBubble extends StatelessWidget {
  const CompanionBubble(this.message, {super.key});
  final CompanionMessage message;
  @override
  Widget build(BuildContext context) {
    final user = message.role == 'user';
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: user ? 32 : 0,
          right: user ? 0 : 24,
          bottom: 16,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
        decoration: BoxDecoration(
          color: user
              ? AssistantColors.composer
              : dark
              ? const Color(0xFF283D4E)
              : const Color(0xFFFDFDFE),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(23),
            topRight: const Radius.circular(23),
            bottomLeft: Radius.circular(user ? 23 : 6),
            bottomRight: Radius.circular(user ? 6 : 23),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isFallback)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Calculated demo guidance',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (message.actionResult != null)
              CompanionActionCard(result: message.actionResult!)
            else
              SelectableText(
                user
                    ? message.text
                    : message.text.replaceAll(
                        RegExp(
                          r'\[(?:calm|warm|slow|curious|whispering|happy|sad|excited|serious|reassuring|thoughtful|friendly|empathetic|laughs|sighs|clears throat|short pause|long pause)\]\s*',
                          caseSensitive: false,
                        ),
                        '',
                      ),
                style: TextStyle(
                  color: user
                      ? AssistantColors.onComposer
                      : dark
                      ? const Color(0xFFF0F5F9)
                      : const Color(0xFF203E51),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
