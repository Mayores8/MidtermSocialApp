import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For picking images from gallery
import 'dart:io'; // For handling file paths
import 'package:flutter/foundation.dart' show kIsWeb; // For detecting web platform
import '../widgets/post_card.dart'; // Widget for displaying individual posts
import '../models/post_model.dart'; // Post model class
import '../services/api_service.dart'; // API service for fetching posts
import 'story_screen.dart'; // Story viewing screen
import 'message_screen.dart'; // Messaging screen
import 'notification_screen.dart'; // Notification screen
import '../main.dart'; // For accessing global state (like isDarkMode)

// Stateful widget for the main home feed
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); // For controlling scaffold (drawer, etc.)
  final ImagePicker _picker = ImagePicker(); // For picking story images
  List<Post> feedPosts = []; // List of posts to show in the feed
  bool isLoading = true; // Flag to show loading indicator
  String? errorMessage; // Stores error message if posts fail to load

  // Hardcoded story artists for demo purposes
  final List<Map<String, String>> storyArtists = [
    {'name': 'Sana_Twice', 'img': 'https://tse1.mm.bing.net/th/id/OIP.W3CG3nj8dlpLtB-ReRLsqgHaNK?rs=1&pid=ImgDetMain'},
    {'name': 'Hani_NJ', 'img': 'https://tse1.mm.bing.net/th/id/OIP.RKwhLs1w6_yyO1o0JPxD8gHaNK?rs=1&pid=ImgDetMain&o=7&rm=3'},
    {'name': 'Lisa_BP', 'img': 'https://wallpapers.com/images/hd/2019-monshoot-mood-korea-lisa-blackpink-hd-a1iqfriyi4palj94.jpg'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPosts(); // Load feed posts on widget initialization
  }

  // Function to load posts using ApiService stream
  void _loadPosts() {
    setState(() {
      isLoading = true; // Show loader
      errorMessage = null; // Clear any previous errors
    });

    ApiService.getPostsStream().listen((posts) {
      if (mounted) {
        setState(() {
          feedPosts = posts; // Update feed posts
          isLoading = false; // Stop loading
        });
      }
    }, onError: (error) {
      print('HomeScreen error loading posts: $error');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load posts: $error'; // Show error message
          isLoading = false; // Stop loading
        });
      }
    });
  }

  // Function to pick a story image from gallery
  Future<void> _pickStoryImage() async {
    final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80
    );
    if (image != null) {
      setState(() {
        storyArtists.insert(0, {'name': 'Your Story', 'img': image.path}); // Add new story at beginning
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Story uploaded!"),
            backgroundColor: Colors.pink
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to global dark mode notifier
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, darkMode, child) {
        final Color themeColor = darkMode ? Colors.white : Colors.black;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: darkMode ? Colors.black : Colors.white,
          appBar: AppBar(
            backgroundColor: darkMode ? Colors.black : Colors.white,
            elevation: 0,
            title: Text(
              'K-STAR',
              style: TextStyle(
                color: darkMode ? const Color(0xFFE91E63) : Colors.pink,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            actions: [
              // Toggle dark mode button
              IconButton(
                icon: Icon(darkMode ? Icons.light_mode : Icons.dark_mode, color: themeColor),
                onPressed: () => isDarkMode.value = !isDarkMode.value,
              ),
              // Navigate to messages
              IconButton(
                icon: Icon(Icons.chat_bubble_outline, color: themeColor),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const MessageScreen())
                ),
              ),
              // Navigate to notifications
              IconButton(
                icon: Icon(Icons.notifications_none, color: themeColor),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const NotificationScreen())
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              _loadPosts(); // Reload posts on pull-to-refresh
              await Future.delayed(const Duration(seconds: 1)); // Small delay for smooth UI
            },
            color: Colors.pink,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Stories section
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: storyArtists.length + 1, // +1 for "Add Story" button
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildAddButton(themeColor); // First item is Add button
                        return _buildStoryCircle(index - 1, themeColor, darkMode); // Other items are story circles
                      },
                    ),
                  ),
                  Divider(color: darkMode ? Colors.white10 : Colors.black.withOpacity(0.1)),

                  // Feed section with different states
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.pink), // Loading spinner
                      ),
                    )
                  else if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadPosts, // Retry loading posts
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (feedPosts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.no_photography, color: Colors.grey, size: 48),
                              SizedBox(height: 16),
                              Text(
                                "No posts yet.\nFollow artists to see their posts!",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                    // Display feed posts
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: feedPosts.length,
                        itemBuilder: (context, index) => PostCard(
                            post: feedPosts[index]
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Add story button widget
  Widget _buildAddButton(Color textColor) {
    return GestureDetector(
      onTap: _pickStoryImage, // Pick story from gallery
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  child: const Icon(Icons.person, color: Colors.grey, size: 35),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle
                    ),
                    child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.blueAccent,
                        child: Icon(Icons.add, color: Colors.white, size: 14)
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Add Story', style: TextStyle(color: textColor, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // Story circle widget for each artist
  Widget _buildStoryCircle(int index, Color textColor, bool darkMode) {
    final artist = storyArtists[index];
    final bool isMyStory = artist['name'] == 'Your Story';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryScreen(
              artistName: artist['name']!,
              image: artist['img']!,
              onDelete: () {
                setState(() => storyArtists.removeAt(index)); // Delete story
              },
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: isMyStory
                        ? [Colors.blue, Colors.cyan]
                        : [Colors.pink, Colors.orange]
                ),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundImage: artist['img']!.startsWith('http')
                    ? NetworkImage(artist['img']!) // Network image for online stories
                    : (kIsWeb ? NetworkImage(artist['img']!) : FileImage(File(artist['img']!))) as ImageProvider, // Local file for personal stories
              ),
            ),
            const SizedBox(height: 4),
            Text(artist['name']!, style: TextStyle(color: textColor, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}