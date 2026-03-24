import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Main NotesScreen widget
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String myNote = "Your note"; // Default note text
  String? selectedMusic;       // Selected music for the note
  File? _quickSnapImage;       // Stores image taken from QuickSnap
  final ImagePicker _picker = ImagePicker(); // ImagePicker instance
  List<Map<String, dynamic>> userNotes = []; // Stores user notes from Firestore
  bool isLoading = true; // Tracks if notes are loading

  // Mock music list for music picker
  final List<Map<String, String>> _mockMusic = [
    {"title": "Armageddon", "artist": "aespa"},
    {"title": "Supernova", "artist": "aespa"},
    {"title": "How Sweet", "artist": "NewJeans"},
    {"title": "Magnetic", "artist": "ILLIT"},
    {"title": "SHEESH", "artist": "BABYMONSTER"},
  ];

  @override
  void initState() {
    super.initState();
    _loadNotes(); // Load notes from Firestore when screen initializes
  }

  // Load user notes from Firestore in real-time
  void _loadNotes() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          // Map Firestore docs to local list
          userNotes = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // Add doc id for reference
            return data;
          }).toList();
          isLoading = false; // Finished loading
        });
      }
    });
  }

  // QuickSnap camera functionality
  Future<void> _takeQuickSnap() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,              // Open camera
        preferredCameraDevice: CameraDevice.front, // Use front camera
      );
      if (photo != null) {
        setState(() => _quickSnapImage = File(photo.path)); // Store image locally
        await _saveNote(); // Save note to Firestore immediately
      }
    } catch (e) {
      // Show error if camera fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error opening camera: $e")),
      );
    }
  }

  // Save note to Firestore
  Future<void> _saveNote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notes')
        .add({
      'text': myNote,                       // Note text
      'music': selectedMusic,               // Optional music
      'hasImage': _quickSnapImage != null,  // Whether a photo exists
      'createdAt': FieldValue.serverTimestamp(), // Timestamp
    });

    // Feedback after saving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Note shared!")),
    );
  }

  // Show bottom sheet to pick music
  void _showMusicPicker(Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Select Music",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          // List of music options
          ..._mockMusic.map((music) => ListTile(
            leading: const Icon(Icons.music_note, color: Colors.pink),
            title: Text(music['title']!, style: const TextStyle(color: Colors.white)),
            subtitle: Text(music['artist']!, style: const TextStyle(color: Colors.white70)),
            onTap: () {
              onSelect("${music['title']} - ${music['artist']}"); // Pass selected music
              Navigator.pop(context); // Close bottom sheet
            },
          )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Show dialog to add/edit a note
  void _showNoteDialog() {
    TextEditingController controller = TextEditingController(text: myNote == "Your note" ? "" : myNote);
    String? tempMusic = selectedMusic; // Temporary music selection

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text("Share a thought", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Note input field
              TextField(
                controller: controller,
                maxLength: 60,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 10),
              // Music picker button
              GestureDetector(
                onTap: () {
                  _showMusicPicker((music) {
                    setDialogState(() => tempMusic = music); // Update music in dialog
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_note, size: 16, color: tempMusic != null ? Colors.pink : Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        tempMusic ?? "Add Music",
                        style: TextStyle(
                          color: tempMusic != null ? Colors.pink : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Dialog actions
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Close dialog
              child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  // Save text and music selection to state
                  myNote = controller.text.isEmpty ? "Your note" : controller.text;
                  selectedMusic = tempMusic;
                });
                await _saveNote(); // Save note to Firestore
                Navigator.pop(context); // Close dialog
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
              child: const Text("Share"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Horizontal Notes & QuickSnap Section
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildQuickSnapItem(), // QuickSnap camera
                GestureDetector(
                  onTap: _showNoteDialog, // Open note dialog
                  child: _buildNoteItem(
                    myNote,
                    "https://i.pravatar.cc/150?u=me",
                    isMe: true,
                    music: selectedMusic,
                  ),
                ),
                // Render notes fetched from Firestore
                ...userNotes.map((note) => _buildNoteItem(
                  note['text'] ?? 'Note',
                  "https://i.pravatar.cc/150?u=${note['id']}",
                  isMe: false,
                  music: note['music'],
                )),
                // Sample static notes
                _buildNoteItem("Feeling hyped!", "https://i.pravatar.cc/150?u=1"),
                _buildNoteItem("Working on K-Star App ✨", "https://i.pravatar.cc/150?u=2"),
                _buildNoteItem("Listen to aespa!", "https://i.pravatar.cc/150?u=3"),
              ],
            ),
          ),
          const Divider(color: Colors.white10),

          // Placeholder for future messages section
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 50),
                  SizedBox(height: 10),
                  Text("Messages will appear here", style: TextStyle(color: Colors.white24)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build QuickSnap camera button widget
  Widget _buildQuickSnapItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          const SizedBox(height: 15),
          GestureDetector(
            onTap: _takeQuickSnap, // Open camera
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.pink, width: 2),
                    image: _quickSnapImage != null
                        ? DecorationImage(image: FileImage(_quickSnapImage!), fit: BoxFit.cover)
                        : null, // Show image if exists
                    color: Colors.white10,
                  ),
                  child: _quickSnapImage == null
                      ? const Icon(Icons.camera_alt, color: Colors.white, size: 28)
                      : null,
                ),
                // Small add/refresh icon at bottom-right
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.pink, shape: BoxShape.circle),
                    child: Icon(
                      _quickSnapImage == null ? Icons.add : Icons.refresh,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "QuickSnap",
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // Build individual note widget
  Widget _buildNoteItem(String text, String imageUrl, {bool isMe = false, String? music}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              // User avatar
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(imageUrl),
                ),
              ),
              Column(
                children: [
                  // Note bubble
                  Container(
                    constraints: const BoxConstraints(maxWidth: 85),
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
                  // Optional music tag
                  if (music != null)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_note, size: 8, color: Colors.white),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              music,
                              style: const TextStyle(color: Colors.white, fontSize: 8),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              // Add icon for current user's note
              if (isMe)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.pink, shape: BoxShape.circle),
                    child: const Icon(Icons.add, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isMe)
            const Text(
              "User",
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
        ],
      ),
    );
  }
}