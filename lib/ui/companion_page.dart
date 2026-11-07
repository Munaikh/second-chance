import 'package:flutter/material.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/grow.dart';
import 'package:second_chance/ui/home.dart';
import 'package:second_chance/ui/support.dart';

class CompanionPage extends StatelessWidget {
  const CompanionPage({super.key, this.initialQuestion});
  final String? initialQuestion;
  @override
  Widget build(BuildContext context) => PreparePage(
    startInConversation: true,
    initialQuestion: initialQuestion,
    onSupport: () => openPage(context, const SupportDetailPage()),
    onGrow: () => openPage(
      context,
      Scaffold(
        appBar: AppBar(title: const Text('Your resilience')),
        body: const GrowPage(),
      ),
    ),
  );
}
