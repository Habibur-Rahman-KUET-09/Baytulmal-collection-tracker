import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../utils/safe_padding.dart';

/// কীভাবে কাজ করে — সংক্ষিপ্ত নির্দেশনা, অ্যাকাউন্ট স্ক্রিন থেকে দেখা যায়।
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.howItWorksTitle)),
      body: ListView(
        padding: safeBodyPadding(context),
        children: [
          for (final section in s.howItWorksSections) _Section(title: section.$1, body: section.$2),
        ],
      ),
    );
  }
}

/// বিস্তারিত নিয়মকানুন (SOP) — অ্যাকাউন্ট স্ক্রিন থেকে দেখা যায়।
class SopScreen extends StatelessWidget {
  const SopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.sopTitle)),
      body: ListView(
        padding: safeBodyPadding(context),
        children: [
          for (final section in s.sopSections) _Section(title: section.$1, body: section.$2),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
