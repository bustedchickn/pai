import 'dart:ui';

import '../models/app_data_snapshot.dart';
import '../models/board_project.dart';
import '../models/document_bookmark.dart';
import '../models/new_project_draft.dart';
import '../models/project.dart';
import '../models/project_document.dart';
import '../models/session_note.dart';
import '../repositories/document_repository.dart';
import '../repositories/project_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/task_repository.dart';
import 'project_document_content_codec.dart';

class PaiDataService {
  PaiDataService({
    required ProjectRepository projectRepository,
    required TaskRepository taskRepository,
    required SessionRepository sessionRepository,
    required DocumentRepository documentRepository,
  }) : _projectRepository = projectRepository,
       _taskRepository = taskRepository,
       _sessionRepository = sessionRepository,
       _documentRepository = documentRepository;

  final ProjectRepository _projectRepository;
  final TaskRepository _taskRepository;
  final SessionRepository _sessionRepository;
  final DocumentRepository _documentRepository;

  Future<AppDataSnapshot> load() => _snapshot();

  Future<AppDataSnapshot> loadProjectPages(String projectId) async {
    await _documentRepository.listDocumentsForProject(projectId);
    return _snapshot();
  }

  Future<AppDataSnapshot> createProject({
    required NewProjectDraft draft,
    required Offset boardPosition,
  }) async {
    final projectId = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    final project = Project(
      id: projectId,
      title: draft.title,
      status: draft.status,
      brief: draft.brief,
      briefPageId: 'brief-$projectId',
      tags: draft.tags,
      nextSteps: const [],
      blockers: const [],
      sessions: const [],
      reminders: const [],
      createdAt: now,
      updatedAt: now,
      isDirty: true,
    );
    final boardProject = BoardProject(
      id: projectId,
      title: draft.title,
      brief: ProjectDocumentContentCodec.previewText(draft.brief),
      tags: draft.tags,
      status: draft.status,
      progress: draft.progress,
      boardPosition: boardPosition,
    );

    await _projectRepository.createProject(
      project: project,
      boardProject: boardProject,
    );
    await _documentRepository.listDocumentsForProject(projectId);
    return _snapshot();
  }

  Future<AppDataSnapshot> addSession(
    String projectId,
    SessionNote session,
  ) async {
    await _sessionRepository.addSession(projectId, session);
    return _snapshot();
  }

  Future<AppDataSnapshot> addTasks(String projectId, List<String> tasks) async {
    await _taskRepository.addTasks(projectId, tasks);
    return _snapshot();
  }

  Future<AppDataSnapshot> completeTask({
    required String projectId,
    required String task,
    required SessionNote completionNote,
    required String updatedBrief,
  }) async {
    final removed = await _taskRepository.removeTask(projectId, task);
    if (!removed) {
      return _snapshot();
    }

    await _sessionRepository.addSession(projectId, completionNote);
    final project = await _projectRepository.getProjectById(projectId);
    if (project != null) {
      final updatedProject = project.copyWith(
        brief: updatedBrief,
        updatedAt: DateTime.now(),
        isDirty: true,
      );
      await _projectRepository.saveProject(updatedProject);
      await _syncBriefPage(updatedProject);
    }
    return _snapshot();
  }

  Future<void> updateBoardProjectPosition(
    String projectId,
    Offset nextPosition,
  ) async {
    final boardProjects = await _projectRepository.listBoardProjects();
    for (final boardProject in boardProjects) {
      if (boardProject.id == projectId) {
        await _projectRepository.saveBoardProject(
          boardProject.copyWith(boardPosition: nextPosition),
        );
        final project = await _projectRepository.getProjectById(projectId);
        if (project != null) {
          await _projectRepository.saveProject(
            project.copyWith(updatedAt: DateTime.now(), isDirty: true),
          );
        }
        return;
      }
    }
  }

  Future<AppDataSnapshot> saveBoardProjects(
    List<BoardProject> boardProjects,
  ) async {
    for (final boardProject in boardProjects) {
      await _projectRepository.saveBoardProject(boardProject);
      final project = await _projectRepository.getProjectById(boardProject.id);
      if (project != null) {
        await _projectRepository.saveProject(
          project.copyWith(updatedAt: DateTime.now(), isDirty: true),
        );
      }
    }
    return _snapshot();
  }

