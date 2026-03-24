import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';
import '../services/api_service.dart';
import '../models/post_model.dart';

class ArtistProfileScreen extends StatefulWidget {
  final String artistName; // The name used to query user data and posts
  final String image;      // Profile image URL passed from the previous screen

  const ArtistProfileScreen({
    super.key,
    required this.artistName,
    required this.image,
  });

  @override
  State<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends State<ArtistProfileScreen> {
  // State variables to manage UI updates
  bool isFollowing = false;
  List<Post> artistPosts = [];        // Holds all posts fetched from Firestore
  Map<String, dynamic>? artistData;   // Holds raw user document data (bio, agency, etc.)
  bool isLoading = true;              // Controls visibility of loading spinners
  int followersCount = 0;
  int followingCount = 0;
  int postCount = 0;

  @override
  void initState() {
    super.initState();
    // Initialize data when the screen is first created
    _checkFollowStatus();
    _loadArtistData();
    _loadArtistPosts();
  }

  /// Checks local service to see if the user already follows this artist
  void _checkFollowStatus() {
    setState(() {
      isFollowing = ApiService.followedArtists.contains(widget.artistName);
    });
  }

  /// Fetches the Artist's user profile document from the 'users' collection
  Future<void> _loadArtistData() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('fullName', isEqualTo: widget.artistName)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        if (mounted) {
          setState(() {
            artistData = data;
            // Extract lengths of the followers/following arrays
            followersCount = (data['followers'] as List?)?.length ?? 0;
            followingCount = (data['following'] as List?)?.length ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading artist data: $e");
    }
  }

  /// Listens to real-time updates from the 'posts' collection for this artist
  void _loadArtistPosts() {
    // Note: We don't use .orderBy() in the query to avoid "Missing Index" errors.
    // We handle the sorting manually in the application code below.
    FirebaseFirestore.instance
        .collection('posts')
        .where('username', isEqualTo: widget.artistName)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        // Map Firestore documents to our local Post model
        List<Post> posts = snapshot.docs.map((doc) => ApiService.postFromDoc(doc)).toList();

        // MANUAL SORT: Sort by date descending (newest first)
        posts.sort((a, b) {
          if (a.createdAt != null && b.createdAt != null) {
            return b.createdAt!.compareTo(a.createdAt!);
          }
          return b.timestamp.compareTo(a.timestamp); // Fallback to string comparison
        });

        setState(() {
          artistPosts = posts;
          postCount = artistPosts.length;
          isLoading = false;
        });
      }
    }, onError: (error) {
      debugPrint("Firestore Error in _loadArtistPosts: $error");
      if (mounted) setState(() => isLoading = false);
    });
  }

  /// Handles the follow/unfollow logic via ApiService and updates local state
  Future<void> _toggleFollow() async {
    await ApiService.toggleFollow(widget.artistName);
    setState(() {
      isFollowing = !isFollowing;
      // Optimistic UI update: change count immediately without waiting for DB refresh
      followersCount += isFollowing ? 1 : -1;
    });
  }

  /// Logic to navigate to a chat session with this specific artist
  Future<void> _startChat() async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('fullName', isEqualTo: widget.artistName)
        .limit(1)
        .get();

    String? otherUserId;
    if (query.docs.isNotEmpty) {
      otherUserId = query.docs.first.id;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => ChatScreen(
            artistName: widget.artistName,
            otherUserId: otherUserId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.artistName),
      ),
      body: DefaultTabController(
        length: 4, // Number of tabs (Grid, Liked, Reels, Saved)
        child: NestedScrollView(
          // Allows the header to scroll away while the TabBar stays pinned
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header: Avatar and Stats
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(widget.image),
                        ),
                        const SizedBox(width: 20),
                        _buildStat(postCount.toString(), 'POSTS'),
                        _buildStat(_formatCount(followersCount), 'FOLLOWERS'),
                        _buildStat(_formatCount(followingCount), 'FOLLOWING'),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // Action Buttons: Follow and Message
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _toggleFollow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing ? Colors.white12 : Colors.pink,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(isFollowing ? 'Following' : 'Follow',
                                style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _startChat,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Message', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    // Artist Details
                    Text(widget.artistName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Text('Official Artist Account', style: TextStyle(color: Colors.pink, fontSize: 13)),
                    const SizedBox(height: 5),
                    Text(artistData?['bio'] ?? 'Welcome to my official profile!'),
                    const SizedBox(height: 10),
                    _buildIconLabel(Icons.star_border, ' Debut: ${artistData?['debut'] ?? 'Unknown'}'),
                    _buildIconLabel(Icons.business_center_outlined, ' Agency: ${artistData?['agency'] ?? 'Unknown'}'),
                  ],
                ),
              ),
            ),
            // The Sticky TabBar section
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  indicatorColor: Colors.pink,
                  labelColor: Colors.pink,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on)),
                    Tab(icon: Icon(Icons.favorite_border)),
                    Tab(icon: Icon(Icons.play_circle_outline)),
                    Tab(icon: Icon(Icons.bookmark_border)),
                  ],
                ),
                Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ],
          // The content displayed for each tab
          body: TabBarView(
            children: [
              _buildPostGrid(),   // Tab 1: Image Grid
              _buildLikedPosts(), // Tab 2: Liked content placeholder
              _buildReelsGrid(),  // Tab 3: Video Grid
              const Center(child: Text('Saved by Artist', style: TextStyle(color: Colors.grey))),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper to create small icons with text labels (Debut/Agency)
  Widget _buildIconLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        Text(text, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  /// Converts large numbers like 1000 to "1.0K" or 1000000 to "1.0M"
  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  /// Helper to build the individual stats (e.g., "12 POSTS")
  Widget _buildStat(String val, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  /// Filters the loaded posts for images and displays them in a 3-column grid
  Widget _buildPostGrid() {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Colors.pink));

    final imagePosts = artistPosts.where((p) => !p.isVideo).toList();
    if (imagePosts.isEmpty) return const Center(child: Text('No posts yet', style: TextStyle(color: Colors.grey)));

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
      ),
      itemCount: imagePosts.length,
      itemBuilder: (context, index) {
        return Image.network(
          imagePosts[index].imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(color: Colors.grey[900], child: const Icon(Icons.image_not_supported)),
        );
      },
    );
  }

  Widget _buildLikedPosts() {
    return const Center(child: Text('Liked posts by artist', style: TextStyle(color: Colors.grey)));
  }

  /// Filters the loaded posts for videos and displays them with a play icon overlay
  Widget _buildReelsGrid() {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: Colors.pink));

    final videoPosts = artistPosts.where((p) => p.isVideo).toList();
    if (videoPosts.isEmpty) return const Center(child: Text('No reels yet', style: TextStyle(color: Colors.grey)));

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2, childAspectRatio: 0.7,
      ),
      itemCount: videoPosts.length,
      itemBuilder: (context, index) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
                videoPosts[index].imageUrl.isNotEmpty ? videoPosts[index].imageUrl : videoPosts[index].profilePic,
                fit: BoxFit.cover
            ),
            // Play icon overlay to signify video content
            Container(color: Colors.black26, child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 40))),
          ],
        );
      },
    );
  }
}

/// Custom delegate required by SliverPersistentHeader to handle the pinned TabBar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color backgroundColor;
  _SliverAppBarDelegate(this._tabBar, this.backgroundColor);

  @override double get minExtent => _tabBar.preferredSize.height;
  @override double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: backgroundColor, child: _tabBar);
  }

  @override bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}