import 'dart:ui';

import '../../models/board_project.dart';
import '../../models/document_bookmark.dart';
import '../../models/project.dart';
import '../../models/project_document.dart';
import '../../models/sync_conflict_backup.dart';
import '../../services/project_document_content_codec.dart';
import '../mock_data.dart';

class InMemoryPaiStore {
  InMemoryPaiStore({
    List<Project>? initialProjects,
    List<BoardProject>? initialBoardProjects,
    List<ProjectDocument>? initialDocuments,
    List<DocumentBookmark>? initialBookmarks,
    List<SyncConflictBackup>? initialConflictBackups,
    DateTime? initialLastManualSyncAt,
  }) : _projects = List<Project>.from(initialProjects ?? mockProjects),
       _boardProjects = List<BoardProject>.from(
         initialBoardProjects ?? mockBoardProjects,
       ),
       _documents = List<ProjectDocument>.from(
         initialDocuments ?? mockProjectDocuments,
       ),
       _bookmarks = List<DocumentBookmark>.from(
         initialBookmarks ?? mockDocumentBookmarks,
       ),
       _conflictBackups = List<SyncConflictBackup>.from(
         initialConflictBackups ?? const [],
       ),
       _lastManualSyncAt = initialLastManualSyncAt;

  List<Project> _projects;
  List<BoardProject> _boardProjects;
  List<ProjectDocument> _documents;
  List<DocumentBookmark> _bookmarks;
  List<SyncConflictBackup> _conflictBackups;
  DateTime? _lastManualSyncAt;

  List<Project> listProjects() => List<Project>.unmodifiable([
    for (final project in _projects)
      if (project.deletedAt == null) project,
  ]);

  List<Project> listAllProjects() => List<Project>.unmodifiable(_projects);

  List<BoardProject> listBoardProjects() => List<BoardProject>.unmodifiable([
    for (final boardProject in _boardProjects)
      if (_projectIsVisible(boardProject.id)) boardProject,
  ]);

  List<BoardProject> listAllBoardProjects() =>
      List<BoardProject>.unmodifiable(_boardProjects);

  void replaceProjects(List<Project> projects) {
    _projects = List<Project>.from(projects);
  }

  void replaceBoardProjects(List<BoardProject> boardProjects) {
    _boardProjects = List<BoardProject>.from(boardProjects);
  }

  void replaceProjectsAndBoardProjects({
    required List<Project> projects,
    required List<BoardProject> boardProjects,
  }) {
    replaceProjects(projects);
    replaceBoardProjects(boardProjects);
  }

  List<ProjectDocument> listDocuments() => List<ProjectDocument>.unmodifiable([
    for (final document in _documents)
      if (document.deletedAt == null && _projectIsVisible(document.projectId))
        document,
  ]);

  List<ProjectDocument> listAllDocuments() =>
      List<ProjectDocument>.unmodifiable(_documents);

  void replaceDocuments(List<ProjectDocument> documents) {
    _documents = List<ProjectDocument>.from(documents);
  }

  List<ProjectDocument> listDocumentsForProject(String projectId) {
    if (!_projectIsVisible(projectId)) {
      return const [];
    }

    return List<ProjectDocument>.unmodifiable([
      for (final document in _documents)
        if (document.projectId == projectId && document.deletedAt == null)
          document,
    ]);
  }

  List<DocumentBookmark> listBookmarks() => List<DocumentBookmark>.unmodifiable(
    _bookmarks.where((bookmark) {
      final document = documentById(bookmark.documentId, includeDeleted: true);
      if (document?.deletedAt != null) {
        return false;
      }

      return document != null && _projectIsVisible(document.projectId);
    }),
  );

  List<DocumentBookmark> listAllBookmarks() =>
      List<DocumentBookmark>.unmodifiable(_bookmarks);

  void replaceBookmarks(List<DocumentBookmark> bookmarks) {
    _bookmarks = List<DocumentBookmark>.from(bookmarks);
  }

  List<DocumentBookmark> listBookmarksForDocument(String documentId) {
    final document = documentById(documentId, includeDeleted: true);
    if (document?.deletedAt != null ||
        document == null ||
        !_projectIsVisible(document.projectId)) {
      return const [];
    }

    return List<DocumentBookmark>.unmodifiable([
      for (final bookmark in _bookmarks)
        if (bookmark.documentId == documentId) bookmark,
    ]);
  }

  List<SyncConflictBackup> listConflictBackups() =>
      List<SyncConflictBackup>.unmodifiable(_conflictBackups);

  void replaceConflictBackups(List<SyncConflictBackup> backups) {
    _conflictBackups = List<SyncConflictBackup>.from(backups);
  }

  void addConflictBackup(SyncConflictBackup backup) {
    _conflictBackups = [backup, ..._conflictBackups].take(40).toList();
  }

  DateTime? get lastManualSyncAt => _lastManualSyncAt;

  void setLastManualSyncAt(DateTime? value) {
    _lastManualSyncAt = value;
  }

  Project? projectById(String projectId) {
    for (final project in _projects) {
      if (project.id == projectId) {
        return project;
      }
    }

    return null;
  }

  BoardProject? boardProjectById(String projectId) {
    for (final boardProject in _boardProjects) {
      if (boardProject.id == projectId) {
        return boardProject;
      }
    }

    return null;
  }

