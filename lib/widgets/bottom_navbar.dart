import 'package:flutter/material.dart';
import '../pages/home.dart';
import '../pages/history.dart';
import '../pages/tracking_booking.dart';
import '../services/auth_service.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  const CustomBottomNavigationBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Color(0xFF0A192F),
      currentIndex: currentIndex,
      onTap: (index) async {
        // Initialize route with a default value
        String route = '/';
        
        if (index == 0) {
          route = '/';
        } else if (index == 1) {
          // For tracking tab, we need to check if user has active bookings
          final isLoggedIn = await AuthService.isLoggedIn();
          if (!isLoggedIn) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Silakan login terlebih dahulu untuk melihat aktifitas booking'))
            );
            route = '/login';
          } else {
            route = '/active-bookings'; // New route for active bookings list
          }
        } else if (index == 2) {
          route = '/history';
        }
        
        Navigator.of(context).pushReplacementNamed(route);
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home, color: Colors.white),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.track_changes, color: Colors.white),
          label: 'Tracking',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history, color: Colors.white),
          label: 'History',
        ),
      ],
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.grey,
    );
  }
}
