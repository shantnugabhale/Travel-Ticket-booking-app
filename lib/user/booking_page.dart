import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
    _updateTravelerForms(0);
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, {required bool isStartDate}) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _startDate : _endDate) ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }

  Future<void> _bookTickets() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields for each traveler.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      final travelersData = _travelerInfoList.map((info) => {
        'firstName': info.firstNameController.text.trim(),
        'middleName': info.middleNameController.text.trim(),
        'surname': info.surnameController.text.trim(),
        'phone': info.phoneController.text.trim(),
        'aadhaar': info.aadhaarController.text.trim(),
        'passportId': info.passportController.text.trim(),
      }).toList();

      await FirebaseFirestore.instance.collection('bookings').add({
        'userId': user.uid,
        'destinationId': widget.destinationId,
        'destinationName': widget.destinationName,
        'destinationImageUrl': widget.destinationImageUrl,
        'pickupLocation': _selectedPickupLocation,
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'travelers': travelersData,
        'totalCost': widget.basePricePerPerson * _numberOfTravelers,
        'status': 'Booked',
        'bookedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking successful!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalCost = widget.basePricePerPerson * _numberOfTravelers;
    
    return Scaffold(
      appBar: AppBar(title: Text('Book Trip to ${widget.destinationName}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trip Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPickupLocation,
                decoration: const InputDecoration(labelText: 'Select Nearest Pickup Location', border: OutlineInputBorder()),
                items: ['Mumbai Airport', 'Pune Airport', 'Delhi Airport']
                    .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedPickupLocation = value),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(children: [Expanded(child: _buildDatePickerField(isStartDate: true)), const SizedBox(width: 16), Expanded(child: _buildDatePickerField(isStartDate: false))]),
              const Divider(height: 40),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Travelers Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  DropdownButton<int>(
                    value: _numberOfTravelers,
                    items: List.generate(10, (i) => i + 1)
                        .map((num) => DropdownMenuItem(value: num, child: Text('$num Person${num > 1 ? 's' : ''}')))
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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Cost:', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  Text('\$${totalCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _bookTickets,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Book Tickets', style: TextStyle(fontSize: 18)),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
  
  // --- FIX: Restored the code for this helper widget ---
  Widget _buildDatePickerField({required bool isStartDate}) {
    DateTime? date = isStartDate ? _startDate : _endDate;
    String label = isStartDate ? 'Start Date' : 'End Date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context, isStartDate: isStartDate),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date == null ? 'Select' : DateFormat('dd MMM, yyyy').format(date),
                  style: TextStyle(fontSize: 16, color: date == null ? Colors.grey[700] : Colors.black),
                ),
                const Icon(Icons.calendar_today_outlined, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
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
              personNumber == 1 ? 'Traveler 1 (Primary Contact)' : 'Traveler $personNumber Details',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            const Divider(height: 20),
            Row(children: [
              Expanded(child: TextFormField(controller: info.firstNameController, decoration: const InputDecoration(labelText: 'First Name'), validator: (v) => v!.isEmpty ? 'Required' : null)),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: info.surnameController, decoration: const InputDecoration(labelText: 'Surname'), validator: (v) => v!.isEmpty ? 'Required' : null)),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: info.middleNameController, decoration: const InputDecoration(labelText: 'Middle Name (Optional)')),
            const SizedBox(height: 12),
            TextFormField(controller: info.phoneController, decoration: const InputDecoration(labelText: 'Phone Number'), keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: info.aadhaarController, decoration: const InputDecoration(labelText: 'Aadhaar Number (Optional)'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextFormField(controller: info.passportController, decoration: const InputDecoration(labelText: 'Passport ID'), validator: (v) => v!.isEmpty ? 'Required' : null),
          ],
        ),
      ),
    );
  }
}