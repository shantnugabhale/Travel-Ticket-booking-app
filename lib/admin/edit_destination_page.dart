import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart'; // Import the intl package

class EditDestinationPage extends StatefulWidget {
  final DocumentSnapshot post;

  const EditDestinationPage({super.key, required this.post});

  @override
  State<EditDestinationPage> createState() => _EditDestinationPageState();
}

class _EditDestinationPageState extends State<EditDestinationPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  late TextEditingController _budgetController;
  late TextEditingController _safetyRatingController;
  late TextEditingController _activitiesController;
  late TextEditingController _imageUrlController;
  late List<TextEditingController> _highlightControllers;

  // State variables
  String? _selectedCurrency;
  DateTime? _startDate;
  DateTime? _endDate;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final data = widget.post.data() as Map<String, dynamic>;

    // Pre-fill controllers with existing data
    _nameController = TextEditingController(text: data['name'] ?? '');
    _locationController = TextEditingController(text: data['location'] ?? '');
    _descriptionController =
        TextEditingController(text: data['description'] ?? '');
    _budgetController =
        TextEditingController(text: (data['budget'] ?? 0).toString());
    _safetyRatingController = TextEditingController(
        text: (data['safetyRating'] ?? 0.0).toString());
    _activitiesController = TextEditingController(
        text: (data['popularActivities'] as List?)?.join(', ') ?? '');
    _imageUrlController = TextEditingController(text: data['imageUrl'] ?? '');

    // Set initial values for dropdown and dates
    _selectedCurrency = data['currency'] ?? 'INR';
    if (data['tripStartDate'] is Timestamp) {
      _startDate = (data['tripStartDate'] as Timestamp).toDate();
    }
    if (data['tripEndDate'] is Timestamp) {
      _endDate = (data['tripEndDate'] as Timestamp).toDate();
    }

    // Pre-fill highlights
    _highlightControllers = (data['mustSeeHighlights'] as List?)
            ?.map((highlight) => TextEditingController(text: highlight.toString()))
            .toList() ??
        [];
    if (_highlightControllers.isEmpty) {
      _highlightControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
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

  Future<void> _updatePost() async {
    if (!_formKey.currentState!.validate() || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields, including dates.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      String downloadUrl = _imageUrlController.text.trim();

      if (_imageFile != null) {
        final oldImageUrl = widget.post['imageUrl'] as String?;
        if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
           try {
            await FirebaseStorage.instance.refFromURL(oldImageUrl).delete();
           } catch (e) {
             debugPrint("Failed to delete old image: $e");
           }
        }
        final fileName = 'destinations/${DateTime.now().millisecondsSinceEpoch}.png';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putFile(_imageFile!);
        downloadUrl = await ref.getDownloadURL();
      }

      final List<String> popularActivities =
          _activitiesController.text.split(',').map((e) => e.trim()).toList();
      final List<String> mustSeeHighlights = _highlightControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      await FirebaseFirestore.instance
          .collection('destinations')
          .doc(widget.post.id)
          .update({
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'imageUrl': downloadUrl,
        'budget': int.tryParse(_budgetController.text.trim()) ?? 0,
        'currency': _selectedCurrency,
        'safetyRating': double.tryParse(_safetyRatingController.text.trim()) ?? 0.0,
        'popularActivities': popularActivities,
        'mustSeeHighlights': mustSeeHighlights,
        'tripStartDate': Timestamp.fromDate(_startDate!),
        'tripEndDate': Timestamp.fromDate(_endDate!),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Post updated successfully!'),
            backgroundColor: Colors.green),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update post: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

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
              _buildImagePickerSection(),
              const SizedBox(height: 24),
              _buildTextFormField(controller: _nameController, label: 'Destination Name'),
              _buildTextFormField(controller: _locationController, label: 'Location'),
              _buildTextFormField(
                  controller: _descriptionController, label: 'Description', maxLines: 5),
              const SizedBox(height: 8),
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
                  label: 'Safety Rating',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              _buildTextFormField(
                  controller: _activitiesController,
                  label: 'Popular Activities (comma-separated)'),
              const SizedBox(height: 24),
              _buildHighlightsSection(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

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

  Widget _buildSubmitButton() {
     return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ElevatedButton(
            onPressed: _updatePost,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
            child: const Text('Save Changes'),
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
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Icon(Icons.error)),
      );
    } else {
      return const Center(
          child: Icon(Icons.camera_alt, size: 50, color: Colors.grey));
    }
  }

  Widget _buildTextFormField(
      {required TextEditingController controller,
      required String label,
      int maxLines = 1,
      TextInputType? keyboardType,
      bool isHighlight = false}) {
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