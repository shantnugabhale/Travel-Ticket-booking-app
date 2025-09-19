import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditAdminPage extends StatefulWidget {
  final String docId;
  final String currentUsername;
  final String collectionName; // 'admin' or 'subadmins'

  const EditAdminPage({
    super.key,
    required this.docId,
    required this.currentUsername,
    required this.collectionName,
  });

  @override
  State<EditAdminPage> createState() => _EditAdminPageState();
}

class _EditAdminPageState extends State<EditAdminPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _usernameController;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.currentUsername);
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    final newPassword = _passwordController.text;
    if (newPassword.isNotEmpty && newPassword != _confirmPasswordController.text) {
      _showError("New passwords do not match.");
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final newUsername = _usernameController.text.trim();
      final Map<String, dynamic> dataToUpdate = {'username': newUsername};

      // Check if username needs to be updated and if it's already taken
      if (newUsername != widget.currentUsername) {
        final existingUser = await FirebaseFirestore.instance
            .collection(widget.collectionName)
            .where('username', isEqualTo: newUsername)
            .limit(1)
            .get();
        if (existingUser.docs.isNotEmpty) {
          _showError("This username is already taken.");
          setState(() { _isLoading = false; });
          return;
        }
      }

      // Only update the password if a new one was entered
      if (newPassword.isNotEmpty) {
        dataToUpdate['password'] = newPassword;
      }

      // Update the document in Firestore
      await FirebaseFirestore.instance
          .collection(widget.collectionName)
          .doc(widget.docId)
          .update(dataToUpdate);

      _showSuccess("Changes saved successfully!");
      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      _showError("An error occurred: $e");
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
  
  void _showSuccess(String message) {
     if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${widget.currentUsername}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a username.' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 6) {
                    return 'Password must be at least 6 characters long.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: const Text('Save Changes'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}