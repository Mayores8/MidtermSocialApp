import 'dart:io'; // For handling files (images/videos) from device storage
import 'package:flutter/material.dart'; // Flutter UI framework
import 'package:image_picker/image_picker.dart'; // For picking images/videos from gallery or camera
import '../services/api_service.dart'; // Custom service to handle API calls (like creating a post)

// Stateful widget to handle the "Create Post" screen
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  // Controllers for text input fields
  final TextEditingController _captionController = TextEditingController(); // For post/reel caption
  final TextEditingController _urlController = TextEditingController(); // For optional media URL

  bool _isReelMode = false; // Flag to toggle between photo post and video reel
  File? _selectedMediaFile; // Stores the selected image or video file
  final ImagePicker _picker = ImagePicker(); // Instance of ImagePicker to pick media
  bool _isLoading = false; // Flag to indicate loading state during API calls

  // Function to pick media from gallery
  Future<void> _pickMedia(bool isVideo) async {
    final XFile? media = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, // Reduce image quality for performance
    );

    // If a media file is selected, update the state
    if (media != null) {
      setState(() {
        _isReelMode = isVideo; // Set mode (photo or reel)
        _selectedMediaFile = File(media.path); // Save the selected file
      });
    }
  }

  // Function to capture media using the camera
  Future<void> _pickFromCamera() async {
    final XFile? media = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear, // Use rear camera by default
    );

    // If media is captured, update the state
    if (media != null) {
      setState(() {
        _selectedMediaFile = File(media.path);
      });
    }
  }

  // Function to handle the creation of a post/reel
  Future<void> _handlePost() async {
    // Validation: ensure either media or URL is provided
    if (_selectedMediaFile == null && _urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select media or enter URL")),
      );
      return;
    }

    setState(() => _isLoading = true); // Show loading indicator

    try {
      // Use URL if provided, otherwise use a placeholder image
      final imageUrl = _urlController.text.isNotEmpty
          ? _urlController.text
          : 'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/800/600';

      // Call the API service to create the post/reel
      await ApiService.createPost(
        imageUrl: imageUrl,
        caption: _captionController.text,
        isVideo: _isReelMode,
        audioName: _isReelMode ? 'Original Audio' : null, // Only for reels
      );

      // After successful post creation, show confirmation and navigate back
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.pink,
            content: Text(_isReelMode ? "Reel published!" : "Post published!"),
          ),
        );
      }
    } catch (e) {
      // Show error if API call fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false); // Hide loading indicator
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isReelMode ? 'New Reel' : 'New Post'), // AppBar title based on mode
        backgroundColor: Colors.black,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2), // Loading indicator
            )
          else
            TextButton(
              onPressed: _handlePost, // Trigger post/reel creation
              child: const Text('POST',
                  style: TextStyle(color: Colors.pink, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Display selected media preview if available
            if (_selectedMediaFile != null)
              Container(
                width: double.infinity,
                height: 350,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(
                    image: FileImage(_selectedMediaFile!), // Show selected image/video
                    fit: BoxFit.cover,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    onPressed: () => setState(() => _selectedMediaFile = null), // Remove selected media
                  ),
                ),
              )
            else
              Column(
                children: [
                  // Input for media URL
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Or paste image/video URL...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.link, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Option to select media from gallery or camera
                  GestureDetector(
                    onTap: () => _pickMedia(_isReelMode), // Tap to pick media from gallery
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isReelMode ? Icons.video_call : Icons.add_a_photo,
                              size: 60, color: Colors.grey),
                          const SizedBox(height: 10),
                          const Text("Tap to select from gallery",
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _pickFromCamera, // Capture new photo from camera
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("Take Photo"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // Input for caption
            TextField(
              controller: _captionController,
              maxLines: 4, // Allow multiline caption
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "What's on your mind? ♡",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Toggle buttons for switching between photo post and video reel
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _isReelMode = false),
                    icon: const Icon(Icons.image),
                    label: const Text("Photo Post"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isReelMode ? Colors.pink : Colors.white10,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _isReelMode = true),
                    icon: const Icon(Icons.video_collection),
                    label: const Text("Video Reel"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isReelMode ? Colors.pink : Colors.white10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}