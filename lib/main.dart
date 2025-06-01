import 'package:flutter/material.dart';
import 'pages/home.dart';
import 'pages/history.dart';
import 'pages/profile.dart';
import 'pages/sign_in_page.dart';
import 'pages/register.dart';
import 'pages/forgotpassword.dart';
import 'services/auth_service.dart';
import 'pages/tracking_booking.dart'; // Add this import
import 'pages/active_bookings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initial auth check
  bool isLoggedIn = false;
  try {
    // PERBAIKAN: Ganti ensureFreshToken() dengan getToken()
    final token = await AuthService.getToken();
    isLoggedIn = token != null && token.isNotEmpty;
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
      title: 'Lapangin Mobile App',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: isLoggedIn ? '/' : '/login',
      routes: {
        '/login': (context) => const SignInPage2(),
        '/': (context) => HomePage(),
        '/history': (context) => HistoryBookingPage(),
        '/profile': (context) => ProfilePage(),
        '/register': (context) => const RegisterPage(),
        '/forgotpassword': (context) => const ForgotPasswordPage(),
        '/tracking':
            (context) => TrackingBookingPage(
              bookingId: ModalRoute.of(context)!.settings.arguments as int,
            ),
        '/active-bookings': (context) => ActiveBookingsPage(),
      },
    );
  }
}
