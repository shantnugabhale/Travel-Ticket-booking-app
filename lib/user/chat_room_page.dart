import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_post_page.dart'; // For the "Create Post" button

class ChatRoomPage extends StatefulWidget {
  final String categoryName;
  final Color categoryColor;

  const ChatRoomPage({
    super.key,
    required this.categoryName,
    required this.categoryColor,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _messageController = TextEditingController();
  String? _currentUserId;
  String _currentUserName = 'Guest';

  // NEW: State to manage the message being replied to
  DocumentSnapshot? _replyingToMessage;

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
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _currentUserId == null) return;

    final messagesRef = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.categoryName)
        .collection('messages');

    final messageData = {
      'text': messageText,
      'senderName': _currentUserName,
      'senderId': _currentUserId,
      'timestamp': Timestamp.now(),
      'likeCount': 0,
      'likedBy': [],
    };
    
    // NEW: If replying to a message, add reply info
    if (_replyingToMessage != null) {
      final replyData = _replyingToMessage!.data() as Map<String, dynamic>;
      messageData['replyingToMessageId'] = _replyingToMessage!.id;
      messageData['replyingToSenderName'] = replyData['senderName'];
      messageData['replyingToText'] = replyData['text'];
    }

    await messagesRef.add(messageData);

    _messageController.clear();
    setState(() {
      _replyingToMessage = null; // Clear the reply context
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryName} Chat'),
        backgroundColor: widget.categoryColor,
        // NEW: Add a "Create Post" button
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Create a post in this category',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePostPage()));
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(widget.categoryName)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageDoc = messages[index];
                    final bool isMe = (messageDoc.data() as Map<String, dynamic>)['senderId'] == _currentUserId;

                    return GestureDetector(
                      // NEW: Long press to set the reply context
                      onLongPress: () {
                        setState(() {
                          _replyingToMessage = messageDoc;
                        });
                      },
                      child: MessageBubble(
                        key: ValueKey(messageDoc.id),
                        messageDocument: messageDoc,
                        isMe: isMe,
                        currentUserId: _currentUserId,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      color: Colors.white,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // NEW: Show the reply context if a message is being replied to
            if (_replyingToMessage != null)
              _buildReplyContext(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: widget.categoryColor),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Widget to display the "Replying to..." context
  Widget _buildReplyContext() {
    final data = _replyingToMessage!.data() as Map<String, dynamic>;
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Replying to ${data['senderName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(data['text'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => setState(() => _replyingToMessage = null),
          ),
        ],
      ),
    );
  }
}


// MODIFIED: MessageBubble is now a stateful widget for likes
class MessageBubble extends StatefulWidget {
  final DocumentSnapshot messageDocument;
  final bool isMe;
  final String? currentUserId;

  const MessageBubble({
    super.key,
    required this.messageDocument,
    required this.isMe,
    this.currentUserId,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  late int _likeCount;
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messageDocument != oldWidget.messageDocument) {
      _initializeState();
    }
  }

  void _initializeState() {
    final data = widget.messageDocument.data() as Map<String, dynamic>;
    _likeCount = data['likeCount'] ?? 0;
    _isLiked = widget.currentUserId != null && (data['likedBy'] as List? ?? []).contains(widget.currentUserId);
  }

  Future<void> _toggleLike() async {
    if (widget.currentUserId == null) return;

    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) _likeCount++; else _likeCount--;
    });

    final messageRef = widget.messageDocument.reference;
    if (_isLiked) {
      messageRef.update({'likedBy': FieldValue.arrayUnion([widget.currentUserId]), 'likeCount': FieldValue.increment(1)});
    } else {
      messageRef.update({'likedBy': FieldValue.arrayRemove([widget.currentUserId]), 'likeCount': FieldValue.increment(-1)});
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.messageDocument.data() as Map<String, dynamic>;
    final bool isReply = data['replyingToText'] != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(data['senderName'], style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Material(
                  borderRadius: BorderRadius.circular(20),
                  elevation: 3.0,
                  color: widget.isMe ? Theme.of(context).primaryColor : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // NEW: If it's a reply, show the original message context
                        if (isReply)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${data['replyingToSenderName']}: ${data['replyingToText']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: widget.isMe ? Colors.white70 : Colors.black54, fontStyle: FontStyle.italic),
                            ),
                          ),
                        Text(
                          data['text'],
                          style: TextStyle(color: widget.isMe ? Colors.white : Colors.black, fontSize: 15.0),
                        ),
                      ],
                    ),
                  ),
                ),
                // NEW: Like button and count
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, size: 16, color: _isLiked ? Colors.red : Colors.grey),
                      onPressed: _toggleLike,
                    ),
                    if (_likeCount > 0)
                      Text('$_likeCount', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}