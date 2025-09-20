import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:trevel_booking_app/user/community_page.dart'; // Import for CommentsBottomSheet and CommentBubble

class ManageUserPostsPage extends StatelessWidget {
  const ManageUserPostsPage({super.key});

  // This function handles the actual deletion from Firebase.
  Future<void> _deletePost(BuildContext context, DocumentSnapshot post) async {
    try {
      final postData = post.data() as Map<String, dynamic>?;

      // 1. Delete the image from Firebase Storage if it exists.
      if (postData != null && postData.containsKey('postImageUrl')) {
        final imageUrl = postData['postImageUrl'] as String;
        if (imageUrl.startsWith('https://firebasestorage.googleapis.com')) {
          try {
            await FirebaseStorage.instance.refFromURL(imageUrl).delete();
          } catch (e) {
            // Log if image deletion fails, but don't stop the process.
            debugPrint("Could not delete image from Storage: $e");
          }
        }
      }

      // 2. Delete the post document from Firestore.
      await FirebaseFirestore.instance.collection('community_posts').doc(post.id).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('User post deleted successfully!'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to delete user post: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  // This function shows a confirmation dialog before deleting.
  void _showDeleteConfirmation(BuildContext context, DocumentSnapshot post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to permanently delete this user post?'),
        actions: <Widget>[
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deletePost(context, post); // Triggers the deletion.
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
        title: const Text('Manage User Posts'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('community_posts')
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
            return const Center(child: Text('No user posts found.'));
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemBuilder: (context, index) {
              final post = posts[index];
              return AdminCommunityPostCard(
                postDocument: post,
                onDelete: () => _showDeleteConfirmation(context, post),
              );
            },
          );
        },
      ),
    );
  }
}

// The dedicated card widget for the admin view
class AdminCommunityPostCard extends StatelessWidget {
  final DocumentSnapshot postDocument;
  final VoidCallback onDelete;

  const AdminCommunityPostCard({
    super.key,
    required this.postDocument,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = postDocument.data() as Map<String, dynamic>;
    final String authorName = data['authorName'] ?? 'Anonymous';
    final String authorImageUrl = data['authorImageUrl'] ?? '';
    final String postImageUrl = data['postImageUrl'] ?? '';
    final String caption = data['caption'] ?? '';
    final int likeCount = data['likeCount'] ?? 0;
    final int commentCount = data['commentCount'] ?? 0;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return CommentsBottomSheet(
                postId: postDocument.id,
                scrollController: scrollController,
              );
            },
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(backgroundImage: NetworkImage(authorImageUrl)),
              title: Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_formatDate((data['createdAt'] as Timestamp).toDate()), style: const TextStyle(color: Colors.grey)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: 'Delete Post',
                onPressed: onDelete, // This calls the confirmation dialog.
              ),
            ),
            Image.network(
              postImageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 300,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 300,
                color: Colors.grey[200],
                child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 50)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(caption, style: const TextStyle(fontSize: 15)),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoChip(icon: Icons.favorite, label: 'Likes ($likeCount)', color: Colors.red),
                      _buildInfoChip(icon: Icons.comment, label: 'Comments ($commentCount)', color: Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label, required Color color}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('d MMM, yyyy').format(date);
  }
}