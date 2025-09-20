import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'booking_page.dart';

class PlanTripPage extends StatefulWidget {
  final String destinationId;
  final String destinationName;
  final String destinationImageUrl;

  const PlanTripPage({
    super.key,
    required this.destinationId,
    required this.destinationName,
    required this.destinationImageUrl,
  });

  @override
  State<PlanTripPage> createState() => _PlanTripPageState();
}

class _PlanTripPageState extends State<PlanTripPage> {
  int _numberOfTravelers = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('destinations').doc(widget.destinationId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Trip details not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final double pricePerPerson = (data['pricePerPerson'] as num?)?.toDouble() ?? 0.0;
          final DateTime startDate = (data['tripStartDate'] as Timestamp? ?? Timestamp.now()).toDate();
          final DateTime endDate = (data['tripEndDate'] as Timestamp? ?? Timestamp.now()).toDate();
          final double totalCost = pricePerPerson * _numberOfTravelers;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(widget.destinationName, textAlign: TextAlign.center),
                  background: Image.network(widget.destinationImageUrl, fit: BoxFit.cover),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Admin-Set Dates ---
                        _buildSectionHeader('Trip Dates'),
                        _buildDateInfo(startDate, endDate),
                        const Divider(height: 40),

                        // --- Traveler Selection ---
                        _buildSectionHeader('How Many People?'),
                        _buildTravelerSelector(),
                        const Divider(height: 40),

                        // --- Comments/Reviews Section ---
                        _buildSectionHeader('What Travelers Are Saying'),
                        _buildReviewsList(),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
      // --- MODIFIED: New Bottom Bar with Cost and Booking Button ---
      bottomNavigationBar: _buildBottomBookingBar(),
    );
  }

  Widget _buildDateInfo(DateTime startDate, DateTime endDate) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text('FROM', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(DateFormat('dd MMM, yyyy').format(startDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Icon(Icons.arrow_forward, color: Colors.blue),
            Column(
              children: [
                const Text('TO', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(DateFormat('dd MMM, yyyy').format(endDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTravelerSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Travelers', style: TextStyle(fontSize: 16)),
          DropdownButton<int>(
            value: _numberOfTravelers,
            underline: const SizedBox(), // Hides the default underline
            items: List.generate(10, (i) => i + 1)
                .map((num) => DropdownMenuItem(value: num, child: Text('$num')))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _numberOfTravelers = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    return SizedBox(
      height: 150, // Constrain the height of the reviews list
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .where('destinationId', isEqualTo: widget.destinationId)
            .limit(3) // Show top 3 reviews
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No reviews yet for this destination.'));
          }
          final reviews = snapshot.data!.docs;
          return ListView.builder(
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final data = reviews[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(data['authorImageUrl'])),
                title: Text(data['authorName']),
                subtitle: Text(data['reviewText'], maxLines: 2, overflow: TextOverflow.ellipsis),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }
  
  // NEW: The bottom bar requires a FutureBuilder to get the price
  Widget _buildBottomBookingBar() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('destinations').doc(widget.destinationId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final pricePerPerson = (data['pricePerPerson'] as num?)?.toDouble() ?? 0.0;
        final totalCost = pricePerPerson * _numberOfTravelers;
        final startDate = (data['tripStartDate'] as Timestamp?)?.toDate();
        final endDate = (data['tripEndDate'] as Timestamp?)?.toDate();

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side: Cost
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total Cost', style: TextStyle(color: Colors.grey)),
                  Text('\$${totalCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              // Right side: Booking Button
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => BookingPage(
                      destinationId: widget.destinationId,
                      destinationName: widget.destinationName,
                      destinationImageUrl: widget.destinationImageUrl,
                      basePricePerPerson: pricePerPerson,
                      initialStartDate: startDate,
                      initialEndDate: endDate,
                      initialTravelers: _numberOfTravelers,
                    ),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: const Text('Book Now'),
              ),
            ],
          ),
        );
      },
    );
  }
}