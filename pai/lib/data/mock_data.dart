import 'package:flutter/widgets.dart';

import '../models/board_project.dart';
import '../models/project.dart';
import '../models/reminder_item.dart';
import '../models/session_note.dart';

const statusPaAiProject = Project(
  id: '1',
  title: 'pai',
  status: 'active',
  brief:
      'MVP is defined. Focus on project CRUD, session recaps, reminders, and later AI summaries.',
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
);

const eventOpsProject = Project(
  id: '2',
  title: 'Event Ops App',
  status: 'active',
  brief: 'Navigation and organization-level polish are the current focus.',
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
);

const practiceAppProject = Project(
  id: '3',
  title: 'Practice App',
  status: 'paused',
  brief:
      'Idea is still interesting, but the feature list needs to be reduced before moving forward.',
  tags: ['Creative', 'Music', 'Mobile'],
  nextSteps: ['Clarify the smallest useful version'],
  blockers: ['Scope is too broad right now'],
  sessions: [],
  reminders: [],
);

const mockProjects = [statusPaAiProject, eventOpsProject, practiceAppProject];

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
