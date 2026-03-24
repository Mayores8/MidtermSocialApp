/// Represents a single user comment in the social media application.
class Comment {
  // These 'final' fields ensure the data is immutable once the object is created.

  /// The display name or handle of the user who wrote the comment.
  final String username;

  /// The actual message content of the comment.
  final String text;

  /// The date and time when the comment was posted.
  final DateTime timestamp;

  /// The constructor uses 'required' named parameters.
  /// This ensures that a Comment cannot be created without all three pieces of data,
  /// preventing null errors in the UI.
  Comment({
    required this.username,
    required this.text,
    required this.timestamp,
  });
}