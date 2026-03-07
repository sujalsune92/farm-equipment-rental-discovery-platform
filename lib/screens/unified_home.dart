import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'farmer_screens.dart';
import 'owner_screens.dart';

/// Unified bottom navigation for renters and owners
class UnifiedHomeScreen extends StatefulWidget {
  const UnifiedHomeScreen({super.key});

  @override
  State<UnifiedHomeScreen> createState() => _UnifiedHomeScreenState();
}

class _UnifiedHomeScreenState extends State<UnifiedHomeScreen> {
  int _tabIndex = 0;

  final _tabs = const [
    FarmerDiscoveryTab(),   // Discover equipment to rent
    FarmerBookingsTab(),    // My bookings as renter
    OwnerListingsTab(),     // My listings as owner
    OwnerBookingsTab(),     // Requests on my equipment
    ProfileTab(),           // Profile & settings
  ];

  final _items = const [
    BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Discover'),
    BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline), label: 'Bookings'),
    BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Listings'),
    BottomNavigationBarItem(icon: Icon(Icons.inbox_outlined), label: 'Requests'),
    BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    // Ensure we have a logged-in user; otherwise send back to login
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: _items,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
