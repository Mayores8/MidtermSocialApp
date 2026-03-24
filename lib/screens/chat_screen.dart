import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A real-time chat interface between the current user and an artist.
class ChatScreen extends StatefulWidget {
  final String artistName;
  final String? conversationId; // Provided if coming from a "Recent Chats" list
  final String? otherUserId;    // Provided if starting a chat from a profile

  const ChatScreen({
    super.key,
    required this.artistName,
    this.conversationId,
    this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Controllers for handling text input and list scrolling
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> messages = [];
  String? conversationId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  /// Determines which conversation to load based on passed parameters
  Future<void> _initializeChat() async {
    // 1. If we already have a conversation ID, use it directly
    if (widget.conversationId != null) {
      conversationId = widget.conversationId;
      _loadMessages();
    }
    // 2. If we only have a User ID, find an existing chat or create a new one in Firestore
    else if (widget.otherUserId != null) {
      conversationId = await ApiService.getOrCreateConversation(widget.otherUserId!);
      _loadMessages();
    }
    // 3. Fallback for mock/demo purposes
    else {
      setState(() => isLoading = false);
    }
  }

  /// Sets up a real-time listener (Stream) for messages in this conversation
  void _loadMessages() {
    if (conversationId == null) return;

    // Listen to the stream from ApiService. When Firestore updates, this code runs again.
    ApiService.getMessagesStream(conversationId!).listen((msgs) {
      if (mounted) {
        setState(() {
          messages = msgs;
          isLoading = false;
        });
        // Auto-scroll to the latest message whenever a new one arrives
        _scrollToBottom();
      }
    });
  }

  /// Smoothly scrolls the message list to the very bottom
  void _scrollToBottom() {
    // We use a post-frame callback or delay to ensure the list has finished rendering
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Validates input and sends the message to Firestore via ApiService
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || conversationId == null) return;

    final text = _messageController.text;
    _messageController.clear(); // Clear input immediately for better UX

    await ApiService.sendMessage(conversationId!, text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${widget.artistName}'),
            ),
            const SizedBox(width: 10),
            Text(widget.artistName),
          ],
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {}, // Future: Block user, clear chat, etc.
          ),
        ],
      ),
      body: Column(
        children: [
          // --- MESSAGE LIST AREA ---
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.pink))
                : messages.isEmpty
                ? _buildEmptyState() // Show placeholder if no messages yet
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                // Check if the current user is the sender to align the bubble
                final isMe = msg['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                return _buildBubble(msg['text'] ?? '', isMe, msg['createdAt']);
              },
            ),
          ),

          // --- MESSAGE INPUT AREA ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
            color: Colors.black,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.pink),
                  onPressed: () {}, // Future: Send images or voice notes
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Message...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.pink),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Visual placeholder for new conversations
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            "Start chatting with ${widget.artistName}",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// Builds an individual message bubble with conditional styling
  Widget _buildBubble(String text, bool isMe, dynamic timestamp) {
    // Format Firestore Timestamp into a readable string (e.g., "14:30")
    String timeStr = '';
    if (timestamp != null) {
      final date = (timestamp as Timestamp).toDate();
      timeStr = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }

    return Align(
      // Align right for "Me", left for the "Other Person"
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.pink : Colors.white10,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            // "Tail" of the bubble switches sides based on sender
            bottomLeft: Radius.circular(isMe ? 15 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            if (timeStr.isNotEmpty)
              Text(
                timeStr,
                style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.grey,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}