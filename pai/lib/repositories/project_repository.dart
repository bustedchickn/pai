import '../models/board_project.dart';
import '../models/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> listProjects();
  Future<List<BoardProject>> listBoardProjects();
  Future<Project?> getProjectById(String projectId);
  Future<void> createProject({
    required Project project,
    required BoardProject boardProject,
  });
  Future<void> deleteProject(String projectId, {required DateTime deletedAt});
  Future<void> saveProject(Project project);
  Future<void> saveBoardProject(BoardProject boardProject);
}
