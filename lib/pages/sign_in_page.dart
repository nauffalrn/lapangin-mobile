import 'package:flutter/material.dart';
import 'home.dart';
import 'register.dart';
import '../services/auth_service.dart';
import '../models/auth_model.dart';

class SignInPage2 extends StatelessWidget {
  const SignInPage2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return PopScope(
      canPop: false, // Prevents back navigation
      child: Scaffold(
        appBar: AppBar(
          title: const Text(""),
          backgroundColor: const Color(0xFF0A192F), // Warna gelap
          automaticallyImplyLeading: false, // This removes the back button
        ),
        body: Container(
          color: const Color(0xFF0A192F), // Latar belakang gelap
          child: Center(
            child: SingleChildScrollView(
              child:
                  isSmallScreen
                      ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          _Logo(), // Komponen logo
                          SizedBox(height: 32), // Jarak antara logo dan form
                          _FormContent(), // Form login
                        ],
                      )
                      : Container(
                        padding: const EdgeInsets.all(32.0),
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Row(
                          children: const [
                            Expanded(child: _Logo()),
                            Expanded(child: Center(child: _FormContent())),
                          ],
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/logo.png', // Path ke file logo
          width: isSmallScreen ? 100 : 200, // Ukuran logo responsif
          height: isSmallScreen ? 100 : 200,
        ),
        const SizedBox(height: 16),
        Text(
          "Welcome to Lapangin!",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white, // Warna teks putih
          ),
        ),
      ],
    );
  }
}

class _FormContent extends StatefulWidget {
  const _FormContent({Key? key}) : super(key: key);

  @override
  State<_FormContent> createState() => __FormContentState();
}

class __FormContentState extends State<_FormContent> {
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding form
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Input email atau username
            TextFormField(
              controller: _loginController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email or username';
                }

                // Cek apakah input berupa email atau username
                bool isEmail = RegExp(
                  r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
                ).hasMatch(value);

                bool isUsername = RegExp(r"^[a-zA-Z0-9_]+$").hasMatch(value);

                if (!isEmail && !isUsername) {
                  return 'Please enter a valid email or username';
                }
                return null;
              },
              style: const TextStyle(color: Colors.white), // Warna teks input
              decoration: const InputDecoration(
                labelText: 'Email or Username',
                hintText: 'Enter your email or username',
                prefixIcon: Icon(Icons.person_outline, color: Colors.white),
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: Colors.white), // Warna label putih
                hintStyle: TextStyle(color: Colors.white70), // Warna hint putih
              ),
            ),
            _gap(),
            // Input Password
            TextFormField(
              controller: _passwordController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
              obscureText: !_isPasswordVisible,
              style: const TextStyle(color: Colors.white), // Warna teks input
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white,
                ),
                border: const OutlineInputBorder(),
                labelStyle: const TextStyle(
                  color: Colors.white,
                ), // Warna label putih
                hintStyle: const TextStyle(
                  color: Colors.white70,
                ), // Warna hint putih
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.white, // Warna ikon visibility
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            _gap(),
            CheckboxListTile(
              value: _rememberMe,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _rememberMe = value;
                });
              },
              title: const Text(
                'Remember me',
                style: TextStyle(color: Colors.white), // Warna teks putih
              ),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: const EdgeInsets.all(0),
            ),
            _gap(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 23.0,
                  ), // Tambahkan padding vertikal untuk membuat tombol lebih tinggi
                ),
                child: const Text('Sign in'),
                onPressed: () async {
                  if (_formKey.currentState?.validate() ?? false) {
                    try {
                      // Show loading spinner
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext dialogContext) {
                          return const Center(child: CircularProgressIndicator());
                        },
                      );

                      final loginRequest = LoginRequest(
                        username: _loginController.text,
                        password: _passwordController.text,
                      );

                      try {
                        // Add both timeout and response size protection
                        await AuthService.login(loginRequest)
                            .timeout(
                              const Duration(seconds: 15),
                              onTimeout: () => throw Exception("Login timed out. Please try again."),
                            );
                        
                        // Check if widget is still mounted before using context
                        if (!mounted) return;
                        
                        // Close the loading dialog
                        Navigator.of(context).pop();
                        
                        // Navigate to home page
                        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                      } catch (e) {
                        // Check if widget is still mounted before using context
                        if (!mounted) return;
                        
                        // Close the loading dialog
                        Navigator.of(context).pop();
                        
                        // Specific error message for out of memory errors
                        String errorMessage = e.toString();
                        if (errorMessage.contains('Out of Memory')) {
                          errorMessage = 'Server response too large. Please contact support.';
                        }
                        
                        // Then show error
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Login failed: $errorMessage')),
                        );
                      }
                    } catch (e) {
                      // This catch block is for dialog-related errors
                      if (!mounted) return;
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
                      );
                    }
                  }
                },
              ),
            ),
            _gap(),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/forgotpassword');
              },
              child: const Text('Forgot Password?'),
            ),
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  const TextSpan(
                    text: "Don't have an account? ",
                    style: TextStyle(
                      color: Colors.white,
                    ), // Ubah warna teks menjadi putih
                  ),
                  WidgetSpan(
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 16);
}
