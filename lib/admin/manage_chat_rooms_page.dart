import 'package:flutter/material.dart';
import 'package:trevel_booking_app/admin/admin_chat_view_page.dart';

class ManageChatRoomsPage extends StatelessWidget {
  const ManageChatRoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // This list should match the categories available to users.
    final List<Map<String, dynamic>> categories = [
      {'name': 'Beaches', 'icon': Icons.beach_access, 'color': Colors.blue},
      {'name': 'Mountains', 'icon': Icons.terrain, 'color': Colors.green},
      {'name': 'Cities', 'icon': Icons.location_city, 'color': Colors.orange},
      {'name': 'Hiking', 'icon': Icons.hiking, 'color': Colors.brown},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Chat to Moderate'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12.0),
            child: ListTile(
              leading: Icon(category['icon'], color: category['color']),
              title: Text(category['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminChatViewPage(
                      categoryName: category['name'],
                      categoryColor: category['color'],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}