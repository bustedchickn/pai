import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              'Settings',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Card(
              child: ListTile(
                leading: Icon(Icons.sync_outlined),
                title: Text('Sync'),
                subtitle: Text(
                  'Start with local data first, then connect Firebase later.',
                ),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.mic_none_outlined),
                title: Text('Voice notes'),
                subtitle: Text(
                  'Enable speech-to-text after the core session flow works.',
                ),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.auto_awesome_outlined),
                title: Text('AI assistant'),
                subtitle: Text(
                  'Use simple prompts and summaries now, then add smarter AI later.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
