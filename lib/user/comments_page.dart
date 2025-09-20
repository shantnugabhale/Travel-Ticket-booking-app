import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommentsPage extends StatefulWidget {
  final String postId;

  const CommentsPage({super.key, required this.postId});

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _commentController = TextEditingController();
  String _currentUserName = 'Guest';
  String? _currentUserId;
  String _currentUserImageUrl = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _currentUserId = user.uid;
          _currentUserName = userDoc.data()?['name'] ?? 'No Name';
          _currentUserImageUrl = userDoc.data()?['imageUrl'] ?? 'https://via.placeholder.com/150';
        });
      }
    }
  }

  Future<void> _postComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty || _currentUserId == null) return;

    final postRef = FirebaseFirestore.instance.collection('community_posts').doc(widget.postId);
    final commentRef = postRef.collection('comments');

    // Use a batch to add the comment and increment the counter atomically
    final batch = FirebaseFirestore.instance.batch();
    
    batch.set(commentRef.doc(), {
      'commentText': commentText,
      'authorName': _currentUserName,
      'authorUid': _currentUserId,
      'authorImageUrl': _currentUserImageUrl,
      'timestamp': Timestamp.now(),
    });

    batch.update(postRef, {'commentCount': FieldValue.increment(1)});

    await batch.commit();
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('community_posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final comments = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final data = comments[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(backgroundImage: NetworkImage(data['authorImageUrl'])),
                      title: Text(data['authorName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(data['commentText']),
                    );
                  },
                );
              },
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      color: Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
              onPressed: _postComment,
            ),
          ],
        ),
      ),
    );
  }
}