/// Implemented by a top-level module screen's State so the shell
/// ([TabletShell]) can trigger a silent data reload when the app resumes
/// from the background — without needing to know each screen's internal
/// load-method name. Only the shell's directly-owned rail entries implement
/// this; deeper pushed screens manage their own lifecycle.
/// See ACCESS_CONTROL_AND_DATA_SYNC_PLAN.md Phase 4.
abstract class Refreshable {
  Future<void> refreshSilently();
}
