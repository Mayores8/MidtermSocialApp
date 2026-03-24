import 'package:flutter/material.dart'; // Flutter UI toolkit
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Authentication for user management
import '../services/api_service.dart'; // Custom API service for backend interactions
import '../models/post_model.dart'; // Post data model
import '../widgets/post_card.dart'; // Widget for displaying a post
import 'create_post_screen.dart'; // Screen for creating a new post
import 'login_screen.dart'; // Login screen
import '../main.dart'; // Main app file (for global variables, etc.)
import 'package:video_player/video_player.dart'; // Video player package
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore for database

// Main user profile screen widget
class UserProfileScreen extends StatefulWidget {
  final String userName; // Username display
  final String birthday; // User's birthday
  final String joinDate; // User's join date

  const UserProfileScreen({
    super.key,
    required this.userName,
    required this.birthday,
    required this.joinDate,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  // User profile data variables
  late String displayName;
  late String bio;
  String profileImage = 'https://i.pravatar.cc/150?u=newuser'; // Default profile image

  // Lists to hold user's posts, liked posts, bookmarked posts, and liked videos
  List<Post> userPosts = [];
  List<Post> likedPosts = [];
  List<Post> bookmarkedPosts = [];
  List<Post> likedVideos = [];

  bool isLoading = true; // Loading state indicator
  int postCount = 0; // Count of user's posts
  int followersCount = 0; // Number of followers
  int followingCount = 0; // Number of following
  String? errorMessage; // For displaying errors

  @override
  void initState() {
    super.initState();
    // Initialize display name and bio from widget data
    displayName = widget.userName;
    bio = "Just joined K-STAR! • Edit Bio";
    // Load user data from Firebase and other sources
    _loadUserData();
  }

  // Method to load user data
  void _loadUserData() {
    final user = FirebaseAuth.instance.currentUser; // Get current user from Firebase Auth

    if (user == null) {
      // If no user is logged in, stop loading
      setState(() => isLoading = false);
      return;
    }

    // Load user's posts with fallback for missing index
    _loadUserPosts(user.uid);

    // Listen for real-time updates on user document in Firestore
    _firestore.collection('users').doc(user.uid).snapshots().listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        // Update profile info from Firestore data
        setState(() {
          displayName = data['fullName'] ?? widget.userName;
          bio = data['bio'] ?? bio;
          profileImage = data['profileImage'] ?? profileImage;
          followersCount = (data['followers'] as List?)?.length ?? 0;
          followingCount = (data['following'] as List?)?.length ?? 0;
          isLoading = false; // Data loaded
        });
      }
    }, onError: (error) {
      print('Error loading user data: $error');
      setState(() => isLoading = false);
    });

    // Load liked posts stream
    ApiService.getLikedPostsStream().listen((posts) {
      if (mounted) {
        setState(() {
          // Separate liked posts into videos and non-videos
          likedPosts = posts.where((p) => !p.isVideo).toList();
          likedVideos = posts.where((p) => p.isVideo).toList();
        });
      }
    }, onError: (error) {
      print('Error loading liked posts: $error');
    });

