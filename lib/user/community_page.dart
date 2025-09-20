import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:intl/intl.dart';
import 'chat_room_page.dart';
import 'create_post_page.dart';
// We are keeping this import in case you need the full page elsewhere.
import 'comments_page.dart';

// This is the main stateful widget that will manage the page and fetch the current user
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  // State variables to hold the logged-in user's data
  String? _currentUserId;
  String _currentUserImageUrl = 'https://via.placeholder.com/150';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  // Function to get the logged-in user's data from Auth and Firestore
  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && userDoc.exists) {
        setState(() {
          _currentUserId = user.uid;
          _currentUserImageUrl = userDoc.data()?['imageUrl'] ?? 'https://via.placeholder.com/150';
        });
      } else if (mounted) {
        // Fallback if user document doesn't exist yet
        setState(() {
          _currentUserId = user.uid;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // A cleaner, floating AppBar
          SliverAppBar(
            title: const Text('Community', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            floating: true,
            elevation: 1,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(_currentUserImageUrl),
                ),
              ),
            ],
          ),

          // Chat Categories Section
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Text(
                'Join a Conversation',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildChatCategories(context),
          ),

          // Section Header for the Feed
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
              child: Text(
                'Recent Posts',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Community Post Feed
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('community_posts').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('Be the first to share a post!'),
                    ),
                  ),
                );
              }
              
              final posts = snapshot.data!.docs;

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final postDocument = posts[index];
                    // Pass the real user ID and a unique key to each card
                    return CommunityPostCard(
                      key: ValueKey(postDocument.id),
                      postDocument: postDocument,
                      currentUserId: _currentUserId,
                    );
                  },
                  childCount: posts.length,
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostPage()));
        },
        child: const Icon(Icons.add),
        tooltip: 'Create a new post',
      ),
    );
  }

  // Helper for Chat Categories using a more modern Chip UI
  Widget _buildChatCategories(BuildContext context) {
    final List<Map<String, dynamic>> categories = [
      {'name': 'Beaches', 'icon': Icons.beach_access},
      {'name': 'Mountains', 'icon': Icons.terrain},
      {'name': 'Cities', 'icon': Icons.location_city},
      {'name': 'Hiking', 'icon': Icons.hiking},
    ];
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16.0),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatRoomPage(categoryName: category['name'], categoryColor: Theme.of(context).primaryColor)));
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              child: Chip(
                avatar: Icon(category['icon'], size: 18, color: Theme.of(context).primaryColor),
                label: Text(category['name']),
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          );
        },
      ),
    );
  }
}

// A StatefulWidget for the post card to handle its own state (likes, etc.)
class CommunityPostCard extends StatefulWidget {
  final DocumentSnapshot postDocument;
  final String? currentUserId;

  const CommunityPostCard({super.key, required this.postDocument, this.currentUserId});

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  late int _likeCount;
  late int _commentCount;
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  // This is crucial for ensuring the card reflects real-time updates from others
  @override
  void didUpdateWidget(CommunityPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.postDocument != oldWidget.postDocument) {
      _initializeState();
    }
  }

  void _initializeState() {
    final data = widget.postDocument.data() as Map<String, dynamic>;
    _likeCount = data['likeCount'] ?? 0;
    _commentCount = data['commentCount'] ?? 0;
    _isLiked = widget.currentUserId != null && (data['likedBy'] as List? ?? []).contains(widget.currentUserId);
  }

  // Handles both the UI update and the backend call for liking/unliking
  Future<void> _toggleLike() async {
    if (widget.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to like posts.')),
      );
      return;
    }

    // Optimistic UI update
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) _likeCount++; else _likeCount--;
    });

    final postRef = FirebaseFirestore.instance.collection('community_posts').doc(widget.postDocument.id);
    final batch = FirebaseFirestore.instance.batch();
    
    if (_isLiked) {
      batch.update(postRef, {'likedBy': FieldValue.arrayUnion([widget.currentUserId]), 'likeCount': FieldValue.increment(1)});
    } else {
      batch.update(postRef, {'likedBy': FieldValue.arrayRemove([widget.currentUserId]), 'likeCount': FieldValue.increment(-1)});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.postDocument.data() as Map<String, dynamic>;
    final String authorName = data['authorName'] ?? 'Anonymous';
    final String authorImageUrl = data['authorImageUrl'] ?? '';
    final String postImageUrl = data['postImageUrl'] ?? '';
    final String caption = data['caption'] ?? '';

    return Card(
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
            trailing: IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
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
                    _buildActionButton(
                      icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                      label: 'Like ($_likeCount)',
                      color: _isLiked ? Colors.red : Colors.grey[700]!,
                      onTap: _toggleLike,
                    ),
                    _buildActionButton(
                      icon: Icons.comment_outlined,
                      label: 'Comment ($_commentCount)',
                      color: Colors.grey[700]!,
                      onTap: () {
                        // **MODIFIED ACTION: Show modal bottom sheet**
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
                                postId: widget.postDocument.id,
                                scrollController: scrollController,
                              );
                            },
                          ),
                        );
                      },
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

  // Helper widget for the Like and Comment buttons
  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // Helper function for smart date/time formatting
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (date.year == now.year) {
      return DateFormat('d MMM').format(date);
    } else {
      return DateFormat('d MMM, yyyy').format(date);
    }
  }
}

// **NEW WIDGET FOR THE FLOATING COMMENTS SCREEN**
class CommentsBottomSheet extends StatefulWidget {
  final String postId;
  final ScrollController scrollController;

  const CommentsBottomSheet({
    super.key,
    required this.postId,
    required this.scrollController,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
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
          _currentUserImageUrl = userDoc.data()?['imageUrl'] ?? '';
        });
      }
    }
  }

  Future<void> _postComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty || _currentUserId == null) return;

    final postRef = FirebaseFirestore.instance.collection('community_posts').doc(widget.postId);
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
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
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Be the first to comment!', style: TextStyle(color: Colors.grey)));
                }
                final comments = snapshot.data!.docs;
                return ListView.builder(
                  controller: widget.scrollController,
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
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 12.0,
        right: 12.0,
        top: 8.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
    );
  }
}