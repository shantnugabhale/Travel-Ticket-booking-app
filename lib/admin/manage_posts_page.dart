import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'edit_destination_page.dart';

class ManagePostsPage extends StatelessWidget {
  const ManagePostsPage({super.key});

  // **MODIFIED: This function is now more robust and handles errors correctly.**
  Future<void> _deletePost(BuildContext context, DocumentSnapshot post) async {
    try {
      // Safely access the post data.
      final postData = post.data() as Map<String, dynamic>?;

      // 1. Check if an imageUrl exists and is a valid Firebase Storage URL.
      if (postData != null && postData.containsKey('imageUrl')) {
        final imageUrl = postData['imageUrl'] as String;
        if (imageUrl.startsWith('https://firebasestorage.googleapis.com')) {
          try {
            // Attempt to delete the image from Firebase Storage.
            await FirebaseStorage.instance.refFromURL(imageUrl).delete();
          } catch (e) {
            // If image deletion fails, print an error but continue to delete the post.
            debugPrint("Could not delete image from Storage: $e");
          }
        }
      }

      // 2. Delete the document from Firestore. This will run even if image deletion fails.
      await FirebaseFirestore.instance.collection('destinations').doc(post.id).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Post deleted successfully!'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      // Catch any other errors during the process.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to delete post: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context, DocumentSnapshot post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to permanently delete this post?'),
        actions: <Widget>[
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deletePost(context, post);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Posts'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('destinations')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('An error occurred: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No posts found.'));
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final postData = post.data() as Map<String, dynamic>;

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(postData['imageUrl'] ?? ''),
                  ),
                  title: Text(postData['name'] ?? 'No Name'),
                  subtitle: Text(postData['location'] ?? 'No Location'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  EditDestinationPage(post: post),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteConfirmation(context, post),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}