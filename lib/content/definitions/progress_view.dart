/// Read-only view of player progress used to evaluate content conditions.
///
/// The runtime `GameState` and the validator's simulated state both implement
/// this interface, so conditions are evaluated identically in both places.
abstract interface class ProgressView {
  bool hasItem(String id);
  bool puzzleSolved(String id);
  int flag(String id);
  bool exitOpen(String id);
  bool examined(String id);
  bool choiceResolved(String id);
  bool visitedRoom(String id);
}
