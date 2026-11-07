import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/forecast.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Demo profiles')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Different lives.\nPersonal support.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 14),
          Text(
            'Two fictional UK households. No bank connection or real customer data.',
            style: TextStyle(color: AppColors.muted(context)),
          ),
          const SizedBox(height: 26),
          for (final p in DemoProfiles.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.canvas(context),
                          child: Text(
                            p.initials,
                            style: TextStyle(color: AppColors.accent(context)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            p.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (p.id == state.profile.id)
                          Icon(
                            CupertinoIcons.checkmark_circle_fill,
                            color: AppColors.accent(context),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(p.description),
                    const SizedBox(height: 7),
                    Text(
                      p.household,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusPill(p.incomeLabel),
                        StatusPill(
                          '${formatPence(p.openingBalancePence)} available',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      key: ValueKey('profile_${p.id}'),
                      label: p.id == state.profile.id
                          ? 'Current profile'
                          : 'Explore ${p.name.split(' ').first}’s story',
                      onPressed: p.id == state.profile.id || state.isGenerating
                          ? null
                          : () async {
                              await state.selectProfile(p.id);
                              if (context.mounted) Navigator.pop(context);
                            },
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          ActionRow(
            icon: CupertinoIcons.list_bullet,
            title: 'Explore the demo data',
            subtitle: 'Eight weeks of reconciled history',
            onTap: () => openPage(context, const LedgerPage()),
          ),
          const SizedBox(height: 16),
          const Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About this prototype',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 10),
                Text(
                  'Built for the NatWest hackathon. The demo clock is 7 November 2026. Forecasts are calculated locally; Cloudy uses ElevenLabs; recovery plans run through a local n8n workflow.',
                ),
                SizedBox(height: 10),
                Text(
                  'Goals and drafts stay on this device. Chat sends only synthetic context to ElevenLabs. No payments, credit applications or messages are sent.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            key: const ValueKey('reset_demo'),
            icon: const Icon(CupertinoIcons.arrow_counterclockwise),
            label: const Text('Reset all demo progress'),
            onPressed: state.isGenerating
                ? null
                : () async {
                    final reset = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Start the demo again?'),
                        content: const Text(
                          'This clears saved goals, actions and drafts for both fictional profiles.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Keep progress'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Reset demo'),
                          ),
                        ],
                      ),
                    );
                    if (reset == true) {
                      await state.resetDemo();
                      if (context.mounted) {
                        Navigator.pop(context);
                        showNotice(context, 'Ready for a fresh start.');
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }
}
