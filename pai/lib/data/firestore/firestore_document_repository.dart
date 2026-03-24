import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/document_bookmark.dart';
import '../../models/project.dart';
import '../../models/project_document.dart';
import '../../repositories/document_repository.dart';
import '../in_memory/in_memory_pai_store.dart';

class FirestoreDocumentRepository implements DocumentRepository {
  FirestoreDocumentRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    required InMemoryPaiStore localStore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _localStore = localStore;

  static const String _usersCollectionName = 'users';
  static const String _projectsCollectionName = 'projects';
  static const String _pagesCollectionName = 'pages';

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final InMemoryPaiStore _localStore;

  String? _loadedUserId;
  final Set<String> _loadedProjectIds = <String>{};

  @override
  Future<ProjectDocument?> getDocumentById(String documentId) async {
    await _ensureLoaded();
    return _localStore.documentById(documentId) ??
        _briefDocumentById(documentId);
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    await _ensureLoaded();
    final document = _localStore.documentById(documentId);
    if (document == null) {
      return;
    }

    _localStore.deleteDocumentRecord(documentId);
    await _pagesCollectionForProject(
      uid: _requireUserId(),
      projectId: document.projectId,
    ).doc(documentId).delete();
  }

  @override
  Future<List<DocumentBookmark>> listBookmarks() async {
    return _localStore.listBookmarks();
  }

  @override
  Future<List<DocumentBookmark>> listBookmarksForDocument(
    String documentId,
  ) async {
    return _localStore.listBookmarksForDocument(documentId);
  }

  @override
  Future<List<ProjectDocument>> listDocuments() async {
    await _ensureLoaded();
    return _localStore.listDocuments();
  }

  @override
  Future<List<ProjectDocument>> listDocumentsForProject(
    String projectId,
  ) async {
    await _ensureProjectLoaded(projectId);
    return _localStore.listDocumentsForProject(projectId);
  }

  @override
  Future<void> saveBookmark(DocumentBookmark bookmark) async {
    _localStore.saveBookmark(bookmark);
  }

  @override
  Future<void> saveDocument(ProjectDocument document) async {
    await _ensureProjectLoaded(document.projectId);
    final uid = _requireUserId();
    final encoded = _encodePage(document);
    await _pagesCollectionForProject(
      uid: uid,
      projectId: document.projectId,
    ).doc(document.id).set(encoded, SetOptions(merge: true));

    if (document.kind == ProjectPageKind.brief) {
      final project = _localStore.projectById(document.projectId);
      if (project == null) {
        return;
      }

      _localStore.saveProject(
        project.copyWith(
          brief: document.content,
          briefPageId: document.id,
          updatedAt: document.updatedAt,
        ),
      );
      return;
    }

    _localStore.saveDocumentRecord(document);
  }

  Future<void> _ensureLoaded() async {
    final uid = _requireUserId();
    if (_loadedUserId != uid) {
      _loadedUserId = uid;
      _loadedProjectIds.clear();
      _localStore.replaceDocuments(const []);
      _localStore.replaceBookmarks(const []);
    }

    for (final project in _localStore.listProjects()) {
      await _ensureProjectLoaded(project.id);
    }
  }

  Future<void> _ensureProjectLoaded(String projectId) async {
    final uid = _requireUserId();
    if (_loadedUserId != uid) {
      _loadedUserId = uid;
      _loadedProjectIds.clear();
      _localStore.replaceDocuments(const []);
      _localStore.replaceBookmarks(const []);
    }

    if (_loadedProjectIds.contains(projectId)) {
      return;
    }

    final project = _localStore.projectById(projectId);
    if (project == null) {
      return;
    }

    final snapshot = await _pagesCollectionForProject(
      uid: uid,
      projectId: projectId,
    ).orderBy('createdAt').get();

    if (snapshot.docs.isEmpty) {
      await _seedProjectPagesFromLocalStore(project);
      _loadedProjectIds.add(projectId);
      return;
    }

    final existingDocuments = [
      for (final document in _localStore.listDocuments())
        if (document.projectId != projectId) document,
    ];
    var hasBriefPage = false;
    var projectWithBrief = project;

    for (final pageDocument in snapshot.docs) {
      final page = _decodePage(
        projectId: projectId,
        pageId: pageDocument.id,
        data: pageDocument.data(),
      );
      if (page.kind == ProjectPageKind.brief) {
        hasBriefPage = true;
        projectWithBrief = projectWithBrief.copyWith(
          brief: page.content,
          briefPageId: page.id,
          updatedAt: page.updatedAt.isAfter(projectWithBrief.updatedAt)
              ? page.updatedAt
              : projectWithBrief.updatedAt,
        );
      } else {
        existingDocuments.add(page);
      }
    }

    if (!hasBriefPage) {
      await _saveBriefPage(projectWithBrief);
    } else {
      _localStore.saveProject(projectWithBrief);
    }
    _localStore.replaceDocuments(existingDocuments);
    _loadedProjectIds.add(projectId);
  }

