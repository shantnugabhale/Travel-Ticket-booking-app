import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:trevel_booking_app/user/community_page.dart';
import 'package:trevel_booking_app/user/destination_detail_page.dart';
import 'package:trevel_booking_app/user/home_page.dart';
import 'package:trevel_booking_app/user/user_ticket_page.dart'; // Import the new ticket page

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  String? _currentUserId;
  // Cache for the 'Saved' tab to prevent image flickering
  final Map<String, Future<List<DocumentSnapshot>>> _savedDestinationsCache = {};

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: Text('Please log in to see your planner.'));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Planner'),
          centerTitle: false,
          backgroundColor: Colors.white,
          elevation: 1,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.luggage), text: 'Booked Trips'),
              Tab(icon: Icon(Icons.favorite), text: 'Saved'),
              Tab(icon: Icon(Icons.thumb_up), text: 'Liked Posts'),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
          ),
        ),
        body: TabBarView(
          children: [
            _buildBookedTripsList(_currentUserId!),
            _buildSavedDestinationsList(_currentUserId!),
            _buildLikedPostsList(_currentUserId!),
          ],
        ),
      ),
    );
  }

  /// This widget displays the user's booked trips and navigates to the ticket page on tap.
  Widget _buildBookedTripsList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .orderBy('bookedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint("Firestore Stream Error: ${snapshot.error}");
          return const Center(
              child: Text('Could not connect to your trips. Please try again later.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('You have no booked trips yet.'));
        }

        final bookings = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final doc = bookings[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};

            final String destinationName = data['destinationName'] as String? ?? 'Unnamed Trip';
            final String imageUrl = data['destinationImageUrl'] as String? ?? '';
            
            String formattedDate = 'Date not specified';
            if (data['startDate'] is Timestamp) {
              formattedDate = DateFormat('dd MMM, yyyy').format((data['startDate'] as Timestamp).toDate());
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: (imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.isAbsolute == true)
                      ? NetworkImage(imageUrl)
                      : null,
                  child: (imageUrl.isEmpty || Uri.tryParse(imageUrl)?.isAbsolute != true)
                      ? const Icon(Icons.flight_takeoff)
                      : null,
                ),
                title: Text(destinationName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Trip Date: $formattedDate'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // **UPDATED:** Navigates to the new UserTicketPage
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserTicketPage(bookingDocument: doc),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// This function for the 'Saved' tab now uses a cache to prevent images
  /// from reloading every time you switch tabs.
  Widget _buildSavedDestinationsList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('saved_destinations')
          .orderBy('savedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('You have no saved destinations.'));
        }
        final savedDocs = snapshot.data!.docs;
        final destinationIds = savedDocs.map((doc) => doc.id).toList();
        final cacheKey = destinationIds.join(',');

        // Use the cache to avoid re-fetching data unnecessarily
        Future<List<DocumentSnapshot>> getFuture() {
          if (_savedDestinationsCache.containsKey(cacheKey)) {
            return _savedDestinationsCache[cacheKey]!;
          } else {
            final future = _getDestinationsFromIds(destinationIds);
            _savedDestinationsCache[cacheKey] = future;
            return future;
          }
        }

        return FutureBuilder<List<DocumentSnapshot>>(
          future: getFuture(),
          builder: (context, destSnapshot) {
            if (!destSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final destinations = destSnapshot.data!;
            return GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.7,
              ),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final destination = destinations[index];
                final data = destination.data() as Map<String, dynamic>;
                return DestinationCard(
                  imageUrl: data['imageUrl'] ?? '',
                  name: data['name'] ?? '',
                  location: data['location'] ?? '',
                  rating: data['safetyRating']?.toDouble() ?? 0.0,
                  price: data['budget']?.toInt() ?? 0,
                  currency: data['currency'] ?? '\$',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DestinationDetailPage(destinationId: destination.id),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<DocumentSnapshot>> _getDestinationsFromIds(
      List<String> ids) async {
    if (ids.isEmpty) return [];
    final futures = ids.map((id) =>
        FirebaseFirestore.instance.collection('destinations').doc(id).get());
    final results = await Future.wait(futures);
    return results.where((doc) => doc.exists).toList();
  }

  Widget _buildLikedPostsList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community_posts')
          .where('likedBy', arrayContains: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('You haven\'t liked any posts yet.'));
        }
        final posts = snapshot.data!.docs;
        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return CommunityPostCard(
              postDocument: post,
              currentUserId: userId,
            );
          },
        );
      },
    );
  }
}