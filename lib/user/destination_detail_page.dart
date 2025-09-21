import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trevel_booking_app/user/plan_trip_page.dart';

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
      setState(() {
        _isFavoriteLoading = false;
      });
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
      // Add to favorites by setting the document
      await favoriteRef.set({'savedAt': Timestamp.now()});
    } else {
      // Remove from favorites
      await favoriteRef.delete();
    }
  }


  // Helper to get the correct currency symbol
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

          // Provide default values for all fields to prevent errors
          final String name = data['name'] ?? 'Unknown Destination';
          final String location = data['location'] ?? 'Unknown Location';
          final String description =
              data['description'] ?? 'No description available.';
          final String imageUrl = data['imageUrl'] ?? '';
          final double safetyRating = data['safetyRating']?.toDouble() ?? 0.0;
          // **FIXED: Correctly reading budget and currency from the new structure**
          final int avgBudget = data['budget']?.toInt() ?? 0;
          final String currency = data['currency'] ?? 'USD';
          final List<String> activities =
              List<String>.from(data['popularActivities'] ?? []);
          final List<String> highlights =
              List<String>.from(data['mustSeeHighlights'] ?? []);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300.0,
                pinned: true,
                stretch: true,
                backgroundColor: Colors.white,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
                  centerTitle: true,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.grey),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                            stops: [0.6, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  _isFavoriteLoading 
                  ? const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)))
                  : IconButton(
                    icon: Icon(
                        _isFavorited
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _isFavorited ? Colors.red : Colors.white),
                    onPressed: _toggleFavorite,
                  ),
                ],
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.grey, size: 18),
                            const SizedBox(width: 4),
                            Text(location,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.grey)),
                            const Spacer(),
                            const Icon(Icons.star,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            const Text("4.8 (1250 reviews)",
                                style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(description,
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                                height: 1.5)),
                        const SizedBox(height: 24),
                        _buildInfoCard(
                          icon: Icons.monetization_on,
                          iconColor: Colors.blue,
                          title: 'Budget Information',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Budget: ${getCurrencySymbol(currency)}$avgBudget',
                                  style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          icon: Icons.health_and_safety,
                          iconColor: Colors.green,
                          title: 'Safety Rating',
                          child: Row(
                            children: [
                              Text('$safetyRating / 10',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: safetyRating / 10,
                                    minHeight: 10,
                                    backgroundColor: Colors.green.shade100,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.green),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Popular Activities'),
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: activities.length,
                            itemBuilder: (ctx, i) =>
                                _buildActivityChip(activities[i]),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Must-See Highlights'),
                        ...highlights
                            .map((item) => _buildHighlightItem(item))
                            .toList(),
                        const SizedBox(height: 80),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child:
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        backgroundColor: Colors.blue.shade50,
        labelStyle:
            TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildHighlightItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.location_pin, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context,
      {required Map<String, dynamic> data}) {
    final String name = data['name'] ?? 'This Trip';
    final String imageUrl = data['imageUrl'] ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.explore),
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
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Write Review'),
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}