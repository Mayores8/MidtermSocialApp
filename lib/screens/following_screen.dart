import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Service for fetching posts from backend
import '../widgets/post_card.dart'; // Widget to display individual posts
import '../main.dart'; // Access global variables, e.g., isDarkMode

// Stateful widget to display posts from accounts the user is following
class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  List<dynamic> followingPosts = []; // Stores posts from followed accounts
  bool isLoading = true; // Flag to show loading indicator while fetching posts

  @override
  void initState() {
    super.initState();
    _loadFollowingPosts(); // Load posts when the screen is initialized
  }

  // Function to fetch following posts using a stream from ApiService
  void _loadFollowingPosts() {
    ApiService.getFollowingPostsStream().listen((posts) {
      if (mounted) { // Ensure widget is still mounted before updating state
        setState(() {
          followingPosts = posts; // Update the list of posts
          isLoading = false; // Stop loading indicator
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen for dark mode changes using a ValueNotifier
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode, // Global notifier for theme mode
      builder: (context, darkMode, child) {
        final Color textColor = darkMode ? Colors.white : Colors.black;

        return Scaffold(
          backgroundColor: darkMode ? Colors.black : Colors.white,
          appBar: AppBar(
            title: const Text(
              'FOLLOWING',
              style: TextStyle(
                  color: Color(0xFFE91E63),
                  fontWeight: FontWeight.bold
              ),
            ),
            backgroundColor: darkMode ? Colors.black : Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor), // Set icon color based on theme
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: textColor), // Refresh icon
                onPressed: () {
                  setState(() => isLoading = true); // Show loading spinner
                  _loadFollowingPosts(); // Reload posts
                },
              ),
            ],
          ),
          body: isLoading
              ? const Center(
            child: CircularProgressIndicator(color: Colors.pink),
          ) // Show spinner while loading
              : followingPosts.isEmpty
              ? _buildEmptyState(textColor) // Show empty state if no posts
              : RefreshIndicator(
            onRefresh: () async {
              _loadFollowingPosts(); // Reload posts on pull-to-refresh
              await Future.delayed(const Duration(seconds: 1)); // Small delay for UI
            },
            color: Colors.pink,
            child: ListView.builder(
              itemCount: followingPosts.length, // Number of posts
              itemBuilder: (context, index) => PostCard(
                  post: followingPosts[index] // Render each post in a PostCard
              ),
            ),
          ),
        );
      },
    );
  }

  // Widget to display when the user is not following anyone
  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_outlined, size: 80, color: textColor.withOpacity(0.2)), // Light icon
          const SizedBox(height: 20),
          Text(
            "You aren't following anyone yet.", // Informative text
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 16),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            onPressed: () {
              // Navigate to search or discovery screen (currently empty)
            },
            child: const Text("Discover Artists", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}