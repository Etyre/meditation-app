/// Logs the session block as a Toggl Track time entry.
abstract class TogglService {
  /// Returns true on success. [projectId] of 0 means no project.
  Future<bool> logTimeEntry({
    required DateTime start,
    required DateTime stop,
    required String description,
    int projectId = 0,
  });
}
