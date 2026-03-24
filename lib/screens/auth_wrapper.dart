import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import 'login_screen.dart';
import '../services/api_service.dart';

/// AuthWrapper: A widget that manages the high-level navigation state of the app.
/// It decides between the Login screen and the Main app content.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. STREAMBUILDER: Listens to the user's authentication state in real-time.
    // authStateChanges() fires a new event whenever a user logs in or out.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // --- STEP 1: LOADING STATE ---
        // While Firebase is still checking the initial connection (token validation)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.pink)),
          );
        }

        // --- STEP 2: USER IS LOGGED IN ---
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;

          // 2. FUTUREBUILDER: Once we know the user is authenticated, we fetch
          // their specific profile details from the 'users' collection in Firestore.
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, userSnapshot) {

              // While the app is waiting for the Firestore database response
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator(color: Colors.pink)),
                );
              }

              // --- DATA INITIALIZATION & FALLBACKS ---
              // These variables hold default values in case the user's Firestore
              // document hasn't been created yet or is missing fields.
              String userName = "K-Star Fan";
              String birthday = "Not Set";
              String joinDate = "Joined 2024";
              String profileImage = "https://i.pravatar.cc/150?u=${user.uid}";

              // If the Firestore document actually exists, extract the data
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final data = userSnapshot.data!.data() as Map<String, dynamic>;

                // Update local variables with actual data from the database
                userName = data['fullName'] ?? userName;
                birthday = data['birthday'] ?? birthday;
                joinDate = data['joinDate'] ?? joinDate;
                profileImage = data['profileImage'] ?? profileImage;

                // Sync the global ApiService so other screens can easily access
                // the current user's info without re-fetching from Firestore.
                ApiService.currentUserData = data;
              }

              // Finally, navigate the user to the Main App interface
              return MainNavigation(
                userName: userName,
                birthday: birthday,
                joinDate: joinDate,
              );
            },
          );
        }

        // --- STEP 3: USER IS NOT LOGGED IN ---
        // If the snapshot has no data, it means the user is logged out or a guest.
        return const LoginScreen();
      },
    );
  }
}