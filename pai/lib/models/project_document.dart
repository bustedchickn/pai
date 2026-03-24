enum ProjectDocumentType { design, implementation, story, research, reference }

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
  final ProjectDocumentType type;
  final String content;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectDocument({
    required this.id,
    required this.projectId,
    required this.title,
    required this.type,
    required this.content,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
  });

  ProjectDocument copyWith({
    String? id,
    String? projectId,
    String? title,
    ProjectDocumentType? type,
    String? content,
    bool? pinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectDocument(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      type: type ?? this.type,
      content: content ?? this.content,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
