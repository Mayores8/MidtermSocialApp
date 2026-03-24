import 'dart:ui'; // For ImageFilter.blur used in background filtering
import 'package:flutter/material.dart'; // Flutter UI toolkit
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore
import '../models/post_model.dart'; // Post data model
import '../screens/chat_screen.dart'; // Chat screen
import '../screens/artist_profile_screen.dart'; // Artist profile screen
import '../services/api_service.dart'; // Backend API service
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Authentication

// Widget for displaying artist profile in a dialog
class ArtistProfileDialog extends StatefulWidget {
  final Post post; // Post object containing artist info
  final String? heroTag; // Optional hero tag for animation

  const ArtistProfileDialog({
    super.key,
    required this.post,
    this.heroTag,
  });

  @override
  State<ArtistProfileDialog> createState() => _ArtistProfileDialogState();
}

class _ArtistProfileDialogState extends State<ArtistProfileDialog> {
  bool isFollowing = false; // Track follow status
  bool isLoading = true; // Track loading state
  Map<String, dynamic>? artistData; // Artist info from Firestore
  int followersCount = 0;
  int followingCount = 0;
  int postCount = 0;
  List<Post> recentPosts = []; // List of recent posts by artist

  @override
  void initState() {
    super.initState();
    // Check if current user follows this artist
    isFollowing = ApiService.followedArtists.contains(widget.post.username);
    _loadArtistData(); // Load artist info
  }

