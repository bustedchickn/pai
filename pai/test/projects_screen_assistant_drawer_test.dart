import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pai/data/mock_data.dart';
import 'package:pai/screens/projects_screen.dart';

void main() {
  testWidgets(
    'assistant drawer is hidden by default and preserves input state',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectsScreen(
            projects: mockProjects,
            documents: mockProjectDocuments,
            bookmarks: mockDocumentBookmarks,
            onProjectSaved: (project) async {},
            onProjectDeleted: (projectId) async {},
            onSessionSaved: (projectId, session) async {},
            onTasksAdded: (projectId, tasks) async {},
            onTaskCompleted:
                (projectId, task, completionNote, updatedBrief) async {},
            onDocumentSaved: (document) async {},
            onBookmarkSaved: (bookmark) async {},
            onDocumentDeleted: (documentId) async {},
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('assistant-drawer-close')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('assistant-drawer-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Assistant'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('assistant-drawer-close')),
        findsOneWidget,
      );
      expect(find.text('Recent Sessions'), findsNothing);
      expect(find.text('Project Stats'), findsNothing);
      expect(find.text('Record Session'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('assistant-question-field')),
        'Need summary',
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('assistant-drawer-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('assistant-drawer-close')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('assistant-drawer-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Need summary'), findsOneWidget);
    },
  );
}
