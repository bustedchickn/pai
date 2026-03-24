import 'board_project.dart';
import 'document_bookmark.dart';
import 'project.dart';
import 'project_document.dart';

class AppDataSnapshot {
  final List<Project> projects;
  final List<BoardProject> boardProjects;
  final List<ProjectDocument> documents;
  final List<DocumentBookmark> bookmarks;

  const AppDataSnapshot({
    required this.projects,
    required this.boardProjects,
    required this.documents,
    required this.bookmarks,
  });
}
