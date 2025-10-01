import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth

class TipsPage extends StatefulWidget {
  const TipsPage({super.key});

  @override
  State<TipsPage> createState() => _TipsPageState();
}

class _TipsPageState extends State<TipsPage> {
  // State variables to hold the current user's data
  String? _currentUserId;
  String _currentUserName = 'Guest';
  String _currentUserImageUrl = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  // Function to get the logged-in user's data from Auth and Firestore
  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Fetch user details from 'users' collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentUserId = user.uid;
          _currentUserName = userDoc.data()?['name'] ?? 'No Name';
          // Assuming you might store an image URL in your user document
          _currentUserImageUrl = userDoc.data()?['imageUrl'] ?? '';
        });
      }
    }
  }

  // UI Logic to Show the "Add Tip" Dialog
  void _showAddTipDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String selectedCategory = 'Safety';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share a New Tip'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Tip Title'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter a title.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ['Safety', 'Budget', 'Packing', 'Solo Travel', 'Transportation']
                      .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) selectedCategory = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Your Tip'),
                  maxLines: 3,
                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter your tip.' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                // Use the fetched user data instead of placeholders
                FirebaseFirestore.instance.collection('tips').add({
                  'title': titleController.text.trim(),
                  'content': contentController.text.trim(),
                  'category': selectedCategory,
                  'authorName': _currentUserName,
                  'authorImageUrl': _currentUserImageUrl,
                  'authorUid': _currentUserId,
                  'createdAt': Timestamp.now(),
                  'likedBy': [],
                  'likeCount': 0,
                });
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Your tip has been shared!'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Tips & Blog'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tips').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tips have been shared yet. Be the first!'));
          }

          final tips = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: tips.length,
            itemBuilder: (context, index) {
              final tipDocument = tips[index];
              
              return TipCard(
                key: ValueKey(tipDocument.id),
                tipDocument: tipDocument,
                currentUserId: _currentUserId,
              );
            },
          );
        },
      ),
      // Hide the "Add Tip" button if no user is logged in
      floatingActionButton: _currentUserId == null
          ? null
          : FloatingActionButton(
              onPressed: _showAddTipDialog,
              child: const Icon(Icons.add),
              tooltip: 'Add a new tip',
            ),
    );
  }
}


// A StatefulWidget card for instant UI updates and real-time sync
class TipCard extends StatefulWidget {
  final DocumentSnapshot tipDocument;
  final String? currentUserId;

  const TipCard({super.key, required this.tipDocument, this.currentUserId});

  @override
  State<TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<TipCard> {
  late int _likeCount;
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }
  
  // This ensures the card updates if another user's like changes the data
  @override
  void didUpdateWidget(TipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tipDocument != oldWidget.tipDocument || widget.currentUserId != oldWidget.currentUserId) {
      _initializeState();
    }
  }

  void _initializeState() {
    final data = widget.tipDocument.data() as Map<String, dynamic>;
    final List<dynamic> likedBy = data['likedBy'] ?? [];
    _likeCount = data['likeCount'] ?? 0;
    _isLiked = widget.currentUserId != null && likedBy.contains(widget.currentUserId);
  }

  Future<void> _toggleLike() async {
    // Prevent liking if no user is logged in
    if (widget.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to like a tip.')),
      );
      return;
    }

    // 1. Optimistic UI Update
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) _likeCount++; else _likeCount--;
    });

    // 2. Backend Update
    final tipRef = FirebaseFirestore.instance.collection('tips').doc(widget.tipDocument.id);
    final batch = FirebaseFirestore.instance.batch();

    if (_isLiked) {
      batch.update(tipRef, {
        'likedBy': FieldValue.arrayUnion([widget.currentUserId]),
        'likeCount': FieldValue.increment(1),
      });
    } else {
      batch.update(tipRef, {
        'likedBy': FieldValue.arrayRemove([widget.currentUserId]),
        'likeCount': FieldValue.increment(-1),
      });
    }
    
    await batch.commit().catchError((error) {
      // Revert the UI change if the backend update fails
      setState(() {
        _isLiked = !_isLiked;
        if (_isLiked) _likeCount++; else _likeCount--;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.tipDocument.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(
                data['category']?.toUpperCase() ?? 'GENERAL',
                style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            Text(data['title'] ?? 'No Title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(data['content'] ?? '', style: const TextStyle(fontSize: 15, color: Colors.black54)),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: (data['authorImageUrl'] ?? '').toString().isNotEmpty ? NetworkImage(data['authorImageUrl']) : null,
                  backgroundColor: Colors.grey[200],
                  child: ((data['authorImageUrl'] ?? '').toString().isEmpty) ? const Icon(Icons.person, size: 14) : null,
                ),
                const SizedBox(width: 8),
                Text(data['authorName'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(_formatDate((data['createdAt'] as Timestamp).toDate()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : Colors.grey,
                  ),
                  onPressed: _toggleLike,
                ),
                Text('$_likeCount'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 7) return '${date.day}/${date.month}/${date.year}';
    if (difference.inDays >= 1) return '${difference.inDays} days ago';
    if (difference.inHours >= 1) return '${difference.inHours} hours ago';
    if (difference.inMinutes >= 1) return '${difference.inMinutes} minutes ago';
    return 'Just now';
  }
}