import 'package:flutter_test/flutter_test.dart';
import 'package:pai/models/board_project.dart';
import 'package:pai/models/document_bookmark.dart';
import 'package:pai/models/new_project_draft.dart';
import 'package:pai/models/project.dart';
import 'package:pai/models/project_document.dart';
import 'package:pai/models/session_note.dart';
import 'package:pai/repositories/document_repository.dart';
import 'package:pai/repositories/project_repository.dart';
import 'package:pai/repositories/session_repository.dart';
import 'package:pai/repositories/task_repository.dart';
import 'package:pai/services/pai_data_service.dart';

void main() {
  group('PaiDataService', () {
    test(
      'createProject triggers project page loading for the new project',
      () async {
        final projectRepository = _FakeProjectRepository();
        final documentRepository = _FakeDocumentRepository();
        final service = PaiDataService(
          projectRepository: projectRepository,
          taskRepository: _FakeTaskRepository(),
          sessionRepository: _FakeSessionRepository(),
          documentRepository: documentRepository,
        );

        final snapshot = await service.createProject(
          draft: const NewProjectDraft(
            title: 'New project',
            brief: 'Start with a short brief.',
            tags: ['Test'],
            status: 'active',
            progress: 0.25,
          ),
          boardPosition: Offset.zero,
        );

        expect(snapshot.projects, hasLength(1));
        final createdProject = snapshot.projects.single;
        expect(documentRepository.loadedProjectIds, [createdProject.id]);
        expect(createdProject.briefPageId, 'brief-${createdProject.id}');
      },
    );

    test('loadProjectPages hydrates the selected project documents', () async {
      final firstProject = _project(
        id: 'p1',
        title: 'First',
        brief: 'First brief',
      );
      final secondProject = _project(
        id: 'p2',
        title: 'Second',
        brief: 'Second brief',
      );
      final projectRepository = _FakeProjectRepository(
        projects: [firstProject, secondProject],
        boardProjects: [
          _boardProject(firstProject),
          _boardProject(secondProject),
        ],
      );
      final documentRepository = _FakeDocumentRepository(
        remoteDocumentsByProject: {
          firstProject.id: [
            _document(
              id: 'doc-1',
              projectId: firstProject.id,
              title: 'First doc',
            ),
          ],
          secondProject.id: [
            _document(
              id: 'doc-2',
              projectId: secondProject.id,
              title: 'Second doc',
            ),
          ],
        },
      );
      final service = PaiDataService(
        projectRepository: projectRepository,
        taskRepository: _FakeTaskRepository(),
        sessionRepository: _FakeSessionRepository(),
        documentRepository: documentRepository,
      );

      final initialSnapshot = await service.load();
      expect(initialSnapshot.documents, isEmpty);

      final snapshot = await service.loadProjectPages(secondProject.id);

      expect(documentRepository.loadedProjectIds, [secondProject.id]);
      expect(snapshot.documents.map((document) => document.id), ['doc-2']);
    });

    test('completeTask persists the updated brief page', () async {
      final project = _project(
        id: 'p1',
        title: 'Workspace',
        brief: 'Original brief',
        nextSteps: const ['Ship onboarding'],
      );
      final briefDocument = ProjectDocument(
        id: project.briefPageId,
        projectId: project.id,
        title: 'Project Brief',
        kind: ProjectPageKind.brief,
        type: ProjectDocumentType.reference,
        content: project.brief,
        pinned: false,
        createdAt: DateTime(2026, 3, 20, 9),
        updatedAt: DateTime(2026, 3, 20, 10),
        orderIndex: 0,
      );
      final projectRepository = _FakeProjectRepository(
        projects: [project],
        boardProjects: [_boardProject(project)],
      );
      final taskRepository = _FakeTaskRepository(removeTaskResult: true);
      final sessionRepository = _FakeSessionRepository();
      final documentRepository = _FakeDocumentRepository(
        initialLoadedDocuments: [briefDocument],
      );
      final service = PaiDataService(
        projectRepository: projectRepository,
        taskRepository: taskRepository,
        sessionRepository: sessionRepository,
        documentRepository: documentRepository,
      );
      const updatedBrief = 'Updated brief after completing the task.';
      const completionNote = SessionNote(
        id: 'session-1',
        dateLabel: 'Just now',
        summary: 'Completed onboarding work',
        type: SessionNoteType.completion,
      );

      final snapshot = await service.completeTask(
        projectId: project.id,
        task: 'Ship onboarding',
        completionNote: completionNote,
        updatedBrief: updatedBrief,
      );

      expect(taskRepository.removedTasks, ['${project.id}:Ship onboarding']);
      expect(sessionRepository.sessionsByProject[project.id], [completionNote]);
      expect(snapshot.projects.single.brief, updatedBrief);

      final savedBrief = documentRepository.savedDocuments.single;
      expect(savedBrief.id, project.briefPageId);
      expect(savedBrief.kind, ProjectPageKind.brief);
      expect(savedBrief.content, updatedBrief);
      expect(savedBrief.createdAt, briefDocument.createdAt);
      expect(savedBrief.orderIndex, 0);
    });

    test('updateProject syncs the brief page when the brief changes', () async {
      final project = _project(
        id: 'p1',
        title: 'Workspace',
        brief: 'Original brief',
      );
      final projectRepository = _FakeProjectRepository(
        projects: [project],
        boardProjects: [_boardProject(project)],
      );
      final documentRepository = _FakeDocumentRepository();
      final service = PaiDataService(
        projectRepository: projectRepository,
        taskRepository: _FakeTaskRepository(),
        sessionRepository: _FakeSessionRepository(),
        documentRepository: documentRepository,
      );

      final updatedProject = project.copyWith(
        brief: 'Updated project brief',
        updatedAt: DateTime(2026, 3, 24, 11),
      );

      await service.updateProject(updatedProject);

      final savedBrief = documentRepository.savedDocuments.single;
      expect(savedBrief.id, project.briefPageId);
      expect(savedBrief.projectId, project.id);
      expect(savedBrief.kind, ProjectPageKind.brief);
      expect(savedBrief.content, 'Updated project brief');
      expect(savedBrief.orderIndex, 0);
    });

    test('saveDocument preserves createdAt for existing documents', () async {
      final project = _project(
        id: 'p1',
        title: 'Workspace',
        brief: 'Original brief',
      );
      final existingDocument = _document(
        id: 'doc-1',
        projectId: project.id,
        title: 'Implementation notes',
      );
      final projectRepository = _FakeProjectRepository(
        projects: [project],
        boardProjects: [_boardProject(project)],
      );
      final documentRepository = _FakeDocumentRepository(
        initialLoadedDocuments: [existingDocument],
      );
      final service = PaiDataService(
        projectRepository: projectRepository,
        taskRepository: _FakeTaskRepository(),
        sessionRepository: _FakeSessionRepository(),
        documentRepository: documentRepository,
      );

      final editedDocument = existingDocument.copyWith(
        content: '# Revised notes',
        createdAt: DateTime(2026, 3, 24, 12),
      );

      await service.saveDocument(editedDocument);

      final savedDocument = documentRepository.savedDocuments.single;
      expect(savedDocument.id, existingDocument.id);
      expect(savedDocument.createdAt, existingDocument.createdAt);
      expect(savedDocument.content, '# Revised notes');
      expect(savedDocument.updatedAt.isAfter(existingDocument.updatedAt), isTrue);
    });
  });
}

