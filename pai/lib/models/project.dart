import 'reminder_item.dart';
import 'session_note.dart';

class Project {
  final String id;
  final String title;
  final String status;
  final String brief;
  final String briefPageId;
  final List<String> tags;
  final List<String> nextSteps;
  final List<String> blockers;
  final List<SessionNote> sessions;
  final List<ReminderItem> reminders;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastOpenedPageId;

  const Project({
    required this.id,
    required this.title,
    required this.status,
    required this.brief,
    required this.briefPageId,
    required this.tags,
    required this.nextSteps,
    required this.blockers,
    required this.sessions,
    required this.reminders,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedPageId,
  });

  Project copyWith({
    String? id,
    String? title,
    String? status,
    String? brief,
    String? briefPageId,
    List<String>? tags,
    List<String>? nextSteps,
    List<String>? blockers,
    List<SessionNote>? sessions,
    List<ReminderItem>? reminders,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? lastOpenedPageId = _copyWithUnset,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      brief: brief ?? this.brief,
      briefPageId: briefPageId ?? this.briefPageId,
      tags: tags ?? this.tags,
      nextSteps: nextSteps ?? this.nextSteps,
      blockers: blockers ?? this.blockers,
      sessions: sessions ?? this.sessions,
      reminders: reminders ?? this.reminders,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedPageId: lastOpenedPageId == _copyWithUnset
          ? this.lastOpenedPageId
          : lastOpenedPageId as String?,
    );
  }
}

const Object _copyWithUnset = Object();
