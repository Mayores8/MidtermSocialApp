import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';

// Enum representing different reaction types
enum ReactionType { like, love, haha, wow, sad, angry }

// Class to hold reaction data: emoji, label, color, and type
class ReactionData {
  final ReactionType type;
  final String emoji;
  final String label;
  final Color color;

  const ReactionData({
    required this.type,
    required this.emoji,
    required this.label,
    required this.color,
  });
}

class ReactionButton extends StatefulWidget {
  final String postId; // ID of the post or comment
  final String? commentId; // Optional comment ID if reaction is on a comment
  final bool isCompact; // Whether to render in compact mode
  final Function(ReactionType?)? onReactionChanged; // Callback on reaction change
  final int initialCount; // Starting reaction count
  final bool showCount; // Whether to display reaction count

  const ReactionButton({
    super.key,
    required this.postId,
    this.commentId,
    this.isCompact = false,
    this.onReactionChanged,
    this.initialCount = 0,
    this.showCount = true,
  });

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton>
    with TickerProviderStateMixin {
  ReactionType? selectedReaction; // Currently selected reaction
  int reactionCount = 0; // Total reactions count
  bool isHovered = false; // Hover state for reactions bar
  bool isLongPress = false; // Long press state for reactions bar

  // Animation controllers for bounce and scaling effects
  late AnimationController _bounceController;
  late AnimationController _scaleController;
  late AnimationController _reactionsController;

  // List of reactions with emoji, label, color, and type
  final List<ReactionData> reactions = const [
    ReactionData(type: ReactionType.like, emoji: "👍", label: "Like", color: Colors.blue),
    ReactionData(type: ReactionType.love, emoji: "❤️", label: "Love", color: Colors.red),
    ReactionData(type: ReactionType.haha, emoji: "😂", label: "Haha", color: Colors.amber),
    ReactionData(type: ReactionType.wow, emoji: "😮", label: "Wow", color: Colors.orange),
    ReactionData(type: ReactionType.sad, emoji: "😢", label: "Sad", color: Colors.indigo),
    ReactionData(type: ReactionType.angry, emoji: "😡", label: "Angry", color: Colors.redAccent),
  ];

  @override
  void initState() {
    super.initState();

    // Initialize reaction count
    reactionCount = widget.initialCount;

    // Setup animation controllers
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _reactionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Load current user's reaction if exists
    _loadUserReaction();

    // Listen to reactions collection for real-time updates
    _listenToReactions();
  }

  // Load current user's reaction from Firestore
  void _loadUserReaction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = widget.commentId ?? widget.postId;
    final collection = widget.commentId != null ? 'comments' : 'posts';

    final reactionDoc = await FirebaseFirestore.instance
        .collection(collection)
        .doc(docId)
        .collection('reactions')
        .doc(user.uid)
        .get();

    if (reactionDoc.exists && mounted) {
      final data = reactionDoc.data() as Map<String, dynamic>;
      final typeStr = data['type'] as String?;
      setState(() {
        // Map string to ReactionType enum
        selectedReaction = ReactionType.values.firstWhere(
              (e) => e.toString().split('.').last == typeStr,
          orElse: () => ReactionType.like,
        );
      });
    }
  }

