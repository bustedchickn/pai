import 'reminder_item.dart';
import 'session_note.dart';

class Project {
  final String id;
  final String title;
  final String status;
  final String brief;
  final List<String> nextSteps;
  final List<String> blockers;
  final List<SessionNote> sessions;
  final List<ReminderItem> reminders;

  const Project({
    required this.id,
    required this.title,
    required this.status,
    required this.brief,
    required this.nextSteps,
    required this.blockers,
    required this.sessions,
    required this.reminders,
  });
}
