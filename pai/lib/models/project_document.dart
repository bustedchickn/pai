enum ProjectDocumentType { design, implementation, story, research, reference }

enum ProjectPageKind { brief, document }

extension ProjectDocumentTypePresentation on ProjectDocumentType {
  String get label {
    switch (this) {
      case ProjectDocumentType.design:
        return 'Design';
      case ProjectDocumentType.implementation:
        return 'Implementation';
      case ProjectDocumentType.story:
        return 'Story';
      case ProjectDocumentType.research:
        return 'Research';
      case ProjectDocumentType.reference:
        return 'Reference';
    }
  }
}

class ProjectDocument {
  final String id;
  final String projectId;
  final String title;
  final ProjectPageKind kind;
  final ProjectDocumentType type;
  final String content;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;
  final bool isDirty;
  final DateTime? deletedAt;
  final int? orderIndex;

  const ProjectDocument({
    required this.id,
    required this.projectId,
    required this.title,
    this.kind = ProjectPageKind.document,
    required this.type,
    required this.content,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncedAt,
    this.isDirty = false,
    this.deletedAt,
    this.orderIndex,
  });

  ProjectDocument copyWith({
    String? id,
    String? projectId,
    String? title,
    ProjectPageKind? kind,
    ProjectDocumentType? type,
    String? content,
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? lastSyncedAt = _projectDocumentCopyWithUnset,
    bool? isDirty,
    Object? deletedAt = _projectDocumentCopyWithUnset,
    Object? orderIndex = _projectDocumentCopyWithUnset,
  }) {
    return ProjectDocument(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      type: type ?? this.type,
      content: content ?? this.content,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt == _projectDocumentCopyWithUnset
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      isDirty: isDirty ?? this.isDirty,
      deletedAt: deletedAt == _projectDocumentCopyWithUnset
          ? this.deletedAt
          : deletedAt as DateTime?,
      orderIndex: orderIndex == _projectDocumentCopyWithUnset
          ? this.orderIndex
          : orderIndex as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'title': title,
      'kind': _pageKindValue(kind),
      'type': _documentTypeValue(type),
      'content': content,
      'pinned': pinned,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'isDirty': isDirty,
      'deletedAt': deletedAt?.toIso8601String(),
      'orderIndex': orderIndex,
    };
  }

  factory ProjectDocument.fromJson(Map<String, dynamic> json) {
    final createdAt = _documentDateTimeFrom(json['createdAt']) ?? DateTime.now();
    return ProjectDocument(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled page',
      kind: _pageKindFrom(json['kind']),
      type: _documentTypeFrom(json['type']),
      content: json['content'] as String? ?? '',
      pinned: json['pinned'] as bool? ?? false,
      createdAt: createdAt,
      updatedAt: _documentDateTimeFrom(json['updatedAt']) ?? createdAt,
      lastSyncedAt: _documentDateTimeFrom(json['lastSyncedAt']),
      isDirty: json['isDirty'] as bool? ?? false,
      deletedAt: _documentDateTimeFrom(json['deletedAt']),
      orderIndex: (json['orderIndex'] as num?)?.toInt(),
    );
  }
}

const Object _projectDocumentCopyWithUnset = Object();

DateTime? _documentDateTimeFrom(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

ProjectPageKind _pageKindFrom(Object? value) {
  return switch (value) {
    'brief' => ProjectPageKind.brief,
    _ => ProjectPageKind.document,
  };
}

String _pageKindValue(ProjectPageKind kind) {
  return switch (kind) {
    ProjectPageKind.brief => 'brief',
    ProjectPageKind.document => 'document',
  };
}

ProjectDocumentType _documentTypeFrom(Object? value) {
  if (value is String) {
    for (final type in ProjectDocumentType.values) {
      if (_documentTypeValue(type) == value) {
        return type;
      }
    }
  }
  return ProjectDocumentType.implementation;
}

String _documentTypeValue(ProjectDocumentType type) {
  return switch (type) {
    ProjectDocumentType.design => 'design',
    ProjectDocumentType.implementation => 'implementation',
    ProjectDocumentType.story => 'story',
    ProjectDocumentType.research => 'research',
    ProjectDocumentType.reference => 'reference',
  };
}
