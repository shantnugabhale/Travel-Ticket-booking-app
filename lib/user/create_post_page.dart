import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  File? _imageFile;
  bool _imageUrlError = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _imageUrlController.clear();
        _imageUrlError = false;
      });
    }
  }

  String _formatImageUrl(String url) {
    if (url.isEmpty) return '';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'https://$url';
    }
    return url;
  }

  Future<void> _submitPost() async {
    // 1. Validate the text fields first
    if (!_formKey.currentState!.validate()) return;
    
    // 2. Check that either an image file or a URL is provided
    if (_imageFile == null && _imageUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image or provide an image URL.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Anonymous';
      final userImageUrl = userDoc.data()?['imageUrl'] ?? 'https://via.placeholder.com/150';

      // 3. Determine the final postImageUrl. This variable is non-nullable.
      String postImageUrl; 

      if (_imageFile != null) {
        // If a file was picked, upload it and get the download URL
        final fileName = 'community_posts/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putFile(_imageFile!);
        postImageUrl = await ref.getDownloadURL();
      } else {
        // Otherwise, use the URL from the text field
        postImageUrl = _formatImageUrl(_imageUrlController.text.trim());
        // Do a final validation check on the URL's format
        if (!Uri.tryParse(postImageUrl)!.hasAbsolutePath) {
          throw Exception('Invalid Image URL format.');
        }
      }

      // 4. Add the document to Firestore, now `postImageUrl` is guaranteed to have a value.
      await FirebaseFirestore.instance.collection('community_posts').add({
        'authorName': userName,
        'authorImageUrl': userImageUrl,
        'authorUid': user.uid,
        'postImageUrl': postImageUrl, // This will never be null
        'caption': _captionController.text.trim(),
        'location': _locationController.text.trim(),
        'createdAt': Timestamp.now(),
        'likedBy': [],
        'likeCount': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post shared successfully!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create post: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
  
  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.white)) : TextButton(
              onPressed: _submitPost,
              child: const Text('Share', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                  child: _buildImagePreview(),
                ),
              ),
              const SizedBox(height: 12),
              const Text("OR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrlController,
                decoration: InputDecoration(
                  labelText: 'Paste image URL here',
                  border: const OutlineInputBorder(),
                  errorText: _imageUrlError ? 'Could not load image from URL' : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _imageFile = null; 
                    _imageUrlError = false; 
                  });
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _captionController,
                decoration: const InputDecoration(labelText: 'Write a caption...', border: OutlineInputBorder()),
                maxLines: 4,
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter a caption.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter a location.' : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final rawUrl = _imageUrlController.text.trim();
    
    if (_imageFile != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_imageFile!, fit: BoxFit.cover));
    } else if (rawUrl.isNotEmpty) {
      final formattedUrl = _formatImageUrl(rawUrl);
      
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          formattedUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_imageUrlError) {
                setState(() { _imageUrlError = true; });
              }
            });
            return const Center(child: Icon(Icons.error_outline, color: Colors.red, size: 40));
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _imageUrlError) {
                  setState(() { _imageUrlError = false; });
                }
              });
              return child;
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      );
    } else {
      return const Center(child: Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.grey));
    }
  }
}