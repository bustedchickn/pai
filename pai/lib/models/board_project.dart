import 'dart:ui';

class BoardProject {
  final String id;
  final String title;
  final String brief;
  final List<String> tags;
  final String status;
  final double progress;
  final Offset boardPosition;

  const BoardProject({
    required this.id,
    required this.title,
    required this.brief,
    required this.tags,
    required this.status,
    required this.progress,
    required this.boardPosition,
  });

  BoardProject copyWith({
    String? id,
    String? title,
    String? brief,
    List<String>? tags,
    String? status,
    double? progress,
    Offset? boardPosition,
  }) {
    return BoardProject(
      id: id ?? this.id,
      title: title ?? this.title,
      brief: brief ?? this.brief,
      tags: tags ?? this.tags,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      boardPosition: boardPosition ?? this.boardPosition,
    );
  }
}
