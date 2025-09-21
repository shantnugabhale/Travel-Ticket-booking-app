import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'booking_details_page.dart'; // Import the new details page

// Enum to represent the different filter options
enum BookingFilter { Today, Week, Month, Year, All }

class ViewBookingsPage extends StatefulWidget {
  const ViewBookingsPage({super.key});

  @override
  State<ViewBookingsPage> createState() => _ViewBookingsPageState();
}

class _ViewBookingsPageState extends State<ViewBookingsPage> {
  BookingFilter _selectedFilter = BookingFilter.All;

  // Helper function to get the start date for the query based on the filter
  DateTime? _getStartDate() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case BookingFilter.Today:
        return DateTime(now.year, now.month, now.day);
      case BookingFilter.Week:
        return now.subtract(Duration(days: now.weekday - 1));
      case BookingFilter.Month:
        return DateTime(now.year, now.month, 1);
      case BookingFilter.Year:
        return DateTime(now.year, 1, 1);
      case BookingFilter.All:
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Base query that can be modified
    Query query = FirebaseFirestore.instance
        .collection('bookings')
        .orderBy('bookedAt', descending: true);

    // Modify the query based on the selected filter
    final startDate = _getStartDate();
    if (startDate != null) {
      query = query.where('bookedAt', isGreaterThanOrEqualTo: startDate);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Bookings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: BookingFilter.values.map((filter) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(filter.name),
                    selected: _selectedFilter == filter,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('An error occurred: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No bookings found for this filter.'));
          }

          final bookings = snapshot.data!.docs;

          return ListView.builder(
            itemCount: bookings.length,
            padding: const EdgeInsets.all(16.0),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final data = booking.data() as Map<String, dynamic>;

              final destinationName = data['destinationName'] ?? 'N/A';
              final travelerList = data['travelers'] as List<dynamic>? ?? [];
              final primaryTraveler =
                  travelerList.isNotEmpty ? travelerList.first : null;
              final travelerName = primaryTraveler != null
                  ? '${primaryTraveler['firstName']} ${primaryTraveler['surname']}'
                  : 'N/A';
              final bookedAt = (data['bookedAt'] as Timestamp?)?.toDate();
              final formattedBookingTime = bookedAt != null
                  ? DateFormat('dd MMM, yyyy - hh:mm a').format(bookedAt)
                  : 'N/A';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(data['destinationImageUrl'] ?? ''),
                  ),
                  title: Text(
                    destinationName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                      'Booked by: $travelerName\nAt: $formattedBookingTime'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingDetailsPage(bookingDocument: booking),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}