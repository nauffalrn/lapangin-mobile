import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'pages/history.dart';
import 'pages/profile.dart';
import 'pages/sign_in_page.dart';
import 'pages/register.dart'; 
import 'pages/forgotpassword.dart'; 

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
        '/login': (context) => const SignInPage2(),
        '/': (context) => HomePage(),
        
        '/history': (context) => HistoryBookingPage(),
        '/profile': (context) => ProfilePage(),
        '/register': (context) => const RegisterPage(), 
        '/forgotpassword': (context) => const ForgotPasswordPage(),
        
      },
    );
  }
}
