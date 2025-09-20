import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trevel_booking_app/user/create_post_page.dart'; 

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
  String _currentUserImageUrl = '';
  String _currentUserName = 'Guest';
  DocumentSnapshot? _replyingToMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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
      'senderImageUrl': _currentUserImageUrl,
      'timestamp': Timestamp.now(),
      'likeCount': 0,
      'likedBy': [],
    };

    if (_replyingToMessage != null) {
      final replyData = _replyingToMessage!.data() as Map<String, dynamic>;
      messageData['replyingToMessageId'] = _replyingToMessage!.id;
      messageData['replyingToSenderName'] = replyData['senderName'];
      messageData['replyingToText'] = replyData['text'];
    }

    await messagesRef.add(messageData);
    _messageController.clear();
    setState(() {
      _replyingToMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryName} Chat'),
        backgroundColor: widget.categoryColor,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Create a post in this category',
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const CreatePostPage()));
            },
          )
        ],
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: Column(
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
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data!.docs;
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12.0),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final messageDoc = messages[index];
                      final bool isMe =
                          (messageDoc.data() as Map<String, dynamic>)['senderId'] ==
                              _currentUserId;
                      return GestureDetector(
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
      ),
    );
  }

  Widget _buildMessageInput() {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingToMessage != null) _buildReplyContext(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: widget.categoryColor,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyContext() {
    final data = _replyingToMessage!.data() as Map<String, dynamic>;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.categoryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Replying to ${data['senderName']}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.categoryColor)),
                Text(data['text'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _replyingToMessage = null),
          ),
        ],
      ),
    );
  }
}

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

  void _initializeState() {
    final data = widget.messageDocument.data() as Map<String, dynamic>;
    _likeCount = data['likeCount'] ?? 0;
    _isLiked = widget.currentUserId != null &&
        (data['likedBy'] as List? ?? []).contains(widget.currentUserId);
  }

  Future<void> _toggleLike() async {
    if (widget.currentUserId == null) return;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    final messageRef = widget.messageDocument.reference;
    if (_isLiked) {
      messageRef.update({
        'likedBy': FieldValue.arrayUnion([widget.currentUserId]),
        'likeCount': FieldValue.increment(1)
      });
    } else {
      messageRef.update({
        'likedBy': FieldValue.arrayRemove([widget.currentUserId]),
        'likeCount': FieldValue.increment(-1)
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.messageDocument.data() as Map<String, dynamic>;
    final bool isReply = data['replyingToText'] != null;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final senderImageUrl = data['senderImageUrl'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: widget.isMe ? _buildMyMessage(data, isReply, timestamp) : _buildOtherMessage(data, isReply, timestamp, senderImageUrl),
    );
  }

  Widget _buildMyMessage(Map<String, dynamic> data, bool isReply, DateTime? timestamp) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildMessageContainer(data, isReply, timestamp),
              _buildLikeButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtherMessage(Map<String, dynamic> data, bool isReply, DateTime? timestamp, String senderImageUrl) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: senderImageUrl.isNotEmpty ? NetworkImage(senderImageUrl) : null,
          child: senderImageUrl.isEmpty
              ? const Icon(Icons.person, size: 20)
              : null,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['senderName'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              _buildMessageContainer(data, isReply, timestamp),
              _buildLikeButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageContainer(Map<String, dynamic> data, bool isReply, DateTime? timestamp) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
      decoration: BoxDecoration(
        color: widget.isMe ? Theme.of(context).primaryColor : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: widget.isMe ? const Radius.circular(20) : const Radius.circular(0),
          bottomRight: widget.isMe ? const Radius.circular(0) : const Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(1, 1),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReply) _buildReplyContent(data),
          Text(
            data['text'],
            style: TextStyle(
                color: widget.isMe ? Colors.white : Colors.black87,
                fontSize: 16.0),
          ),
          const SizedBox(height: 5),
          if (timestamp != null)
            Text(
              DateFormat('hh:mm a').format(timestamp),
              style: TextStyle(
                  color: widget.isMe ? Colors.white70 : Colors.grey,
                  fontSize: 12),
            ),
        ],
      ),
    );
  }
  
  Widget _buildReplyContent(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.white.withOpacity(0.2) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
              color: widget.isMe ? Colors.white54 : Theme.of(context).primaryColor,
              width: 3),
        ),
      ),
      child: Text(
        '${data['replyingToSenderName']}: ${data['replyingToText']}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: widget.isMe ? Colors.white70 : Colors.black54,
            fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _buildLikeButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggleLike,
            child: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: _isLiked ? Colors.red : Colors.grey,
            ),
          ),
          if (_likeCount > 0) const SizedBox(width: 4),
          if (_likeCount > 0)
            Text('$_likeCount',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}