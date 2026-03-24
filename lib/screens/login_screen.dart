import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase authentication
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore for user data
import 'signup_screen.dart'; // Navigation to signup screen
import '../main.dart'; // Access global state (if needed)
import '../services/api_service.dart'; // For caching user info and followed artists

// Stateful widget for the login screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // Form key for validation
  final _emailController = TextEditingController(); // Controller for email input
  final _passwordController = TextEditingController(); // Controller for password input
  bool _isLoading = false; // Flag to show loading spinner
  bool _obscurePassword = true; // Controls password visibility

  // Function to handle login
  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) { // Validate form fields
      setState(() => _isLoading = true); // Show loading indicator
      try {
        // Sign in with Firebase Authentication
        UserCredential cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Fetch user data from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .get();

        if (userDoc.exists && mounted) {
          final userData = userDoc.data() as Map<String, dynamic>;

          // Cache user data in ApiService
          ApiService.currentUserData = userData;

          // Cache followed artists
          final following = List<String>.from(userData['following'] ?? []);
          ApiService.followedArtists = Set<String>.from(following);

          // Navigate to main navigation screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainNavigation(
                userName: userData['fullName'] ?? 'User',
                birthday: userData['birthday'] ?? 'N/A',
                joinDate: userData['joinDate'] ?? 'Unknown',
              ),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        // Handle login errors
        String message = e.message ?? "Login failed";
        if (e.code == 'user-not-found') {
          message = "No user found with this email.";
        } else if (e.code == 'wrong-password') {
          message = "Wrong password provided.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false); // Hide loading indicator
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark-themed background
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
        child: Form(
          key: _formKey, // Assign form key
          child: Column(
            children: [
              // App logo / icon
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.pink, width: 2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    "K\nSTAR",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.pink,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Login",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // Email input
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco("Email", Icons.email),
                validator: (v) => v!.isEmpty ? "Enter email" : null,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password input
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword, // Hide password text
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                  // Toggle password visibility
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.pink,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => v!.length < 6 ? "Minimum 6 characters" : null,
              ),
              const SizedBox(height: 30),

              // Login button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin, // Disable while loading
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Log In", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
              const SizedBox(height: 20),

              // Navigate to signup screen
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const SignUpScreen()),
                ),
                child: const Text(
                  "Don't have an account? Sign up",
                  style: TextStyle(color: Colors.pink),
                ),
              ),

              // Fill demo credentials for testing
              TextButton(
                onPressed: () {
                  _emailController.text = "demo@kstar.app";
                  _passwordController.text = "password123";
                },
                child: const Text(
                  "Fill demo credentials",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Input decoration helper function
  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      labelStyle: const TextStyle(color: Colors.grey),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.pink),
      ),
    );
  }
}