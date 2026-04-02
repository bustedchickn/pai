class ReminderItem {
  final String id;
  final String title;
  final String dueLabel;
  final String projectTitle;

  const ReminderItem({
    required this.id,
    required this.title,
    required this.dueLabel,
    required this.projectTitle,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'dueLabel': dueLabel,
      'projectTitle': projectTitle,
    };
  }

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    return ReminderItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      dueLabel: json['dueLabel'] as String? ?? '',
      projectTitle: json['projectTitle'] as String? ?? '',
    );
  }
}
