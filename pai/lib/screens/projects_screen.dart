import 'package:flutter/material.dart';

import '../models/document_bookmark.dart';
import '../models/project.dart';
import '../models/project_document.dart';
import '../models/session_note.dart';
import 'project_workspace_view.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({
    super.key,
    required this.projects,
    required this.documents,
    required this.bookmarks,
    required this.onProjectSaved,
    required this.onSessionSaved,
    required this.onTasksAdded,
    required this.onTaskCompleted,
    required this.onDocumentSaved,
    required this.onBookmarkSaved,
    required this.onDocumentDeleted,
    this.selectedProjectId,
    this.selectionRequestId = 0,
  });

  final List<Project> projects;
  final List<ProjectDocument> documents;
  final List<DocumentBookmark> bookmarks;
  final Future<void> Function(Project project) onProjectSaved;
  final Future<void> Function(String projectId, SessionNote session)
  onSessionSaved;
  final Future<void> Function(String projectId, List<String> tasks)
  onTasksAdded;
  final Future<void> Function(
    String projectId,
    String task,
    SessionNote completionNote,
    String updatedBrief,
  )
  onTaskCompleted;
  final Future<void> Function(ProjectDocument document) onDocumentSaved;
  final Future<void> Function(DocumentBookmark bookmark) onBookmarkSaved;
  final Future<void> Function(String documentId) onDocumentDeleted;
  final String? selectedProjectId;
  final int selectionRequestId;

  @override
  Widget build(BuildContext context) {
    return ProjectWorkspaceView(
      projects: projects,
      documents: documents,
      bookmarks: bookmarks,
      onProjectSaved: onProjectSaved,
      onSessionSaved: onSessionSaved,
      onTasksAdded: onTasksAdded,
      onTaskCompleted: onTaskCompleted,
      onDocumentSaved: onDocumentSaved,
      onBookmarkSaved: onBookmarkSaved,
      onDocumentDeleted: onDocumentDeleted,
      selectedProjectId: selectedProjectId,
      selectionRequestId: selectionRequestId,
    );
  }
}
