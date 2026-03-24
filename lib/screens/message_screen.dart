import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For picking/taking images
import '../main.dart'; // For global dark mode state
import 'chat_screen.dart'; // Navigate to individual chat
import '../services/api_service.dart'; // Fetch conversations
import 'package:firebase_auth/firebase_auth.dart'; // Current user info
import 'package:cloud_firestore/cloud_firestore.dart'; // Timestamp handling

// Stateful widget for the Messages screen
class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  String myNote = "Your note"; // User’s personal note
  File? _quickSnapImage; // Stores the image from QuickSnap
  final ImagePicker _picker = ImagePicker(); // Image picker instance
  List<Map<String, dynamic>> conversations = []; // Stores conversations

  @override
  void initState() {
    super.initState();
    _loadConversations(); // Load conversations on init
  }

  // Listen to real-time conversation updates
  void _loadConversations() {
    ApiService.getConversationsStream().listen((convos) {
      if (mounted) {
        setState(() => conversations = convos);
      }
    });
  }

  // Take a quick snap with the front camera
  Future<void> _takeQuickSnap() async {
    final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front
    );
    if (photo != null) setState(() => _quickSnapImage = File(photo.path));
  }

  // Show a dialog for editing the user note
  void _showNoteDialog() {
    TextEditingController controller = TextEditingController(
        text: myNote == "Your note" ? "" : myNote
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode.value ? const Color(0xFF1A1A1A) : Colors.white,
        title: Text("Share a thought",
            style: TextStyle(color: isDarkMode.value ? Colors.white : Colors.black)),
        content: TextField(
          controller: controller,
          maxLength: 60,
          autofocus: true,
          style: TextStyle(color: isDarkMode.value ? Colors.white : Colors.black),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")
          ),
          ElevatedButton(
            onPressed: () {
              // Update note or reset to default if empty
              setState(() => myNote = controller.text.isEmpty ? "Your note" : controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: const Text("Share"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode, // Reacts to dark mode changes
      builder: (context, darkMode, child) {
        final Color themeColor = darkMode ? Colors.white : Colors.black;

        return Scaffold(
          backgroundColor: darkMode ? Colors.black : Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: themeColor),
            title: const Text('K-STAR MESSAGES',
                style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
          ),
          body: Column(
            children: [
              // Top horizontal list for QuickSnap and Notes
              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    _buildQuickSnapItem(themeColor), // QuickSnap camera
                    GestureDetector(
                        onTap: _showNoteDialog,
                        child: _buildNoteItem(myNote, "https://i.pravatar.cc/150?u=me", true, themeColor)
                    ),
                    // Example notes from other users
                    _buildNoteItem("Feeling hyped!", "https://i.pravatar.cc/150?u=1", false, themeColor),
                    _buildNoteItem("aespa is back!", "https://i.pravatar.cc/150?u=2", false, themeColor),
                  ],
                ),
              ),

              // Search bar for chats
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  style: TextStyle(color: themeColor),
                  decoration: InputDecoration(
                    hintText: 'Search chats...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: darkMode ? Colors.white10 : Colors.black12,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none
                    ),
                  ),
                ),
              ),

              // List of conversations
              Expanded(
                child: conversations.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 60, color: themeColor.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(
                        "No messages yet",
                        style: TextStyle(color: themeColor.withOpacity(0.5)),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final convo = conversations[index];
                    return _buildConversationItem(convo, themeColor);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Build each conversation item in the list
  Widget _buildConversationItem(Map<String, dynamic> convo, Color textColor) {
    final currentUser = FirebaseAuth.instance.currentUser;
    // Determine the other participant
    final otherUserId = (convo['participants'] as List)
        .firstWhere((id) => id != currentUser?.uid, orElse: () => '');
    final names = convo['participantNames'] as Map<String, dynamic>? ?? {};
    final images = convo['participantImages'] as Map<String, dynamic>? ?? {};
    final otherName = names[otherUserId] ?? 'User';
    final otherImage = images[otherUserId] ?? 'https://i.pravatar.cc/150?u=$otherUserId';
    final lastMessage = convo['lastMessage'] ?? '';
    final unread = (convo['unreadCount'] as Map<String, dynamic>?)?[currentUser?.uid] ?? 0;

    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => ChatScreen(
            artistName: otherName,
            conversationId: convo['id'],
          ),
        ),
      ),
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(otherImage),
      ),
      title: Row(
        children: [
          Text(otherName,
              style: TextStyle(
                  color: textColor,
                  fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal
              )),
          const Spacer(),
          Text(
            _formatTime(convo['lastMessageTime']),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread > 0 ? textColor : Colors.grey,
          fontSize: 14,
          fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      // Show unread message count badge
      trailing: unread > 0
          ? Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.pink,
          shape: BoxShape.circle,
        ),
        child: Text(
          unread.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      )
          : null,
    );
  }

  // Format timestamp into human-readable time
  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = (timestamp as Timestamp).toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  // QuickSnap camera item
  Widget _buildQuickSnapItem(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          const SizedBox(height: 15),
          GestureDetector(
            onTap: _takeQuickSnap, // Open camera
            child: Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.pink, width: 2),
                image: _quickSnapImage != null
                    ? DecorationImage(image: FileImage(_quickSnapImage!), fit: BoxFit.cover)
                    : null,
                color: Colors.grey.withOpacity(0.2),
              ),
              child: _quickSnapImage == null
                  ? Icon(Icons.camera_alt, color: color, size: 28)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text("QuickSnap", style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
        ],
      ),
    );
  }

  // Build a Note item for horizontal list
  Widget _buildNoteItem(String text, String img, bool isMe, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          const SizedBox(height: 15),
          Stack(
            alignment: Alignment.topCenter,
            children: [
              CircleAvatar(radius: 30, backgroundImage: NetworkImage(img)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.black, fontSize: 10),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(isMe ? "You" : "User",
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
        ],
      ),
    );
  }
}