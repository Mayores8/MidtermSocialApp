import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// StoryScreen displays a single story image/video with reactions and replies.
/// Supports likes, emoji reactions, replies, and deleting your own story.
class StoryScreen extends StatefulWidget {
  final String artistName; // Story owner / artist name
  final String image; // Story image path or URL
  final VoidCallback? onDelete; // Callback when the story is deleted

  const StoryScreen({
    super.key,
    required this.artistName,
    required this.image,
    this.onDelete,
  });

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> with SingleTickerProviderStateMixin {
  // Controller for the story progress animation (like Instagram/Snapchat)
  late AnimationController _animationController;

  // Controller and focus for reply input
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Active floating emoji reactions on screen
  final List<Widget> _activeReactions = [];

  bool _isLiked = false; // Track like state
  int _likeCount = 0; // Number of likes
  List<Map<String, dynamic>> _storyReactions = []; // Loaded reactions from Firestore

  @override
  void initState() {
    super.initState();

    // 5-second animation for the progress bar / story duration
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    // Pause story animation when typing a reply
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _animationController.stop();
      } else {
        _animationController.forward();
      }
    });

    // Close story when animation finishes
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.pop(context);
      }
    });

    _animationController.forward(); // Start story animation
    _loadStoryData(); // Load initial story data like reactions
  }

  /// Load reactions and likes from Firestore (only for "Your Story")
  void _loadStoryData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.artistName == 'Your Story') {
      final reactions = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('stories')
          .doc('current')
          .collection('reactions')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _storyReactions = reactions.docs.map((doc) => doc.data()).toList();
        _likeCount = _storyReactions.length;
      });
    }
  }

  /// Send a reply to the story
  void _sendReply() async {
    String message = _replyController.text.trim();
    if (message.isNotEmpty) {
      _replyController.clear();
      _focusNode.unfocus();
      _animationController.forward();

      // Save reply to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('stories')
            .doc(widget.artistName)
            .collection('replies')
            .add({
          'userId': user.uid,
          'text': message,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Show a temporary feedback to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Reply sent to ${widget.artistName}!"),
          backgroundColor: Colors.pinkAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Like or unlike the story
  void _likeStory() async {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final storyRef = FirebaseFirestore.instance.collection('stories').doc(widget.artistName);

      if (_isLiked) {
        await storyRef.collection('likes').doc(user.uid).set({
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await storyRef.collection('likes').doc(user.uid).delete();
      }
    }

    if (_isLiked) _addReaction('❤️'); // Floating heart reaction
  }

  /// Confirm deletion of the story
  void _confirmDelete() {
    _animationController.stop(); // Pause story
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Delete Story?", style: TextStyle(color: Colors.white)),
        content: const Text("This action cannot be undone.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _animationController.forward(); // Resume if canceled
            },
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              // Delete the story document from Firestore
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('stories')
                    .doc('current')
                    .delete();
              }

              Navigator.pop(context); // Close dialog
              if (widget.onDelete != null) widget.onDelete!();
              Navigator.pop(context); // Close story screen
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Adds a floating emoji reaction
  void _addReaction(String emoji) {
    final key = UniqueKey();

    setState(() {
      _activeReactions.add(
        ThreeDReaction(
          key: key,
          emoji: emoji,
          onComplete: () {
            setState(() => _activeReactions.removeWhere((w) => w.key == key));
          },
        ),
      );
    });

    // Save reaction to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('stories')
          .doc(widget.artistName)
          .collection('reactions')
          .add({
        'userId': user.uid,
        'emoji': emoji,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _replyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMyStory = widget.artistName == "Your Story";

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (_focusNode.hasFocus) {
            _focusNode.unfocus();
          } else {
            Navigator.pop(context); // Tap anywhere to close story
          }
        },
        child: Stack(
          children: [
            // -----------------------------
            // Background Image
            // -----------------------------
            Positioned.fill(
              child: widget.image.startsWith('http') || kIsWeb
                  ? Image.network(widget.image, fit: BoxFit.cover)
                  : Image.file(File(widget.image), fit: BoxFit.cover),
            ),

            // -----------------------------
            // Top progress bar
            // -----------------------------
            Positioned(
              top: 50,
              left: 10,
              right: 10,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, _) => LinearProgressIndicator(
                  value: _animationController.value,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  backgroundColor: Colors.white24,
                  minHeight: 2,
                ),
              ),
            ),

            // -----------------------------
            // Animated Reactions Layer
            // -----------------------------
            ..._activeReactions,

            // -----------------------------
            // Header: profile + delete + likes
            // -----------------------------
            Positioned(
              top: 65,
              left: 20,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: widget.image.startsWith('http') || kIsWeb
                            ? NetworkImage(widget.image)
                            : FileImage(File(widget.image)) as ImageProvider,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.artistName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Like button
                      GestureDetector(
                        onTap: _likeStory,
                        child: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.red : Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _likeCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      if (isMyStory)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                          onPressed: _confirmDelete,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // -----------------------------
            // Bottom input and quick reactions
            // -----------------------------
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick emoji reactions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['❤️', '🔥', '😂', '😮', '👏', '😢'].map((emoji) {
                      return GestureDetector(
                        onTap: () => _addReaction(emoji),
                        child: Text(emoji, style: const TextStyle(fontSize: 32)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 15),

                  // Reply input field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          focusNode: _focusNode,
                          onSubmitted: (_) => _sendReply(),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Reply to ${widget.artistName}...",
                            hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                            filled: true,
                            fillColor: Colors.black54,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        backgroundColor: Colors.pinkAccent,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          onPressed: _sendReply,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3D floating emoji animation used for reactions
class ThreeDReaction extends StatefulWidget {
  final String emoji;
  final VoidCallback onComplete;

  const ThreeDReaction({super.key, required this.emoji, required this.onComplete});

  @override
  State<ThreeDReaction> createState() => _ThreeDReactionState();
}

class _ThreeDReactionState extends State<ThreeDReaction> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _randomX;
  late double _randomRotation;
  late double _wobbleSpeed;

  @override
  void initState() {
    super.initState();

    // Randomize initial positions and rotation for 3D effect
    _randomX = (math.Random().nextDouble() * 160) - 80;
    _randomRotation = (math.Random().nextDouble() * 0.6) - 0.3;
    _wobbleSpeed = (math.Random().nextDouble() * 10) + 5;

    // Animation for emoji moving upward
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double progress = _controller.value;
        double opacity = 1.0;
        if (progress < 0.1) opacity = progress * 10; // fade in
        if (progress > 0.8) opacity = (1.0 - progress) * 5; // fade out

        final double wobble = math.sin(progress * _wobbleSpeed) * 20; // side wobble
        double scale = 1.2 + (progress * 0.5); // grow slightly

        return Positioned(
          bottom: 120 + (progress * 550), // move up
          left: (MediaQuery.of(context).size.width / 2) + (_randomX * progress) + wobble - 25,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(_randomRotation * progress)
                ..rotateZ(math.sin(progress * 5) * 0.2)
                ..scale(scale),
              alignment: Alignment.center,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 45)),
            ),
          ),
        );
      },
    );
  }
}