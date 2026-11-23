// Tiny shared state so push handling knows which Study Group chat is on screen.
class GroupPushState {
  /// Group id of the chat screen currently open, or null.
  static int? openGroupId;
}
