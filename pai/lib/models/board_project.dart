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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'brief': brief,
      'tags': tags,
      'status': status,
      'progress': progress,
      'boardPosition': {
        'dx': boardPosition.dx,
        'dy': boardPosition.dy,
      },
    };
  }

  factory BoardProject.fromJson(Map<String, dynamic> json) {
    final boardPosition = json['boardPosition'];
    return BoardProject(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled project',
      brief: json['brief'] as String? ?? '',
      tags: [
        for (final item in (json['tags'] as List<dynamic>? ?? const []))
          if (item is String) item,
      ],
      status: json['status'] as String? ?? 'active',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      boardPosition: boardPosition is Map<String, dynamic>
          ? Offset(
              (boardPosition['dx'] as num?)?.toDouble() ?? 0,
              (boardPosition['dy'] as num?)?.toDouble() ?? 0,
            )
          : Offset.zero,
    );
  }
}
