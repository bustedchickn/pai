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
      orderIndex: orderIndex == _projectDocumentCopyWithUnset
          ? this.orderIndex
          : orderIndex as int?,
    );
  }
}

const Object _projectDocumentCopyWithUnset = Object();
