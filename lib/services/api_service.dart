import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore for database interactions
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Authentication
import 'package:flutter/material.dart'; // Flutter UI toolkit
import '../models/post_model.dart'; // Post data model

// ApiService provides static methods for interacting with Firebase backend
class ApiService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance
  static final FirebaseAuth _auth = FirebaseAuth.instance; // Firebase Auth instance

  // Notifiers for sync and message updates
  static ValueNotifier<int> syncNotifier = ValueNotifier(0);
  static ValueNotifier<int> messageNotifier = ValueNotifier(0);

  // Set to store followed artists' usernames
  static Set<String> followedArtists = {};
  // Map to hold current user data
  static Map<String, dynamic>? currentUserData;

  // Initialize user data, load current user info and following list
  static Future<void> initializeUser() async {
    final user = _auth.currentUser; // Get current authenticated user
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get(); // Fetch user document
      if (doc.exists) {
        currentUserData = doc.data(); // Store user data locally
        final following = List<String>.from(currentUserData?['following'] ?? []);
        followedArtists = Set<String>.from(following); // Populate followed artists set
      }
    }
  }

  // Toggle follow/unfollow for a given username
  static Future<void> toggleFollow(String username) async {
    final user = _auth.currentUser; // Current user
    if (user == null) return;
    final userRef = _firestore.collection('users').doc(user.uid); // Reference to current user document

    if (followedArtists.contains(username)) {
      // If already following, remove from set and update Firestore
      followedArtists.remove(username);
      await userRef.update({
        'following': FieldValue.arrayRemove([username]),
        'followingCount': FieldValue.increment(-1),
      });
    } else {
      // If not following, add to set and update Firestore
      followedArtists.add(username);
      await userRef.update({
        'following': FieldValue.arrayUnion([username]),
        'followingCount': FieldValue.increment(1),
      });
      await _createFollowNotification(username); // Notify user of new follow
    }
    syncNotifier.value++; // Trigger UI update
  }

  // Create a notification for a follow action
  static Future<void> _createFollowNotification(String targetUsername) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Find the user document with matching fullName (username)
    final targetUser = await _firestore.collection('users')
        .where('fullName', isEqualTo: targetUsername)
        .limit(1)
        .get();

    if (targetUser.docs.isNotEmpty) {
      // Add notification document to 'notifications' collection
      await _firestore.collection('notifications').add({
        'userId': targetUser.docs.first.id, // Target user ID
        'senderId': user.uid, // Current user ID
        'senderName': currentUserData?['fullName'] ?? 'User', // Name of follower
        'senderImage': currentUserData?['profileImage'] ?? '', // Profile image
        'type': 'follow', // Notification type
        'message': 'started following you', // Notification message
        'read': false, // Mark as unread
        'createdAt': FieldValue.serverTimestamp(), // Timestamp
      });
    }
  }
 //ito yung kumuuha ng data mula sa firbase apos kino-convert nia into post objcts

  static Stream<List<Post>> getPostsStream() {
    return _firestore
        .collection('posts')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return getMockPosts(); // Return mock posts if empty

      // Convert documents to Post objects
      List<Post> posts = snapshot.docs.map((doc) => postFromDoc(doc)).toList();
      // Manually sort posts by createdAt descending
      posts.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return posts;
    }).handleError((error) {
      // Log error and return mock data
      debugPrint('Error in getPostsStream: $error');
      return getMockPosts();
    });
  }

  // FIXED: Reels stream filtering only video posts, with in-memory sorting
  static Stream<List<Post>> getReelsStream() {
    return _firestore
        .collection('posts')
        .where('isVideo', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return getMockPosts().where((p) => p.isVideo).toList();

      // Convert docs to Post and sort in-memory
      List<Post> reels = snapshot.docs.map((doc) => postFromDoc(doc)).toList();
      reels.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return reels;
    }).handleError((error) {
      debugPrint('Error in getReelsStream: $error');
      return getMockPosts().where((p) => p.isVideo).toList();
    });
  }

  // FIXED: Fetch posts from followed artists with in-memory sorting
  static Stream<List<Post>> getFollowingPostsStream() {
    if (followedArtists.isEmpty) return Stream.value([]); // Return empty if no followed artists

    final usernamesToQuery = followedArtists.take(10).toList(); // Limit to 10 for performance

    return _firestore
        .collection('posts')
        .where('username', whereIn: usernamesToQuery)
        .snapshots()
        .map((snapshot) {
      List<Post> posts = snapshot.docs.map((doc) => postFromDoc(doc)).toList();
      // Sort posts by createdAt descending
      posts.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return posts;
    }).handleError((error) {
      debugPrint('Error in getFollowingPostsStream: $error');
      return <Post>[];
    });
  }

  // Convert a DocumentSnapshot into a Post object
  static Post postFromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final currentUser = _auth.currentUser;

    // Extract likes and bookmarks as list of user IDs
    final likes = List<String>.from(data['likes'] ?? []);
    final bookmarks = List<String>.from(data['bookmarks'] ?? []);

    // Determine if current user has liked/bookmarked this post
    final isLiked = currentUser != null && likes.contains(currentUser.uid);
    final isBookmarked = currentUser != null && bookmarks.contains(currentUser.uid);

    // Create and return Post object
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? '',
      profilePic: data['profilePic'] ?? '',
      timestamp: _formatTimestamp(data['createdAt']),
      imageUrl: data['imageUrl'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      audioName: data['audioName'] ?? 'Original Audio',
      caption: data['caption'] ?? '',
      bio: data['bio'] ?? '',
      debut: data['debut'] ?? '',
      agency: data['agency'] ?? '',
      postCount: data['postCount']?.toString() ?? '0',
      followersCount: data['followersCount']?.toString() ?? '0',
      followingCount: data['followingCount']?.toString() ?? '0',
      gridImages: List<String>.from(data['gridImages'] ?? []),
      isVerified: data['isVerified'] ?? true,
      likes: likes.length,
      isLiked: isLiked,
      isBookmarked: isBookmarked,
      comments: data['commentsCount'] ?? 0,
      shares: data['sharesCount'] ?? 0,
      isVideo: data['isVideo'] ?? false,
      commentList: [], // Placeholder, comments are fetched separately
      // Store the DateTime for sorting
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // Helper to format timestamp into a human-readable string
  static String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'now';
    final date = (timestamp as Timestamp).toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.month}/${date.day}'; // Fallback format
  }

  // Toggle like/unlike a post
  static Future<void> toggleLike(String postId, bool isLiked) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final postRef = _firestore.collection('posts').doc(postId);

    if (isLiked) {
      // Remove user ID from likes array and decrement count
      await postRef.update({
        'likes': FieldValue.arrayRemove([user.uid]),
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      // Add user ID to likes array and increment count
      await postRef.update({
        'likes': FieldValue.arrayUnion([user.uid]),
        'likesCount': FieldValue.increment(1),
      });
      // Optionally notify the post owner if not self
      final post = await postRef.get();
      final postData = post.data() as Map<String, dynamic>;
      if (postData['userId'] != user.uid) {
        await _firestore.collection('notifications').add({
          'userId': postData['userId'], // Post owner's ID
          'senderId': user.uid, // Current user ID
          'senderName': currentUserData?['fullName'] ?? 'User',
          'senderImage': currentUserData?['profileImage'] ?? '',
          'type': 'like',
          'postId': postId,
          'message': 'liked your post',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    syncNotifier.value++; // Trigger UI update
  }

  // Toggle bookmark/unbookmark a post
  static Future<void> toggleBookmark(String postId, bool isBookmarked) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final postRef = _firestore.collection('posts').doc(postId);
    final bookmarkRef = _firestore.collection('bookmarks').doc(user.uid).collection('items').doc(postId);

    if (isBookmarked) {
      // Remove user from bookmarks array in post document
      await postRef.update({'bookmarks': FieldValue.arrayRemove([user.uid])});
      // Remove from user's bookmarks collection
      await bookmarkRef.delete();
    } else {
      // Add user to bookmarks array
      await postRef.update({'bookmarks': FieldValue.arrayUnion([user.uid])});
      // Add to user's bookmarks collection
      await bookmarkRef.set({'postId': postId, 'createdAt': FieldValue.serverTimestamp()});
    }
    syncNotifier.value++; // Trigger UI update
  }

  // Get stream of user's bookmarked posts
  static Stream<List<Post>> getBookmarkedPostsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]); // Empty stream if no user
    return _firestore.collection('bookmarks').doc(user.uid).collection('items').snapshots().asyncMap((snapshot) async {
      final posts = <Post>[];
      for (var doc in snapshot.docs) {
        final postDoc = await _firestore.collection('posts').doc(doc.id).get();
        if (postDoc.exists) posts.add(postFromDoc(postDoc));
      }
      return posts;
    });
  }

  // Get stream of posts liked by current user
  static Stream<List<Post>> getLikedPostsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]); // Empty if not logged in
    return _firestore.collection('posts').where('likes', arrayContains: user.uid).snapshots().map((snapshot) {
      List<Post> posts = snapshot.docs.map((doc) => postFromDoc(doc)).toList();
      // Sort posts by createdAt descending
      posts.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return posts;
    });
  }

  // Share a post (create a shared copy)
  static Future<void> sharePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    // Increment share count of original post
    await _firestore.collection('posts').doc(postId).update({'sharesCount': FieldValue.increment(1)});
    final post = await _firestore.collection('posts').doc(postId).get();

    if (post.exists) {
      final postData = post.data() as Map<String, dynamic>;
      // Create a new post as a share with original post info
      await _firestore.collection('posts').add({
        ...postData,
        'userId': user.uid,
        'username': currentUserData?['fullName'] ?? 'User',
        'profilePic': currentUserData?['profileImage'] ?? '',
        'isShared': true,
        'originalPostId': postId,
        'originalUsername': postData['username'],
        'createdAt': FieldValue.serverTimestamp(),
        // Reset counters for new share
        'likes': [], 'likesCount': 0, 'bookmarks': [], 'commentsCount': 0, 'sharesCount': 0,
      });
    }
    syncNotifier.value++; // Notify UI
  }

  // Create a new post
  static Future<String> createPost({
    required String imageUrl,
    String? videoUrl,
    required String caption,
    bool isVideo = false,
    String? audioName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Fetch user info for post attribution
    final userInfo = (await _firestore.collection('users').doc(user.uid).get()).data() as Map<String, dynamic>;

    // Add new post document
    final postRef = await _firestore.collection('posts').add({
      'userId': user.uid,
      'username': userInfo['fullName'] ?? 'User',
      'profilePic': userInfo['profileImage'] ?? 'https://i.pravatar.cc/150?u=${user.uid}',
      'imageUrl': imageUrl,
      'videoUrl': videoUrl ?? '',
      'caption': caption,
      'isVideo': isVideo,
      'audioName': audioName ?? (isVideo ? 'Original Audio' : ''),
      'likes': [],
      'likesCount': 0,
      'bookmarks': [],
      'commentsCount': 0,
      'sharesCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'bio': userInfo['bio'] ?? '',
      'debut': userInfo['debut'] ?? '',
      'agency': userInfo['agency'] ?? '',
      'isVerified': false,
    });
    // Increment user's post count
    await _firestore.collection('users').doc(user.uid).update({'postCount': FieldValue.increment(1)});
    syncNotifier.value++; // Notify UI
    return postRef.id; // Return new post ID
  }

  // Fetch comments for a post
  static Stream<List<Comment>> getCommentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      return Comment(
        username: data['username'] ?? 'User',
        text: data['text'] ?? '',
        time: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }).toList());
  }

  // Add a comment to a post
  static Future<void> addComment(String postId, String text) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Fetch current user info
    final userInfo = (await _firestore.collection('users').doc(user.uid).get()).data() as Map<String, dynamic>;

    // Add comment document
    await _firestore.collection('posts').doc(postId).collection('comments').add({
      'userId': user.uid,
      'username': userInfo['fullName'] ?? 'User',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment comment count
    await _firestore.collection('posts').doc(postId).update({'commentsCount': FieldValue.increment(1)});

    // Fetch post data to notify owner if comment is from another user
    final postData = (await _firestore.collection('posts').doc(postId).get()).data() as Map<String, dynamic>;
    if (postData['userId'] != user.uid) {
      await _firestore.collection('notifications').add({
        'userId': postData['userId'],
        'senderId': user.uid,
        'senderName': userInfo['fullName'] ?? 'User',
        'senderImage': userInfo['profileImage'] ?? '',
        'type': 'comment',
        'postId': postId,
        'message': 'commented: $text',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    syncNotifier.value++; // Trigger UI update
  }

  // Update user profile info
  static Future<void> updateProfile({required String displayName, required String bio, String? profileImage}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final updateData = {
      'fullName': displayName,
      'bio': bio,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (profileImage != null) {
      updateData['profileImage'] = profileImage;
    }
    // Update user document
    await _firestore.collection('users').doc(user.uid).update(updateData);

    // Update all posts with new username/profilePic
    final posts = await _firestore.collection('posts').where('userId', isEqualTo: user.uid).get();
    final batch = _firestore.batch();
    for (var doc in posts.docs) {
      batch.update(doc.reference, {
        'username': displayName,
        if (profileImage != null) 'profilePic': profileImage,
      });
    }
    await batch.commit();

    // Re-initialize user data
    await initializeUser();

    // Notify UI
    syncNotifier.value++;
  }

  // Fetch notifications stream for current user
  static Stream<List<Map<String, dynamic>>> getNotificationsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    // Listen to notifications ordered by latest
    return _firestore.collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // Add document ID
      return data;
    }).toList());
  }

  // Mark a notification as read
  static Future<void> markNotificationRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({'read': true});
  }

  // Get or create a direct message conversation with another user
  static Future<String> getOrCreateConversation(String otherUserId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Search for existing conversation with the other user
    final existing = await _firestore.collection('conversations')
        .where('participants', arrayContains: user.uid)
        .get();

    for (var doc in existing.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(otherUserId)) return doc.id; // Found existing convo
    }

    // If not found, create new conversation
    final otherUserData = (await _firestore.collection('users').doc(otherUserId).get()).data() as Map<String, dynamic>;
    final currentData = (await _firestore.collection('users').doc(user.uid).get()).data() as Map<String, dynamic>;

    final convoRef = await _firestore.collection('conversations').add({
      'participants': [user.uid, otherUserId],
      'participantNames': {
        user.uid: currentData['fullName'] ?? 'User',
        otherUserId: otherUserData['fullName'] ?? 'User'
      },
      'participantImages': {
        user.uid: currentData['profileImage'] ?? '',
        otherUserId: otherUserData['profileImage'] ?? ''
      },
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': {user.uid: 0, otherUserId: 0},
      'createdAt': FieldValue.serverTimestamp(),
    });
    return convoRef.id; // Return new conversation ID
  }

  // Stream of conversations for current user
  static Stream<List<Map<String, dynamic>>> getConversationsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]); // Empty stream if no user
    return _firestore.collection('conversations')
        .where('participants', arrayContains: user.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // Add document ID
      return data;
    }).toList());
  }

  // Stream of messages in a conversation
  static Stream<List<Map<String, dynamic>>> getMessagesStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // Add message ID
      return data;
    }).toList());
  }

  // Send a message in a conversation
  static Future<void> sendMessage(String conversationId, String text) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Batch to add message and update conversation
    final batch = _firestore.batch();
    final messageRef = _firestore.collection('conversations').doc(conversationId).collection('messages').doc();
    // Add message document
    batch.set(messageRef, {
      'senderId': user.uid,
      'text': text,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
    // Update last message info
    batch.update(_firestore.collection('conversations').doc(conversationId),
        {'lastMessage': text, 'lastMessageTime': FieldValue.serverTimestamp()});
    await batch.commit();
    messageNotifier.value++; // Notify message update
  }

  // Return mock posts for testing or fallback
  static List<Post> getMockPosts() {
    return [
      Post(
        id: 'mock1',
        username: 'Hani_NJ',
        profilePic: 'https://tse1.mm.bing.net/th/id/OIP.RKwhLs1w6_yyO1o0JPxD8gHaNK?rs=1&pid=ImgDetMain&o=7&rm=3',
        timestamp: '22h',
        imageUrl: 'https://img.vogue.co.kr/vogue/2023/10/style_6531debb22297-1126x1400.jpg',
        caption: 'Thank you for your support! ♡',
        bio: 'NewJeans Hanni Official',
        debut: 'Aug 1, 2022',
        agency: 'ADOR (HYBE)',
        postCount: '45',
        followersCount: '10M',
        followingCount: '5',
        gridImages: ['https://picsum.photos/id/101/400/400'],
        likes: 129,
        comments: 34,
        shares: 89,
        createdAt: DateTime.now().subtract(const Duration(hours: 22)),
      ),
      Post(
        id: 'mock2',
        username: 'Sana_Twice',
        profilePic: 'https://tse1.mm.bing.net/th/id/OIP.W3CG3nj8dlpLtB-ReRLsqgHaNK?rs=1&pid=ImgDetMain',
        timestamp: '1d',
        imageUrl: 'https://pbs.twimg.com/media/FvmC-hpacAAWi9S.jpg:large',
        caption: 'Did you watch the new MV yet? ❤️',
        bio: 'No Sana No Life! ✨',
        debut: 'Oct 20, 2015',
        agency: 'JYP Entertainment',
        postCount: '17',
        followersCount: '15M',
        followingCount: '92',
        gridImages: ['https://picsum.photos/id/201/400/400'],
        likes: 450,
        comments: 120,
        shares: 56,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Post(
        id: 'mock3',
        username: 'Lisa_BP',
        profilePic: 'https://wallpapers.com/images/hd/2019-monshoot-mood-korea-lisa-blackpink-hd-a1iqfriyi4palj94.jpg',
        timestamp: '3h',
        imageUrl: 'https://i.imgur.com/8F8U4yL.jpg',
        videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        caption: 'LALISA 🖤💖',
        audioName: 'LALISA - Lisa',
        bio: 'BLACKPINK LISA Official',
        debut: 'Aug 8, 2016',
        agency: 'YG Entertainment',
        postCount: '90',
        followersCount: '95M',
        followingCount: '0',
        gridImages: [
          'https://picsum.photos/id/302/400/400',
          'https://picsum.photos/id/303/400/400',
        ],
        likes: 100,
        comments: 20,
        shares: 60,
        isVideo: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Post(
        id: 'mock4',
        username: 'Sana_Twice',
        profilePic: 'https://tse1.mm.bing.net/th/id/OIP.W3CG3nj8dlpLtB-ReRLsqgHaNK?rs=1&pid=ImgDetMain',
        timestamp: '6h',
        imageUrl: 'https://picsum.photos/id/301/800/600',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
        caption: 'Hi Everyone ♡♡ #Sana #Twice',
        audioName: 'Signal - Twice',
        bio: 'No Sana No Life! ✨',
        debut: 'Oct 20, 2015',
        agency: 'JYP Entertainment',
        postCount: '13',
        followersCount: '15M',
        followingCount: '92',
        gridImages: ['https://picsum.photos/id/201/400/400'],
        likes: 20,
        comments: 50,
        shares: 10,
        isVideo: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      Post(
        id: 'mock5',
        username: 'Jungkook_BTS',
        profilePic: 'https://tse3.mm.bing.net/th/id/OIP.VgEyhgOgxNV1HoJxyyoBNwHaO0?rs=1&pid=ImgDetMain&o=7&rm=3',
        timestamp: '8h',
        imageUrl: 'https://picsum.photos/id/301/800/600',
        videoUrl: 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
        caption: 'Focus on the music. 🥁 #JK #Seven',
        audioName: 'Seven - BTS',
        bio: 'Jungkook Official',
        debut: 'Aug 8, 2013',
        agency: 'HYBE Entertainment',
        postCount: '5',
        followersCount: '84M',
        followingCount: '7',
        gridImages: [
          'https://picsum.photos/id/302/400/400',
          'https://picsum.photos/id/303/400/400',
        ],
        likes: 30,
        comments: 40,
        shares: 20,
        isVideo: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
    ];
  }

  // New method to delete a post by its ID
  static Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final postDoc = await postRef.get();

    if (postDoc.exists) {
      final postData = postDoc.data() as Map<String, dynamic>;
      // Check if the current user is the owner of the post
      if (postData['userId'] == user.uid) {
        // Delete the post document
        await postRef.delete();

        // Optionally, delete related comments
        final commentsRef = postRef.collection('comments');
        final commentsSnapshot = await commentsRef.get();
        final batch = _firestore.batch();
        for (var commentDoc in commentsSnapshot.docs) {
          batch.delete(commentDoc.reference);
        }
        await batch.commit();

        // Decrement user's post count
        await _firestore.collection('users').doc(user.uid).update({
          'postCount': FieldValue.increment(-1),
        });

        // Trigger UI update
        syncNotifier.value++;
      } else {
        // Optionally handle unauthorized deletion attempt
        debugPrint('User not authorized to delete this post.');
      }
    }
  }
}