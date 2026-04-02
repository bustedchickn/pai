class DocumentBookmark {
  final String id;
  final String documentId;
  final String label;
  final String? note;
  final String anchor;

  const DocumentBookmark({
    required this.id,
    required this.documentId,
    required this.label,
    this.note,
    required this.anchor,
  });

  DocumentBookmark copyWith({
    String? id,
    String? documentId,
    String? label,
    String? note,
    String? anchor,
  }) {
    return DocumentBookmark(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      label: label ?? this.label,
      note: note ?? this.note,
      anchor: anchor ?? this.anchor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentId': documentId,
      'label': label,
      'note': note,
      'anchor': anchor,
    };
  }

  factory DocumentBookmark.fromJson(Map<String, dynamic> json) {
    return DocumentBookmark(
      id: json['id'] as String? ?? '',
      documentId: json['documentId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      note: json['note'] as String?,
      anchor: json['anchor'] as String? ?? '',
    );
  }
}
