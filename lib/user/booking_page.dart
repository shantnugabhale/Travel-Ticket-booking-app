import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:trevel_booking_app/user/payment_page.dart';

class TravelerInfo {
  final TextEditingController firstNameController;
  final TextEditingController middleNameController;
  final TextEditingController surnameController;
  final TextEditingController phoneController;
  final TextEditingController aadhaarController;
  final TextEditingController passportController;

  TravelerInfo()
      : firstNameController = TextEditingController(),
        middleNameController = TextEditingController(),
        surnameController = TextEditingController(),
        phoneController = TextEditingController(),
        aadhaarController = TextEditingController(),
        passportController = TextEditingController();

  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    surnameController.dispose();
    phoneController.dispose();
    aadhaarController.dispose();
    passportController.dispose();
  }
}

class BookingPage extends StatefulWidget {
  final String destinationId;
  final String destinationName;
  final String destinationImageUrl;
  final double basePricePerPerson;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final int? initialTravelers;

  const BookingPage({
    super.key,
    required this.destinationId,
    required this.destinationName,
    required this.destinationImageUrl,
    this.basePricePerPerson = 120.0,
    this.initialStartDate,
    this.initialEndDate,
    this.initialTravelers,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String? _selectedPickupLocation;
  DateTime? _startDate;
  DateTime? _endDate;
  int _numberOfTravelers = 1;

  List<TravelerInfo> _travelerInfoList = [TravelerInfo()];
  late Future<DocumentSnapshot> _destinationFuture;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    if (widget.initialTravelers != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateTravelerForms(widget.initialTravelers!);
      });
    }
    _destinationFuture = FirebaseFirestore.instance
        .collection('destinations')
        .doc(widget.destinationId)
        .get();
  }

  void _updateTravelerForms(int count) {
    setState(() {
      _numberOfTravelers = count;
      for (var info in _travelerInfoList) {
        info.dispose();
      }
      _travelerInfoList = List.generate(count, (_) => TravelerInfo());
    });
  }

  @override
  void dispose() {
    for (var info in _travelerInfoList) {
      info.dispose();
    }
    super.dispose();
  }

  Future<void> _proceedToPayment() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all required fields for each traveler.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final destinationData = await _destinationFuture;
    final currency = (destinationData.data() as Map<String, dynamic>)['currency'] ?? 'USD';

    final bookingDetails = {
      'userId': FirebaseAuth.instance.currentUser!.uid,
      'destinationId': widget.destinationId,
      'destinationName': widget.destinationName,
      'destinationImageUrl': widget.destinationImageUrl,
      'pickupLocation': _selectedPickupLocation,
      'startDate': Timestamp.fromDate(_startDate!),
      'endDate': Timestamp.fromDate(_endDate!),
      'travelers': _travelerInfoList
          .map((info) => {
                'firstName': info.firstNameController.text.trim(),
                'middleName': info.middleNameController.text.trim(),
                'surname': info.surnameController.text.trim(),
                'phone': info.phoneController.text.trim(),
                'aadhaar': info.aadhaarController.text.trim(),
                'passportId': info.passportController.text.trim(),
              })
          .toList(),
      'totalCost': widget.basePricePerPerson * _numberOfTravelers,
      'status': 'Booked',
      'bookedAt': Timestamp.now(),
      'paymentIntentId': null, // This will be filled in on the Payment Page
    };

    // Navigate to payment page without waiting for a result
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          totalCost: widget.basePricePerPerson * _numberOfTravelers,
          currency: currency,
          bookingDetails: bookingDetails,
        ),
      ),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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
      appBar: AppBar(title: Text('Book Trip to ${widget.destinationName}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trip Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPickupLocation,
                decoration: const InputDecoration(
                    labelText: 'Select Nearest Pickup Location',
                    border: OutlineInputBorder()),
                items: ['Mumbai Airport', 'Pune Airport', 'Delhi Airport']
                    .map((loc) =>
                        DropdownMenuItem(value: loc, child: Text(loc)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedPickupLocation = value),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _buildDatePickerField(isStartDate: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildDatePickerField(isStartDate: false))
              ]),
              const Divider(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Travelers Information',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  DropdownButton<int>(
                    value: _numberOfTravelers,
                    items: List.generate(10, (i) => i + 1)
                        .map((num) => DropdownMenuItem(
                            value: num,
                            child: Text('$num Person${num > 1 ? 's' : ''}')))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _updateTravelerForms(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _travelerInfoList.length,
                itemBuilder: (context, index) {
                  return TravelerForm(
                    personNumber: index + 1,
                    info: _travelerInfoList[index],
                  );
                },
              ),
              const Divider(height: 40),
              _buildCostSection(),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _proceedToPayment,
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Proceed to Payment',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerField({required bool isStartDate}) {
    DateTime? date = isStartDate ? _startDate : _endDate;
    String label = isStartDate ? 'Start Date' : 'End Date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade100,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date == null
                    ? 'Not set'
                    : DateFormat('dd MMM, yyyy').format(date),
                style: TextStyle(
                    fontSize: 16,
                    color: date == null ? Colors.grey[700] : Colors.black),
              ),
              const Icon(Icons.calendar_today_outlined, color: Colors.grey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCostSection() {
    return FutureBuilder<DocumentSnapshot>(
      future: _destinationFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final currency = data['currency'] ?? 'USD';
        final totalCost = widget.basePricePerPerson * _numberOfTravelers;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total Cost:',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            Text('${getCurrencySymbol(currency)}${totalCost.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        );
      },
    );
  }
}

class TravelerForm extends StatelessWidget {
  final int personNumber;
  final TravelerInfo info;
  const TravelerForm({super.key, required this.personNumber, required this.info});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              personNumber == 1
                  ? 'Traveler 1 (Primary Contact)'
                  : 'Traveler $personNumber Details',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent),
            ),
            const Divider(height: 20),
            Row(children: [
              Expanded(
                  child: TextFormField(
                      controller: info.firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null)),
              const SizedBox(width: 8),
              Expanded(
                  child: TextFormField(
                      controller: info.surnameController,
                      decoration: const InputDecoration(labelText: 'Surname'),
                      validator: (v) => v!.isEmpty ? 'Required' : null)),
            ]),
            const SizedBox(height: 12),
            TextFormField(
                controller: info.middleNameController,
                decoration: const InputDecoration(labelText: 'Middle Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: info.phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: info.aadhaarController,
                decoration: const InputDecoration(labelText: 'Aadhaar Number'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: info.passportController,
                decoration: const InputDecoration(labelText: 'Passport ID'),
                validator: (v) => v!.isEmpty ? 'Required' : null),
          ],
        ),
      ),
    );
  }
}