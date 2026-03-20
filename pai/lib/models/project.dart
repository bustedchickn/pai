import 'reminder_item.dart';
import 'session_note.dart';

class Project {
  final String id;
  final String title;
  final String status;
  final String brief;
  final List<String> tags;
  final List<String> nextSteps;
  final List<String> blockers;
  final List<SessionNote> sessions;
  final List<ReminderItem> reminders;

  const Project({
    required this.id,
    required this.title,
    required this.status,
    required this.brief,
    required this.tags,
    required this.nextSteps,
    required this.blockers,
    required this.sessions,
    required this.reminders,
  });

  Project copyWith({
    String? id,
    String? title,
    String? status,
    String? brief,
    List<String>? tags,
    List<String>? nextSteps,
    List<String>? blockers,
    List<SessionNote>? sessions,
    List<ReminderItem>? reminders,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      brief: brief ?? this.brief,
      tags: tags ?? this.tags,
      nextSteps: nextSteps ?? this.nextSteps,
      blockers: blockers ?? this.blockers,
      sessions: sessions ?? this.sessions,
      reminders: reminders ?? this.reminders,
    );
  }
}
