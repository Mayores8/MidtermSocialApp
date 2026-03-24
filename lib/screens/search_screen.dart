import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/api_service.dart';
import '../models/post_model.dart';
import 'artist_profile_screen.dart';
import '../main.dart';
import '../widgets/post_card.dart';

// SearchScreen allows searching for artists, posts, and displays trending content
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> recent = ['Twice - Official', 'Blackpink', 'AHOF', 'Jungkook']; // Recent searches
  List<Map<String, dynamic>> _searchResults = []; // Holds current search results
  List<Map<String, dynamic>> _trendingArtists = []; // Trending artists for explore view
  bool _isSearching = false; // Whether user is typing a search query
  bool isLoading = false; // Loading state for search

  @override
  void initState() {
    super.initState();
    _loadTrendingArtists(); // Load trending artists when screen initializes
  }

  // Load top artists from Firestore
  void _loadTrendingArtists() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isArtist', isEqualTo: true)
        .limit(10)
        .get();

    if (mounted) {
      setState(() {
        _trendingArtists = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // Keep Firestore document ID
          return data;
        }).toList();
      });
    }
  }

  // Triggered when search input changes
  void _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      isLoading = true;
    });

    // Search users by name
    final usersQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('fullName', isGreaterThanOrEqualTo: query)
        .where('fullName', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    // Search posts by caption
    final postsQuery = await FirebaseFirestore.instance
        .collection('posts')
        .where('caption', isGreaterThanOrEqualTo: query)
        .where('caption', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    if (mounted) {
      setState(() {
        _searchResults = [
          // Map users to search results
          ...usersQuery.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['type'] = 'user';
            return data;
          }),
          // Map posts to search results
          ...postsQuery.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['type'] = 'post';
            return data;
          }),
        ];
        isLoading = false;
      });
    }
  }

  // Navigate to artist profile
  void _navigateToArtist(Map<String, dynamic> artist) {
    // Add to recent searches
    if (!recent.contains(artist['fullName'])) {
      setState(() => recent.insert(0, artist['fullName']));
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistProfileScreen(
          artistName: artist['fullName'] ?? 'Unknown',
          image: artist['profileImage'] ?? 'https://i.pravatar.cc/150?u=${artist['id']}',
        ),
      ),
    );
  }

  // Navigate to post detail view
  void _navigateToPost(Map<String, dynamic> post) {
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
            child: Column(
              children: [
                PostCard(post: ApiService.postFromDoc(
                    FirebaseFirestore.instance.collection('posts').doc(post['id']) as DocumentSnapshot
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode, // Observe dark mode setting
      builder: (context, darkMode, child) {
        final Color textColor = darkMode ? Colors.white : Colors.black;

        return Scaffold(
          backgroundColor: darkMode ? Colors.black : Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                // Search input field
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Search artists, posts...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.pink),
                      suffixIcon: _isSearching
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: darkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                // Results or Explore view
                Expanded(
                  child: _isSearching
                      ? _buildSearchResults(textColor)
                      : _buildExploreView(textColor, darkMode),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Builds list of search results
  Widget _buildSearchResults(Color textColor) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.pink));
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          "No results found.",
          style: TextStyle(color: textColor.withOpacity(0.5)),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final isUser = item['type'] == 'user';

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(
                item['profileImage'] ?? item['profilePic'] ?? 'https://i.pravatar.cc/150?u=${item['id']}'
            ),
          ),
          title: Text(
            item['fullName'] ?? item['username'] ?? 'Unknown',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          subtitle: Text(
            isUser ? (item['isArtist'] == true ? 'Artist' : 'User') : 'Post',
            style: const TextStyle(color: Colors.pink, fontSize: 12),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          onTap: () => isUser ? _navigateToArtist(item) : _navigateToPost(item),
        );
      },
    );
  }

  // Explore view shows recent searches, trending artists and tags
  Widget _buildExploreView(Color textColor, bool darkMode) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent searches
          if (recent.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => recent.clear()),
                    child: const Text('Clear All', style: TextStyle(color: Colors.pink)),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recent.length > 5 ? 5 : recent.length,
              itemBuilder: (context, index) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: darkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
                  child: const Icon(Icons.history, color: Colors.grey, size: 20),
                ),
                title: Text(recent[index], style: TextStyle(color: textColor)),
                onTap: () {
                  _searchController.text = recent[index];
                  _onSearchChanged(recent[index]);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  onPressed: () => setState(() => recent.removeAt(index)),
                ),
              ),
            ),
          ],

          // Trending Artists section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Trending Artists',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
              ),
            ),
          ),
          if (_trendingArtists.isEmpty)
            const Center(child: CircularProgressIndicator(color: Colors.pink))
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _trendingArtists.length,
                itemBuilder: (context, index) {
                  final artist = _trendingArtists[index];
                  return GestureDetector(
                    onTap: () => _navigateToArtist(artist),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundImage: NetworkImage(
                                artist['profileImage'] ?? 'https://i.pravatar.cc/150?u=${artist['id']}'
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            artist['fullName'] ?? 'Unknown',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Trending Tags section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Trending Tags',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              '#KPOP',
              '#NewJeans',
              '#BTS',
              '#BLACKPINK',
              '#TWICE',
              '#aespa',
              '#IVE',
              '#LE_SSERAFIM',
            ].map((tag) => ActionChip(
              label: Text(tag),
              onPressed: () {
                _searchController.text = tag;
                _onSearchChanged(tag);
              },
              backgroundColor: darkMode ? Colors.white10 : Colors.black.withOpacity(0.05),
              labelStyle: TextStyle(color: textColor),
            )).toList(),
          ),
        ],
      ),
    );
  }
}