import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trevel_booking_app/user/plan_trip_page.dart';
import 'package:trevel_booking_app/user/write_review_page.dart';

class DestinationDetailPage extends StatefulWidget {
  final String destinationId;

  const DestinationDetailPage({super.key, required this.destinationId});

  @override
  State<DestinationDetailPage> createState() => _DestinationDetailPageState();
}

class _DestinationDetailPageState extends State<DestinationDetailPage> {
  bool _isFavorited = false;
  bool _isFavoriteLoading = true;
  String? _currentUserId;

  late Future<DocumentSnapshot> _destinationFuture;

  @override
  void initState() {
    super.initState();
    _destinationFuture = FirebaseFirestore.instance
        .collection('destinations')
        .doc(widget.destinationId)
        .get();
    _checkIfFavorited();
  }

  Future<void> _checkIfFavorited() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      final favoriteDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('saved_destinations')
          .doc(widget.destinationId)
          .get();
      if (mounted) {
        setState(() {
          _isFavorited = favoriteDoc.exists;
          _isFavoriteLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isFavoriteLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to save destinations.')),
      );
      return;
    }

    setState(() { _isFavorited = !_isFavorited; });

    final favoriteRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('saved_destinations')
        .doc(widget.destinationId);

    if (_isFavorited) {
      await favoriteRef.set({'savedAt': Timestamp.now()});
    } else {
      await favoriteRef.delete();
    }
  }

  String getCurrencySymbol(String currencyCode) {
    switch (currencyCode) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currencyCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<DocumentSnapshot>(
        future: _destinationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Destination not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String name = data['name'] ?? 'Unknown Destination';
          final String location = data['location'] ?? 'Unknown Location';
          final String description = data['description'] ?? 'No description available.';
          final String imageUrl = data['imageUrl'] ?? '';
          final double safetyRating = data['safetyRating']?.toDouble() ?? 0.0;
          final int avgBudget = data['budget']?.toInt() ?? 0;
          final String currency = data['currency'] ?? 'USD';
          final List<String> activities = List<String>.from(data['popularActivities'] ?? []);
          final List<String> highlights = List<String>.from(data['mustSeeHighlights'] ?? []);

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(name, imageUrl),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(location, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        _buildStatsSection(),
                        const Divider(height: 40),
                        _buildSectionHeader('About this Destination'),
                        Text(description, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)),
                        const SizedBox(height: 24),
                        _buildInfoCard(
                          icon: Icons.monetization_on,
                          iconColor: Colors.blue,
                          title: 'Budget Information',
                          child: Text(
                            'Avg. Budget: ${getCurrencySymbol(currency)}$avgBudget',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          icon: Icons.health_and_safety,
                          iconColor: Colors.green,
                          title: 'Safety Rating',
                          child: Row(
                            children: [
                              Text('$safetyRating / 10', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: safetyRating / 10,
                                    minHeight: 10,
                                    backgroundColor: Colors.green.shade100,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Popular Activities'),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: activities.map((activity) => _buildActivityChip(activity)).toList(),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Must-See Highlights'),
                        ...highlights.map((item) => _buildHighlightItem(item)).toList(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  )
                ]),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<DocumentSnapshot>(
        future: _destinationFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          return _buildBottomActionBar(context, data: data);
        },
      ),
    );
  }

  Widget _buildSliverAppBar(String name, String imageUrl) {
    return SliverAppBar(
      expandedHeight: 300.0,
      pinned: true,
      stretch: true,
      backgroundColor: Theme.of(context).primaryColor,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)])),
        centerTitle: true,
        background: Hero(
          tag: widget.destinationId,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        _isFavoriteLoading
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)),
              )
            : IconButton(
                icon: Icon(
                  _isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorited ? Colors.redAccent : Colors.white,
                  size: 28,
                ),
                onPressed: _toggleFavorite,
              ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('destinationId', isEqualTo: widget.destinationId)
          .snapshots(),
      builder: (context, reviewSnapshot) {
        if (reviewSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        double averageRating = 0.0;
        final reviewCount = reviewSnapshot.data?.docs.length ?? 0;
        if (reviewCount > 0) {
          double totalRating = 0;
          for (var doc in reviewSnapshot.data!.docs) {
            totalRating += (doc.data() as Map<String, dynamic>)['rating'] ?? 0;
          }
          averageRating = totalRating / reviewCount;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .where('destinationId', isEqualTo: widget.destinationId)
              .snapshots(),
          builder: (context, bookingSnapshot) {
            if (bookingSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final bookingCount = bookingSnapshot.data?.docs.length ?? 0;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(Icons.star_rate_rounded, 'Rating', '${averageRating.toStringAsFixed(1)}/5'),
                  _buildStatItem(Icons.people_alt_rounded, 'Bookings', bookingCount.toString()),
                  _buildStatItem(Icons.reviews_rounded, 'Reviews', reviewCount.toString()),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 32),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    );
  }
  
    Widget _buildInfoCard(
      {required IconData icon,
      required Color iconColor,
      required String title,
      required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 1)
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: iconColor)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildActivityChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.blue.shade50,
      labelStyle: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildHighlightItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Icon(Icons.check_circle_outline, color: Colors.deepOrangeAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, height: 1.5))),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, {required Map<String, dynamic> data}) {
    final String name = data['name'] ?? 'This Trip';
    final String imageUrl = data['imageUrl'] ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.explore_rounded),
              label: const Text('Plan Trip'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlanTripPage(
                      destinationId: widget.destinationId,
                      destinationName: name,
                      destinationImageUrl: imageUrl,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Write Review'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WriteReviewPage(
                      destinationId: widget.destinationId,
                      destinationName: name,
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

