import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminChatViewPage extends StatefulWidget {
  final String categoryName;
  final Color categoryColor;

  const AdminChatViewPage({
    super.key,
    required this.categoryName,
    required this.categoryColor,
  });

  @override
  State<AdminChatViewPage> createState() => _AdminChatViewPageState();
}

class _AdminChatViewPageState extends State<AdminChatViewPage> {
  // This function performs the actual deletion in Firestore.
  Future<void> _deleteMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.categoryName)
          .collection('messages')
          .doc(messageId)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // NEW: This function shows a SnackBar at the bottom for delete confirmation.
  void _showDeleteInteraction(String messageId) {
    // Hide any existing SnackBars to prevent overlap.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final snackBar = SnackBar(
      content: const Text('Delete this message?'),
      action: SnackBarAction(
        label: 'DELETE',
        textColor: Colors.redAccent,
        onPressed: () {
          _deleteMessage(messageId);
        },
      ),
      duration: const Duration(seconds: 4), // How long the snackbar is visible
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryName} Chat'),
        backgroundColor: widget.categoryColor,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .doc(widget.categoryName)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final messages = snapshot.data!.docs;

          if (messages.isEmpty) {
            return const Center(child: Text('No messages in this chat room yet.'));
          }

          return ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(12.0),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final messageDoc = messages[index];
              return AdminMessageBubble(
                messageDocument: messageDoc,
                // MODIFIED: The action now shows the bottom snackbar.
                onDoubleTap: () => _showDeleteInteraction(messageDoc.id),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminMessageBubble extends StatelessWidget {
  final DocumentSnapshot messageDocument;
  // MODIFIED: Changed from onLongPress to onDoubleTap for clarity.
  final VoidCallback onDoubleTap;

  const AdminMessageBubble({
    super.key,
    required this.messageDocument,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final data = messageDocument.data() as Map<String, dynamic>;
    final senderName = data['senderName'] ?? 'Unknown User';
    final messageText = data['text'] ?? '';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    return GestureDetector(
      // MODIFIED: The trigger for deletion is now a double tap.
      onDoubleTap: onDoubleTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              senderName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Material(
              borderRadius: BorderRadius.circular(15),
              elevation: 2,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(messageText, style: const TextStyle(fontSize: 16.0)),
                    const SizedBox(height: 5),
                    if (timestamp != null)
                      Text(
                        DateFormat('d MMM, hh:mm a').format(timestamp),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}