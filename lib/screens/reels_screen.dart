import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';

// ReelsScreen displays vertical video reels similar to Instagram/TikTok
class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  bool _showFollowingOnly = false; // Tracks which tab is active
  List<Post> reels = []; // List of reels videos
  bool isLoading = true; // Loading state
  String? errorMessage; // Store any error messages

  @override
  void initState() {
    super.initState();
    _loadReels(); // Load reels on initialization
  }

  // Load reels from API service
  void _loadReels() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // Choose stream based on selected tab
    final stream = _showFollowingOnly
        ? ApiService.getFollowingPostsStream()
        : ApiService.getReelsStream();

    stream.listen((posts) {
      if (mounted) {
        setState(() {
          // Filter only posts that are videos
          reels = posts.where((p) => p.isVideo).toList();
          isLoading = false;
        });
      }
    }, onError: (error) {
      print('ReelsScreen error: $error');
      if (mounted) {
        setState(() {
          errorMessage = error.toString();
          isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content area
          if (isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.pink))
          else if (errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading reels',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadReels,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (reels.isEmpty)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_library, color: Colors.grey, size: 64),
                    SizedBox(height: 16),
                    Text(
                      "No reels available",
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Pull down to refresh",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              RefreshIndicator(
                onRefresh: () async {
                  _loadReels(); // Reload reels on pull-to-refresh
                  await Future.delayed(const Duration(seconds: 1));
                },
                color: Colors.pink,
                backgroundColor: Colors.black,
                child: PageView.builder(
                  scrollDirection: Axis.vertical, // Vertical scrolling like reels
                  itemCount: reels.length,
                  itemBuilder: (context, index) {
                    return ReelPlayerItem(
                      post: reels[index],
                      onFollowToggle: () => setState(() {}), // Refresh follow button
                    );
                  },
                ),
              ),

          // Top tabs for "Reels" and "Following"
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTopTab(
                  "Reels",
                  !_showFollowingOnly,
                      () => setState(() {
                    _showFollowingOnly = false;
                    _loadReels(); // Reload reels tab
                  }),
                ),
                const SizedBox(width: 30),
                _buildTopTab(
                  "Following",
                  _showFollowingOnly,
                      () => setState(() {
                    _showFollowingOnly = true;
                    _loadReels(); // Reload following tab
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds a top tab button
  Widget _buildTopTab(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white38,
              fontSize: 18,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 20,
              color: Colors.white,
            ),
        ],
      ),
    );
  }
}

// Single Reel Player Item
class ReelPlayerItem extends StatefulWidget {
  final Post post; // Post to display
  final VoidCallback onFollowToggle; // Callback for follow button
  const ReelPlayerItem({
    super.key,
    required this.post,
    required this.onFollowToggle,
  });

  @override
  State<ReelPlayerItem> createState() => _ReelPlayerItemState();
}

class _ReelPlayerItemState extends State<ReelPlayerItem> {
  late VideoPlayerController _controller; // Video player controller
  bool _isLiked = false;
  bool _isBookmarked = false;
  bool _showPauseIcon = false; // Show overlay pause icon
  bool _isMuted = false;
  int _likeCount = 0;
  int _commentCount = 0;
  List<Comment> _comments = [];
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _isBookmarked = widget.post.isBookmarked;
    _likeCount = widget.post.likes;
    _commentCount = widget.post.comments;

    // Use post video URL, fallback to default if empty
    final videoUrl = widget.post.videoUrl.isNotEmpty
        ? widget.post.videoUrl
        : 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

    // Initialize video player
    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play(); // Auto-play video
          _controller.setLooping(true); // Loop video
        }
      }).catchError((error) {
        print('Error initializing video: $error');
      });

    // Load comments for the post in real-time
    ApiService.getCommentsStream(widget.post.id).listen((comments) {
      if (mounted) {
        setState(() {
          _comments = comments;
          _commentCount = comments.length;
        });
      }
    });
  }

  // Play or pause video
  void _togglePlayPause() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
      _showPauseIcon = true;
    });
    // Hide pause icon after 0.5s
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showPauseIcon = false);
    });
  }

  // Toggle mute
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  // Toggle like status
  Future<void> _toggleLike() async {
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    await ApiService.toggleLike(widget.post.id, wasLiked);
  }

  // Toggle bookmark status
  Future<void> _toggleBookmark() async {
    setState(() => _isBookmarked = !_isBookmarked);
    await ApiService.toggleBookmark(widget.post.id, !_isBookmarked);
  }

  // Show comments in a modal bottom sheet
  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Header row with title and close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Comments",
                        style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Text(
                    "${_comments.length} comments",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  // Comments list
                  Expanded(
                    child: _comments.isEmpty
                        ? const Center(
                      child: Text(
                        "No comments yet",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                        : ListView.builder(
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final c = _comments[index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(
                                'https://i.pravatar.cc/150?u=${c.username}'
                            ),
                          ),
                          title: Text(
                            c.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            c.text,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  // Add comment row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Add a comment...",
                            hintStyle: TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.pink),
                        onPressed: () async {
                          if (_commentController.text.trim().isEmpty) return;
                          await ApiService.addComment(
                              widget.post.id,
                              _commentController.text.trim()
                          );
                          _commentController.clear();
                          setModalState(() {}); // Refresh modal
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isFollowing = ApiService.followedArtists.contains(widget.post.username);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player
        _controller.value.isInitialized
            ? GestureDetector(
          onTap: _togglePlayPause, // Tap to play/pause
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
        )
            : const Center(
          child: CircularProgressIndicator(color: Colors.pink),
        ),

        // Pause/play icon overlay
        if (_showPauseIcon)
          Center(
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _controller.value.isPlaying ? Icons.play_arrow : Icons.pause,
                size: 60,
                color: Colors.white,
              ),
            ),
          ),

        // Bottom info overlay (profile, caption, music, mute)
        Positioned(
          bottom: 25,
          left: 15,
          right: 15,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile picture + username + follow button
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(widget.post.profilePic),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '@${widget.post.username}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            ApiService.toggleFollow(widget.post.username);
                            widget.onFollowToggle();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white),
                              borderRadius: BorderRadius.circular(5),
                              color: isFollowing
                                  ? Colors.transparent
                                  : Colors.pink.withOpacity(0.8),
                            ),
                            child: Text(
                              isFollowing ? 'Following' : 'Follow',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Caption
                    Text(
                      widget.post.caption,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    // Audio info
                    Row(
                      children: [
                        const Icon(
                          Icons.music_note,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.post.audioName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Mute/unmute button
              GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Right side action buttons (like, comment, share, bookmark)
        Positioned(
          right: 15,
          bottom: 100,
          child: Column(
            children: [
              _buildAction(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                label: _formatCount(_likeCount),
                color: _isLiked ? Colors.pink : Colors.white,
                onTap: _toggleLike,
              ),
              _buildAction(
                icon: Icons.chat_bubble_outline,
                label: _formatCount(_commentCount),
                onTap: _showComments,
              ),
              _buildAction(
                icon: Icons.send_outlined,
                label: 'Share',
                onTap: () async {
                  await ApiService.sharePost(widget.post.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Shared!")),
                  );
                },
              ),
              _buildAction(
                icon: _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                label: 'Save',
                color: _isBookmarked ? Colors.amber : Colors.white,
                onTap: _toggleBookmark,
              ),
              const Icon(Icons.more_horiz, color: Colors.white),
            ],
          ),
        ),
      ],
    );
  }

  // Format like/comment counts for display (K/M)
  String _formatCount(int count) {
    if (count >= 1000000) return "${(count / 1000000).toStringAsFixed(1)}M";
    if (count >= 1000) return "${(count / 1000).toStringAsFixed(1)}K";
    return count.toString();
  }

  // Builds individual action button
  Widget _buildAction({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, size: 35, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}