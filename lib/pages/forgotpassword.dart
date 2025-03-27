import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController inputController = TextEditingController();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        backgroundColor: const Color(0xFF0A192F),
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        color: const Color(0xFF0A192F),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Enter your email or username to reset password",
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: inputController,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email or username';
                }
                bool isEmail = RegExp(
                  r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
                ).hasMatch(value);
                bool isUsername = RegExp(r"^[a-zA-Z0-9_]+$").hasMatch(value);
                if (!isEmail && !isUsername) {
                  return 'Please enter a valid email or username';
                }
                return null;
              },
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Email or Username',
                hintText: 'Enter your email or username',
                prefixIcon: Icon(Icons.person, color: Colors.white),
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: Colors.white),
                hintStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password reset link sent")),
                );
              },
              child: const Text("Reset Password"),
            ),
          ],
        ),
      ),
    );
  }
}