  Future<void> _seedProjectPagesFromLocalStore(Project project) async {
    final batch = _firestore.batch();
    final briefPage = _briefDocumentFromProject(project);
    batch.set(
      _pagesCollectionForProject(
        uid: _requireUserId(),
        projectId: project.id,
      ).doc(briefPage.id),
      _encodePage(briefPage),
    );

    for (final document in _localStore.listDocumentsForProject(project.id)) {
      batch.set(
        _pagesCollectionForProject(
          uid: _requireUserId(),
          projectId: project.id,
        ).doc(document.id),
        _encodePage(document),
      );
    }

    await batch.commit();
  }

  Future<void> _saveBriefPage(Project project) async {
    final briefPage = _briefDocumentFromProject(project);
    await _pagesCollectionForProject(
      uid: _requireUserId(),
      projectId: project.id,
    ).doc(briefPage.id).set(_encodePage(briefPage), SetOptions(merge: true));
    _localStore.saveProject(project);
  }

  CollectionReference<Map<String, dynamic>> _pagesCollectionForProject({
    required String uid,
    required String projectId,
  }) {
    return _firestore
        .collection(_usersCollectionName)
        .doc(uid)
        .collection(_projectsCollectionName)
        .doc(projectId)
        .collection(_pagesCollectionName);
  }

  ProjectDocument? _briefDocumentById(String documentId) {
    for (final project in _localStore.listProjects()) {
      if (project.briefPageId == documentId) {
        return _briefDocumentFromProject(project);
      }
    }
    return null;
  }

  ProjectDocument _briefDocumentFromProject(Project project) {
    return ProjectDocument(
      id: project.briefPageId,
      projectId: project.id,
      title: 'Project Brief',
      kind: ProjectPageKind.brief,
      type: ProjectDocumentType.reference,
      content: project.brief,
      pinned: false,
      createdAt: project.createdAt,
      updatedAt: project.updatedAt,
      orderIndex: 0,
    );
  }

  ProjectDocument _decodePage({
    required String projectId,
    required String pageId,
    required Map<String, dynamic> data,
  }) {
    final kind = _pageKindFrom(data['kind']);
    final createdAt = _timestampFrom(data['createdAt']) ?? DateTime.now();
    final updatedAt = _timestampFrom(data['updatedAt']) ?? createdAt;
    return ProjectDocument(
      id: pageId,
      projectId: projectId,
      title: (data['title'] as String?) ?? 'Untitled page',
      kind: kind,
      type: _documentTypeFrom(data['type'], fallbackKind: kind),
      content: (data['content'] as String?) ?? '',
      pinned: (data['isPinned'] as bool?) ?? false,
      createdAt: createdAt,
      updatedAt: updatedAt,
      orderIndex: (data['orderIndex'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> _encodePage(ProjectDocument document) {
    return {
      'title': document.title,
      'content': document.content,
      'kind': _pageKindValue(document.kind),
      'type': _documentTypeValue(document.type),
      'isPinned': document.pinned,
      'createdAt': Timestamp.fromDate(document.createdAt),
      'updatedAt': Timestamp.fromDate(document.updatedAt),
      if (document.orderIndex != null) 'orderIndex': document.orderIndex,
    };
  }

  ProjectPageKind _pageKindFrom(Object? value) {
    return switch (value) {
      'brief' => ProjectPageKind.brief,
      _ => ProjectPageKind.document,
    };
  }

  String _pageKindValue(ProjectPageKind kind) {
    return switch (kind) {
      ProjectPageKind.brief => 'brief',
      ProjectPageKind.document => 'document',
    };
  }

  ProjectDocumentType _documentTypeFrom(
    Object? value, {
    required ProjectPageKind fallbackKind,
  }) {
    if (value is String) {
      for (final type in ProjectDocumentType.values) {
        if (_documentTypeValue(type) == value) {
          return type;
        }
      }
    }

    return fallbackKind == ProjectPageKind.brief
        ? ProjectDocumentType.reference
        : ProjectDocumentType.implementation;
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

  DateTime? _timestampFrom(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  String _requireUserId() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError(
        'Document repository accessed before Firebase Auth completed sign-in.',
      );
    }
    return uid;
  }
}
