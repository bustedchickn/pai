import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/board_project.dart';
import '../../models/project.dart';
import '../../repositories/project_repository.dart';
import '../../services/project_document_content_codec.dart';
import '../in_memory/in_memory_pai_store.dart';

class FirestoreProjectRepository implements ProjectRepository {
  FirestoreProjectRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    required InMemoryPaiStore localStore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _localStore = localStore;

  static const String _usersCollectionName = 'users';
  static const String _projectsCollectionName = 'projects';
  static const int _seedVersion = 1;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final InMemoryPaiStore _localStore;

  String? _loadedUserId;

  DocumentReference<Map<String, dynamic>> _userDocument(String uid) =>
      _firestore.collection(_usersCollectionName).doc(uid);

  CollectionReference<Map<String, dynamic>> _projectsCollectionForUser(
    String uid,
  ) => _userDocument(uid).collection(_projectsCollectionName);

  @override
  Future<void> createProject({
    required Project project,
    required BoardProject boardProject,
  }) async {
    await _ensureLoaded();
    final uid = _requireUserId();
    await _projectsCollectionForUser(uid)
        .doc(project.id)
        .set(
          _encodeProjectDocument(project: project, boardProject: boardProject),
        );
    _localStore.addProject(project, boardProject);
    _loadedUserId = uid;
  }

  @override
  Future<void> deleteProject(
    String projectId, {
    required DateTime deletedAt,
  }) async {
    await _ensureLoaded();
    final uid = _requireUserId();
    final existingProject = _localStore.projectById(projectId);
    if (existingProject == null) {
      return;
    }

    _localStore.softDeleteProject(projectId, deletedAt: deletedAt);
    final deletedProject = _localStore.projectById(projectId);
    if (deletedProject == null) {
      return;
    }

    final boardProject =
        _localStore.boardProjectById(projectId) ??
        _boardProjectFromProject(deletedProject);
    await _projectsCollectionForUser(uid)
        .doc(projectId)
        .set(
          _encodeProjectDocument(
            project: deletedProject,
            boardProject: boardProject,
          ),
          SetOptions(merge: true),
        );
  }

  @override
  Future<Project?> getProjectById(String projectId) async {
    await _ensureLoaded();
    return _localStore.projectById(projectId);
  }

  @override
  Future<List<BoardProject>> listBoardProjects() async {
    await _ensureLoaded();
    return _localStore.listBoardProjects();
  }

  @override
  Future<List<Project>> listProjects() async {
    await _ensureLoaded();
    return _localStore.listProjects();
  }

  @override
  Future<void> saveBoardProject(BoardProject boardProject) async {
    await _ensureLoaded();
    final uid = _requireUserId();
    _localStore.saveBoardProject(boardProject);
    final project = _localStore.projectById(boardProject.id);
    if (project == null) {
      return;
    }

    await _projectsCollectionForUser(uid)
        .doc(boardProject.id)
        .set(
          _encodeProjectDocument(project: project, boardProject: boardProject),
          SetOptions(merge: true),
        );
  }

  @override
  Future<void> saveProject(Project project) async {
    await _ensureLoaded();
    final uid = _requireUserId();
    _localStore.saveProject(project);
    final boardProject =
        _localStore.boardProjectById(project.id) ??
        BoardProject(
          id: project.id,
          title: project.title,
          brief: ProjectDocumentContentCodec.previewText(project.brief),
          tags: project.tags,
          status: project.status,
          progress: 0,
          boardPosition: Offset.zero,
        );

    await _projectsCollectionForUser(uid)
        .doc(project.id)
        .set(
          _encodeProjectDocument(project: project, boardProject: boardProject),
          SetOptions(merge: true),
        );
  }

