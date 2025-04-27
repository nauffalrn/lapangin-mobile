import 'package:flutter/material.dart';
import '../pages/home.dart';
import '../pages/history.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  const CustomBottomNavigationBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Color(0xFF0A192F),
      currentIndex: currentIndex,
      onTap: (index) {
        String route;
        if (index == 0) {
          route = '/';
        } else {
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
          icon: Icon(Icons.history, color: Colors.white),
          label: 'History',
        ),
      ],
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.grey,
    );
  }
}
