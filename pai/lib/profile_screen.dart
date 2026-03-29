import 'package:flutter/material.dart';

import 'models/app_appearance_mode.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: 0.14,
                      ),
                      child: Text(
                        'P',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Appearance and workspace settings in one calm place.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ProfileSection(
              title: 'Appearance',
              subtitle: 'Choose how pai looks across the app.',
              child: RadioGroup<AppAppearanceMode>(
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
            ),
            const SizedBox(height: 16),
            _ProfileSection(
              title: 'Workspace',
              subtitle: 'Keep the home screen focused.',
              child: SwitchListTile.adaptive(
                value: showWorkspaceStats,
                contentPadding: EdgeInsets.zero,
                onChanged: onShowWorkspaceStatsChanged,
                title: const Text('Show workspace stats'),
                subtitle: const Text(
                  'Display summary metrics on the desktop workspace.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
