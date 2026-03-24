import '../models/document_bookmark.dart';
import '../models/project_document.dart';

abstract class DocumentRepository {
  Future<List<ProjectDocument>> listDocuments();
  Future<List<ProjectDocument>> listDocumentsForProject(String projectId);
  Future<ProjectDocument?> getDocumentById(String documentId);
  Future<void> saveDocument(ProjectDocument document);
  Future<void> deleteDocument(String documentId);
  Future<List<DocumentBookmark>> listBookmarks();
  Future<List<DocumentBookmark>> listBookmarksForDocument(String documentId);
  Future<void> saveBookmark(DocumentBookmark bookmark);
}
