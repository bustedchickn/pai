import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pai/data/mock_data.dart';
import 'package:pai/models/project.dart';
import 'package:pai/screens/projects_screen.dart';

void main() {
  Widget buildScreen({
    String? selectedProjectId,
    List<Project>? projects,
  }) {
    return MaterialApp(
      home: ProjectsScreen(
        projects: projects ?? mockProjects,
        documents: mockProjectDocuments,
        bookmarks: mockDocumentBookmarks,
        selectedProjectId: selectedProjectId,
        onProjectSaved: (project) async {},
        onSessionSaved: (projectId, session) async {},
        onTasksAdded: (projectId, tasks) async {},
        onTaskCompleted: (
          projectId,
          task,
          completionNote,
          updatedBrief,
        ) async {},
        onDocumentSaved: (document) async {},
        onBookmarkSaved: (bookmark) async {},
        onDocumentDeleted: (documentId) async {},
      ),
    );
  }

  Future<void> pumpWorkspace(
    WidgetTester tester, {
    String? selectedProjectId,
    List<Project>? projects,
  }) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      buildScreen(selectedProjectId: selectedProjectId, projects: projects),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens last opened page when available', (
    WidgetTester tester,
  ) async {
    await pumpWorkspace(tester, selectedProjectId: '1');

    expect(find.text('Implementation backlog'), findsWidgets);
    expect(
      find.byKey(const ValueKey('page-nav-d1')),
      findsOneWidget,
    );
  });

  testWidgets('falls back to brief page when last opened page is missing', (
    WidgetTester tester,
  ) async {
    final projects = [
      mockProjects.first.copyWith(lastOpenedPageId: 'missing-page'),
      ...mockProjects.skip(1),
    ];

    await pumpWorkspace(
      tester,
      selectedProjectId: '1',
      projects: projects,
    );

    expect(find.text('Project Brief'), findsWidgets);
  });

  testWidgets('clicking a page in the sidebar opens it immediately', (
    WidgetTester tester,
  ) async {
    await pumpWorkspace(tester, selectedProjectId: '1');

    await tester.tap(find.byKey(const ValueKey('page-nav-d2')));
    await tester.pumpAndSettle();

    expect(find.text('Design notes'), findsWidgets);
  });

  testWidgets('pinned section is hidden when a project has no pinned pages', (
    WidgetTester tester,
  ) async {
    await pumpWorkspace(tester, selectedProjectId: '3');

    expect(find.text('Pinned'), findsNothing);
  });

  testWidgets('clicking the project name flips to the project hub and back', (
    WidgetTester tester,
  ) async {
    await pumpWorkspace(tester, selectedProjectId: '1');

    await tester.tap(find.byKey(const ValueKey('project-hub-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('project-hub-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('project-hub-record-session')), findsOneWidget);
    expect(find.text('Recent Sessions'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('project-hub-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('project-hub-view')), findsNothing);
    expect(find.text('Implementation backlog'), findsWidgets);
  });

  testWidgets('record session reveals the project hub composer', (
    WidgetTester tester,
  ) async {
    await pumpWorkspace(tester, selectedProjectId: '1');

    await tester.tap(find.byKey(const ValueKey('project-hub-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const ValueKey('project-hub-record-session')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('project-hub-session-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('project-hub-speech-button')),
      findsOneWidget,
    );
  });
}
