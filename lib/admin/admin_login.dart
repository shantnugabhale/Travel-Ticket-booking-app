import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:trevel_booking_app/admin/admin_home_page.dart';
import 'package:trevel_booking_app/admin/subadmin_home_page.dart'; // MODIFIED: Import subadmin home page

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _loginAdmin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please enter both username and password.');
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final enteredUsername = _usernameController.text.trim();
      final enteredPassword = _passwordController.text.trim();

      // --- MODIFIED LOGIN LOGIC ---

      // 1. First, check the 'admin' collection
      var adminQuery = await FirebaseFirestore.instance
          .collection('admin')
          .where('username', isEqualTo: enteredUsername)
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        // Admin username found, check password
        final adminData = adminQuery.docs.first.data();
        if (enteredPassword == adminData['password']) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AdminHomePage()),
            );
          }
        } else {
          _showError('Invalid username or password.');
        }
        return; // Stop after checking admin
      }

      // 2. If not found in 'admin', check the 'subadmins' collection
      var subadminQuery = await FirebaseFirestore.instance
          .collection('subadmins')
          .where('username', isEqualTo: enteredUsername)
          .limit(1)
          .get();
      
      if (subadminQuery.docs.isNotEmpty) {
        // Subadmin username found, check password
        final subadminData = subadminQuery.docs.first.data();
        if (enteredPassword == subadminData['password']) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const SubadminHomePage()),
            );
          }
        } else {
          _showError('Invalid username or password.');
        }
        return; // Stop after checking subadmin
      }

      // 3. If the username was not found in either collection
      _showError('Invalid username or password.');

    } catch (e) {
      _showError('An error occurred. Please try again.');
      debugPrint('Login Error: $e');
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The UI remains the same, only the title is slightly changed for clarity.
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Portal Login"), // MODIFIED: More generic title
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            // ... The rest of your UI code is unchanged ...
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.admin_panel_settings, size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 20),
              const Text(
                "Admin Portal",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: "Username",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _loginAdmin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text("Login", style: TextStyle(fontSize: 18)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}