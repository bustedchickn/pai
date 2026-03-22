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
}
