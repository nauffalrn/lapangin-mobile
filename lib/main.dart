import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'pages/history.dart';
import 'pages/profile.dart';
import 'pages/sign_in_page.dart'; // Pastikan path ini benar

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const SignInPage2(), // Pastikan class ini ada
        '/': (context) => HomePage(),
        '/history': (context) => HistoryBookingPage(),
        '/profile': (context) => ProfilePage(),
      },
    );
  }
}
