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

  // Initial auth check
  bool isLoggedIn = false;
  try {
    final token = await AuthService.ensureFreshToken();
    isLoggedIn = token != null;
    print("User is logged in: $isLoggedIn");
  } catch (e) {
    print("Error initializing auth: $e");
    // Clear any potentially corrupted tokens
    await AuthService.logout();
  }

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const MyApp({Key? key, required this.isLoggedIn}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: isLoggedIn ? '/' : '/login',
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
