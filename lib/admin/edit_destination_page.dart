import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditDestinationPage extends StatefulWidget {
  final DocumentSnapshot post;

  const EditDestinationPage({super.key, required this.post});

  @override
  State<EditDestinationPage> createState() => _EditDestinationPageState();
}

class _EditDestinationPageState extends State<EditDestinationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  late TextEditingController _budgetController;
  late TextEditingController _currencyController;
  late TextEditingController _safetyRatingController;
  late TextEditingController _activitiesController;
  late TextEditingController _imageUrlController;
  late List<TextEditingController> _highlightControllers;

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final data = widget.post.data() as Map<String, dynamic>;

    // Pre-fill controllers with existing data
    _nameController = TextEditingController(text: data['name']);
    _locationController = TextEditingController(text: data['location']);
    _descriptionController = TextEditingController(text: data['description']);
    _budgetController = TextEditingController(text: data['budget']['averageDaily']?.toString() ?? '');
    _currencyController = TextEditingController(text: data['budget']['currency']);
    _safetyRatingController = TextEditingController(text: data['safetyRating']?.toString() ?? '');
    _activitiesController = TextEditingController(text: (data['popularActivities'] as List).join(', '));
    _imageUrlController = TextEditingController(text: data['imageUrl']);
    _highlightControllers = (data['mustSeeHighlights'] as List)
        .map((highlight) => TextEditingController(text: highlight.toString()))
        .toList();
    if (_highlightControllers.isEmpty) {
      _highlightControllers.add(TextEditingController());
    }
  }
  
  // The dispose method needs to be updated to handle all the controllers.
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

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _imageUrlController.clear();
      });
    }
  }

  Future<void> _updatePost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _isLoading = true; });

    try {
      String downloadUrl = _imageUrlController.text.trim();

      // If a new image was picked, upload it and delete the old one
      if (_imageFile != null) {
        // Delete old image from storage
        final oldImageUrl = widget.post['imageUrl'] as String;
        await FirebaseStorage.instance.refFromURL(oldImageUrl).delete();

        // Upload new image
        final fileName = 'destinations/${DateTime.now().millisecondsSinceEpoch}.png';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putFile(_imageFile!);
        downloadUrl = await ref.getDownloadURL();
      }

      // Prepare data for update
      final List<String> popularActivities = _activitiesController.text.split(',').map((e) => e.trim()).toList();
      final List<String> mustSeeHighlights = _highlightControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

      // Update the document in Firestore
      await FirebaseFirestore.instance.collection('destinations').doc(widget.post.id).update({
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
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post updated successfully!'), backgroundColor: Colors.green),
      );
      if(mounted) Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update post: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  // The build method for the UI is nearly identical to the Upload Page,
  // but it uses the controllers pre-filled in initState.
  // We'll just change the AppBar title and the button text/function.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Destination')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // This UI part is the same as the upload page,
              // it will just be pre-filled with data.
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImagePreview(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(child: Text("OR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),

              TextFormField(
                controller: _imageUrlController,
                decoration: InputDecoration(
                  labelText: 'Paste Image URL',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (value) {
                  if (value.trim().isNotEmpty) {
                    setState(() { _imageFile = null; });
                  } else {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 24),
              
              // ... All other TextFormFields and the dynamic highlight builder ...
              // They will automatically use the pre-filled controllers.
              _buildTextFormField(controller: _nameController, label: 'Destination Name'),
              _buildTextFormField(controller: _locationController, label: 'Location'),
              _buildTextFormField(controller: _descriptionController, label: 'Description', maxLines: 5),
              _buildTextFormField(controller: _budgetController, label: 'Average Daily Budget', keyboardType: TextInputType.number),
              _buildTextFormField(controller: _currencyController, label: 'Currency'),
              _buildTextFormField(controller: _safetyRatingController, label: 'Safety Rating', keyboardType: TextInputType.numberWithOptions(decimal: true)),
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

              // --- Submit Button ---
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _updatePost, // Call update function
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: const Text('Save Changes'), // Changed text
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _buildImagePreview() {
    final imageUrl = _imageUrlController.text.trim();

    if (_imageFile != null) {
      return Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity);
    } else if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.error)),
      );
    } else {
      return const Center(child: Icon(Icons.camera_alt, size: 50, color: Colors.grey));
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