    // Load bookmarked posts stream
    ApiService.getBookmarkedPostsStream().listen((posts) {
      if (mounted) {
        setState(() => bookmarkedPosts = posts);
      }
    }, onError: (error) {
      print('Error loading bookmarks: $error');
    });
  }

  // Method to load user posts with fallback if index is missing
  void _loadUserPosts(String userId) async {
    try {
      // First attempt: with orderBy (requires index)
      final query = _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true); // Order posts by creation time

      query.snapshots().listen((snapshot) {
        if (mounted) {
          setState(() {
            // Map documents to Post objects
            userPosts = snapshot.docs.map((doc) => ApiService.postFromDoc(doc)).toList();
            postCount = userPosts.length; // Update post count
            isLoading = false; // Data loaded
            errorMessage = null;
          });
        }
      }, onError: (error) {
        print('Error with ordered query: $error');
        // If index missing, fallback to without orderBy
        _loadUserPostsWithoutOrder(userId);
      });
    } catch (e) {
      print('Error setting up query: $e');
      // Fallback if error occurs
      _loadUserPostsWithoutOrder(userId);
    }
  }

  // Fallback method: load posts without orderBy (less efficient)
  void _loadUserPostsWithoutOrder(String userId) {
    _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        // Convert documents to Post objects
        final posts = snapshot.docs.map((doc) => ApiService.postFromDoc(doc)).toList();
        // Sort posts in memory based on timestamp (descending)
        posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        setState(() {
          userPosts = posts;
          postCount = userPosts.length;
          isLoading = false;
          errorMessage = 'Create index for better performance'; // Suggest creating index
        });
      }
    }, onError: (error) {
      print('Error loading posts without order: $error');
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading posts: $error';
      });
    });
  }

  // Firebase Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Method to show profile editing dialog
  void _showEditProfileDialog(bool darkMode) {
    // Controllers for input fields
    TextEditingController nameController = TextEditingController(text: displayName);
    TextEditingController bioController = TextEditingController(text: bio);
    String? newImageUrl; // To hold new profile image URL

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
        title: const Text("Edit Profile", style: TextStyle(color: Colors.pink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Profile image with tap to change
            GestureDetector(
              onTap: () {
                // Show dialog to input new image URL
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Change Profile Picture"),
                    content: TextField(
                      decoration: const InputDecoration(
                        hintText: "Enter image URL",
                      ),
                      onChanged: (value) => newImageUrl = value,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              },
              child: CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(profileImage),
                child: const Icon(Icons.camera_alt, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            // Input for display name
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Display Name",
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: darkMode ? Colors.white24 : Colors.black12),
                ),
              ),
              style: TextStyle(color: darkMode ? Colors.white : Colors.black),
            ),
            // Input for bio
            TextField(
              controller: bioController,
              decoration: InputDecoration(
                labelText: "Bio",
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: darkMode ? Colors.white24 : Colors.black12),
                ),
              ),
              style: TextStyle(color: darkMode ? Colors.white : Colors.black),
            ),
          ],
        ),
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          // Save button
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            onPressed: () async {
              try {
                // Call API to update profile
                await ApiService.updateProfile(
                  displayName: nameController.text,
                  bio: bioController.text,
                  profileImage: newImageUrl,
                );
                // Update local state
                setState(() {
                  displayName = nameController.text;
                  bio = bioController.text;
                  if (newImageUrl != null) profileImage = newImageUrl!;
                });
                Navigator.pop(context); // Close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Profile updated!")),
                );
              } catch (e) {
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use ValueListenableBuilder for dark mode toggle
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, darkMode, child) {
        final Color textColor = darkMode ? Colors.white : Colors.black;
        return Scaffold(
          backgroundColor: darkMode ? Colors.black : Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            title: GestureDetector(
              onTap: () => _showAccountSwitcher(context, darkMode),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("@${displayName.toLowerCase().replaceAll(' ', '')}", style: TextStyle(color: textColor)),
                  Icon(Icons.keyboard_arrow_down, color: textColor),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.menu, color: textColor),
                onPressed: () => _showLogMenu(context, darkMode),
              ),
            ],
          ),
          body: DefaultTabController(
            length: 4, // Four tabs: posts, liked, videos, bookmarks
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                // Profile header with user info
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile picture and stats row
                        Row(
                          children: [
                            Stack(
                              children: [
                                // Profile picture
                                CircleAvatar(
                                  radius: 40,
                                  backgroundImage: NetworkImage(profileImage),
                                ),
                                // Edit profile overlay icon
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _showEditProfileDialog(darkMode),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.pink,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.edit, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 20),
                            // Display post, followers, following stats
                            _buildStat(postCount.toString(), 'POSTS', textColor),
                            _buildStat(followersCount.toString(), 'FOLLOWERS', textColor),
                            _buildStat(followingCount.toString(), 'FOLLOWING', textColor),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Edit profile button
                        ElevatedButton(
                          onPressed: () => _showEditProfileDialog(darkMode),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkMode ? Colors.white10 : Colors.black12,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 36),
                          ),
                          child: Text('Edit Profile', style: TextStyle(fontSize: 12, color: textColor)),
                        ),
                        // Display user's display name
                        Text(displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                        // User bio
                        Text(bio, style: TextStyle(color: textColor.withOpacity(0.8))),
                        const SizedBox(height: 10),
                        // Birth date info
                        Row(
                          children: [
                            Icon(Icons.cake_outlined, size: 16, color: textColor.withOpacity(0.6)),
                            Text(' Born ${widget.birthday}', style: TextStyle(color: textColor.withOpacity(0.6))),
                          ],
                        ),
                        // Join date info
                        Row(
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 16, color: textColor.withOpacity(0.6)),
                            Text(' Joined ${widget.joinDate}', style: TextStyle(color: textColor.withOpacity(0.6))),
                          ],
                        ),
                        // Show error message if any
                        if (errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              errorMessage!,
                              style: TextStyle(color: Colors.orange, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Sticky tab bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      indicatorColor: Colors.pink,
                      labelColor: Colors.pink,
                      unselectedLabelColor: Colors.grey,
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_on)), // Posts grid
                        Tab(icon: Icon(Icons.favorite_border)), // Liked posts
                        Tab(icon: Icon(Icons.play_circle_outline)), // Videos
                        Tab(icon: Icon(Icons.bookmark_border)), // Bookmarks
                      ],
                    ),
                    darkMode,
                  ),
                ),
              ],
              // Tab views for each section
              body: TabBarView(
                children: [
                  _buildPostsGrid(userPosts, textColor), // User's posts grid
                  _buildInteractedList(likedPosts, "No liked posts yet ♡", textColor), // Liked posts list
                  _buildVideoGrid(likedVideos, textColor), // Liked videos grid
                  _buildInteractedList(bookmarkedPosts, "No saved posts yet", textColor), // Bookmarks list
                ],
              ),
            ),
          ),
          // Floating button to create new post
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.pink,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreatePostScreen()),
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  // Helper widget to build posts grid
  Widget _buildPostsGrid(List<Post> posts, Color textColor) {
    if (isLoading) {
      // Show loading indicator while loading
      return const Center(child: CircularProgressIndicator(color: Colors.pink));
    }
    if (posts.isEmpty) {
      // Show message if no posts
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 60, color: textColor.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text("Share your first post!", style: TextStyle(color: textColor.withOpacity(0.5))),
          ],
        ),
      );
    }
    // Display posts in grid view with pull-to-refresh
    return RefreshIndicator(
      onRefresh: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          _loadUserPosts(user.uid);
        }
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return GestureDetector(
            onTap: () => _showPostDetail(post),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Post image
                Image.network(
                  post.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
                // Overlay play icon if video
                if (post.isVideo)
                  const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 40)),
                // Likes count at bottom right
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.white, size: 14),
                      const SizedBox(width: 2),
                      Text(
                        post.likes.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper to build video grid (liked videos)
  Widget _buildVideoGrid(List<Post> reels, Color textColor) {
    if (reels.isEmpty) {
      // Show message if no videos
      return Center(
        child: Text("No liked videos yet", style: TextStyle(color: textColor.withOpacity(0.5))),
      );
    }
    // Grid view for videos with aspect ratio
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.7,
      ),
      itemCount: reels.length,
      itemBuilder: (context, index) {
        final reel = reels[index];
        return GestureDetector(
          onTap: () => _playVideo(reel),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail (profile pic) as placeholder
              Image.network(
                reel.profilePic,
                fit: BoxFit.cover,
              ),
              // Overlay icon to indicate video
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 40)),
              ),
              // Likes count overlay
              Positioned(
                bottom: 4,
                left: 4,
                child: Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.white, size: 14),
                    const SizedBox(width: 2),
                    Text(
                      reel.likes.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Function to navigate to video player screen
  void _playVideo(Post reel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoUrl: reel.videoUrl),
      ),
    );
  }

  // Function to show post details in bottom sheet
  void _showPostDetail(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: PostCard(post: post),
          );
        },
      ),
    );
  }

  // Helper to build list of liked/bookmarked posts
  Widget _buildInteractedList(List<Post> posts, String emptyMsg, Color textColor) {
    if (posts.isEmpty) {
      // Show message if no posts
      return Center(
        child: Text(emptyMsg, style: TextStyle(color: textColor.withOpacity(0.5))),
      );
    }
    // List view for posts
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: posts.length,
      itemBuilder: (context, index) => PostCard(post: posts[index]),
    );
  }

  // Helper to build stats (posts, followers, following)
  Widget _buildStat(String val, String label, Color textColor) {
    return Expanded(
      child: Column(
        children: [
          Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  // Show account switcher modal
  void _showAccountSwitcher(BuildContext context, bool darkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Current account info
            ListTile(
              leading: CircleAvatar(backgroundImage: NetworkImage(profileImage)),
              title: Text(displayName, style: TextStyle(color: darkMode ? Colors.white : Colors.black)),
              trailing: const Icon(Icons.check_circle, color: Colors.blue),
            ),
            // Option to add new account
            ListTile(
              leading: Icon(Icons.add, color: darkMode ? Colors.white : Colors.black),
              title: Text('Add K-STAR account', style: TextStyle(color: darkMode ? Colors.white : Colors.black)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // Show logout or settings menu
  void _showLogMenu(BuildContext context, bool darkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Settings option
          ListTile(
            leading: Icon(Icons.settings, color: darkMode ? Colors.white : Colors.black),
            title: Text('Settings', style: TextStyle(color: darkMode ? Colors.white : Colors.black)),
          ),
          // Log out option
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (c) => const LoginScreen()),
                      (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

// Video Player Screen for clickable videos
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl; // URL of the video to play
  const VideoPlayerScreen({super.key, required this.videoUrl});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller; // Controller for video playback
  bool _isInitialized = false; // Whether video is initialized

  @override
  void initState() {
    super.initState();
    // Initialize controller with network URL
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _controller.play(); // Auto-play on load
          _controller.setLooping(true); // Loop video
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose controller to free resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        )
            : const CircularProgressIndicator(color: Colors.pink),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            // Toggle play/pause
            _controller.value.isPlaying ? _controller.pause() : _controller.play();
          });
        },
        child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}

// Delegate class for sticky TabBar header
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar; // The TabBar widget
  final bool darkMode; // For styling based on theme

  _SliverAppBarDelegate(this._tabBar, this.darkMode);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: darkMode ? const Color(0xFF121212) : Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}