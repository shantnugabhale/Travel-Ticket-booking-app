import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:trevel_booking_app/services/data.dart'; // Import your secret key
import 'ticket_confirmation_page.dart'; // Import the new page

class PaymentPage extends StatefulWidget {
  final double totalCost;
  final String currency;
  final Map<String, dynamic> bookingDetails;

  const PaymentPage({
    super.key,
    required this.totalCost,
    required this.currency,
    required this.bookingDetails,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  Map<String, dynamic>? paymentIntent;
  bool _isLoading = false;

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> makePayment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      paymentIntent = await createPaymentIntent(widget.totalCost, widget.currency);

      if (paymentIntent == null || paymentIntent!['client_secret'] == null) {
        _showError('Failed to create payment intent. Please try again.');
        return;
      }

      // Add paymentIntentId to booking details before showing payment sheet
      widget.bookingDetails['paymentIntentId'] = paymentIntent!['id'];


      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent!['client_secret'],
          style: ThemeMode.light,
          merchantDisplayName: 'Travel Booking App',
        ),
      );

      await displayPaymentSheet();
    } catch (e) {
      _showError('An unexpected error occurred: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> displayPaymentSheet() async {
    try {
      await Stripe.instance.presentPaymentSheet();

      // **FIX: Save booking to Firestore AFTER successful payment**
      await FirebaseFirestore.instance.collection('bookings').add(widget.bookingDetails);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Payment Successful & Booking Saved!"), backgroundColor: Colors.green),
      );
      
      // Navigate to confirmation page
      if(mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => TicketConfirmationPage(
              bookingDetails: widget.bookingDetails,
            ),
          ),
        );
      }

    } on StripeException catch (e) {
      _showError('Payment failed: ${e.error.localizedMessage}');
    } catch (e) {
      _showError('Payment successful, but failed to save booking: $e');
    }
  }

  Future<Map<String, dynamic>?> createPaymentIntent(double amount, String currency) async {
    try {
      Map<String, dynamic> body = {
        'amount': (amount * 100).toInt().toString(),
        'currency': currency.toLowerCase(),
        'payment_method_types[]': 'card'
      };

      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer $secrekey',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: body,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body)['error'];
        _showError('Stripe API Error: ${error['message']}');
        return null;
      }
    } catch (err) {
      _showError('Failed to connect to payment service. Please check your internet connection.');
      return null;
    }
  }

  String getCurrencySymbol(String currencyCode) {
    switch (currencyCode) {
      case 'INR': return '₹';
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      default: return currencyCode;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extracting details for easier access
    final details = widget.bookingDetails;
    final travelers = details['travelers'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirm Your Booking"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Destination Details
            _buildSectionHeader("Trip Details"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow("Destination:", details['destinationName']),
                    _buildDetailRow("Pickup Location:", details['pickupLocation']),
                    _buildDetailRow("Start Date:", DateFormat('dd MMM, yyyy').format(details['startDate'].toDate())),
                    _buildDetailRow("End Date:", DateFormat('dd MMM, yyyy').format(details['endDate'].toDate())),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Traveler Details
            _buildSectionHeader("Traveler(s)"),
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
                       Text("Traveler ${idx + 1}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                       const Divider(),
                      _buildDetailRow("Name:", "${traveler['firstName']} ${traveler['surname']}"),
                      _buildDetailRow("Phone:", traveler['phone']),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 100), // Extra space to not be hidden by the button
          ],
        ),
      ),
      // NEW: Bottom navigation bar for the payment button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Total Cost:", style: TextStyle(color: Colors.grey)),
                  Text(
                    '${getCurrencySymbol(widget.currency)}${widget.totalCost.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : makePayment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Proceed to Payment"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Helper widget to build section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  // NEW: Helper widget to display a row of details
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
}