  ProjectDocument? documentById(
    String documentId, {
    bool includeDeleted = false,
  }) {
    for (final document in _documents) {
      if (document.id == documentId) {
        if (!includeDeleted &&
            (document.deletedAt != null ||
                !_projectIsVisible(document.projectId))) {
          return null;
        }
        return document;
      }
    }

    return null;
  }

  void addProject(Project project, BoardProject boardProject) {
    _projects = [..._projects, project];
    _boardProjects = [..._boardProjects, boardProject];
  }

  void saveProject(Project project) {
    final projectIndex = _projects.indexWhere(
      (current) => current.id == project.id,
    );
    if (projectIndex >= 0) {
      _projects = [
        for (var index = 0; index < _projects.length; index++)
          if (index == projectIndex) project else _projects[index],
      ];
    } else {
      _projects = [..._projects, project];
    }

    final boardProjectIndex = _boardProjects.indexWhere(
      (boardProject) => boardProject.id == project.id,
    );
    if (boardProjectIndex >= 0) {
      _boardProjects = [
        for (var index = 0; index < _boardProjects.length; index++)
          if (index == boardProjectIndex)
            _boardProjects[index].copyWith(
              title: project.title,
              brief: ProjectDocumentContentCodec.previewText(project.brief),
              tags: project.tags,
              status: project.status,
            )
          else
            _boardProjects[index],
      ];
    } else {
      _boardProjects = [
        ..._boardProjects,
        BoardProject(
          id: project.id,
          title: project.title,
          brief: ProjectDocumentContentCodec.previewText(project.brief),
          tags: project.tags,
          status: project.status,
          progress: 0,
          boardPosition: Offset.zero,
        ),
      ];
    }
  }

  void saveBoardProject(BoardProject boardProject) {
    final boardProjectIndex = _boardProjects.indexWhere(
      (current) => current.id == boardProject.id,
    );
    if (boardProjectIndex >= 0) {
      _boardProjects = [
        for (var index = 0; index < _boardProjects.length; index++)
          if (index == boardProjectIndex)
            boardProject
          else
            _boardProjects[index],
      ];
    } else {
      _boardProjects = [..._boardProjects, boardProject];
    }
  }

  void saveDocumentRecord(ProjectDocument document) {
    final documentIndex = _documents.indexWhere(
      (current) => current.id == document.id,
    );
    if (documentIndex >= 0) {
      _documents = [
        for (var index = 0; index < _documents.length; index++)
          if (index == documentIndex) document else _documents[index],
      ];
    } else {
      _documents = [..._documents, document];
    }
  }

  void softDeleteDocument(String documentId, {required DateTime deletedAt}) {
    final document = documentById(documentId, includeDeleted: true);
    if (document == null) {
      return;
    }

    saveDocumentRecord(
      document.copyWith(
        deletedAt: deletedAt,
        updatedAt: deletedAt,
        isDirty: true,
      ),
    );
    _bookmarks = [
      for (final bookmark in _bookmarks)
        if (bookmark.documentId != documentId) bookmark,
    ];
  }

  void softDeleteProject(String projectId, {required DateTime deletedAt}) {
    final project = projectById(projectId);
    if (project == null) {
      return;
    }

    saveProject(
      project.copyWith(
        deletedAt: deletedAt,
        updatedAt: deletedAt,
        isDirty: true,
      ),
    );

    final deletedDocumentIds = <String>{};
    for (final document in _documents) {
      if (document.projectId != projectId) {
        continue;
      }

      deletedDocumentIds.add(document.id);
      saveDocumentRecord(
        document.copyWith(
          deletedAt: document.deletedAt ?? deletedAt,
          updatedAt: deletedAt,
          isDirty: true,
        ),
      );
    }

    _bookmarks = [
      for (final bookmark in _bookmarks)
        if (!deletedDocumentIds.contains(bookmark.documentId)) bookmark,
    ];
  }

  void deleteDocumentRecord(String documentId) {
    _documents = [
      for (final document in _documents)
        if (document.id != documentId) document,
    ];
    _bookmarks = [
      for (final bookmark in _bookmarks)
        if (bookmark.documentId != documentId) bookmark,
    ];
  }

  void saveBookmark(DocumentBookmark bookmark) {
    final bookmarkIndex = _bookmarks.indexWhere(
      (current) => current.id == bookmark.id,
    );
    if (bookmarkIndex >= 0) {
      _bookmarks = [
        for (var index = 0; index < _bookmarks.length; index++)
          if (index == bookmarkIndex) bookmark else _bookmarks[index],
      ];
    } else {
      _bookmarks = [..._bookmarks, bookmark];
    }
  }

  void replaceAll({
    required List<Project> projects,
    required List<BoardProject> boardProjects,
    required List<ProjectDocument> documents,
    required List<DocumentBookmark> bookmarks,
    required List<SyncConflictBackup> conflictBackups,
    required DateTime? lastManualSyncAt,
  }) {
    _projects = List<Project>.from(projects);
    _boardProjects = List<BoardProject>.from(boardProjects);
    _documents = List<ProjectDocument>.from(documents);
    _bookmarks = List<DocumentBookmark>.from(bookmarks);
    _conflictBackups = List<SyncConflictBackup>.from(conflictBackups);
    _lastManualSyncAt = lastManualSyncAt;
  }

  bool _projectIsVisible(String projectId) {
    final project = projectById(projectId);
    return project != null && project.deletedAt == null;
  }
}
