import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/ui/design.dart';

class VoiceCompanionPanel extends StatelessWidget {
  const VoiceCompanionPanel({
    super.key,
    required this.companion,
    required this.transcript,
    required this.onMute,
    required this.onEnd,
    required this.onChat,
  });

  final CompanionController companion;
  final Widget transcript;
  final VoidCallback onMute, onEnd, onChat;

  @override
  Widget build(BuildContext context) {
    final ready =
        companion.isVoiceActive &&
        companion.phase != CompanionPhase.connecting &&
        companion.phase != CompanionPhase.error;
    final status = switch (companion.phase) {
      CompanionPhase.connecting => 'Connecting to Cloudy…',
      CompanionPhase.speaking => 'Cloudy is speaking',
      CompanionPhase.listening =>
        companion.isMuted ? 'Microphone muted' : 'Cloudy is listening',
      CompanionPhase.error => 'Let’s reconnect',
      CompanionPhase.thinking => 'Cloudy is thinking…',
      _ => 'Talk with Cloudy',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _VoiceAction(
                      key: const ValueKey('voice_mute'),
                      icon: companion.isMuted
                          ? CupertinoIcons.mic_slash
                          : CupertinoIcons.mic,
                      label: companion.isMuted ? 'Unmute' : 'Mute',
                      onPressed: ready ? onMute : null,
                    ),
                  ),
                  Expanded(
                    child: _VoiceAction(
                      key: const ValueKey('voice_end'),
                      icon: CupertinoIcons.phone_down_fill,
                      label: 'End',
                      onPressed: onEnd,
                      destructive: true,
                    ),
                  ),
                  Expanded(
                    child: _VoiceAction(
                      key: const ValueKey('voice_chat'),
                      icon: CupertinoIcons.chat_bubble,
                      label: 'Chat',
                      onPressed: onChat,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: transcript),
          ],
        ),
      ),
    );
  }
}

class _VoiceAction extends StatelessWidget {
  const _VoiceAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 56),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      foregroundColor: destructive
          ? Theme.of(context).colorScheme.error
          : AppColors.ink(context),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}
