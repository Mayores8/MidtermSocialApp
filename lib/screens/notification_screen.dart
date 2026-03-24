import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import 'artist_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// NotificationScreen widget displays user's notifications
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> notifications = []; // Stores notifications fetched
  bool isLoading = true; // Tracks loading state

  @override
  void initState() {
    super.initState();
    _loadNotifications(); // Load notifications when screen initializes
  }

  // Subscribe to real-time notifications stream from ApiService
  void _loadNotifications() {
    ApiService.getNotificationsStream().listen((notifs) {
      if (mounted) {
        setState(() {
          notifications = notifs; // Update local list
          isLoading = false;      // Done loading
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: () async {
              // Mark all unread notifications as read
              for (var notif in notifications.where((n) => !(n['read'] ?? true))) {
                await ApiService.markNotificationRead(notif['id']);
              }
            },
            child: const Text("Mark all read", style: TextStyle(color: Colors.pink)),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: Colors.white10),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pink)) // Show loader
          : notifications.isEmpty
          ? const Center(
        child: Text(
          "No notifications yet",
          style: TextStyle(color: Colors.grey),
        ),
      )
          : ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return _buildNotificationItem(notif); // Build each notification
        },
      ),
    );
  }

  // Build individual notification item
  Widget _buildNotificationItem(Map<String, dynamic> notif) {
    final bool isRead = notif['read'] ?? false; // Track if read
    final String type = notif['type'] ?? 'post'; // Type of notification

    // Determine icon and color based on type
    IconData icon;
    Color color;
    switch (type) {
      case 'like':
        icon = Icons.favorite;
        color = Colors.red;
        break;
      case 'comment':
        icon = Icons.comment;
        color = Colors.blue;
        break;
      case 'follow':
        icon = Icons.person_add;
        color = Colors.green;
        break;
      case 'post':
        icon = Icons.post_add;
        color = Colors.pink;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return Dismissible(
      key: Key(notif['id']),
      background: Container(color: Colors.red, child: const Icon(Icons.delete)),
      onDismissed: (_) {
        // Delete notification from Firestore on swipe
        FirebaseFirestore.instance
            .collection('notifications')
            .doc(notif['id'])
            .delete();
      },
      child: ListTile(
        tileColor: isRead ? null : Colors.white.withOpacity(0.05), // Highlight if unread
        leading: Stack(
          children: [
            // Sender avatar
            CircleAvatar(
              backgroundImage: NetworkImage(notif['senderImage'] ?? ''),
            ),
            // Small icon indicating type
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 10, color: Colors.white),
              ),
            ),
          ],
        ),
        // Notification text
        title: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            children: [
              TextSpan(
                text: notif['senderName'] ?? 'User',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: ' ${notif['message'] ?? ''}'),
            ],
          ),
        ),
        // Time since notification
        subtitle: Text(
          _formatTime(notif['createdAt']),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        onTap: () {
          // Mark notification as read
          if (!isRead) {
            ApiService.markNotificationRead(notif['id']);
          }

          // Navigate or show content depending on type
          if (type == 'post' && notif['postId'] != null) {
            _showPostPopup(notif['postId']); // Show post popup
          } else if (type == 'follow') {
            // Navigate to artist profile
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (c) => ArtistProfileScreen(
                  artistName: notif['senderName'],
                  image: notif['senderImage'] ?? '',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  // Format Firestore Timestamp into relative time string
  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = (timestamp as Timestamp).toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // Show a post inside a draggable bottom sheet
  void _showPostPopup(String postId) async {
    // Fetch post document from Firestore
    final doc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .get();

    if (doc.exists && mounted) {
      final post = ApiService.postFromDoc(doc); // Convert doc to Post model
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF121212),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // Small handle at the top
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "New Post",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  PostCard(post: post), // Display post content
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      );
    }
  }
}