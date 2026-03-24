import 'dart:ui';

import '../../models/board_project.dart';
import '../../models/document_bookmark.dart';
import '../../models/project.dart';
import '../../models/project_document.dart';
import '../../services/project_document_content_codec.dart';
import '../mock_data.dart';

class InMemoryPaiStore {
  InMemoryPaiStore({
    List<Project>? initialProjects,
    List<BoardProject>? initialBoardProjects,
    List<ProjectDocument>? initialDocuments,
    List<DocumentBookmark>? initialBookmarks,
  }) : _projects = List<Project>.from(initialProjects ?? mockProjects),
       _boardProjects = List<BoardProject>.from(
         initialBoardProjects ?? mockBoardProjects,
       ),
       _documents = List<ProjectDocument>.from(
         initialDocuments ?? mockProjectDocuments,
       ),
       _bookmarks = List<DocumentBookmark>.from(
         initialBookmarks ?? mockDocumentBookmarks,
       );

  List<Project> _projects;
  List<BoardProject> _boardProjects;
  List<ProjectDocument> _documents;
  List<DocumentBookmark> _bookmarks;

  List<Project> listProjects() => List<Project>.unmodifiable(_projects);

  List<BoardProject> listBoardProjects() =>
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

  List<ProjectDocument> listDocuments() =>
      List<ProjectDocument>.unmodifiable(_documents);

  void replaceDocuments(List<ProjectDocument> documents) {
    _documents = List<ProjectDocument>.from(documents);
  }

  List<ProjectDocument> listDocumentsForProject(String projectId) {
    return List<ProjectDocument>.unmodifiable([
      for (final document in _documents)
        if (document.projectId == projectId) document,
    ]);
  }

  List<DocumentBookmark> listBookmarks() =>
      List<DocumentBookmark>.unmodifiable(_bookmarks);

  void replaceBookmarks(List<DocumentBookmark> bookmarks) {
    _bookmarks = List<DocumentBookmark>.from(bookmarks);
  }

  List<DocumentBookmark> listBookmarksForDocument(String documentId) {
    return List<DocumentBookmark>.unmodifiable([
      for (final bookmark in _bookmarks)
        if (bookmark.documentId == documentId) bookmark,
    ]);
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

  ProjectDocument? documentById(String documentId) {
    for (final document in _documents) {
      if (document.id == documentId) {
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
}
