import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewsPage extends StatelessWidget {
  const ReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Reviews'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot>(
        // Listen to the 'reviews' collection, ordered by most recent
        stream: FirebaseFirestore.instance.collection('reviews').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('An error occurred.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No reviews yet.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final reviews = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final reviewDocument = reviews[index];
              return ReviewCard(reviewDocument: reviewDocument);
            },
          );
        },
      ),
    );
  }
}

/// A reusable card widget to display a single user review.
class ReviewCard extends StatelessWidget {
  final DocumentSnapshot reviewDocument;

  const ReviewCard({super.key, required this.reviewDocument});

  // Helper function to build the star rating row
  Widget _buildStarRating(double rating) {
    List<Widget> stars = [];
    for (int i = 1; i <= 5; i++) {
      IconData iconData = Icons.star_border;
      Color color = Colors.grey;
      if (i <= rating) {
        iconData = Icons.star;
        color = Colors.amber;
      } else if (i - 0.5 <= rating) {
        iconData = Icons.star_half;
        color = Colors.amber;
      }
      stars.add(Icon(iconData, color: color, size: 18));
    }
    return Row(children: stars);
  }

  // Helper to format the date nicely
  String _formatDate(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inDays > 7) return '${date.day}/${date.month}/${date.year}';
    if (difference.inDays >= 1) return '${difference.inDays}d ago';
    if (difference.inHours >= 1) return '${difference.inHours}h ago';
    if (difference.inMinutes >= 1) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final data = reviewDocument.data() as Map<String, dynamic>;

    // Provide default values to prevent errors if data is missing
    final String authorName = data['authorName'] ?? 'Anonymous';
    final String authorImageUrl = data['authorImageUrl'] ?? 'https://via.placeholder.com/150';
    final String destinationName = data['destinationName'] ?? 'a destination';
    final double rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final String reviewText = data['reviewText'] ?? 'No comment provided.';
    final DateTime createdAt = (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar, Name, Destination, and Date
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(authorImageUrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        'reviewed $destinationName',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(_formatDate(createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),

            // Star Rating
            _buildStarRating(rating),
            const SizedBox(height: 12),

            // Review Text
            Text(
              reviewText,
              style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
