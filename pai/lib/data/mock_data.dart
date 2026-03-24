import 'package:flutter/widgets.dart';

import '../models/board_project.dart';
import '../models/document_bookmark.dart';
import '../models/project.dart';
import '../models/project_document.dart';
import '../models/reminder_item.dart';
import '../models/session_note.dart';

final statusPaAiProject = Project(
  id: '1',
  title: 'pai',
  status: 'active',
  brief:
      'MVP is defined. Focus on project CRUD, session recaps, reminders, and later AI summaries.',
  briefPageId: 'brief-1',
  tags: ['Coding', 'Flutter', 'MVP'],
  nextSteps: [
    'Set up local models',
    'Build project detail screen',
    'Add session recap flow',
  ],
  blockers: ['Need a simple data layer that works on desktop and mobile'],
  sessions: [
    SessionNote(
      id: 's1',
      dateLabel: 'Today',
      summary:
          'Outlined the app as a local-first project assistant with synced reminders.',
    ),
    SessionNote(
      id: 's2',
      dateLabel: 'Yesterday',
      summary: 'Decided to start with mock data before adding Firebase.',
    ),
  ],
  reminders: [
    ReminderItem(
      id: 'r1',
      title: 'Create Flutter models',
      dueLabel: 'Tonight',
      projectTitle: 'pai',
    ),
    ReminderItem(
      id: 'r2',
      title: 'Design project detail page',
      dueLabel: 'Tomorrow',
      projectTitle: 'pai',
    ),
  ],
  createdAt: DateTime(2026, 3, 15, 9, 0),
  updatedAt: DateTime(2026, 3, 21, 18, 30),
  lastOpenedPageId: 'd1',
);

final eventOpsProject = Project(
  id: '2',
  title: 'Event Ops App',
  status: 'active',
  brief: 'Navigation and organization-level polish are the current focus.',
  briefPageId: 'brief-2',
  tags: ['Work', 'Operations', 'Web'],
  nextSteps: ['Refine nav flow', 'Polish event pages'],
  blockers: [],
  sessions: [
    SessionNote(
      id: 's3',
      dateLabel: '2 days ago',
      summary: 'Moved the app to a Firebase-hosted SPA structure.',
    ),
  ],
  reminders: [
    ReminderItem(
      id: 'r3',
      title: 'Review billing flow',
      dueLabel: 'Friday',
      projectTitle: 'Event Ops App',
    ),
  ],
  createdAt: DateTime(2026, 3, 14, 11, 0),
  updatedAt: DateTime(2026, 3, 20, 16, 5),
  lastOpenedPageId: 'd3',
);

final practiceAppProject = Project(
  id: '3',
  title: 'Practice App',
  status: 'paused',
  brief:
      'Idea is still interesting, but the feature list needs to be reduced before moving forward.',
  briefPageId: 'brief-3',
  tags: ['Creative', 'Music', 'Mobile'],
  nextSteps: ['Clarify the smallest useful version'],
  blockers: ['Scope is too broad right now'],
  sessions: [],
  reminders: [],
  createdAt: DateTime(2026, 3, 13, 16, 0),
  updatedAt: DateTime(2026, 3, 19, 20, 40),
);

final mockProjects = [statusPaAiProject, eventOpsProject, practiceAppProject];

const mockBoardProjects = [
  BoardProject(
    id: '1',
    title: 'pai',
    brief:
        'MVP is defined. Focus on project CRUD, session recaps, reminders, and later AI summaries.',
    tags: ['Coding', 'Flutter', 'MVP'],
    status: 'active',
    progress: 0.35,
    boardPosition: Offset(80, 120),
  ),
  BoardProject(
    id: '2',
    title: 'Event Ops App',
    brief: 'Navigation and organization-level polish are the current focus.',
    tags: ['Work', 'Operations', 'Web'],
    status: 'active',
    progress: 0.70,
    boardPosition: Offset(430, 220),
  ),
  BoardProject(
    id: '3',
    title: 'Practice App',
    brief:
        'Idea is still interesting, but the feature list needs to be reduced before moving forward.',
    tags: ['Creative', 'Music', 'Mobile'],
    status: 'paused',
    progress: 0.20,
    boardPosition: Offset(220, 470),
  ),
];

final mockProjectDocuments = [
  ProjectDocument(
    id: 'd1',
    projectId: '1',
    title: 'Implementation backlog',
    type: ProjectDocumentType.implementation,
    content:
        '# Repository layer\n- Keep AppShell as the lightweight coordinator.\n- Move local data behind repository interfaces.\n\n# Firebase prep\n- Keep writes async.\n- Separate project, task, session, and document concerns.\n',
    pinned: true,
    createdAt: DateTime(2026, 3, 18, 9, 0),
    updatedAt: DateTime(2026, 3, 21, 18, 30),
  ),
  ProjectDocument(
    id: 'd2',
    projectId: '1',
    title: 'Design notes',
    type: ProjectDocumentType.design,
    content:
        '# Experience goals\nThe project page should feel calm, practical, and easy to scan.\n\n# Layout notes\n- Keep one-page project detail flow.\n- Add documents without turning the screen into a full editor.\n',
    pinned: false,
    createdAt: DateTime(2026, 3, 19, 14, 0),
    updatedAt: DateTime(2026, 3, 20, 11, 15),
  ),
  ProjectDocument(
    id: 'd3',
    projectId: '2',
    title: 'Billing flow research',
    type: ProjectDocumentType.research,
    content:
        '# Findings\n- Billing setup friction happens during plan selection.\n- The review screen needs clearer copy and fallback guidance.\n',
    pinned: true,
    createdAt: DateTime(2026, 3, 17, 10, 45),
    updatedAt: DateTime(2026, 3, 20, 16, 5),
  ),
  ProjectDocument(
    id: 'd4',
    projectId: '3',
    title: 'Lore fragments',
    type: ProjectDocumentType.story,
    content:
        '# Core mood\nA playful music world where practice reshapes the environment.\n\n# Character note\nThe guide character should encourage experimentation instead of grading progress.\n',
    pinned: false,
    createdAt: DateTime(2026, 3, 16, 19, 20),
    updatedAt: DateTime(2026, 3, 19, 20, 40),
  ),
];

final mockDocumentBookmarks = [
  DocumentBookmark(
    id: 'b1',
    documentId: 'd1',
    label: 'Repo layer',
    note: 'Core architectural split for the local-first app.',
    anchor: 'Repository layer',
  ),
  DocumentBookmark(
    id: 'b2',
    documentId: 'd1',
    label: 'Firebase prep',
    note: 'Requirements for the next backend step.',
    anchor: 'Firebase prep',
  ),
  DocumentBookmark(
    id: 'b3',
    documentId: 'd2',
    label: 'Layout notes',
    anchor: 'Layout notes',
  ),
  DocumentBookmark(
    id: 'b4',
    documentId: 'd3',
    label: 'Findings',
    note: 'Useful summary before revisiting the billing UI.',
    anchor: 'Findings',
  ),
];
