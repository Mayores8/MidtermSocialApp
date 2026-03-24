import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a comment made by a user on a post.
class Comment {
  final String id;        // Unique identifier for the comment (usually from Firestore)
  final String username;  // The name of the user who posted the comment
  final String text;      // The actual message content
  final DateTime time;    // When the comment was created
  final String? userId;   // Optional ID of the user (useful for linking to profiles)

  Comment({
    this.id = '',
    required this.username,
    required this.text,
    required this.time,
    this.userId,
  });

  /// Factory constructor to create a Comment object from a Firestore document.
  /// This bridges the gap between raw database data and structured Dart objects.
  factory Comment.fromFirestore(DocumentSnapshot doc) {
    // Convert document data to a Map
    final data = doc.data() as Map<String, dynamic>;

    return Comment(
      id: doc.id, // The document ID from Firestore
      username: data['username'] ?? 'User', // Fallback to 'User' if name is missing
      text: data['text'] ?? '',
      // Firestore stores dates as 'Timestamp', so we convert it to Dart's 'DateTime'
      time: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: data['userId'],
    );
  }
}

/// Represents a social media post containing media, user info, and engagement stats.
class Post {
  // --- Identification & User Info ---
  final String id;
  final String userId;
  final String username;
  final String profilePic;
  final String bio;
  final bool isVerified;

  // --- Post Content ---
  final String timestamp; // String representation of time (e.g., "2 hours ago")
  final String imageUrl;
  final String videoUrl;
  final String audioName;
  final String caption;
  final bool isVideo;
  final List<String> gridImages; // Used if the post has a gallery/grid of images

  // --- Stats (Likes, Comments, Shares) ---
  // Some are 'int' for counts, others are 'bool' to track the current user's interaction
  int likes;
  bool isLiked;       // Mutable: changes when the user taps the heart icon
  bool isBookmarked;  // Mutable: changes when the user saves the post
  final int comments;
  final int shares;

  // --- Profile/Account Details ---
  final String debut;
  final String agency;
  final String postCount;
  final String followersCount;
  final String followingCount;

  // --- Sharing/Republishing Logic ---
  final bool isShared;
  final String? originalPostId;   // Links to the source if this is a shared post
  final String? originalUsername;

  // --- Lists & Metadata ---
  List<Comment> commentList; // A list of Comment objects associated with this post
  final DateTime? createdAt; // Raw date object for sorting logic

  Post({
    required this.id,
    this.userId = '',
    required this.username,
    required this.profilePic,
    required this.timestamp,
    required this.imageUrl,
    required this.caption,
    this.bio = '',
    this.debut = '',
    this.agency = '',
    this.postCount = '',
    this.followersCount = '0',
    this.followingCount = '0',
    this.gridImages = const [],
    this.videoUrl = '',
    this.audioName = 'Original Audio',
    this.isVerified = true,
    required this.likes,
    this.isLiked = false,
    this.isBookmarked = false,
    required this.comments,
    required this.shares,
    this.isVideo = false,
    this.isShared = false,
    this.originalPostId,
    this.originalUsername,
    List<Comment>? commentList,
    this.createdAt,
  }) : commentList = commentList ?? [];
// The line above (Initializer List) ensures that if no comments are provided,
// the list is initialized as an empty array instead of being null.
}