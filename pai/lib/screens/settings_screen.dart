import 'package:flutter/material.dart';

import '../models/app_appearance_mode.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.appearanceMode,
    required this.onAppearanceModeChanged,
    required this.showWorkspaceStats,
    required this.onShowWorkspaceStatsChanged,
  });

  final AppAppearanceMode appearanceMode;
  final ValueChanged<AppAppearanceMode> onAppearanceModeChanged;
  final bool showWorkspaceStats;
  final ValueChanged<bool> onShowWorkspaceStatsChanged;

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
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose how PAI looks across the app.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<AppAppearanceMode>(
                      groupValue: appearanceMode,
                      onChanged: (value) {
                        if (value != null) {
                          onAppearanceModeChanged(value);
                        }
                      },
                      child: Column(
                        children: [
                          for (final mode in AppAppearanceMode.values)
                            RadioListTile<AppAppearanceMode>(
                              value: mode,
                              contentPadding: EdgeInsets.zero,
                              title: Text(mode.label),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile.adaptive(
                secondary: const Icon(Icons.bar_chart_rounded),
                value: showWorkspaceStats,
                onChanged: onShowWorkspaceStatsChanged,
                title: const Text('Show workspace stats'),
                subtitle: const Text(
                  'Display summary stats at the top of the workspace',
                ),
              ),
            ),
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

