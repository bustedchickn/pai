import 'package:flutter/material.dart';

import '../models/app_sync_state.dart';

class GlobalSyncBar extends StatelessWidget {
  const GlobalSyncBar({
    super.key,
    required this.syncState,
    required this.onSyncRequested,
    this.compact = false,
  });

  final AppSyncState syncState;
  final VoidCallback? onSyncRequested;
  final bool compact;

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
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 8 : 10,
        ),
        child: Wrap(
          spacing: compact ? 8 : 12,
          runSpacing: compact ? 6 : 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_sync_outlined,
                  color: tone,
                  size: compact ? 16 : 18,
                ),
                SizedBox(width: compact ? 6 : 8),
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
                    if (!compact)
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