  // Listen to real-time reactions collection to update count
  void _listenToReactions() {
    final docId = widget.commentId ?? widget.postId;
    final collection = widget.commentId != null ? 'comments' : 'posts';

    FirebaseFirestore.instance
        .collection(collection)
        .doc(docId)
        .collection('reactions')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          reactionCount = snapshot.docs.length;
        });
      }
    });
  }

  // Save a reaction to Firestore
  Future<void> _saveReaction(ReactionType reaction) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = widget.commentId ?? widget.postId;
    final collection = widget.commentId != null ? 'comments' : 'posts';

    final postRef = FirebaseFirestore.instance.collection(collection).doc(docId);
    final reactionRef = postRef.collection('reactions').doc(user.uid);

    final batch = FirebaseFirestore.instance.batch();

    // If user had a previous reaction, decrement its counter
    if (selectedReaction != null) {
      batch.update(postRef, {
        'reactions.${selectedReaction!.name}': FieldValue.increment(-1),
      });
    }

    // Save new reaction
    batch.set(reactionRef, {
      'userId': user.uid,
      'type': reaction.name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment reaction count for the new reaction
    batch.update(postRef, {
      'reactions.${reaction.name}': FieldValue.increment(1),
      // Optionally, increment total likes if needed
    });

    await batch.commit();

    // Create notification if on a post (not comment)
    if (widget.commentId == null) {
      final post = await postRef.get();
      final postData = post.data() as Map<String, dynamic>?;

      if (postData != null && postData['userId'] != user.uid) {
        // Get emoji for reaction
        final reactionData = reactions.firstWhere((r) => r.type == reaction);
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': postData['userId'], // Post owner
          'senderId': user.uid, // Current user
          'senderName': ApiService.currentUserData?['fullName'] ?? 'User',
          'senderImage': ApiService.currentUserData?['profileImage'] ?? '',
          'type': 'reaction',
          'postId': widget.postId,
          'reactionType': reaction.name,
          'message': 'reacted ${reactionData.emoji} to your post',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // Notify parent widget of reaction change
    if (widget.onReactionChanged != null) {
      widget.onReactionChanged!(reaction);
    }
  }

  // Remove the current reaction
  Future<void> _removeReaction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || selectedReaction == null) return;

    final docId = widget.commentId ?? widget.postId;
    final collection = widget.commentId != null ? 'comments' : 'posts';

    final postRef = FirebaseFirestore.instance.collection(collection).doc(docId);
    final reactionRef = postRef.collection('reactions').doc(user.uid);

    final batch = FirebaseFirestore.instance.batch();

    batch.delete(reactionRef);
    batch.update(postRef, {
      'reactions.${selectedReaction!.name}': FieldValue.increment(-1),
      // Optionally, decrement total likes
    });

    await batch.commit();

    if (widget.onReactionChanged != null) {
      widget.onReactionChanged!(null);
    }
  }

  // Handle tap (like/unlike)
  void _handleTap() {
    if (selectedReaction != null) {
      // Remove reaction
      setState(() {
        selectedReaction = null;
        reactionCount--;
      });
      _removeReaction();
      _bounceController.reverse();
    } else {
      // Default to 'like'
      _selectReaction(ReactionType.like);
    }
  }

  // Select a reaction
  void _selectReaction(ReactionType reaction) {
    final wasSelected = selectedReaction == reaction;

    setState(() {
      if (wasSelected) {
        // Deselect
        selectedReaction = null;
        reactionCount--;
        _removeReaction();
      } else {
        // New reaction
        if (selectedReaction == null) {
          reactionCount++;
        }
        selectedReaction = reaction;
        _saveReaction(reaction);
      }
      isHovered = false;
    });

    // Animate bounce
    _bounceController.forward().then((_) => _bounceController.reverse());
    _reactionsController.reverse();

    // Optional haptic feedback
    // HapticFeedback.lightImpact();
  }

  // Handle long press start to show reactions
  void _onLongPressStart(LongPressStartDetails details) {
    setState(() => isLongPress = true);
    _reactionsController.forward(); // Animate reactions bar
    _scaleController.forward(); // Animate scale effect
  }

  // Handle long press end
  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() => isLongPress = false);
    if (!isHovered) {
      _reactionsController.reverse(); // Hide reactions if not hovered
    }
    _scaleController.reverse(); // Reset scale
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _scaleController.dispose();
    _reactionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      child: AnimatedBuilder(
        animation: _bounceController,
        builder: (context, child) {
          final bounceValue = _bounceController.value;
          final scale = 1.0 + (bounceValue * 0.2);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main reaction button
            _buildMainButton(),

            // Show reactions bar on long press or hover
            if (isLongPress || _reactionsController.value > 0)
              Positioned(
                bottom: widget.isCompact ? 35 : 45,
                left: -20,
                child: AnimatedBuilder(
                  animation: _reactionsController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _reactionsController.value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - _reactionsController.value)),
                        child: child,
                      ),
                    );
                  },
                  child: _buildReactionsBar(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Build the main reaction button
  Widget _buildMainButton() {
    final reaction = selectedReaction != null
        ? reactions.firstWhere((r) => r.type == selectedReaction)
        : null;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCompact ? 8 : 12,
        vertical: widget.isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: selectedReaction != null
            ? reaction!.color.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show selected reaction emoji or thumb icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: selectedReaction != null
                ? Text(
              reaction!.emoji,
              key: ValueKey('emoji-${reaction.type}'),
              style: TextStyle(
                fontSize: widget.isCompact ? 18 : 22,
              ),
            )
                : Icon(
              Icons.thumb_up_outlined,
              key: const ValueKey('like-icon'),
              size: widget.isCompact ? 18 : 22,
              color: Colors.grey[400],
            ),
          ),
          if (widget.showCount) ...[
            const SizedBox(width: 6),
            // Show reaction count with animation
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _formatCount(reactionCount),
                key: ValueKey('count-$reactionCount'),
                style: TextStyle(
                  color: selectedReaction != null
                      ? reactions.firstWhere((r) => r.type == selectedReaction).color
                      : Colors.grey[400],
                  fontSize: widget.isCompact ? 12 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Build the reactions bar with all reactions
  Widget _buildReactionsBar() {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) {
        setState(() => isHovered = false);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!isHovered && mounted) {
            _reactionsController.reverse();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: reactions.asMap().entries.map((entry) {
            final index = entry.key;
            final reaction = entry.value;

            // Animate each reaction icon with delay
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + (index * 50)),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onTap: () => _selectReaction(reaction.type),
                child: MouseRegion(
                  onEnter: (_) => _scaleController.forward(),
                  onExit: (_) => _scaleController.reverse(),
                  child: AnimatedBuilder(
                    animation: _scaleController,
                    builder: (context, child) {
                      final scale = 1.0 + (_scaleController.value * 0.3);
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[100],
                      ),
                      child: Text(
                        reaction.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Helper to format large number counts
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

// A compact version for showing reactions on comments
class CompactReactionButton extends StatelessWidget {
  final String postId;
  final String? commentId;
  final int count;

  const CompactReactionButton({
    super.key,
    required this.postId,
    this.commentId,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ReactionButton(
      postId: postId,
      commentId: commentId,
      isCompact: true,
      initialCount: count,
    );
  }
}

// Widget to display the reactions summary of a post
class ReactionSummary extends StatelessWidget {
  final String postId;

  const ReactionSummary({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('reactions')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink(); // No reactions
        }

        final reactions = snapshot.data!.docs;
        final reactionCounts = <ReactionType, int>{};

        // Count each reaction type
        for (var doc in reactions) {
          final data = doc.data() as Map<String, dynamic>;
          final typeStr = data['type'] as String?;
          if (typeStr != null) {
            final type = ReactionType.values.firstWhere(
                  (e) => e.toString().split('.').last == typeStr,
              orElse: () => ReactionType.like,
            );
            reactionCounts[type] = (reactionCounts[type] ?? 0) + 1;
          }
        }

        // Sort reactions by count descending
        final sortedReactions = reactionCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Row(
          children: [
            // Display top 3 reaction emojis
            Row(
              children: sortedReactions.take(3).map((entry) {
                final reactionData = _getReactionData(entry.key);
                return Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(reactionData.emoji, style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
            ),
            const SizedBox(width: 6),
            // Total reactions count
            Text(
              reactions.length.toString(),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper to get reaction data for a ReactionType
  ReactionData _getReactionData(ReactionType type) {
    final reactions = const [
      ReactionData(type: ReactionType.like, emoji: "👍", label: "Like", color: Colors.blue),
      ReactionData(type: ReactionType.love, emoji: "❤️", label: "Love", color: Colors.red),
      ReactionData(type: ReactionType.haha, emoji: "😂", label: "Haha", color: Colors.amber),
      ReactionData(type: ReactionType.wow, emoji: "😮", label: "Wow", color: Colors.orange),
      ReactionData(type: ReactionType.sad, emoji: "😢", label: "Sad", color: Colors.indigo),
      ReactionData(type: ReactionType.angry, emoji: "😡", label: "Angry", color: Colors.redAccent),
    ];

    return reactions.firstWhere((r) => r.type == type);
  }
}