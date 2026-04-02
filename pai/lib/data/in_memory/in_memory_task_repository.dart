import '../../models/project.dart';
import '../../repositories/task_repository.dart';
import 'in_memory_pai_store.dart';

class InMemoryTaskRepository implements TaskRepository {
  InMemoryTaskRepository(this._store);

  final InMemoryPaiStore _store;

  @override
  Future<void> addTasks(String projectId, List<String> tasks) async {
    final project = _requireProject(projectId);
    final mergedTasks = [...project.nextSteps];
    final existingTasks = {
      for (final task in project.nextSteps) task.toLowerCase(),
    };

    for (final task in tasks) {
      final trimmed = task.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (existingTasks.add(trimmed.toLowerCase())) {
        mergedTasks.add(trimmed);
      }
    }

    _store.saveProject(
      project.copyWith(
        nextSteps: mergedTasks,
        updatedAt: DateTime.now(),
        isDirty: true,
      ),
    );
  }

  @override
  Future<List<String>> listTasks(String projectId) async {
    return List<String>.from(_requireProject(projectId).nextSteps);
  }

  @override
  Future<bool> removeTask(String projectId, String task) async {
    final project = _requireProject(projectId);
    final hasTask = project.nextSteps.contains(task);
    if (!hasTask) {
      return false;
    }

    _store.saveProject(
      project.copyWith(
        nextSteps: [
          for (final nextStep in project.nextSteps)
            if (nextStep != task) nextStep,
        ],
        updatedAt: DateTime.now(),
        isDirty: true,
      ),
    );
    return true;
  }

  Project _requireProject(String projectId) {
    final project = _store.projectById(projectId);
    if (project == null) {
      throw StateError('Missing project for id $projectId');
    }

    return project;
  }
}
