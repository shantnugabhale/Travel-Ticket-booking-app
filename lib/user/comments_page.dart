import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _currentUserId = user.uid;
          _currentUserName = userDoc.data()?['name'] ?? 'No Name';
          _currentUserImageUrl = userDoc.data()?['imageUrl'] ?? '';
        });
      }
    }
  }

  Future<void> _postComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty || _currentUserId == null) return;

    final postRef =
        FirebaseFirestore.instance.collection('community_posts').doc(widget.postId);
    final commentRef = postRef.collection('comments');

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
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: Column(
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
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text(
                      'Be the first to comment!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ));
                  }
                  final comments = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.all(12.0),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final data = comments[index].data() as Map<String, dynamic>;
                      return CommentBubble(commentData: data);
                    },
                  );
                },
              ),
            ),
            _buildCommentInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: Theme.of(context).primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _postComment,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommentBubble extends StatefulWidget {
  final Map<String, dynamic> commentData;
  final String? commentId;
  final String? postId;
  final String? currentUserId;

  const CommentBubble({
    super.key, 
    required this.commentData,
    this.commentId,
    this.postId,
    this.currentUserId,
  });

  @override
  State<CommentBubble> createState() => _CommentBubbleState();
}

class _CommentBubbleState extends State<CommentBubble> {
  late int _likeCount;
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  void _initializeState() {
    final likedBy = widget.commentData['likedBy'] as List? ?? [];
    _likeCount = widget.commentData['likeCount'] ?? 0;
    _isLiked = widget.currentUserId != null && likedBy.contains(widget.currentUserId);
  }

  Future<void> _toggleLike() async {
    if (widget.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to like comments.')),
      );
      return;
    }

    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) _likeCount++; else _likeCount--;
    });

    // Update the comment in Firestore
    if (widget.commentId != null && widget.postId != null) {
      try {
        final commentRef = FirebaseFirestore.instance
            .collection('community_posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(widget.commentId);

        if (_isLiked) {
          commentRef.update({
            'likedBy': FieldValue.arrayUnion([widget.currentUserId]),
            'likeCount': FieldValue.increment(1),
          });
        } else {
          commentRef.update({
            'likedBy': FieldValue.arrayRemove([widget.currentUserId]),
            'likeCount': FieldValue.increment(-1),
          });
        }
      } catch (e) {
        // Revert the UI change if the backend update fails
        setState(() {
          _isLiked = !_isLiked;
          if (_isLiked) _likeCount++; else _likeCount--;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorName = widget.commentData['authorName'] ?? 'Anonymous';
    final authorImageUrl = widget.commentData['authorImageUrl'] ?? '';
    final commentText = widget.commentData['commentText'] ?? '';
    final timestamp = (widget.commentData['timestamp'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage:
                authorImageUrl.isNotEmpty ? NetworkImage(authorImageUrl) : null,
            child: authorImageUrl.isEmpty
                ? const Icon(Icons.person, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(authorName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(15),
                      bottomLeft: Radius.circular(15),
                      bottomRight: Radius.circular(15),
                    ),
                     boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 1),
                        )
                      ]
                  ),
                  child: Text(
                    commentText,
                    style: const TextStyle(color: Colors.black87, fontSize: 15.0),
                  ),
                ),
                Row(
                  children: [
                    if (timestamp != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5.0, left: 5.0),
                        child: Text(
                          DateFormat('hh:mm a, d MMM').format(timestamp),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: _isLiked ? Colors.red : Colors.grey,
                          ),
                          if (_likeCount > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '$_likeCount',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}