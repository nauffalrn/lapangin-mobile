import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'pages/history.dart';
import 'pages/profile.dart';
import 'pages/sign_in_page.dart';
import 'pages/register.dart';
import 'pages/forgotpassword.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi AuthService untuk mendapatkan token
  try {
    await AuthService.getToken();
  } catch (e) {
    print("Error initializing auth: $e");
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute:
          '/login', // Default ke login, AuthService.initialize() akan dicek di halaman login
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
