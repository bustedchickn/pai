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
  final DateTime? lastSyncedAt;
  final bool isDirty;
  final DateTime? deletedAt;
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
    this.lastSyncedAt,
    this.isDirty = false,
    this.deletedAt,
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
    Object? lastSyncedAt = _copyWithUnset,
    bool? isDirty,
    Object? deletedAt = _copyWithUnset,
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
      lastSyncedAt: lastSyncedAt == _copyWithUnset
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      isDirty: isDirty ?? this.isDirty,
      deletedAt: deletedAt == _copyWithUnset
          ? this.deletedAt
          : deletedAt as DateTime?,
      lastOpenedPageId: lastOpenedPageId == _copyWithUnset
          ? this.lastOpenedPageId
          : lastOpenedPageId as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status,
      'brief': brief,
      'briefPageId': briefPageId,
      'tags': tags,
      'nextSteps': nextSteps,
      'blockers': blockers,
      'sessions': [for (final session in sessions) session.toJson()],
      'reminders': [for (final reminder in reminders) reminder.toJson()],
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'isDirty': isDirty,
      'deletedAt': deletedAt?.toIso8601String(),
      'lastOpenedPageId': lastOpenedPageId,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled project',
      status: json['status'] as String? ?? 'active',
      brief: json['brief'] as String? ?? '',
      briefPageId:
          json['briefPageId'] as String? ??
          'brief-${json['id'] as String? ?? ''}',
      tags: _stringListFrom(json['tags']),
      nextSteps: _stringListFrom(json['nextSteps']),
      blockers: _stringListFrom(json['blockers']),
      sessions: _sessionListFrom(json['sessions']),
      reminders: _reminderListFrom(json['reminders']),
      createdAt: _dateTimeFrom(json['createdAt']) ?? DateTime.now(),
      updatedAt:
          _dateTimeFrom(json['updatedAt']) ??
          _dateTimeFrom(json['createdAt']) ??
          DateTime.now(),
      lastSyncedAt: _dateTimeFrom(json['lastSyncedAt']),
      isDirty: json['isDirty'] as bool? ?? false,
      deletedAt: _dateTimeFrom(json['deletedAt']),
      lastOpenedPageId: json['lastOpenedPageId'] as String?,
    );
  }
}

const Object _copyWithUnset = Object();

DateTime? _dateTimeFrom(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

List<String> _stringListFrom(Object? value) {
  if (value is! List) {
    return const [];
  }

  return [
    for (final item in value)
      if (item is String) item,
  ];
}

List<SessionNote> _sessionListFrom(Object? value) {
  if (value is! List) {
    return const [];
  }

  return [
    for (final item in value)
      if (item is Map<String, dynamic>) SessionNote.fromJson(item),
  ];
}

List<ReminderItem> _reminderListFrom(Object? value) {
  if (value is! List) {
    return const [];
  }

  return [
    for (final item in value)
      if (item is Map<String, dynamic>) ReminderItem.fromJson(item),
  ];
}
