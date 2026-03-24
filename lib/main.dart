import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart'; // Firebase configuration options
import 'screens/home_screen.dart';
import 'screens/reels_screen.dart';
import 'screens/following_screen.dart';
import 'screens/search_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/auth_wrapper.dart';
import '../services/api_service.dart';

// Global theme notifier
ValueNotifier<bool> isDarkMode = ValueNotifier(true);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize API service with user data
  await ApiService.initializeUser();

  // Run the app
  runApp(const KStarApp());
}

class KStarApp extends StatelessWidget {
  const KStarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, darkMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: Colors.white,
            primaryColor: const Color(0xFFE91E63),
            textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.black)),
          ),
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF121212),
            primaryColor: const Color(0xFFE91E63),
            textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
          ),
          themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  final String userName;
  final String birthday;
  final String joinDate;

  const MainNavigation({
    super.key,
    required this.userName,
    required this.birthday,
    required this.joinDate,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const HomeScreen(),
      const ReelsScreen(),
      const FollowingScreen(),
      const SearchScreen(),
      UserProfileScreen(
        userName: widget.userName,
        birthday: widget.birthday,
        joinDate: widget.joinDate,
      ),
    ];

    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, darkMode, child) {
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.pink,
            unselectedItemColor: darkMode ? Colors.white70 : Colors.black54,
            backgroundColor: darkMode ? Colors.black : Colors.white,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.play_circle_outline), label: 'Reels'),
              BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'Following'),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}