Project _project({
  required String id,
  required String title,
  required String brief,
  List<String> nextSteps = const [],
}) {
  final now = DateTime(2026, 3, 24, 9);
  return Project(
    id: id,
    title: title,
    status: 'active',
    brief: brief,
    briefPageId: 'brief-$id',
    tags: const ['Test'],
    nextSteps: nextSteps,
    blockers: const [],
    sessions: const [],
    reminders: const [],
    createdAt: now,
    updatedAt: now,
  );
}

BoardProject _boardProject(Project project) {
  return BoardProject(
    id: project.id,
    title: project.title,
    brief: project.brief,
    tags: project.tags,
    status: project.status,
    progress: 0.5,
    boardPosition: Offset.zero,
  );
}

ProjectDocument _document({
  required String id,
  required String projectId,
  required String title,
}) {
  final now = DateTime(2026, 3, 24, 10);
  return ProjectDocument(
    id: id,
    projectId: projectId,
    title: title,
    type: ProjectDocumentType.implementation,
    content: '# $title',
    pinned: false,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeProjectRepository implements ProjectRepository {
  _FakeProjectRepository({
    List<Project>? projects,
    List<BoardProject>? boardProjects,
  }) : _projects = List<Project>.from(projects ?? const []),
       _boardProjects = List<BoardProject>.from(boardProjects ?? const []);

  List<Project> _projects;
  List<BoardProject> _boardProjects;

  @override
  Future<void> createProject({
    required Project project,
    required BoardProject boardProject,
  }) async {
    _projects = [..._projects, project];
    _boardProjects = [..._boardProjects, boardProject];
  }

  @override
  Future<Project?> getProjectById(String projectId) async {
    for (final project in _projects) {
      if (project.id == projectId) {
        return project;
      }
    }
    return null;
  }

  @override
  Future<List<BoardProject>> listBoardProjects() async {
    return List<BoardProject>.unmodifiable(_boardProjects);
  }

  @override
  Future<List<Project>> listProjects() async {
    return List<Project>.unmodifiable(_projects);
  }

  @override
  Future<void> saveBoardProject(BoardProject boardProject) async {
    final index = _boardProjects.indexWhere(
      (current) => current.id == boardProject.id,
    );
    if (index >= 0) {
      _boardProjects = [
        for (var i = 0; i < _boardProjects.length; i++)
          if (i == index) boardProject else _boardProjects[i],
      ];
      return;
    }

    _boardProjects = [..._boardProjects, boardProject];
  }

  @override
  Future<void> saveProject(Project project) async {
    final index = _projects.indexWhere((current) => current.id == project.id);
    if (index >= 0) {
      _projects = [
        for (var i = 0; i < _projects.length; i++)
          if (i == index) project else _projects[i],
      ];
      return;
    }

    _projects = [..._projects, project];
  }
}

class _FakeDocumentRepository implements DocumentRepository {
  _FakeDocumentRepository({
    Map<String, List<ProjectDocument>>? remoteDocumentsByProject,
    List<ProjectDocument>? initialLoadedDocuments,
  }) : _remoteDocumentsByProject = {
         for (final entry in (remoteDocumentsByProject ?? const {}).entries)
           entry.key: List<ProjectDocument>.from(entry.value),
       },
       _loadedDocuments = List<ProjectDocument>.from(
         initialLoadedDocuments ?? const [],
       );

  final Map<String, List<ProjectDocument>> _remoteDocumentsByProject;
  List<ProjectDocument> _loadedDocuments;
  final List<String> loadedProjectIds = <String>[];
  final List<ProjectDocument> savedDocuments = <ProjectDocument>[];

  @override
  Future<void> deleteDocument(String documentId) async {
    _loadedDocuments = [
      for (final document in _loadedDocuments)
        if (document.id != documentId) document,
    ];
  }

  @override
  Future<ProjectDocument?> getDocumentById(String documentId) async {
    for (final document in _loadedDocuments) {
      if (document.id == documentId) {
        return document;
      }
    }
    return null;
  }

  @override
  Future<List<DocumentBookmark>> listBookmarks() async => const [];

  @override
  Future<List<DocumentBookmark>> listBookmarksForDocument(
    String documentId,
  ) async => const [];

  @override
  Future<List<ProjectDocument>> listDocuments() async {
    return List<ProjectDocument>.unmodifiable(_loadedDocuments);
  }

  @override
  Future<List<ProjectDocument>> listDocumentsForProject(
    String projectId,
  ) async {
    loadedProjectIds.add(projectId);
    final remoteDocuments = _remoteDocumentsByProject[projectId] ?? const [];
    final currentDocuments = [
      for (final document in _loadedDocuments)
        if (document.projectId != projectId) document,
      ...remoteDocuments,
    ];
    _loadedDocuments = currentDocuments;
    return List<ProjectDocument>.unmodifiable(
      _loadedDocuments.where((document) => document.projectId == projectId),
    );
  }

  @override
  Future<void> saveBookmark(DocumentBookmark bookmark) async {}

  @override
  Future<void> saveDocument(ProjectDocument document) async {
    savedDocuments.add(document);
    final index = _loadedDocuments.indexWhere(
      (current) => current.id == document.id,
    );
    if (index >= 0) {
      _loadedDocuments = [
        for (var i = 0; i < _loadedDocuments.length; i++)
          if (i == index) document else _loadedDocuments[i],
      ];
      return;
    }

    _loadedDocuments = [..._loadedDocuments, document];
  }
}

class _FakeSessionRepository implements SessionRepository {
  final Map<String, List<SessionNote>> sessionsByProject =
      <String, List<SessionNote>>{};

  @override
  Future<void> addSession(String projectId, SessionNote session) async {
    sessionsByProject[projectId] = [
      ...(sessionsByProject[projectId] ?? const []),
      session,
    ];
  }

  @override
  Future<List<SessionNote>> listSessions(String projectId) async {
    return List<SessionNote>.unmodifiable(
      sessionsByProject[projectId] ?? const [],
    );
  }
}

class _FakeTaskRepository implements TaskRepository {
  _FakeTaskRepository({this.removeTaskResult = false});

  final bool removeTaskResult;
  final List<String> removedTasks = <String>[];

  @override
  Future<void> addTasks(String projectId, List<String> tasks) async {}

  @override
  Future<List<String>> listTasks(String projectId) async => const [];

  @override
  Future<bool> removeTask(String projectId, String task) async {
    removedTasks.add('$projectId:$task');
    return removeTaskResult;
  }
}
