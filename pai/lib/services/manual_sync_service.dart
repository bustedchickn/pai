import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/in_memory/in_memory_pai_store.dart';
import '../models/app_data_snapshot.dart';
import '../models/app_sync_state.dart';
import '../models/board_project.dart';
import '../models/document_bookmark.dart';
import '../models/project.dart';
import '../models/project_document.dart';
import '../models/reminder_item.dart';
import '../models/session_note.dart';
import '../models/sync_conflict_backup.dart';
import 'auth_bootstrap_service.dart';

class ManualSyncResult {
  const ManualSyncResult({required this.snapshot, required this.syncState});

  final AppDataSnapshot snapshot;
  final AppSyncState syncState;
}

class ManualSyncService {
  ManualSyncService({
    required InMemoryPaiStore localStore,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _localStore = localStore,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  static const String _usersCollection = 'users';
  static const String _projectsCollectionName = 'projects';
  static const String _pagesCollectionName = 'pages';

  final InMemoryPaiStore _localStore;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AppSyncState describeState(
    AuthBootstrapResult authResult, {
    AppSyncStatus? status,
    String? errorMessage,
  }) {
    final pendingChangesCount = _pendingChangeCount();
    if (!authResult.usesFirebaseAuth || authResult.uid == null) {
      return AppSyncState(
        status: AppSyncStatus.localOnly,
        pendingChangesCount: pendingChangesCount,
        canSync: false,
        lastSyncedAt: _localStore.lastManualSyncAt,
      );
    }

    final resolvedStatus =
        status ??
        (pendingChangesCount > 0
            ? AppSyncStatus.pendingChanges
            : AppSyncStatus.synced);
    return AppSyncState(
      status: resolvedStatus,
      pendingChangesCount: pendingChangesCount,
      canSync: true,
      lastSyncedAt: _localStore.lastManualSyncAt,
      errorMessage: errorMessage,
      userId: authResult.uid,
      isAnonymous: authResult.isAnonymous,
    );
  }

  Future<AppSyncState> loadState(AuthBootstrapResult authResult) async {
    final currentState = describeState(authResult);
    if (!currentState.canSync || authResult.uid == null) {
      return currentState;
    }

    try {
      final userSnapshot = await _userDocument(authResult.uid!).get();
      final remoteLastSync = _dateTimeFrom(
        userSnapshot.data()?['lastManualSyncAt'],
      );
      if (_localStore.lastManualSyncAt == null && remoteLastSync != null) {
        _localStore.setLastManualSyncAt(remoteLastSync);
      }
      return currentState.copyWith(lastSyncedAt: _localStore.lastManualSyncAt);
    } catch (_) {
      return currentState;
    }
  }

  Future<ManualSyncResult> sync(AuthBootstrapResult authResult) async {
    final initialState = describeState(
      authResult,
      status: AppSyncStatus.syncing,
    );
    if (!initialState.canSync || authResult.uid == null) {
      return ManualSyncResult(
        snapshot: _buildSnapshot(),
        syncState: initialState,
      );
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid != authResult.uid) {
      throw StateError('Manual sync requires an authenticated Firebase user.');
    }

    final uid = authResult.uid!;
    final syncStartedAt = DateTime.now();
    final localProjects = {
      for (final project in _localStore.listAllProjects()) project.id: project,
    };
    final localBoardProjects = {
      for (final boardProject in _localStore.listAllBoardProjects())
        boardProject.id: boardProject,
    };
    final localDocuments = {
      for (final document in _localStore.listAllDocuments())
        document.id: document,
    };
    final localBookmarksByDocument = <String, List<DocumentBookmark>>{};
    for (final bookmark in _localStore.listAllBookmarks()) {
      localBookmarksByDocument
          .putIfAbsent(bookmark.documentId, () => <DocumentBookmark>[])
          .add(bookmark);
    }

    final projectSnapshot = await _projectsCollection(uid).get();
    final remoteProjects = <String, _RemoteProjectBundle>{};
    for (final document in projectSnapshot.docs) {
      remoteProjects[document.id] = _decodeRemoteProject(
        document.id,
        document.data(),
      );
    }

    final remoteDocuments = <String, _RemotePageBundle>{};
    for (final projectId in remoteProjects.keys) {
      final pageSnapshot = await _pagesCollection(
        uid: uid,
        projectId: projectId,
      ).get();
      for (final pageDocument in pageSnapshot.docs) {
        remoteDocuments[pageDocument.id] = _decodeRemotePage(
          projectId: projectId,
          pageId: pageDocument.id,
          data: pageDocument.data(),
        );
      }
    }

    final nextProjects = <Project>[];
    final nextBoardProjects = <BoardProject>[];
    final nextDocuments = <ProjectDocument>[];
    final nextBookmarks = <DocumentBookmark>[];
    final nextConflictBackups = [..._localStore.listConflictBackups()];
    final batch = _firestore.batch();

    for (final projectId in {...localProjects.keys, ...remoteProjects.keys}) {
      final resolved = _resolveProject(
        localProject: localProjects[projectId],
        localBoardProject: localBoardProjects[projectId],
        remoteBundle: remoteProjects[projectId],
        syncTimestamp: syncStartedAt,
        uid: uid,
        batch: batch,
        onBackup: nextConflictBackups.add,
      );
      if (resolved == null) {
        continue;
      }
      nextProjects.add(resolved.project);
      nextBoardProjects.add(resolved.boardProject);
    }

    final deletedProjectIds = {
      for (final project in nextProjects)
        if (project.deletedAt != null) project.id,
    };

    for (final documentId in {
      ...localDocuments.keys,
      ...remoteDocuments.keys,
    }) {
      final localDocument = localDocuments[documentId];
      final remoteBundle = remoteDocuments[documentId];
      final projectId =
          localDocument?.projectId ?? remoteBundle?.document.projectId;
      if (projectId != null && deletedProjectIds.contains(projectId)) {
        batch.delete(
          _pagesCollection(uid: uid, projectId: projectId).doc(documentId),
        );
        continue;
      }

      final resolved = _resolveDocument(
        localDocument: localDocument,
        localBookmarks: localBookmarksByDocument[documentId] ?? const [],
        remoteBundle: remoteBundle,
        syncTimestamp: syncStartedAt,
        uid: uid,
        batch: batch,
        onBackup: nextConflictBackups.add,
      );
      if (resolved == null) {
        continue;
      }
      nextDocuments.add(resolved.document);
      if (resolved.document.deletedAt == null) {
        nextBookmarks.addAll(resolved.bookmarks);
      }
    }

    batch.set(_userDocument(uid), {
      'updatedAt': Timestamp.fromDate(syncStartedAt),
      'lastSeenAt': Timestamp.fromDate(syncStartedAt),
      'lastManualSyncAt': Timestamp.fromDate(syncStartedAt),
      'isAnonymous': authResult.isAnonymous,
    }, SetOptions(merge: true));
    await batch.commit();

    _localStore.replaceAll(
      projects: nextProjects,
      boardProjects: nextBoardProjects,
      documents: nextDocuments,
      bookmarks: nextBookmarks,
      conflictBackups: nextConflictBackups,
      lastManualSyncAt: syncStartedAt,
    );

    return ManualSyncResult(
      snapshot: _buildSnapshot(),
      syncState: describeState(
        authResult,
        status: _pendingChangeCount() > 0
            ? AppSyncStatus.pendingChanges
            : AppSyncStatus.synced,
      ).copyWith(lastSyncedAt: syncStartedAt),
    );
  }

  _ResolvedProject? _resolveProject({
    required Project? localProject,
    required BoardProject? localBoardProject,
    required _RemoteProjectBundle? remoteBundle,
    required DateTime syncTimestamp,
    required String uid,
    required WriteBatch batch,
    required void Function(SyncConflictBackup backup) onBackup,
  }) {
    if (localProject == null && remoteBundle == null) {
      return null;
    }

    if (localProject == null && remoteBundle != null) {
      return _ResolvedProject(
        project: remoteBundle.project.copyWith(
          isDirty: false,
          lastSyncedAt: syncTimestamp,
        ),
        boardProject: remoteBundle.boardProject,
      );
    }

    if (localProject != null && remoteBundle == null) {
      final boardProject =
          localBoardProject ?? _boardProjectFromProject(localProject);
      batch.set(
        _projectsCollection(uid).doc(localProject.id),
        _encodeProject(project: localProject, boardProject: boardProject),
        SetOptions(merge: true),
      );
      return _ResolvedProject(
        project: localProject.copyWith(
          isDirty: false,
          lastSyncedAt: syncTimestamp,
        ),
        boardProject: boardProject,
      );
    }

    final remoteProject = remoteBundle!.project;
    final local = localProject!;
    final boardProject = localBoardProject ?? remoteBundle.boardProject;
    final localDeletedAt = local.deletedAt;
    final remoteDeletedAt = remoteProject.deletedAt;

    if (localDeletedAt != null || remoteDeletedAt != null) {
      if (localDeletedAt != null && remoteDeletedAt == null) {
        onBackup(_backupForProject(remoteProject, SyncConflictSource.remote));
        batch.set(
          _projectsCollection(uid).doc(local.id),
          _encodeProject(project: local, boardProject: boardProject),
          SetOptions(merge: true),
        );
        return _ResolvedProject(
          project: local.copyWith(isDirty: false, lastSyncedAt: syncTimestamp),
          boardProject: boardProject,
        );
      }

      if (remoteDeletedAt != null && localDeletedAt == null) {
        onBackup(_backupForProject(local, SyncConflictSource.local));
        return _ResolvedProject(
          project: remoteProject.copyWith(
            isDirty: false,
            lastSyncedAt: syncTimestamp,
          ),
          boardProject: boardProject,
        );
      }

      if (localDeletedAt!.isAfter(remoteDeletedAt!)) {
        onBackup(_backupForProject(remoteProject, SyncConflictSource.remote));
        batch.set(
          _projectsCollection(uid).doc(local.id),
          _encodeProject(project: local, boardProject: boardProject),
          SetOptions(merge: true),
        );
        return _ResolvedProject(
          project: local.copyWith(isDirty: false, lastSyncedAt: syncTimestamp),
          boardProject: boardProject,
        );
      }

      if (remoteDeletedAt.isAfter(localDeletedAt)) {
        onBackup(_backupForProject(local, SyncConflictSource.local));
        return _ResolvedProject(
          project: remoteProject.copyWith(
            isDirty: false,
            lastSyncedAt: syncTimestamp,
          ),
          boardProject: boardProject,
        );
      }

      return _ResolvedProject(
        project: local.copyWith(
          isDirty: false,
          lastSyncedAt: syncTimestamp,
          deletedAt: remoteDeletedAt,
        ),
        boardProject: boardProject,
      );
    }

    final localStamp = _effectiveTimestamp(local.updatedAt, local.deletedAt);
    final remoteStamp = _effectiveTimestamp(
      remoteProject.updatedAt,
      remoteProject.deletedAt,
    );

    if (remoteStamp.isAfter(localStamp)) {
      onBackup(_backupForProject(local, SyncConflictSource.local));
      return _ResolvedProject(
        project: remoteProject.copyWith(
          isDirty: false,
          lastSyncedAt: syncTimestamp,
        ),
        boardProject: remoteBundle.boardProject,
      );
    }

    if (localStamp.isAfter(remoteStamp)) {
      onBackup(_backupForProject(remoteProject, SyncConflictSource.remote));
      batch.set(
        _projectsCollection(uid).doc(local.id),
        _encodeProject(project: local, boardProject: boardProject),
        SetOptions(merge: true),
      );
      return _ResolvedProject(
        project: local.copyWith(isDirty: false, lastSyncedAt: syncTimestamp),
        boardProject: boardProject,
      );
    }

    return _ResolvedProject(
      project: local.copyWith(isDirty: false, lastSyncedAt: syncTimestamp),
      boardProject: boardProject,
    );
  }

  _ResolvedDocument? _resolveDocument({
    required ProjectDocument? localDocument,
    required List<DocumentBookmark> localBookmarks,
    required _RemotePageBundle? remoteBundle,
    required DateTime syncTimestamp,
    required String uid,
    required WriteBatch batch,
    required void Function(SyncConflictBackup backup) onBackup,
  }) {
    if (localDocument == null && remoteBundle == null) {
      return null;
    }

    if (localDocument == null && remoteBundle != null) {
      return _ResolvedDocument(
        document: remoteBundle.document.copyWith(
          isDirty: false,
          lastSyncedAt: syncTimestamp,
        ),
        bookmarks: remoteBundle.document.deletedAt == null
            ? remoteBundle.bookmarks
            : const [],
      );
    }

    if (localDocument != null && remoteBundle == null) {
      batch.set(
        _pagesCollection(
          uid: uid,
          projectId: localDocument.projectId,
        ).doc(localDocument.id),
        _encodePage(localDocument, localBookmarks),
        SetOptions(merge: true),
      );
      return _ResolvedDocument(
        document: localDocument.copyWith(
          isDirty: false,
          lastSyncedAt: syncTimestamp,
        ),
        bookmarks: localDocument.deletedAt == null ? localBookmarks : const [],
      );
    }

    final remoteDocument = remoteBundle!.document;
    final local = localDocument!;
    final localDeletedAt = local.deletedAt;
    final remoteDeletedAt = remoteDocument.deletedAt;

    if (localDeletedAt != null || remoteDeletedAt != null) {
      if (localDeletedAt != null && remoteDeletedAt == null) {
        onBackup(_backupForDocument(remoteDocument, SyncConflictSource.remote));
        batch.set(
          _pagesCollection(uid: uid, projectId: local.projectId).doc(local.id),
          _encodePage(local, localBookmarks),
          SetOptions(merge: true),
        );
        return _ResolvedDocument(
          document: local.copyWith(isDirty: false, lastSyncedAt: syncTimestamp),
          bookmarks: const [],
        );
      }

      if (remoteDeletedAt != null && localDeletedAt == null) {
        onBackup(_backupForDocument(local, SyncConflictSource.local));
        return _ResolvedDocument(
          document: remoteDocument.copyWith(
            isDirty: false,
            lastSyncedAt: syncTimestamp,
          ),
          bookmarks: const [],
        );
      }

      if (localDeletedAt!.isAfter(remoteDeletedAt!)) {
        onBackup(_backupForDocument(remoteDocument, SyncConflictSource.remote));
        batch.set(
          _pagesCollection(uid: uid, projectId: local.projectId).doc(local.id),
          _encodePage(local, localBookmarks),
          SetOptions(merge: true),
        );
        return _ResolvedDocument(
          document: local.copyWith(isDirty: false, lastSyncedAt: syncTimestamp),
          bookmarks: const [],
        );
      }

      if (remoteDeletedAt.isAfter(localDeletedAt)) {
        onBackup(_backupForDocument(local, SyncConflictSource.local));
        return _ResolvedDocument(
          document: remoteDocument.copyWith(
            isDirty: false,
            lastSyncedAt: syncTimestamp,
          ),
          bookmarks: const [],
        );
      }

      return _ResolvedDocument(
        document: local.copyWith(
          isDirty: false,
          lastSyncedAt: syncTimestamp,
          deletedAt: remoteDeletedAt,
        ),
        bookmarks: const [],
      );
    }

    final localStamp = _effectiveTimestamp(local.updatedAt, local.deletedAt);
    final remoteStamp = _effectiveTimestamp(
      remoteDocument.updatedAt,
      remoteDocument.deletedAt,
    );

    if (remoteStamp.isAfter(localStamp)) {
      onBackup(_backupForDocument(local, SyncConflictSource.local));
      return _ResolvedDocument(
        document: remoteDocument.copyWith(
          isDirty: false,
          lastSyncedAt: syncTimestamp,
        ),
        bookmarks: remoteBundle.bookmarks,
      );
    }

    if (localStamp.isAfter(remoteStamp)) {
      onBackup(_backupForDocument(remoteDocument, SyncConflictSource.remote));
      batch.set(
        _pagesCollection(uid: uid, projectId: local.projectId).doc(local.id),
        _encodePage(local, localBookmarks),
        SetOptions(merge: true),
      );
      return _ResolvedDocument(
        document: local.copyWith(isDirty: false, lastSyncedAt: syncTimestamp),
        bookmarks: localBookmarks,
      );
    }

    return _ResolvedDocument(
      document: local.copyWith(isDirty: false, lastSyncedAt: syncTimestamp),
      bookmarks: localBookmarks,
    );
  }

  AppDataSnapshot _buildSnapshot() {
    return AppDataSnapshot(
      projects: _localStore.listProjects(),
      boardProjects: _localStore.listBoardProjects(),
      documents: _localStore.listDocuments(),
      bookmarks: _localStore.listBookmarks(),
    );
  }

  int _pendingChangeCount() {
    return _localStore
            .listAllProjects()
            .where((project) => project.isDirty)
            .length +
        _localStore
            .listAllDocuments()
            .where((document) => document.isDirty)
            .length;
  }

  DocumentReference<Map<String, dynamic>> _userDocument(String uid) {
    return _firestore.collection(_usersCollection).doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _projectsCollection(String uid) {
    return _userDocument(uid).collection(_projectsCollectionName);
  }

  CollectionReference<Map<String, dynamic>> _pagesCollection({
    required String uid,
    required String projectId,
  }) {
    return _projectsCollection(
      uid,
    ).doc(projectId).collection(_pagesCollectionName);
  }

  _RemoteProjectBundle _decodeRemoteProject(
    String projectId,
    Map<String, dynamic> data,
  ) {
    final createdAt = _dateTimeFrom(data['createdAt']) ?? DateTime.now();
    final updatedAt = _dateTimeFrom(data['updatedAt']) ?? createdAt;
    final project = Project(
      id: projectId,
      title: data['title'] as String? ?? 'Untitled project',
      status: data['status'] as String? ?? 'active',
      brief: data['brief'] as String? ?? data['description'] as String? ?? '',
      briefPageId: data['briefPageId'] as String? ?? 'brief-$projectId',
      tags: _stringListFrom(data['tags']),
      nextSteps: _stringListFrom(data['nextSteps']),
      blockers: _stringListFrom(data['blockers']),
      sessions: _sessionListFrom(data['sessions']),
      reminders: _reminderListFrom(data['reminders']),
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastSyncedAt: _dateTimeFrom(data['lastSyncedAt']) ?? updatedAt,
      isDirty: false,
      deletedAt: _dateTimeFrom(data['deletedAt']),
      lastOpenedPageId: data['lastOpenedPageId'] as String?,
    );
    return _RemoteProjectBundle(
      project: project,
      boardProject: BoardProject(
        id: project.id,
        title: project.title,
        brief: project.brief,
        tags: project.tags,
        status: project.status,
        progress: (data['progress'] as num?)?.toDouble() ?? 0,
        boardPosition: _offsetFrom(data['boardPosition']) ?? Offset.zero,
      ),
    );
  }

  _RemotePageBundle _decodeRemotePage({
    required String projectId,
    required String pageId,
    required Map<String, dynamic> data,
  }) {
    final createdAt = _dateTimeFrom(data['createdAt']) ?? DateTime.now();
    final updatedAt = _dateTimeFrom(data['updatedAt']) ?? createdAt;
    return _RemotePageBundle(
      document: ProjectDocument(
        id: pageId,
        projectId: projectId,
        title: data['title'] as String? ?? 'Untitled page',
        kind: switch (data['kind']) {
          'brief' => ProjectPageKind.brief,
          _ => ProjectPageKind.document,
        },
        type: _documentTypeFrom(data['type']),
        content: data['content'] as String? ?? '',
        pinned: data['isPinned'] as bool? ?? false,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastSyncedAt: _dateTimeFrom(data['lastSyncedAt']) ?? updatedAt,
        isDirty: false,
        deletedAt: _dateTimeFrom(data['deletedAt']),
        orderIndex: (data['orderIndex'] as num?)?.toInt(),
      ),
      bookmarks: _bookmarkListFrom(data['bookmarks'], pageId),
    );
  }

  Map<String, dynamic> _encodeProject({
    required Project project,
    required BoardProject boardProject,
  }) {
    return {
      'id': project.id,
      'title': project.title,
      'status': project.status,
      'brief': project.brief,
      'description': project.brief,
      'briefPageId': project.briefPageId,
      'tags': project.tags,
      'nextSteps': project.nextSteps,
      'blockers': project.blockers,
      'sessions': [for (final session in project.sessions) session.toJson()],
      'reminders': [
        for (final reminder in project.reminders) reminder.toJson(),
      ],
      'createdAt': Timestamp.fromDate(project.createdAt),
      'updatedAt': Timestamp.fromDate(project.updatedAt),
      'lastSyncedAt': Timestamp.fromDate(_syncTimestampForProject(project)),
      'deletedAt': project.deletedAt == null
          ? null
          : Timestamp.fromDate(project.deletedAt!),
      'pendingSync': false,
      'lastOpenedPageId': project.lastOpenedPageId,
      'progress': boardProject.progress,
      'boardPosition': {
        'dx': boardProject.boardPosition.dx,
        'dy': boardProject.boardPosition.dy,
      },
    };
  }

  Map<String, dynamic> _encodePage(
    ProjectDocument document,
    List<DocumentBookmark> bookmarks,
  ) {
    return {
      'id': document.id,
      'title': document.title,
      'content': document.content,
      'kind': switch (document.kind) {
        ProjectPageKind.brief => 'brief',
        ProjectPageKind.document => 'document',
      },
      'type': _documentTypeValue(document.type),
      'isPinned': document.pinned,
      'createdAt': Timestamp.fromDate(document.createdAt),
      'updatedAt': Timestamp.fromDate(document.updatedAt),
      'lastSyncedAt': Timestamp.fromDate(_syncTimestampForDocument(document)),
      'deletedAt': document.deletedAt == null
          ? null
          : Timestamp.fromDate(document.deletedAt!),
      'pendingSync': false,
      'orderIndex': document.orderIndex,
      'bookmarks': [for (final bookmark in bookmarks) bookmark.toJson()],
    };
  }

  DateTime _syncTimestampForProject(Project project) {
    return project.lastSyncedAt ?? project.updatedAt;
  }

  DateTime _syncTimestampForDocument(ProjectDocument document) {
    return document.lastSyncedAt ?? document.updatedAt;
  }

  SyncConflictBackup _backupForProject(
    Project project,
    SyncConflictSource source,
  ) {
    return SyncConflictBackup(
      id: 'backup-project-${project.id}-${DateTime.now().microsecondsSinceEpoch}',
      entityType: SyncConflictEntityType.project,
      entityId: project.id,
      projectId: project.id,
      title: project.title,
      capturedAt: DateTime.now(),
      source: source,
      payload: project.toJson(),
    );
  }

  SyncConflictBackup _backupForDocument(
    ProjectDocument document,
    SyncConflictSource source,
  ) {
    return SyncConflictBackup(
      id: 'backup-document-${document.id}-${DateTime.now().microsecondsSinceEpoch}',
      entityType: SyncConflictEntityType.document,
      entityId: document.id,
      projectId: document.projectId,
      title: document.title,
      capturedAt: DateTime.now(),
      source: source,
      payload: document.toJson(),
    );
  }

  DateTime _effectiveTimestamp(DateTime updatedAt, DateTime? deletedAt) {
    if (deletedAt == null) {
      return updatedAt;
    }
    return deletedAt.isAfter(updatedAt) ? deletedAt : updatedAt;
  }

  DateTime? _dateTimeFrom(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
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

  List<DocumentBookmark> _bookmarkListFrom(Object? value, String documentId) {
    if (value is! List) {
      return const [];
    }

    return [
      for (final item in value)
        if (item is Map<String, dynamic>)
          DocumentBookmark.fromJson({
            ...item,
            'documentId': item['documentId'] ?? documentId,
          }),
    ];
  }

  Offset? _offsetFrom(Object? value) {
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

  ProjectDocumentType _documentTypeFrom(Object? value) {
    if (value is String) {
      for (final type in ProjectDocumentType.values) {
        if (_documentTypeValue(type) == value) {
          return type;
        }
      }
    }
    return ProjectDocumentType.implementation;
  }

  String _documentTypeValue(ProjectDocumentType type) {
    return switch (type) {
      ProjectDocumentType.design => 'design',
      ProjectDocumentType.implementation => 'implementation',
      ProjectDocumentType.story => 'story',
      ProjectDocumentType.research => 'research',
      ProjectDocumentType.reference => 'reference',
    };
  }

  BoardProject _boardProjectFromProject(Project project) {
    return BoardProject(
      id: project.id,
      title: project.title,
      brief: project.brief,
      tags: project.tags,
      status: project.status,
      progress: 0,
      boardPosition: Offset.zero,
    );
  }
}

class _RemoteProjectBundle {
  const _RemoteProjectBundle({
    required this.project,
    required this.boardProject,
  });

  final Project project;
  final BoardProject boardProject;
}

class _RemotePageBundle {
  const _RemotePageBundle({required this.document, required this.bookmarks});

  final ProjectDocument document;
  final List<DocumentBookmark> bookmarks;
}

class _ResolvedProject {
  const _ResolvedProject({required this.project, required this.boardProject});

  final Project project;
  final BoardProject boardProject;
}

class _ResolvedDocument {
  const _ResolvedDocument({required this.document, required this.bookmarks});

  final ProjectDocument document;
  final List<DocumentBookmark> bookmarks;
}
