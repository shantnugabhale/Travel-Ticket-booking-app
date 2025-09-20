import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class UploadDestinationPage extends StatefulWidget {
  const UploadDestinationPage({super.key});

  @override
  State<UploadDestinationPage> createState() => _UploadDestinationPageState();
}

class _UploadDestinationPageState extends State<UploadDestinationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers for text fields
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _safetyRatingController = TextEditingController();
  final _activitiesController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _newCategoryController = TextEditingController();

  // State variables
  String? _selectedCurrency = 'INR';
  String? _selectedCategory = 'Beaches';
  DateTime? _startDate;
  DateTime? _endDate;
  // **NEW: State variable for the featured switch**
  bool _isFeatured = false;

  List<TextEditingController> _highlightControllers = [TextEditingController()];
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _safetyRatingController.dispose();
    _activitiesController.dispose();
    _imageUrlController.dispose();
    _newCategoryController.dispose();
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

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? (_startDate ?? DateTime.now()) : (_endDate ?? _startDate ?? DateTime.now());
    final firstDate = isStartDate ? DateTime.now() : (_startDate ?? DateTime.now());

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(DateTime.now().year + 5),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }

  Future<void> _uploadPost() async {
    if (!_formKey.currentState!.validate() || _startDate == null || _endDate == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all required fields, including dates and category.'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (_imageFile == null && _imageUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select an image OR provide an image URL.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() { _isLoading = true; });

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

      final List<String> popularActivities =
          _activitiesController.text.split(',').map((e) => e.trim()).toList();
      final List<String> mustSeeHighlights = _highlightControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      final String categoryToSave = _selectedCategory == 'Other'
          ? _newCategoryController.text.trim()
          : _selectedCategory!;

      await FirebaseFirestore.instance.collection('destinations').add({
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl': downloadUrl,
        'budget': int.tryParse(_budgetController.text.trim()) ?? 0,
        'currency': _selectedCurrency,
        'safetyRating':
            double.tryParse(_safetyRatingController.text.trim()) ?? 0.0,
        'popularActivities': popularActivities,
        'mustSeeHighlights': mustSeeHighlights,
        'category': categoryToSave,
        // **NEW: Save the featured status to Firestore**
        'isFeatured': _isFeatured,
        'tripStartDate': Timestamp.fromDate(_startDate!),
        'tripEndDate': Timestamp.fromDate(_endDate!),
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Destination uploaded successfully!'),
            backgroundColor: Colors.green),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to upload: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
              _buildImagePickerSection(),
              const SizedBox(height: 24),
              _buildTextFormField(
                  controller: _nameController,
                  label: 'Destination Name'),
              _buildTextFormField(
                  controller: _locationController,
                  label: 'Location'),
              _buildTextFormField(
                  controller: _descriptionController,
                  label: 'Description',
                  maxLines: 5),
              const SizedBox(height: 8),
              _buildCategoryDropdown(),
              if (_selectedCategory == 'Other')
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: _buildTextFormField(
                    controller: _newCategoryController,
                    label: 'Enter New Category',
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildDatePickerField(isStartDate: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDatePickerField(isStartDate: false)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextFormField(
                        controller: _budgetController,
                        label: 'Budget',
                        keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCurrencyDropdown()),
                ],
              ),
              _buildTextFormField(
                  controller: _safetyRatingController,
                  label: 'Safety Rating (e.g., 9.5)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true)),
              _buildTextFormField(
                  controller: _activitiesController,
                  label: 'Popular Activities (comma-separated)'),
              
              // **NEW: Featured Destination Switch**
              const SizedBox(height: 8),
              _buildFeaturedSwitch(),

              const SizedBox(height: 24),
              _buildHighlightsSection(),
              const SizedBox(height: 24),
              _buildUploadButton(),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Widgets

  Widget _buildImagePickerSection() {
    return Column(
      children: [
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
              setState(() => _imageFile = null);
            } else {
              setState(() {});
            }
          },
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: ['Beaches', 'Mountains', 'Cities', 'Forests', 'Hiking', 'Other']
          .map((String category) {
        return DropdownMenuItem<String>(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedCategory = newValue;
        });
      },
      validator: (value) => value == null ? 'Required' : null,
    );
  }

  Widget _buildDatePickerField({required bool isStartDate}) {
    final date = isStartDate ? _startDate : _endDate;
    final label = isStartDate ? 'From' : 'To';
    final hint = isStartDate ? 'Start Date' : 'End Date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context, isStartDate),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date == null ? hint : DateFormat('dd MMM yyyy').format(date),
                  style: TextStyle(
                    fontSize: 16,
                    color: date == null ? Colors.grey.shade600 : Colors.black,
                  ),
                ),
                const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCurrency,
      decoration: InputDecoration(
        labelText: 'Currency',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: ['INR', 'USD', 'EUR', 'GBP'].map((String currency) {
        return DropdownMenuItem<String>(value: currency, child: Text(currency));
      }).toList(),
      onChanged: (String? newValue) {
        setState(() => _selectedCurrency = newValue);
      },
      validator: (value) => value == null ? 'Required' : null,
    );
  }
  
  Widget _buildFeaturedSwitch() {
    return SwitchListTile(
      title: const Text('Mark as Featured'),
      subtitle: const Text('Featured destinations appear on the home screen.'),
      value: _isFeatured,
      onChanged: (bool value) {
        setState(() {
          _isFeatured = value;
        });
      },
      secondary: Icon(
        Icons.star,
        color: _isFeatured ? Colors.amber : Colors.grey,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildHighlightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          onPressed: () => setState(() => _highlightControllers.add(TextEditingController())),
        ),
      ],
    );
  }

  Widget _buildUploadButton() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ElevatedButton(
            onPressed: _uploadPost,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
            child: const Text('Upload Post'),
          );
  }

  Widget _buildImagePreview() {
    final imageUrl = _imageUrlController.text.trim();
    if (_imageFile != null) {
      return Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity);
    } else if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
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

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool isHighlight = false,
  }) {
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