  Future<AppDataSnapshot> updateProject(Project project) async {
    final existingProject = await _projectRepository.getProjectById(project.id);
    final shouldMarkDirty = _hasSyncRelevantProjectChanges(
      existingProject,
      project,
    );
    final normalizedProject = existingProject == null
        ? project.copyWith(isDirty: true)
        : project.copyWith(
            isDirty: shouldMarkDirty ? true : existingProject.isDirty,
            lastSyncedAt: existingProject.lastSyncedAt,
            deletedAt: existingProject.deletedAt,
            updatedAt: shouldMarkDirty
                ? project.updatedAt
                : existingProject.updatedAt,
          );
    await _projectRepository.saveProject(normalizedProject);
    if (existingProject == null || existingProject.brief != project.brief) {
      await _syncBriefPage(normalizedProject);
    }
    return _snapshot();
  }

  Future<AppDataSnapshot> deleteProject(String projectId) async {
    await _projectRepository.deleteProject(
      projectId,
      deletedAt: DateTime.now(),
    );
    return _snapshot();
  }

  Future<AppDataSnapshot> saveDocument(ProjectDocument document) async {
    final now = DateTime.now();
    final existing = await _documentRepository.getDocumentById(document.id);
    await _documentRepository.saveDocument(
      document.copyWith(
        createdAt: existing?.createdAt ?? document.createdAt,
        updatedAt: now,
        lastSyncedAt: existing?.lastSyncedAt,
        deletedAt: null,
        isDirty: true,
      ),
    );
    return _snapshot();
  }

  Future<AppDataSnapshot> saveBookmark(DocumentBookmark bookmark) async {
    await _documentRepository.saveBookmark(bookmark);
    final document = await _documentRepository.getDocumentById(
      bookmark.documentId,
    );
    if (document != null) {
      await _documentRepository.saveDocument(
        document.copyWith(updatedAt: DateTime.now(), isDirty: true),
      );
    }
    return _snapshot();
  }

  Future<AppDataSnapshot> deleteDocument(String documentId) async {
    await _documentRepository.deleteDocument(documentId);
    return _snapshot();
  }

  Future<AppDataSnapshot> _snapshot() async {
    final projects = await _projectRepository.listProjects();
    final boardProjects = await _projectRepository.listBoardProjects();
    final documents = await _documentRepository.listDocuments();
    final bookmarks = await _documentRepository.listBookmarks();
    return AppDataSnapshot(
      projects: projects,
      boardProjects: boardProjects,
      documents: documents,
      bookmarks: bookmarks,
    );
  }

  Future<void> _syncBriefPage(Project project) async {
    final existingBrief = await _documentRepository.getDocumentById(
      project.briefPageId,
    );
    await _documentRepository.saveDocument(
      ProjectDocument(
        id: project.briefPageId,
        projectId: project.id,
        title: 'Project Brief',
        kind: ProjectPageKind.brief,
        type: ProjectDocumentType.reference,
        content: project.brief,
        pinned: false,
        createdAt: existingBrief?.createdAt ?? project.createdAt,
        updatedAt: project.updatedAt,
        lastSyncedAt: project.lastSyncedAt,
        isDirty: project.isDirty,
        deletedAt: project.deletedAt,
        orderIndex: existingBrief?.orderIndex ?? 0,
      ),
    );
  }

  bool _hasSyncRelevantProjectChanges(Project? existing, Project next) {
    if (existing == null) {
      return true;
    }

    return existing.title != next.title ||
        existing.status != next.status ||
        existing.brief != next.brief ||
        !_sameStringList(existing.tags, next.tags) ||
        !_sameStringList(existing.nextSteps, next.nextSteps) ||
        !_sameStringList(existing.blockers, next.blockers) ||
        !_sameSessions(existing.sessions, next.sessions) ||
        !_sameReminders(existing.reminders, next.reminders);
  }

  bool _sameStringList(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  bool _sameSessions(List<SessionNote> left, List<SessionNote> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id ||
          left[index].dateLabel != right[index].dateLabel ||
          left[index].summary != right[index].summary ||
          left[index].type != right[index].type) {
        return false;
      }
    }
    return true;
  }

  bool _sameReminders(List<dynamic> left, List<dynamic> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      final leftReminder = left[index];
      final rightReminder = right[index];
      if (leftReminder.id != rightReminder.id ||
          leftReminder.title != rightReminder.title ||
          leftReminder.dueLabel != rightReminder.dueLabel ||
          leftReminder.projectTitle != rightReminder.projectTitle) {
        return false;
      }
    }
    return true;
  }
}
