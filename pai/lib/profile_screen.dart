import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models/app_appearance_mode.dart';
import 'services/auth_bootstrap_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.appearanceMode,
    required this.onAppearanceModeChanged,
    required this.showWorkspaceStats,
    required this.onShowWorkspaceStatsChanged,
    required this.authState,
    required this.onLinkGoogleRequested,
    this.isLinkingGoogle = false,
  });

  final AppAppearanceMode appearanceMode;
  final ValueChanged<AppAppearanceMode> onAppearanceModeChanged;
  final bool showWorkspaceStats;
  final ValueChanged<bool> onShowWorkspaceStatsChanged;
  final AuthBootstrapResult authState;
  final Future<void> Function() onLinkGoogleRequested;
  final bool isLinkingGoogle;

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
                            'Appearance, workspace, and account settings in one calm place.',
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
              title: 'Account',
              subtitle: authState.isGoogleLinked
                  ? 'Your Firebase account is already linked to Google.'
                  : authState.isAnonymous
                  ? 'Upgrade this anonymous account without losing its existing UID or synced data.'
                  : 'Connect Google sign-in for this app session.',
              child: _AccountSection(
                authState: authState,
                onGoogleRequested: onLinkGoogleRequested,
                isProcessing: isLinkingGoogle,
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

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.authState,
    required this.onGoogleRequested,
    required this.isProcessing,
  });

  final AuthBootstrapResult authState;
  final Future<void> Function() onGoogleRequested;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showWindowsHint =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        !authState.isGoogleLinked;
    final actionLabel = authState.isGoogleLinked
        ? 'Linked to Google'
        : authState.isAnonymous
        ? 'Link Google Account'
        : 'Sign in with Google';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: authState.canLinkGoogle && !isProcessing
              ? () => onGoogleRequested()
              : null,
          icon: isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  authState.isGoogleLinked
                      ? Icons.check_circle_outline_rounded
                      : Icons.login_rounded,
                ),
          label: Text(actionLabel),
        ),
        const SizedBox(height: 12),
        Text(authState.accountLabel),
        if (authState.displayName != null &&
            authState.displayName!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(authState.displayName!),
        ],
        if (authState.email != null) ...[
          const SizedBox(height: 4),
          Text(authState.email!),
        ],
        if (authState.uid != null) ...[
          const SizedBox(height: 4),
          Text(authState.uid!, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ProviderChip(
              label: authState.isAnonymous
                  ? 'Anonymous account'
                  : 'Anonymous disabled',
            ),
            for (final provider in authState.linkedProviders)
              _ProviderChip(label: _providerLabel(provider)),
            if (authState.linkedProviders.isEmpty)
              const _ProviderChip(label: 'No linked providers yet'),
          ],
        ),
        if (showWindowsHint) ...[
          const SizedBox(height: 12),
          Text(
            'On Windows, Google sign-in opens your browser and returns to the app when finished.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

String _providerLabel(String providerId) {
  return switch (providerId) {
    'google.com' => 'Google',
    'anonymous' => 'Anonymous',
    _ => providerId,
  };
}
