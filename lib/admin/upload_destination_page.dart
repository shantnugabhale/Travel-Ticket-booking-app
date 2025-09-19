import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 

class UploadDestinationPage extends StatefulWidget {
  const UploadDestinationPage({super.key});

  @override
  State<UploadDestinationPage> createState() => _UploadDestinationPageState();
}

class _UploadDestinationPageState extends State<UploadDestinationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _currencyController = TextEditingController();
  final _safetyRatingController = TextEditingController();
  final _activitiesController = TextEditingController();
  final _imageUrlController = TextEditingController();

  List<TextEditingController> _highlightControllers = [TextEditingController()];

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _imageUrlController.clear();
      });
    }
  }

  // The _uploadPost and dispose methods remain the same as before.
  // No changes are needed in the logic, only in the UI.

  Future<void> _uploadPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_imageFile == null && _imageUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image OR provide an image URL.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String downloadUrl; 

      if (_imageFile != null) {
        final fileName = 'destinations/${DateTime.now().millisecondsSinceEpoch}.png';
        final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        final UploadTask uploadTask = storageRef.putFile(_imageFile!);
        final TaskSnapshot taskSnapshot = await uploadTask;
        downloadUrl = await taskSnapshot.ref.getDownloadURL();
      } else {
        downloadUrl = _imageUrlController.text.trim();
      }

      final List<String> popularActivities = _activitiesController.text.split(',').map((e) => e.trim()).toList();
      final List<String> mustSeeHighlights = _highlightControllers.map((controller) => controller.text.trim()).where((text) => text.isNotEmpty).toList();

      await FirebaseFirestore.instance.collection('destinations').add({
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl': downloadUrl,
        'budget': {
          'averageDaily': int.tryParse(_budgetController.text.trim()) ?? 0,
          'currency': _currencyController.text.trim().toUpperCase(),
        },
        'safetyRating': double.tryParse(_safetyRatingController.text.trim()) ?? 0.0,
        'popularActivities': popularActivities,
        'mustSeeHighlights': mustSeeHighlights,
        'createdAt': Timestamp.now(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destination uploaded successfully!'), backgroundColor: Colors.green),
      );
      if(mounted) Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _currencyController.dispose();
    _safetyRatingController.dispose();
    _activitiesController.dispose();
    _imageUrlController.dispose();
    for (var controller in _highlightControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Destination')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- MODIFIED: Image Picker and Previewer ---
              GestureDetector(
                onTap: _pickImage, // You can still tap to get gallery option
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImagePreview(), // Using a helper function for clarity
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(child: Text("OR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),

              // --- MODIFIED: Image URL Field ---
              TextFormField(
                controller: _imageUrlController,
                decoration: InputDecoration(
                  labelText: 'Paste Image URL',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (value) {
                  // When user types in this field, clear the picked file and rebuild the UI
                  if (value.trim().isNotEmpty) {
                    setState(() { _imageFile = null; });
                  } else {
                    setState(() {}); // Rebuild to remove image if URL is cleared
                  }
                },
              ),
              const SizedBox(height: 24),

              // The rest of the form fields...
              _buildTextFormField(controller: _nameController, label: 'Destination Name (e.g., Tokyo, Japan)'),
              _buildTextFormField(controller: _locationController, label: 'Location (e.g., Tokyo, Japan)'),
              _buildTextFormField(controller: _descriptionController, label: 'Description', maxLines: 5),
              _buildTextFormField(controller: _budgetController, label: 'Average Daily Budget', keyboardType: TextInputType.number),
              _buildTextFormField(controller: _currencyController, label: 'Currency (e.g., JPY)'),
              _buildTextFormField(controller: _safetyRatingController, label: 'Safety Rating (e.g., 9.5)', keyboardType: TextInputType.numberWithOptions(decimal: true)),
              _buildTextFormField(controller: _activitiesController, label: 'Popular Activities (comma-separated)'),
              const SizedBox(height: 24),
              Text('Must-See Highlights', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _highlightControllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTextFormField(
                            controller: _highlightControllers[index],
                            label: 'Highlight #${index + 1}',
                            isHighlight: true,
                          ),
                        ),
                        if (_highlightControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _highlightControllers[index].dispose();
                                _highlightControllers.removeAt(index);
                              });
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Highlight'),
                onPressed: () {
                  setState(() {
                    _highlightControllers.add(TextEditingController());
                  });
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _uploadPost,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: const Text('Upload Post'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Helper widget to decide which image to show
  Widget _buildImagePreview() {
    final imageUrl = _imageUrlController.text.trim();

    if (_imageFile != null) {
      // Priority 1: Show the picked image file
      return Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity);
    } else if (imageUrl.isNotEmpty) {
      // Priority 2: Show the image from the URL
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        // Show a loading indicator while the image is fetching
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        // Show an error icon if the URL is invalid
        errorBuilder: (context, error, stackTrace) {
          return const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 50),
              SizedBox(height: 8),
              Text('Invalid Image URL', textAlign: TextAlign.center),
            ],
          );
        },
      );
    } else {
      // Default: Show the placeholder
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 50, color: Colors.grey),
            Text('Tap to select an image file'),
          ],
        ),
      );
    }
  }

  Widget _buildTextFormField({required TextEditingController controller, required String label, int maxLines = 1, TextInputType? keyboardType, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (!isHighlight && (value == null || value.isEmpty)) {
            return 'This field cannot be empty';
          }
          return null;
        },
      ),
    );
  }
}