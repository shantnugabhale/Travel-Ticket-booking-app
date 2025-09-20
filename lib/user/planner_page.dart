import 'package:flutter/material.dart';
 
import 'dart:ui'; // For BackdropFilter

class PlannerPage extends StatelessWidget {
  const PlannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder data for demonstration.
    // In a real app, this would come from a StreamBuilder connected to Firestore.
    final List<Map<String, dynamic>> upcomingTrips = [
      {
        'imageUrl': 'https://images.unsplash.com/photo-1502602898657-3e91760c0337?ixlib=rb-4.0.3&q=85&fm=jpg&crop=entropy&cs=srgb&w=320',
        'destination': 'Paris, France',
        'dates': 'Oct 10 - Oct 17, 2025',
        'status': 'Upcoming',
      },
      {
        'imageUrl': 'https://images.unsplash.com/photo-1533929736458-ca588913c835?ixlib=rb-4.0.3&q=85&fm=jpg&crop=entropy&cs=srgb&w=320',
        'destination': 'Kyoto, Japan',
        'dates': 'Nov 22 - Nov 29, 2025',
        'status': 'Upcoming',
      }
    ];

    final List<Map<String, dynamic>> pastTrips = [
      {
        'imageUrl': 'https://images.unsplash.com/photo-1523906834658-6e24ef2386f9?ixlib=rb-4.0.3&q=85&fm=jpg&crop=entropy&cs=srgb&w=320',
        'destination': 'Rome, Italy',
        'dates': 'May 05 - May 12, 2024',
        'status': 'Completed',
      }
    ];

    return DefaultTabController(
      length: 3, // Number of tabs
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Trip Planner'),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 1,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past Trips'),
              Tab(text: 'Saved Ideas'),
            ],
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
          ),
        ),
        body: TabBarView(
          children: [
            // Upcoming Trips Tab
            _buildTripList(upcomingTrips),

            // Past Trips Tab
            _buildTripList(pastTrips),

            // Saved Ideas Tab (Placeholder)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lightbulb_outline, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No saved ideas yet.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            // TODO: Navigate to a "Create New Trip" page
          },
          label: const Text('Plan a New Trip'),
          icon: const Icon(Icons.add),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  /// A reusable widget to build the list of trip cards.
  Widget _buildTripList(List<Map<String, dynamic>> trips) {
    if (trips.isEmpty) {
      return const Center(child: Text('No trips in this category.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return TripCard(
          imageUrl: trip['imageUrl'],
          destination: trip['destination'],
          dates: trip['dates'],
          status: trip['status'],
        );
      },
    );
  }
}

/// A custom card widget to display a summary of a planned trip.
class TripCard extends StatelessWidget {
  final String imageUrl;
  final String destination;
  final String dates;
  final String status;

  const TripCard({
    super.key,
    required this.imageUrl,
    required this.destination,
    required this.dates,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias, // Ensures the image respects the card's rounded corners
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 20.0),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to the detailed itinerary for this trip
        },
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.3), // Darken the image for better text contrast
                BlendMode.darken,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  destination,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 4),
                // Using a frosted glass effect for the date container
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        dates,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}