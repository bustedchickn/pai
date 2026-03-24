import '../../models/document_bookmark.dart';
import '../../models/project_document.dart';
import '../../repositories/document_repository.dart';
import 'in_memory_pai_store.dart';

class InMemoryDocumentRepository implements DocumentRepository {
  InMemoryDocumentRepository(this._store);

  final InMemoryPaiStore _store;

  @override
  Future<ProjectDocument?> getDocumentById(String documentId) async {
    return _store.documentById(documentId);
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    _store.deleteDocumentRecord(documentId);
  }

  @override
  Future<List<DocumentBookmark>> listBookmarks() async {
    return _store.listBookmarks();
  }

  @override
  Future<List<DocumentBookmark>> listBookmarksForDocument(
    String documentId,
  ) async {
    return _store.listBookmarksForDocument(documentId);
  }

  @override
  Future<List<ProjectDocument>> listDocuments() async {
    return _store.listDocuments();
  }

  @override
  Future<List<ProjectDocument>> listDocumentsForProject(
    String projectId,
  ) async {
    return _store.listDocumentsForProject(projectId);
  }

  @override
  Future<void> saveBookmark(DocumentBookmark bookmark) async {
    _store.saveBookmark(bookmark);
  }

  @override
  Future<void> saveDocument(ProjectDocument document) async {
    _store.saveDocumentRecord(document);
  }
}