  Future<void> _ensureLoaded() async {
    final uid = _requireUserId();
    if (_loadedUserId == uid) {
      return;
    }

    final userSnapshot = await _userDocument(uid).get();
    final snapshot = await _projectsCollectionForUser(
      uid,
    ).orderBy('createdAt').get();
    if (snapshot.docs.isEmpty) {
      if (!userSnapshot.exists) {
        await _seedRemoteFromLocalStore(uid);
      } else {
        _localStore.replaceProjectsAndBoardProjects(
          projects: const [],
          boardProjects: const [],
        );
      }
      _loadedUserId = uid;
      return;
    }

    _hydrateLocalStore(snapshot.docs);
    await _userDocument(uid).set({
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _loadedUserId = uid;
  }

  Future<void> _seedRemoteFromLocalStore(String uid) async {
    final projects = _localStore.listProjects();
    final boardProjects = _localStore.listBoardProjects();
    final batch = _firestore.batch();
    batch.set(_userDocument(uid), {
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSeenAt': FieldValue.serverTimestamp(),
      'projectSeedVersion': _seedVersion,
    }, SetOptions(merge: true));

    for (final project in projects) {
      final boardProject =
          _localStore.boardProjectById(project.id) ??
          boardProjects.where((candidate) => candidate.id == project.id).first;
      batch.set(
        _projectsCollectionForUser(uid).doc(project.id),
        _encodeProjectDocument(project: project, boardProject: boardProject),
      );
    }

    await batch.commit();
  }

  void _hydrateLocalStore(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final projects = <Project>[];
    final boardProjects = <BoardProject>[];

    for (final document in documents) {
      final localProject = _localStore.projectById(document.id);
      final localBoardProject = _localStore.boardProjectById(document.id);
      final project = _decodeProject(
        projectId: document.id,
        data: document.data(),
        localProject: localProject,
      );
      final boardProject = _decodeBoardProject(
        project: project,
        data: document.data(),
        localBoardProject: localBoardProject,
      );
      projects.add(project);
      boardProjects.add(boardProject);
    }

    _localStore.replaceProjectsAndBoardProjects(
      projects: projects,
      boardProjects: boardProjects,
    );
  }

  Map<String, dynamic> _encodeProjectDocument({
    required Project project,
    required BoardProject boardProject,
  }) {
    return {
      'title': project.title,
      'description': project.brief,
      'status': project.status,
      'createdAt': Timestamp.fromDate(project.createdAt),
      'updatedAt': Timestamp.fromDate(project.updatedAt),
      'lastSyncedAt': project.lastSyncedAt == null
          ? null
          : Timestamp.fromDate(project.lastSyncedAt!),
      'deletedAt': project.deletedAt == null
          ? null
          : Timestamp.fromDate(project.deletedAt!),
      'pendingSync': project.isDirty,
      'lastOpenedPageId': project.lastOpenedPageId,
      'tags': project.tags,
      'progress': boardProject.progress,
      'boardPosition': {
        'dx': boardProject.boardPosition.dx,
        'dy': boardProject.boardPosition.dy,
      },
    };
  }

  Project _decodeProject({
    required String projectId,
    required Map<String, dynamic> data,
    required Project? localProject,
  }) {
    final createdAt =
        _timestampFrom(data['createdAt']) ?? localProject?.createdAt;
    final updatedAt =
        _timestampFrom(data['updatedAt']) ?? localProject?.updatedAt;
    final brief = (data['description'] as String?) ?? localProject?.brief ?? '';

    return Project(
      id: projectId,
      title:
          (data['title'] as String?) ??
          localProject?.title ??
          'Untitled project',
      status: (data['status'] as String?) ?? localProject?.status ?? 'active',
      brief: brief,
      briefPageId: localProject?.briefPageId ?? 'brief-$projectId',
      tags: _stringListFrom(data['tags']) ?? localProject?.tags ?? const [],
      nextSteps: localProject?.nextSteps ?? const [],
      blockers: localProject?.blockers ?? const [],
      sessions: localProject?.sessions ?? const [],
      reminders: localProject?.reminders ?? const [],
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? createdAt ?? DateTime.now(),
      lastSyncedAt:
          _timestampFrom(data['lastSyncedAt']) ?? localProject?.lastSyncedAt,
      isDirty: data['pendingSync'] as bool? ?? localProject?.isDirty ?? false,
      deletedAt: _timestampFrom(data['deletedAt']) ?? localProject?.deletedAt,
      lastOpenedPageId:
          data['lastOpenedPageId'] as String? ?? localProject?.lastOpenedPageId,
    );
  }

  BoardProject _decodeBoardProject({
    required Project project,
    required Map<String, dynamic> data,
    required BoardProject? localBoardProject,
  }) {
    return BoardProject(
      id: project.id,
      title: project.title,
      brief: ProjectDocumentContentCodec.previewText(project.brief),
      tags: project.tags,
      status: project.status,
      progress:
          _doubleFrom(data['progress']) ?? localBoardProject?.progress ?? 0,
      boardPosition:
          _offsetFromMap(data['boardPosition']) ??
          localBoardProject?.boardPosition ??
          Offset.zero,
    );
  }

  DateTime? _timestampFrom(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  List<String>? _stringListFrom(Object? value) {
    if (value is! List) {
      return null;
    }

    return [
      for (final item in value)
        if (item is String) item,
    ];
  }

  double? _doubleFrom(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  BoardProject _boardProjectFromProject(Project project) {
    return BoardProject(
      id: project.id,
      title: project.title,
      brief: ProjectDocumentContentCodec.previewText(project.brief),
      tags: project.tags,
      status: project.status,
      progress: 0,
      boardPosition: Offset.zero,
    );
  }

  Offset? _offsetFromMap(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final dx = value['dx'];
    final dy = value['dy'];
    if (dx is num && dy is num) {
      return Offset(dx.toDouble(), dy.toDouble());
    }
    return null;
  }

  String _requireUserId() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError(
        'Project repository accessed before Firebase Auth completed sign-in.',
      );
    }
    return uid;
  }
}
