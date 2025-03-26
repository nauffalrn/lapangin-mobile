import 'package:flutter/material.dart';
import '../widgets/bottom_navbar.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: const Color(0xFF0A192F),
          leading: Padding(
            padding: const EdgeInsets.only(left: 8.0), // Jarak dari tepi kiri
            child: Image.asset(
              'assets/logo.png', // Path ke file logo
              width: 40, // Ukuran logo
              height: 40,
            ),
          ),
          title: const Text(
            'Profile',
            style: TextStyle(
              fontSize: 22, // Ukuran heading disamakan
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true, // Pastikan teks berada di tengah
        ),
      ),
      body: const Center(
        child: Text('Ini Halaman Profile', style: TextStyle(fontSize: 18)),
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 2),
    );
  }
}
