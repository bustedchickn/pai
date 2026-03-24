abstract class TaskRepository {
  Future<List<String>> listTasks(String projectId);
  Future<void> addTasks(String projectId, List<String> tasks);
  Future<bool> removeTask(String projectId, String task);
}
