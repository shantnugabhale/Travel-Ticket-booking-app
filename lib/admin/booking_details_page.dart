import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BookingDetailsPage extends StatelessWidget {
  final DocumentSnapshot bookingDocument;

  const BookingDetailsPage({super.key, required this.bookingDocument});

  @override
  Widget build(BuildContext context) {
    final data = bookingDocument.data() as Map<String, dynamic>;
    final travelers = data['travelers'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Booking for ${data['destinationName'] ?? 'N/A'}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Trip Information'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow('Destination', data['destinationName'] ?? 'N/A'),
                    _buildDetailRow('Pickup Location', data['pickupLocation'] ?? 'N/A'),
                    _buildDetailRow(
                        'Start Date',
                        _formatDate((data['startDate'] as Timestamp?)?.toDate())),
                    _buildDetailRow(
                        'End Date',
                        _formatDate((data['endDate'] as Timestamp?)?.toDate())),
                    _buildDetailRow('Status', data['status'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Payment Details'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow('Total Cost',
                        '${data['totalCost']?.toStringAsFixed(2) ?? 'N/A'}'),
                    _buildDetailRow('Payment ID',
                        data['paymentIntentId'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Traveler Details (${travelers.length})'),
            ...travelers.asMap().entries.map((entry) {
              int idx = entry.key;
              var traveler = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
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
                      const Divider(),
                      _buildDetailRow('Name',
                          '${traveler['firstName']} ${traveler['surname']}'),
                      _buildDetailRow('Phone', traveler['phone'] ?? 'N/A'),
                      _buildDetailRow(
                          'Aadhaar', traveler['aadhaar'] ?? 'N/A'),
                      _buildDetailRow(
                          'Passport ID', traveler['passportId'] ?? 'N/A'),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd MMM, yyyy').format(date);
  }
}