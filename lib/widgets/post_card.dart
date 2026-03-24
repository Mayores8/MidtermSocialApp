import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';
import 'artist_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final bool showShareOptions;

  const PostCard({
    super.key,
    required this.post,
    this.showShareOptions = true,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  String? selectedReaction;
  int reactionCount = 0;
  bool reacted = false;
  bool isBookmarked = false;
  List<Comment> comments = [];

  // Mapping of reactions to their emoji
  final Map<String, String> reactions = {
    "like": "👍",
    "love": "❤️",
    "haha": "😂",
    "wow": "😮",
    "sad": "😢",
    "angry": "😡",
  };

  @override
  void initState() {
    super.initState();
    reactionCount = widget.post.likes;
    reacted = widget.post.isLiked;
    isBookmarked = widget.post.isBookmarked;
    selectedReaction = reacted ? "love" : null;

    // Load comments from API/Firestore
    _loadComments();
  }

  // Listen for comment updates for this post
  void _loadComments() {
    ApiService.getCommentsStream(widget.post.id).listen((commentList) {
      if (mounted) {
        setState(() {
          comments = commentList;
        });
      }
    });
  }

  // Handle reactions (like, love, etc.)
  void react(String reaction) async {
    final wasLiked = reacted;
    setState(() {
      if (!reacted) {
        reactionCount++;
        reacted = true;
      } else if (selectedReaction == reaction) {
        reactionCount--;
        reacted = false;
        selectedReaction = null;
      } else {
        selectedReaction = reaction;
      }
    });

    await ApiService.toggleLike(widget.post.id, wasLiked);
  }

  // Show reaction selection sheet
  void showReactions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(10),
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: reactions.entries.map((entry) {
              return GestureDetector(
                onTap: () {
                  react(entry.key);
                  Navigator.pop(context);
                },
                child: Text(entry.value, style: const TextStyle(fontSize: 32)),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Open the comments section
  void _openComments() {
    final TextEditingController controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: 400,
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Header with total comments count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Comments",
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${comments.length} comments",
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // List of comments
                    Expanded(
                      child: comments.isEmpty
                          ? const Center(
                        child: Text(
                          "No comments yet\nBe the first to comment!",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                          : ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final c = comments[index];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundImage: NetworkImage(
                                  'https://i.pravatar.cc/150?u=${c.username}'),
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
                            trailing: Text(
                              _formatTime(c.time),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    // Comment input field
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: "Write a comment...",
                              hintStyle: TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white10,
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.all(Radius.circular(20)),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.pink),
                          onPressed: () async {
                            if (controller.text.trim().isEmpty) return;

                            await ApiService.addComment(
                                widget.post.id, controller.text.trim());

                            controller.clear();
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Format comment/post time
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  // Share post options
  void _sharePost() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Share",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.send, color: Colors.blue),
                title: const Text("Send to friends",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showSendToFriends();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link, color: Colors.green),
                title: const Text("Copy link",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Link copied to clipboard!")),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Dummy friends list modal
  void _showSendToFriends() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (context) => const Center(
        child:
        Text("Friends list coming soon!", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // Format likes count (K/M)
  String formatLikes(int likes) {
    if (likes >= 1000000) {
      return "${(likes / 1000000).toStringAsFixed(1)}M";
    }
    if (likes >= 1000) {
      return "${(likes / 1000).toStringAsFixed(1)}K";
    }
    return likes.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post header with profile pic, username, timestamp, and burger menu
        ListTile(
          leading: GestureDetector(
            onTap: () => _openDialog(context),
            child: CircleAvatar(
              backgroundImage: NetworkImage(widget.post.profilePic),
            ),
          ),
          title: GestureDetector(
            onTap: () => _openDialog(context),
            child: Row(
              children: [
                Text(
                  widget.post.username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                if (widget.post.isVerified)
                  const Icon(Icons.verified, size: 14, color: Colors.blue),
                Text(
                  ' • ${widget.post.timestamp}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          // Burger menu with delete functionality
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) async {
              if (value == 'delete') {
                // Call API to delete the post
                await ApiService.deletePost(widget.post.id);

                // Show confirmation message
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Post deleted")),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ),

        // If the post is shared, show original username
        if (widget.post.isShared && widget.post.originalUsername != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              "Shared from @${widget.post.originalUsername}",
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        // Post image
        Image.network(
          widget.post.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: widget.post.isVideo ? 500 : 350,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 350,
              color: Colors.black12,
              child: const Center(child: Icon(Icons.image_not_supported)),
            );
          },
        ),

        // Reaction buttons row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => react("love"),
                onLongPress: showReactions,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    selectedReaction != null
                        ? reactions[selectedReaction]!
                        : "🤍",
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(formatLikes(reactionCount)),
              IconButton(
                icon: const Icon(Icons.mode_comment_outlined),
                onPressed: _openComments,
              ),
              Text('${comments.length}'),
              if (widget.showShareOptions)
                IconButton(
                  icon: const Icon(Icons.send_outlined),
                  onPressed: _sharePost,
                ),
              const Spacer(),
              // Bookmark toggle
              IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked ? Colors.amber : Colors.white,
                ),
                onPressed: () async {
                  setState(() => isBookmarked = !isBookmarked);
                  await ApiService.toggleBookmark(widget.post.id, !isBookmarked);
                },
              ),
            ],
          ),
        ),

        // Post caption
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.post.caption,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),

        const SizedBox(height: 15),
        const Divider(color: Colors.white10, height: 1),
      ],
    );
  }

  // Open artist profile dialog
  void _openDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ArtistProfileDialog(post: widget.post),
    );
  }
}