  Future<void> _loadArtistData() async {
    // Search for artist in Firestore by fullName
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('fullName', isEqualTo: widget.post.username)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      // If found, set artist data and follower/following/post counts
      final data = query.docs.first.data();
      setState(() {
        artistData = data;
        followersCount = (data['followers'] as List?)?.length ?? 0;
        followingCount = (data['following'] as List?)?.length ?? 0;
        postCount = data['postCount'] ?? 0;
        isLoading = false;
      });
    } else {
      // Fallback: extract counts from post data by parsing string numbers
      setState(() {
        followersCount = int.tryParse(widget.post.followersCount.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        followingCount = int.tryParse(widget.post.followingCount.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        postCount = int.tryParse(widget.post.postCount.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        isLoading = false;
      });
    }

    // Load recent posts by the artist
    _loadRecentPosts();
  }

  void _loadRecentPosts() {
    // Fetch latest 6 posts by the artist, ordered by creation time
    FirebaseFirestore.instance
        .collection('posts')
        .where('username', isEqualTo: widget.post.username)
        .orderBy('createdAt', descending: true)
        .limit(6)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          // Map documents to Post objects
          recentPosts = snapshot.docs.map((doc) => ApiService.postFromDoc(doc)).toList();
        });
      }
    });
  }

  Future<void> _toggleFollow() async {
    // Toggle follow/unfollow status
    setState(() => isFollowing = !isFollowing);
    await ApiService.toggleFollow(widget.post.username); // Call backend toggle

    // Refresh follower count after toggle
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('fullName', isEqualTo: widget.post.username)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      setState(() {
        followersCount = (data['followers'] as List?)?.length ?? 0;
      });
    }
  }

  Future<void> _startChat() async {
    // Find the user ID of the artist to chat
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('fullName', isEqualTo: widget.post.username)
        .limit(1)
        .get();

    String? otherUserId;
    if (query.docs.isNotEmpty) {
      otherUserId = query.docs.first.id;
    }

    if (mounted) {
      Navigator.pop(context); // Close dialog
      // Navigate to chat screen with artist info
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => ChatScreen(
            artistName: widget.post.username,
            otherUserId: otherUserId,
          ),
        ),
      );
    }
  }

  void _viewFullProfile() {
    // Close dialog and navigate to full profile page
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => ArtistProfileScreen(
          artistName: widget.post.username,
          image: widget.post.profilePic,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use BackdropFilter for blurred background
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hero profile image with gradient overlay and close button
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Stack(
                  children: [
                    // Hero animated profile image
                    Hero(
                      tag: widget.heroTag ?? 'artist-${widget.post.id}',
                      child: Image.network(
                        widget.post.profilePic,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Show placeholder if image fails
                          return Container(
                            height: 200,
                            color: Colors.grey[300],
                            child: const Icon(Icons.person, size: 80, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                    // Gradient overlay for visual effect
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Close button at top right
                    Positioned(
                      top: 10,
                      right: 10,
                      child: CircleAvatar(
                        backgroundColor: Colors.black38,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    // Verified badge if artist is verified
                    if (widget.post.isVerified)
                      const Positioned(
                        bottom: 10,
                        right: 10,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.check, color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
              ),

              // Main content below image
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Animate the username appearance
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        widget.post.username,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Show bio if available
                    if (artistData?['bio'] != null || widget.post.bio.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          artistData?['bio'] ?? widget.post.bio,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Stats row for posts, followers, following
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatColumn(
                          _formatCount(postCount),
                          'Posts',
                          Icons.grid_on,
                        ),
                        _buildDivider(),
                        _buildStatColumn(
                          _formatCount(followersCount),
                          'Followers',
                          Icons.people_outline,
                        ),
                        _buildDivider(),
                        _buildStatColumn(
                          _formatCount(followingCount),
                          'Following',
                          Icons.person_outline,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Recent posts preview
                    if (recentPosts.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Recent Posts',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Horizontal list of recent post thumbnails
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: recentPosts.length > 3 ? 3 : recentPosts.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                // Show post detail if needed
                              },
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: NetworkImage(recentPosts[index].imageUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Follow and message buttons
                    Row(
                      children: [
                        // Follow button with animated style
                        Expanded(
                          flex: 2,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: ElevatedButton(
                              onPressed: _toggleFollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing ? Colors.grey[200] : Colors.black,
                                foregroundColor: isFollowing ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isFollowing ? Icons.check : Icons.add,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isFollowing ? 'Following' : 'Follow',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Chat button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _startChat,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Icon(Icons.chat_bubble_outline, size: 18),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // View full profile button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _viewFullProfile,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.black12),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View Full Profile',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget to build stats columns
  Widget _buildStatColumn(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.pink, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Helper widget for divider between stats
  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey[300],
    );
  }

  // Helper to format large counts into K/M
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

// Extension on ApiService to convert DocumentSnapshot to Post object
extension PostConversion on ApiService {
  static Post postFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final currentUser = FirebaseAuth.instance.currentUser;

    // Extract likes and bookmarks as string lists
    final likes = List<String>.from(data['likes'] ?? []);
    final bookmarks = List<String>.from(data['bookmarks'] ?? []);

    // Determine if current user liked or bookmarked
    final isLiked = currentUser != null && likes.contains(currentUser.uid);
    final isBookmarked = currentUser != null && bookmarks.contains(currentUser.uid);

    // Return Post object with data
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      profilePic: data['profilePic'] ?? '',
      timestamp: _formatTimestamp(data['createdAt']),
      imageUrl: data['imageUrl'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      audioName: data['audioName'] ?? 'Original Audio',
      caption: data['caption'] ?? '',
      bio: data['bio'] ?? '',
      debut: data['debut'] ?? '',
      agency: data['agency'] ?? '',
      postCount: data['postCount']?.toString() ?? '0',
      followersCount: data['followersCount']?.toString() ?? '0',
      followingCount: data['followingCount']?.toString() ?? '0',
      gridImages: List<String>.from(data['gridImages'] ?? []),
      isVerified: data['isVerified'] ?? true,
      likes: likes.length,
      isLiked: isLiked,
      isBookmarked: isBookmarked,
      comments: data['commentsCount'] ?? 0,
      shares: data['sharesCount'] ?? 0,
      isVideo: data['isVideo'] ?? false,
      commentList: [],
    );
  }

  static String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'now';
    final date = (timestamp as Timestamp).toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.month}/${date.day}';
  }
}