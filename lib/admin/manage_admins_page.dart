// In manage_admins_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_admin_page.dart'; // MODIFIED: Import the new edit page

class ManageAdminsPage extends StatelessWidget {
  // ... The _deleteSubadmin and _showDeleteConfirmation functions remain the same ...
  Future<void> _deleteSubadmin(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance.collection('subadmins').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subadmin deleted successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete subadmin: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context, String docId, String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Text('Do you want to permanently delete the subadmin "$username"?'),
        actions: <Widget>[
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Yes, Delete'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteSubadmin(context, docId);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... The DefaultTabController and Scaffold remain the same ...
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Admins'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Admins', icon: Icon(Icons.shield)),
              Tab(text: 'Subadmins', icon: Icon(Icons.security)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUserList(
              collection: 'admin',
              canDelete: false, 
            ),
            _buildUserList(
              collection: 'subadmins',
              canDelete: true, 
              onDelete: (docId, username) => _showDeleteConfirmation(context, docId, username),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODIFIED: The _buildUserList widget ---
  Widget _buildUserList({
    required String collection,
    required bool canDelete,
    Function(String, String)? onDelete,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('An error occurred: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No users found in this category.'));
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final userData = user.data() as Map<String, dynamic>;
            final username = userData['username'] ?? 'No username';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: Icon(
                  canDelete ? Icons.security : Icons.shield,
                  color: canDelete ? Colors.blueAccent : Colors.green,
                ),
                title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- NEW: Edit Button ---
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EditAdminPage(
                              docId: user.id,
                              currentUsername: username,
                              collectionName: collection,
                            ),
                          ),
                        );
                      },
                    ),
                    // Show delete button only if canDelete is true
                    if (canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        onPressed: () => onDelete?.call(user.id, username),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}