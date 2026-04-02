import 'package:flutter/material.dart';

import '../models/app_sync_state.dart';

class GlobalSyncBar extends StatelessWidget {
  const GlobalSyncBar({
    super.key,
    required this.syncState,
    required this.onSyncRequested,
  });

  final AppSyncState syncState;
  final VoidCallback? onSyncRequested;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tone = switch (syncState.status) {
      AppSyncStatus.synced => colorScheme.tertiary,
      AppSyncStatus.pendingChanges => colorScheme.primary,
      AppSyncStatus.syncing => colorScheme.primary,
      AppSyncStatus.failed => colorScheme.error,
      AppSyncStatus.localOnly => colorScheme.onSurfaceVariant,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_sync_outlined, color: tone, size: 18),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      syncState.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tone,
                      ),
                    ),
                    Text(
                      syncState.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: syncState.canSync ? onSyncRequested : null,
              icon: syncState.status == AppSyncStatus.syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              label: const Text('Sync'),
            ),
          ],
        ),
      ),
    );
  }
}
