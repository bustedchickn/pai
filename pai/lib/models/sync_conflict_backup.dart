enum SyncConflictEntityType { project, document }
enum SyncConflictSource { local, remote }

class SyncConflictBackup {
  const SyncConflictBackup({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.projectId,
    required this.title,
    required this.capturedAt,
    required this.source,
    required this.payload,
  });

  final String id;
  final SyncConflictEntityType entityType;
  final String entityId;
  final String? projectId;
  final String title;
  final DateTime capturedAt;
  final SyncConflictSource source;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': switch (entityType) {
        SyncConflictEntityType.project => 'project',
        SyncConflictEntityType.document => 'document',
      },
      'entityId': entityId,
      'projectId': projectId,
      'title': title,
      'capturedAt': capturedAt.toIso8601String(),
      'source': switch (source) {
        SyncConflictSource.local => 'local',
        SyncConflictSource.remote => 'remote',
      },
      'payload': payload,
    };
  }

  factory SyncConflictBackup.fromJson(Map<String, dynamic> json) {
    return SyncConflictBackup(
      id: json['id'] as String? ?? '',
      entityType: switch (json['entityType']) {
        'project' => SyncConflictEntityType.project,
        _ => SyncConflictEntityType.document,
      },
      entityId: json['entityId'] as String? ?? '',
      projectId: json['projectId'] as String?,
      title: json['title'] as String? ?? '',
      capturedAt:
          DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
          DateTime.now(),
      source: switch (json['source']) {
        'remote' => SyncConflictSource.remote,
        _ => SyncConflictSource.local,
      },
      payload: Map<String, dynamic>.from(
        json['payload'] as Map<dynamic, dynamic>? ?? const {},
      ),
    );
  }
}
