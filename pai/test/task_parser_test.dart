import 'package:flutter_test/flutter_test.dart';
import 'package:pai/services/task_parser.dart';

void main() {
  group('normalizeTaskInput', () {
    test('inserts likely boundaries before repeated intent markers', () {
      expect(
        normalizeTaskInput('I need to go to the store I need to buy milk'),
        'I need to go to the store. I need to buy milk',
      );
    });

    test(
      'normalizes whitespace and punctuation without losing the raw text later',
      () {
        expect(
          normalizeTaskInput('  I need to write docs,then send it  '),
          'I need to write docs, then send it',
        );
      },
    );
  });

  group('segmentTaskClauses', () {
    test('splits the run-on example into candidate clauses', () {
      final clauses = segmentTaskClauses(
        normalizeTaskInput(
          'I need to go to the store I need to add more features and add a better description of the project also do it',
        ),
      );

      expect(clauses, <String>[
        'I need to go to the store',
        'I need to add more features',
        'add a better description of the project',
        'also do it',
      ]);
    });

    test(
      'splits concrete tasks joined by and when a new verb phrase starts',
      () {
        final clauses = segmentTaskClauses(
          normalizeTaskInput('Buy milk and call mom'),
        );
        expect(clauses, <String>['Buy milk', 'call mom']);
      },
    );

    test('does not over-split noun phrases', () {
      final clauses = segmentTaskClauses(
        normalizeTaskInput('Buy milk and bread'),
      );
      expect(clauses, <String>['Buy milk and bread']);
    });

    test('splits on sequence markers like after that', () {
      final clauses = segmentTaskClauses(
        normalizeTaskInput('Review the brief after that send the invoice'),
      );
      expect(clauses, <String>[
        'Review the brief',
        'after that send the invoice',
      ]);
    });

    test('splits coordinated comma action lists', () {
      final clauses = segmentTaskClauses(
        normalizeTaskInput(
          'I need to go to the store, hang up my clothes, and eat food',
        ),
      );
      expect(clauses, <String>[
        'I need to go to the store',
        'hang up my clothes',
        'eat food',
      ]);
    });

    test('does not split descriptive commas that are not action lists', () {
      final clauses = segmentTaskClauses(
        normalizeTaskInput('email John, the manager at work'),
      );
      expect(clauses, <String>['email John, the manager at work']);
    });
  });

  group('classifyTaskClause', () {
    test('classifies a concrete action as an atomic task', () {
      final item = classifyTaskClause('Go to the store');
      expect(item.classification, ParsedTaskClassification.atomicTask);
      expect(item.confidence, greaterThan(0.8));
      expect(item.normalizedText, 'Go to the store');
    });

    test('classifies a broad feature request as a goal with suggestions', () {
      final item = classifyTaskClause('Add more features');
      expect(item.classification, ParsedTaskClassification.goal);
      expect(item.normalizedText, 'Plan additional features');
      expect(item.suggestedSubtasks, <String>[
        'List desired features',
        'Prioritize feature ideas',
        'Implement selected features',
      ]);
    });

    test('classifies do it as an execution signal', () {
      final item = classifyTaskClause('do it');
      expect(item.classification, ParsedTaskClassification.executionSignal);
      expect(item.confidence, lessThan(0.5));
    });

    test('classifies vague pronoun actions as ambiguous', () {
      final item = classifyTaskClause('update it');
      expect(item.classification, ParsedTaskClassification.ambiguous);
      expect(item.confidence, lessThan(0.4));
    });

    test('classifies note-like content as note', () {
      final item = classifyTaskClause('FYI the client already approved it');
      expect(item.classification, ParsedTaskClassification.note);
    });

    test('strips hedge words from soft intent task phrasing', () {
      final item = classifyTaskClause('I should probably exercise');
      expect(item.classification, ParsedTaskClassification.atomicTask);
      expect(item.normalizedText, 'Exercise');
    });

    test('supports soft intent without an explicit intent marker', () {
      final item = classifyTaskClause('maybe call mom');
      expect(item.classification, ParsedTaskClassification.atomicTask);
      expect(item.normalizedText, 'Call mom');
    });

    test('extracts conditional reminders into concrete tasks', () {
      final item = classifyTaskClause(
        'when adding the wumbo feature I need to remember to bumbify it',
      );
      expect(item.classification, ParsedTaskClassification.atomicTask);
      expect(item.normalizedText, 'Bumbify the wumbo feature');
      expect(item.reason, contains('conditional reminder'));
    });
  });

  group('parseTasks', () {
    test(
      'preserves raw input and emits structured items for the example prompt',
      () {
        const input =
            'I need to go to the store I need to add more features and add a better description of the project also do it';
        final result = parseTasks(input);

        expect(result.rawInput, input);
        expect(result.normalizedInput, contains('I need to go to the store.'));
        expect(result.items.length, 4);
        expect(
          result.items.map((item) => item.classification).toList(),
          <ParsedTaskClassification>[
            ParsedTaskClassification.atomicTask,
            ParsedTaskClassification.goal,
            ParsedTaskClassification.atomicTask,
            ParsedTaskClassification.executionSignal,
          ],
        );
        expect(result.items.first.sourceSpan, isNotNull);
      },
    );

    test('builds clean final tasks for the run-on example', () {
      const input =
          'I need to go to the store I need to add more features and add a better description of the project also do it';
      final result = parseTasks(input);
      final finalTitles = result.finalTasks.map((task) => task.title).toList();

      expect(finalTitles, contains('Go to the store'));
      expect(finalTitles, contains('Improve the project description'));
      expect(finalTitles, contains('Plan additional project features'));
      expect(result.signals.executionRequested, isTrue);
      expect(result.signals.ambiguityDetected, isFalse);
    });

    test(
      'keeps a single related concrete child independent when the domain does not match',
      () {
        const input =
            'I need to add more features and add a better description of the project';
        final result = parseTasks(input);

        final featureGoal = result.items[0];
        final descriptionTask = result.items[1];
        expect(featureGoal.classification, ParsedTaskClassification.goal);
        expect(
          descriptionTask.classification,
          ParsedTaskClassification.atomicTask,
        );
        expect(descriptionTask.parentId, isNull);
      },
    );

    test('groups concrete page changes under a broader landing-page goal', () {
      final result = parseTasks(
        'I need to redesign the landing page and update the hero text and replace the screenshot',
      );

      expect(result.items[0].classification, ParsedTaskClassification.goal);
      expect(
        result.items[1].classification,
        ParsedTaskClassification.subtaskCandidate,
      );
      expect(
        result.items[2].classification,
        ParsedTaskClassification.subtaskCandidate,
      );
      expect(result.items[1].parentId, result.items[0].id);
      expect(result.items[2].parentId, result.items[0].id);
      expect(
        result.finalTasks,
        contains(
          predicate<FinalTaskSuggestion>(
            (task) =>
                task.title == 'Update the hero text' &&
                task.parentTitle == 'Redesign the landing page',
          ),
        ),
      );
    });

    test('keeps shopping and work tasks side by side', () {
      final result = parseTasks(
        'Need to buy milk I need to refactor the auth flow then send the invoice',
      );
      final titles = result.finalTasks.map((task) => task.title).toList();

      expect(titles, contains('Buy milk'));
      expect(titles, contains('Refactor the auth flow'));
      expect(titles, contains('Send the invoice'));
    });

    test('surfaces ambiguity when only vague language is present', () {
      final result = parseTasks('handle that and update it');
      expect(result.signals.ambiguityDetected, isTrue);
      expect(result.finalTasks, isEmpty);
    });

    test('handles multiple concrete project tasks joined by and', () {
      final result = parseTasks(
        'I should review the contract and add a better description of the project',
      );
      final titles = result.finalTasks.map((task) => task.title).toList();

      expect(titles, <String>[
        'Review the contract',
        'Improve the project description',
      ]);
    });

    test('dedupes repeated tasks in final output', () {
      final result = parseTasks('Update the roadmap and update the roadmap');
      expect(result.finalTasks.map((task) => task.title).toList(), <String>[
        'Update the roadmap',
      ]);
    });

    test('extracts a soft intent task as a single atomic item', () {
      final result = parseTasks('I should probably exercise');
      expect(result.items, hasLength(1));
      expect(
        result.items.single.classification,
        ParsedTaskClassification.atomicTask,
      );
      expect(result.items.single.normalizedText, 'Exercise');
    });

    test('splits comma separated coordinated actions into final tasks', () {
      final result = parseTasks(
        'I need to go to the store, hang up my clothes, and eat food',
      );
      expect(result.finalTasks.map((task) => task.title).toList(), <String>[
        'Go to the store',
        'Hang up my clothes',
        'Eat food',
      ]);
    });

    test('extracts conditional reminder with pronoun resolution', () {
      final result = parseTasks(
        'when adding the wumbo feature I need to remember to bumbify it',
      );
      expect(result.items, hasLength(1));
      expect(
        result.items.single.classification,
        ParsedTaskClassification.atomicTask,
      );
      expect(result.items.single.normalizedText, 'Bumbify the wumbo feature');
      expect(result.finalTasks.map((task) => task.title).toList(), <String>[
        'Bumbify the wumbo feature',
      ]);
    });

    test('extracts a direct conditional task', () {
      final result = parseTasks('before shipping, test the login flow');
      expect(result.items, hasLength(1));
      expect(result.items.single.normalizedText, 'Test the login flow');
      expect(
        result.items.single.classification,
        ParsedTaskClassification.atomicTask,
      );
    });

    test('does not over-split descriptive commas', () {
      final result = parseTasks('email John, the manager at work');
      expect(result.items, hasLength(1));
      expect(result.finalTasks, hasLength(1));
      expect(result.finalTasks.single.title, 'Email John, the manager at work');
    });

    test('handles the mixed multiline example end to end', () {
      const input =
          'I need to go to the store, hang up my clothes, and eat food\n'
          'I should probably exercise\n\n'
          'when adding the wumbo feature I need to remember to bumbify it.';
      final result = parseTasks(input);

      expect(result.finalTasks.map((task) => task.title).toList(), <String>[
        'Go to the store',
        'Hang up my clothes',
        'Eat food',
        'Exercise',
        'Bumbify the wumbo feature',
      ]);
    });

    test('merges a but-clause pronoun modifier into the previous task', () {
      final result = parseTasks(
        'I might need to exercise, but I should do it outside',
      );

      expect(result.finalTasks.map((task) => task.title).toList(), <String>[
        'Exercise outside',
      ]);
      expect(result.items.first.normalizedText, 'Exercise outside');
      expect(result.items.last.classification, ParsedTaskClassification.note);
    });

    test('merges a sequence pronoun modifier into the previous task', () {
      final result = parseTasks('Call mom, then do it tonight');

      expect(result.finalTasks.map((task) => task.title).toList(), <String>[
        'Call mom tonight',
      ]);
    });

    test('merges a time modifier introduced by but', () {
      final result = parseTasks('Write the email, but do it after class');

      expect(result.finalTasks.map((task) => task.title).toList(), <String>[
        'Write the email after class',
      ]);
    });

    test('does not merge unsupported manner modifiers', () {
      final result = parseTasks('Fix the bug, but do it better');

      expect(result.finalTasks.map((task) => task.title).toList(), <String>[
        'Fix the bug',
      ]);
      expect(
        result.items.last.classification,
        ParsedTaskClassification.executionSignal,
      );
    });

    test('extracts safe tasks from mixed narrative notes', () {
      const input = '''
          in canvas it says that i should be fine if I don't do that good at a test, but I want to do good at the test.

          I need to take that test.

          I should take a test
          ''';
      final result = parseTasks(input);

      expect(result.finalTasks, isNotEmpty);
      expect(
        result.finalTasks.map((task) => task.title).toList(),
        contains('Take the test'),
      );
      expect(
        result.finalTasks.where((task) => task.title == 'Take the test'),
        hasLength(1),
      );
    });

    test('exposes helper enrichment directly', () {
      expect(suggestSubtasksForGoal('Plan additional features'), <String>[
        'List desired features',
        'Prioritize feature ideas',
        'Implement selected features',
      ]);
    });

    test('serializes to the requested JSON shape', () {
      final json = parseTasks('Buy milk').toJson();
      expect(json['rawInput'], 'Buy milk');
      expect(json['normalizedInput'], 'Buy milk');
      expect((json['items'] as List).single['classification'], 'atomic_task');
      expect((json['signals'] as Map)['executionRequested'], isFalse);
    });
  });
}
