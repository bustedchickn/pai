enum AppSyncStatus { localOnly, synced, pendingChanges, syncing, failed }

class AppSyncState {
  const AppSyncState({
    required this.status,
    required this.pendingChangesCount,
    required this.canSync,
    this.lastSyncedAt,
    this.errorMessage,
    this.userId,
    this.isAnonymous = false,
  });

  final AppSyncStatus status;
  final int pendingChangesCount;
  final bool canSync;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final String? userId;
  final bool isAnonymous;

  String get label {
    return switch (status) {
      AppSyncStatus.localOnly => 'Local only',
      AppSyncStatus.synced => 'Synced',
      AppSyncStatus.pendingChanges => 'Pending changes',
      AppSyncStatus.syncing => 'Syncing...',
      AppSyncStatus.failed => 'Sync failed',
    };
  }

  String get subtitle {
    if (status == AppSyncStatus.failed && errorMessage != null) {
      return errorMessage!;
    }
    if (status == AppSyncStatus.localOnly) {
      return 'Using local data on this device';
    }
    if (pendingChangesCount > 0) {
      return '$pendingChangesCount local change${pendingChangesCount == 1 ? '' : 's'} waiting';
    }
    if (lastSyncedAt == null) {
      return 'Ready to sync';
    }
    return 'Last sync ${_formatRelative(lastSyncedAt!)}';
  }

  AppSyncState copyWith({
    AppSyncStatus? status,
    int? pendingChangesCount,
    bool? canSync,
    Object? lastSyncedAt = _unset,
    Object? errorMessage = _unset,
    Object? userId = _unset,
    bool? isAnonymous,
  }) {
    return AppSyncState(
      status: status ?? this.status,
      pendingChangesCount: pendingChangesCount ?? this.pendingChangesCount,
      canSync: canSync ?? this.canSync,
      lastSyncedAt: lastSyncedAt == _unset
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
      userId: userId == _unset ? this.userId : userId as String?,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }
}

const Object _unset = Object();

String _formatRelative(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) {
    return 'just now';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours}h ago';
  }
  return '${difference.inDays}d ago';
}
