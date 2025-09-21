import 'package:flutter/material.dart';
import 'package:trevel_booking_app/admin/create_subadmin_page.dart';
import 'package:trevel_booking_app/admin/manage_admins_page.dart';
import 'package:trevel_booking_app/admin/manage_chat_rooms_page.dart';
import 'package:trevel_booking_app/admin/manage_posts_page.dart';
import 'package:trevel_booking_app/admin/manage_user_posts_page.dart';
import 'package:trevel_booking_app/admin/upload_destination_page.dart';
import 'package:trevel_booking_app/admin/view_bookings_page.dart';
import 'admin_login.dart'; // Make sure to import your admin login page

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        // The back arrow is usually handled automatically by Navigator
        // leading: IconButton(icon: Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.of(context).pop()),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AdminLoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey[100], // A light background color
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DashboardCard(
              icon: Icons.upload_file,
              title: 'Upload Post',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UploadDestinationPage(),
                  ),
                );
              },
            ),
            DashboardCard(
              icon: Icons.edit_calendar,
              title: 'Manage Post',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManagePostsPage()),
                );
              },
            ),
            DashboardCard(
              icon: Icons.local_activity,
              title: 'View Tickets',
              onTap: () {
                // TODO: Navigate to the View Tickets page
                debugPrint('View Tickets tapped');
              },
            ),
            DashboardCard(
              icon: Icons.person_add,
              title: 'Create Subadmin',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateSubadminPage()),
                );
              },
            ),
            DashboardCard(
              icon: Icons.manage_accounts,
              title: 'Manage Admins',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ManageAdminsPage()),
                );
              },
            ),
            DashboardCard(
              icon: Icons.supervised_user_circle,
              title: 'Manage User Posts',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageUserPostsPage(),
                  ),
                );
              },
            ),
            DashboardCard(
              icon: Icons.chat_bubble_outline,
              title: 'Moderate Chats',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageChatRoomsPage(),
                  ),
                );
              },
            ),
              DashboardCard(
              icon: Icons.local_activity,
              title: 'View Tickets',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ViewBookingsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A reusable card widget for the dashboard items
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 30.0, color: Theme.of(context).primaryColor),
              const SizedBox(width: 20.0),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
