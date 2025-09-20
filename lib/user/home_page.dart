import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:trevel_booking_app/user/Tips_page.dart';
import 'package:trevel_booking_app/user/community_page.dart';
import 'package:trevel_booking_app/user/reviews_page.dart';
import 'destination_detail_page.dart';
import 'planner_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomePageContent(),
    PlannerPage(),
    TipsPage(),
    CommunityPage(),
    ReviewsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today), label: 'Planner'),
          BottomNavigationBarItem(
              icon: Icon(Icons.lightbulb_outline), label: 'Tips'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Community'),
          BottomNavigationBarItem(
              icon: Icon(Icons.star_border), label: 'Reviews'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 10,
      ),
    );
  }
}

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  final String _userLocation = "New York, USA";
  String _selectedCategory = 'All';

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine the query based on the selected category
    Query destinationsQuery;
    if (_selectedCategory == 'All') {
      destinationsQuery = FirebaseFirestore.instance.collection('destinations');
    } else {
      destinationsQuery = FirebaseFirestore.instance
          .collection('destinations')
          .where('category', isEqualTo: _selectedCategory);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Travel Explorer'),
        centerTitle: false,
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_none, size: 28),
              onPressed: () {}),
          const SizedBox(width: 8),
          const CircleAvatar(
              backgroundImage: NetworkImage('https://via.placeholder.com/150'),
              radius: 18),
          const SizedBox(width: 16),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 60,
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome Back!',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.grey, size: 18),
                        const SizedBox(width: 4),
                        Text(_userLocation,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search destinations...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildCategoryFilter(),
              const SizedBox(height: 32),
              
              // Featured Destinations Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Featured Destinations',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('destinations')
                      .where('isFeatured', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                     if (snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No featured items yet.'));
                    }
                    return AnimationLimiter(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 16),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final destination = snapshot.data!.docs[index];
                          final data =
                              destination.data() as Map<String, dynamic>;
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              horizontalOffset: 50.0,
                              child: FadeInAnimation(
                                child: DestinationCard(
                                  imageUrl: data['imageUrl'] ?? '', name: data['name'] ?? '', location: data['location'] ?? '',
                                  rating: data['safetyRating']?.toDouble() ?? 0.0, 
                                  price: data['budget']?.toInt() ?? 0,
                                  currency: data['currency'] ?? '\$', 
                                  isFeatured: true,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DestinationDetailPage(destinationId: destination.id))),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              
              // Popular Destinations Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Popular Destinations',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: StreamBuilder<QuerySnapshot>(
                  stream: destinationsQuery.snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.docs.isEmpty) return const Center(heightFactor: 5, child: Text('No destinations found for this category.'));
                    
                    return AnimationLimiter(
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.7,
                        ),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final destination = snapshot.data!.docs[index];
                          final data = destination.data() as Map<String, dynamic>;
                          return AnimationConfiguration.staggeredGrid(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            columnCount: 2,
                            child: ScaleAnimation(
                              child: FadeInAnimation(
                                child: DestinationCard(
                                  imageUrl: data['imageUrl'] ?? '', name: data['name'] ?? '', location: data['location'] ?? '',
                                  rating: data['safetyRating']?.toDouble() ?? 0.0, 
                                  price: data['budget']?.toInt() ?? 0,
                                  currency: data['currency'] ?? '\$',
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DestinationDetailPage(destinationId: destination.id))),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final List<Map<String, dynamic>> categories = [
      {'name': 'All', 'icon': Icons.public},
      {'name': 'Beaches', 'icon': Icons.beach_access},
      {'name': 'Mountains', 'icon': Icons.terrain},
      {'name': 'Cities', 'icon': Icons.location_city},
      {'name': 'Forests', 'icon': Icons.park},
      {'name': 'Hiking', 'icon': Icons.hiking},
    ];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category['name'];
          return CategoryChip(
            label: category['name'],
            icon: category['icon'],
            isSelected: isSelected,
            onTap: () => _onCategorySelected(category['name']),
          );
        },
      ),
    );
  }
}

// ALL HELPER WIDGETS BELOW (No changes needed here, but included for completeness)

class CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.black54),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const UserAccountsDrawerHeader(
            accountName: Text("Shantnu"),
            accountEmail: Text("shantnu@example.com"),
            currentAccountPicture: CircleAvatar(backgroundImage: NetworkImage('https://via.placeholder.com/150')),
            decoration: BoxDecoration(
              color: Colors.blue,
              image: DecorationImage(
                fit: BoxFit.cover,
                image: NetworkImage('https://images.unsplash.com/photo-1542051841857-5f90071e7989'),
              ),
            ),
          ),
          ListTile(leading: const Icon(Icons.account_circle), title: const Text('Profile'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.bookmark_border), title: const Text('Saved Trips'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.settings), title: const Text('Settings'), onTap: () => Navigator.pop(context)),
          const Divider(),
          ListTile(leading: const Icon(Icons.exit_to_app), title: const Text('Logout'), onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class DestinationCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String location;
  final double rating;
  final int price;
  final String currency;
  final VoidCallback onTap;
  final bool isFeatured;

  const DestinationCard({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.location,
    required this.rating,
    required this.price,
    required this.currency,
    required this.onTap,
    this.isFeatured = false,
  });

  @override
  Widget build(BuildContext context) {
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isFeatured ? 200 : null,
        margin: EdgeInsets.only(right: isFeatured ? 16 : 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                imageUrl,
                height: isFeatured ? 140 : 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: isFeatured ? 140 : 120,
                  color: Colors.grey[300],
                  child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Text(location, style: const TextStyle(fontSize: 14, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.amber[600], size: 18),
                              const SizedBox(width: 4),
                              Flexible(child: Text('$rating', overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${getCurrencySymbol(currency)}$price',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}