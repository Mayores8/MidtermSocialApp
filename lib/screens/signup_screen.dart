import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// SignUpScreen allows new users to create an account with email, password, and profile info.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Form key to validate form fields
  final _formKey = GlobalKey<FormState>();

  // Controllers for text input fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _usernameController = TextEditingController();

  // Selected gender, defaults to "Male"
  String _gender = "Male";

  // Loading indicator flag
  bool _isLoading = false;

  // Password visibility toggle
  bool _obscurePassword = true;

  /// Opens a date picker to select birthday
  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000), // default date shown
      firstDate: DateTime(1950),   // earliest selectable date
      lastDate: DateTime.now(),    // latest selectable date
    );
    if (picked != null) {
      // Format selected date as "March 24, 2026" and set to text field
      setState(() => _birthdayController.text = DateFormat('MMMM dd, yyyy').format(picked));
    }
  }

  /// Handles the sign-up logic: validation, auth, Firestore storage
  Future<void> _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true); // Show loading indicator

      try {
        // -----------------------------
        // Step 1: Check if username is already taken
        // -----------------------------
        final usernameCheck = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: _usernameController.text.trim())
            .get();

        if (usernameCheck.docs.isNotEmpty) {
          // Throw FirebaseAuthException to handle in catch block
          throw FirebaseAuthException(
            code: 'username-taken',
            message: 'Username is already taken',
          );
        }

        // -----------------------------
        // Step 2: Create user in Firebase Auth
        // -----------------------------
        UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Format the join date as "March 2026"
        String joinDate = DateFormat('MMMM yyyy').format(DateTime.now());

        // -----------------------------
        // Step 3: Save user details to Firestore
        // -----------------------------
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'fullName': _nameController.text.trim(),
          'username': _usernameController.text.trim(),
          'birthday': _birthdayController.text,
          'gender': _gender,
          'joinDate': joinDate,
          'email': _emailController.text.trim(),
          'bio': 'Just joined K-STAR! ✨',
          'profileImage': 'https://i.pravatar.cc/150?u=${cred.user!.uid}',
          'followers': [],       // initially empty list
          'following': [],       // initially empty list
          'followersCount': 0,
          'followingCount': 0,
          'postCount': 0,
          'isArtist': false,    // default new user is not an artist
          'createdAt': FieldValue.serverTimestamp(),
        });

        // -----------------------------
        // Step 4: Success feedback
        // -----------------------------
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Account Created! Please Login."),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Go back to login screen
        }
      }
      on FirebaseAuthException catch (e) {
        // -----------------------------
        // Handle common Firebase auth errors
        // -----------------------------
        String message = e.message ?? "Error occurred";

        if (e.code == 'email-already-in-use') {
          message = "Email is already registered.";
        } else if (e.code == 'weak-password') {
          message = "Password is too weak.";
        } else if (e.code == 'username-taken') {
          message = "Username is already taken.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
      catch (e) {
        // Catch-all for any other error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
      finally {
        // Remove loading indicator
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark theme background
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
        child: Form(
          key: _formKey, // Attach form key for validation
          child: Column(
            children: [
              // -----------------------------
              // Screen title
              // -----------------------------
              const Text(
                "Sign Up",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              // -----------------------------
              // Username field
              // -----------------------------
              TextFormField(
                controller: _usernameController,
                decoration: _inputDeco("Username", Icons.alternate_email),
                style: const TextStyle(color: Colors.white),
                validator: (v) {
                  if (v!.isEmpty) return "Enter username";  // Empty check
                  if (v.contains(' ')) return "No spaces allowed"; // Space check
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // -----------------------------
              // Full Name field
              // -----------------------------
              TextFormField(
                controller: _nameController,
                decoration: _inputDeco("Full Name", Icons.person),
                style: const TextStyle(color: Colors.white),
                validator: (v) => v!.isEmpty ? "Enter name" : null,
              ),
              const SizedBox(height: 16),

              // -----------------------------
              // Birthday field (read-only)
              // -----------------------------
              TextFormField(
                controller: _birthdayController,
                readOnly: true,
                onTap: _selectDate, // opens date picker
                decoration: _inputDeco("Birthday", Icons.calendar_today),
                style: const TextStyle(color: Colors.white),
                validator: (v) => v!.isEmpty ? "Select birthday" : null,
              ),
              const SizedBox(height: 16),

              // -----------------------------
              // Email field
              // -----------------------------
              TextFormField(
                controller: _emailController,
                decoration: _inputDeco("Email", Icons.email),
                style: const TextStyle(color: Colors.white),
                validator: (v) {
                  if (v!.isEmpty) return "Enter email"; // Empty check
                  if (!v.contains('@')) return "Enter valid email"; // simple validation
                  return null;
                },
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // -----------------------------
              // Password field
              // -----------------------------
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword, // hide/show password
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.pink),
                  ),
                  prefixIcon: const Icon(Icons.lock, color: Colors.grey),
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
              const SizedBox(height: 20),

              // -----------------------------
              // Gender selection
              // -----------------------------
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Gender", style: TextStyle(color: Colors.white)),
              ),
              Row(
                children: [
                  Radio(
                    value: "Male",
                    groupValue: _gender,
                    onChanged: (v) => setState(() => _gender = v!),
                    activeColor: Colors.pink,
                  ),
                  const Text("Male", style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 20),
                  Radio(
                    value: "Female",
                    groupValue: _gender,
                    onChanged: (v) => setState(() => _gender = v!),
                    activeColor: Colors.pink,
                  ),
                  const Text("Female", style: TextStyle(color: Colors.white)),
                  const SizedBox(width: 20),
                  Radio(
                    value: "Other",
                    groupValue: _gender,
                    onChanged: (v) => setState(() => _gender = v!),
                    activeColor: Colors.pink,
                  ),
                  const Text("Other", style: TextStyle(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 30),

              // -----------------------------
              // Sign Up button
              // -----------------------------
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSignUp, // disable when loading
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Sign Up",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),

              // -----------------------------
              // Login navigation link
              // -----------------------------
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Already have an account? Login",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Input decoration helper for consistent styling
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