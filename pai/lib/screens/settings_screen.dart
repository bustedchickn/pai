import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_appearance_mode.dart';
import '../models/app_sync_state.dart';
import '../services/auth_bootstrap_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.appearanceMode,
    required this.onAppearanceModeChanged,
    required this.showWorkspaceStats,
    required this.onShowWorkspaceStatsChanged,
    required this.syncState,
    required this.onSyncRequested,
    required this.authState,
    required this.onLinkGoogleRequested,
    this.isLinkingGoogle = false,
  });

  final AppAppearanceMode appearanceMode;
  final ValueChanged<AppAppearanceMode> onAppearanceModeChanged;
  final bool showWorkspaceStats;
  final ValueChanged<bool> onShowWorkspaceStatsChanged;
  final AppSyncState syncState;
  final Future<void> Function() onSyncRequested;
  final AuthBootstrapResult authState;
  final Future<void> Function() onLinkGoogleRequested;
  final bool isLinkingGoogle;

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
            const SizedBox(height: 12),
            _AccountCard(
              authState: authState,
              onGoogleRequested: onLinkGoogleRequested,
              isProcessing: isLinkingGoogle,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_sync_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cloud sync',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: syncState.canSync
                              ? () => onSyncRequested()
                              : null,
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text('Sync now'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(syncState.label),
                    const SizedBox(height: 4),
                    Text(syncState.subtitle),
                    const SizedBox(height: 12),
                    const Text(
                      'PAI stays local-first. Editing happens on-device, and Sync uploads only the changed projects and pages when you ask for it.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.keyboard_voice_outlined),
                title: Text('Dictation'),
                subtitle: Text(
                  'Standard TextField editing already works with OS keyboard dictation. The existing in-app mic flow only inserts text and does not store audio recordings.',
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_circle_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Account',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
              ],
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
            const SizedBox(height: 12),
            Text(
              authState.isGoogleLinked
                  ? 'This Firebase account is already linked to Google, so future sign-ins can reuse the same user and synced data.'
                  : authState.isAnonymous
                  ? 'Link Google to upgrade this anonymous Firebase account without changing its UID or the Firestore data already attached to it.'
                  : 'Sign in with Google to connect this app to a Google-backed Firebase account.',
            ),
            if (showWindowsHint) ...[
              const SizedBox(height: 8),
              Text(
                'On Windows, Google sign-in opens your browser and returns to the app when finished.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
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
