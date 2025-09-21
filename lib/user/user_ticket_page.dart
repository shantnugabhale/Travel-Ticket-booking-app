import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class UserTicketPage extends StatelessWidget {
  final DocumentSnapshot bookingDocument;

  const UserTicketPage({super.key, required this.bookingDocument});

  @override
  Widget build(BuildContext context) {
    final data = bookingDocument.data() as Map<String, dynamic>? ?? {};
    final travelers = data['travelers'] as List<dynamic>? ?? [];
    final destinationName = data['destinationName'] ?? 'N/A';
    final imageUrl = data['destinationImageUrl'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Your Ticket'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Ticket Widget
            TicketWidget(
              data: data,
              travelers: travelers,
              destinationName: destinationName,
              imageUrl: imageUrl,
              bookingId: bookingDocument.id,
            ),
            const SizedBox(height: 24),
            
            // Traveler Details Section
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Traveler Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ...travelers.asMap().entries.map((entry) {
              int idx = entry.key;
              var traveler = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Traveler ${idx + 1}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent),
                      ),
                      const Divider(height: 20),
                      _buildDetailRow('Name', '${traveler['firstName']} ${traveler['surname']}'),
                      _buildDetailRow('Phone', traveler['phone'] ?? 'N/A'),
                      _buildDetailRow('Aadhaar', traveler['aadhaar'] ?? 'N/A'),
                      _buildDetailRow('Passport ID', traveler['passportId'] ?? 'N/A'),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

// This is the main visual widget for the ticket
class TicketWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<dynamic> travelers;
  final String destinationName;
  final String imageUrl;
  final String bookingId;

  const TicketWidget({
    super.key,
    required this.data,
    required this.travelers,
    required this.destinationName,
    required this.imageUrl,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 180,
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destinationName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      data['pickupLocation'] ?? 'N/A',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const DashedSeparator(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDateInfo('From', (data['startDate'] as Timestamp?)?.toDate()),
                const Icon(Icons.flight_takeoff, color: Colors.blue, size: 30),
                _buildDateInfo('To', (data['endDate'] as Timestamp?)?.toDate()),
              ],
            ),
          ),
           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${travelers.length} Traveler(s)',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: QrImageView(
              data: bookingId,
              version: QrVersions.auto,
              size: 120.0,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, DateTime? date) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          date != null ? DateFormat('dd MMM yyyy').format(date) : 'N/A',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}

class DashedSeparator extends StatelessWidget {
  const DashedSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 10.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Flex(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            direction: Axis.horizontal,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: dashHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.grey[400]),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}