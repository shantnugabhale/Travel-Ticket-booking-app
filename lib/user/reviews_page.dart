import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trevel_booking_app/user/destination_detail_page.dart';
import 'profile_page.dart';

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
        stream: FirebaseFirestore.instance.collection('reviews').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('An error occurred.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No reviews yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
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

/// A reusable card widget to display a single user review with a background image.
class ReviewCard extends StatefulWidget {
  final DocumentSnapshot reviewDocument;

  const ReviewCard({super.key, required this.reviewDocument});

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  String? _destinationImageUrl;
  bool _isLoadingImage = true;

  @override
  void initState() {
    super.initState();
    _fetchDestinationImage();
  }

  Future<void> _fetchDestinationImage() async {
    try {
      final data = widget.reviewDocument.data() as Map<String, dynamic>;
      final String destinationId = data['destinationId'] ?? '';

      if (destinationId.isNotEmpty) {
        final destDoc = await FirebaseFirestore.instance.collection('destinations').doc(destinationId).get();
        if (destDoc.exists && mounted) {
          setState(() {
            _destinationImageUrl = destDoc.data()?['imageUrl'];
            _isLoadingImage = false;
          });
        } else {
           if (mounted) setState(() => _isLoadingImage = false);
        }
      } else {
         if (mounted) setState(() => _isLoadingImage = false);
      }
    } catch (e) {
       if (mounted) setState(() => _isLoadingImage = false);
       // Optionally handle error, e.g., print(e);
    }
  }
  
  // Helper function to build the star rating row
  Widget _buildStarRating(double rating) {
    List<Widget> stars = [];
    for (int i = 1; i <= 5; i++) {
      IconData iconData = Icons.star_border_rounded;
      if (i <= rating) {
        iconData = Icons.star_rounded;
      } else if (i - 0.5 <= rating) {
        iconData = Icons.star_half_rounded;
      }
      stars.add(Icon(iconData, color: Colors.amber, size: 20));
    }
    return Row(children: stars);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.reviewDocument.data() as Map<String, dynamic>;
    final String destinationId = data['destinationId'] ?? '';
    final String authorName = data['authorName'] ?? 'Anonymous';
    final String authorImageUrl = data['authorImageUrl'] ?? '';
    final String destinationName = data['destinationName'] ?? 'A destination';
    final double rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final String reviewText = data['reviewText'] ?? 'No comment provided.';

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 5,
      clipBehavior: Clip.antiAlias, // Important for rounded corners on the image
      child: InkWell(
        onTap: () {
          if (destinationId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DestinationDetailPage(destinationId: destinationId),
              ),
            );
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not find destination details.'))
             );
          }
        },
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            // Background Image
            _buildBackgroundImage(),
            // Content
            _buildContentOverlay(authorName, authorImageUrl, destinationName, rating, reviewText),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundImage() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: _isLoadingImage
          ? const Center(child: CircularProgressIndicator())
          : (_destinationImageUrl == null || _destinationImageUrl!.isEmpty)
              ? Container(color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 40))
              : Image.network(
                  _destinationImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image, color: Colors.grey, size: 40)),
                ),
    );
  }

  Widget _buildContentOverlay(String authorName, String authorImageUrl, String destinationName, double rating, String reviewText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.8), Colors.black.withOpacity(0.2), Colors.transparent],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Important for Stack layout
        children: [
          Text(
            destinationName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 5, color: Colors.black87)],
            ),
          ),
          const SizedBox(height: 8),
          _buildStarRating(rating),
          const SizedBox(height: 12),
          Text(
            reviewText,
            style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: authorImageUrl.isNotEmpty ? NetworkImage(authorImageUrl) : null,
                child: authorImageUrl.isEmpty ? const Icon(Icons.person, size: 16) : null,
              ),
              const SizedBox(width: 8),
              Text(
                'by $authorName',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

