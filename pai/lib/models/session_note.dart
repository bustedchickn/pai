enum SessionNoteType { recap, completion }

class SessionNote {
  final String id;
  final String dateLabel;
  final String summary;
  final SessionNoteType type;

  const SessionNote({
    required this.id,
    required this.dateLabel,
    required this.summary,
    this.type = SessionNoteType.recap,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dateLabel': dateLabel,
      'summary': summary,
      'type': switch (type) {
        SessionNoteType.recap => 'recap',
        SessionNoteType.completion => 'completion',
      },
    };
  }

  factory SessionNote.fromJson(Map<String, dynamic> json) {
    return SessionNote(
      id: json['id'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      type: switch (json['type']) {
        'completion' => SessionNoteType.completion,
        _ => SessionNoteType.recap,
      },
    );
  }
}
