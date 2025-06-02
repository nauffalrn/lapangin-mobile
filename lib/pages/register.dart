import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home.dart';
import '../services/auth_service.dart';
import '../models/auth_model.dart';
import '../config/api_config.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        backgroundColor: const Color(0xFF0A192F),
      ),
      body: Container(
        color: const Color(0xFF0A192F),
        child: Center(
          child: SingleChildScrollView(
            child: isSmallScreen
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      _Logo(),
                      SizedBox(height: 32),
                      _RegisterForm(),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.all(32.0),
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Row(
                      children: const [
                        Expanded(child: _Logo()),
                        Expanded(child: Center(child: _RegisterForm())),
                      ],
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
          'assets/logo.png',
          width: isSmallScreen ? 100 : 200,
          height: isSmallScreen ? 100 : 200,
        ),
        const SizedBox(height: 16),
        Text(
          "Join Lapangin!",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm({Key? key}) : super(key: key);

  @override
  State<_RegisterForm> createState() => __RegisterFormState();
}

class __RegisterFormState extends State<_RegisterForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // Error states untuk setiap field
  String? _usernameError;
  String? _emailError;
  String? _phoneError;

  // TAMBAHAN: Method untuk check duplikasi real-time
  Future<bool> _checkDuplicateUsername(String username) async {
    if (username.isEmpty) return true;
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/check-username/$username'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['exists'] != true; // Return true jika username TIDAK ada (available)
      }
      return true; // Jika error, anggap available
    } catch (e) {
      print("Error checking username: $e");
      return true; // Jika error, anggap available
    }
  }

  Future<bool> _checkDuplicateEmail(String email) async {
    if (email.isEmpty) return true;
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/check-email/$email'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['exists'] != true; // Return true jika email TIDAK ada (available)
      }
      return true;
    } catch (e) {
      print("Error checking email: $e");
      return true;
    }
  }

  Future<bool> _checkDuplicatePhone(String phone) async {
    if (phone.isEmpty) return true;
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/check-phone/$phone'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['exists'] != true; // Return true jika phone TIDAK ada (available)
      }
      return true;
    } catch (e) {
      print("Error checking phone: $e");
      return true;
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Registration Successful"),
          content: const Text(
            "Your account has been created successfully. Please login to continue.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(
              _emailController,
              "Email",
              "Enter your email",
              Icons.email,
              isEmail: true,
              customError: _emailError,
              onChanged: (value) async {
                if (value.isNotEmpty && RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                  final isAvailable = await _checkDuplicateEmail(value);
                  setState(() {
                    _emailError = isAvailable ? null : 'Email sudah terdaftar';
                  });
                } else {
                  setState(() {
                    _emailError = null;
                  });
                }
              },
            ),
            _gap(),
            _buildTextField(
              _usernameController,
              "Username",
              "Enter your username",
              Icons.person,
              customError: _usernameError,
              onChanged: (value) async {
                if (value.length >= 3) {
                  final isAvailable = await _checkDuplicateUsername(value);
                  setState(() {
                    _usernameError = isAvailable ? null : 'Username sudah digunakan';
                  });
                } else {
                  setState(() {
                    _usernameError = null;
                  });
                }
              },
            ),
            _gap(),
            _buildTextField(
              _nameController,
              "Name",
              "Enter your name",
              Icons.badge,
            ),
            _gap(),
            _buildTextField(
              _phoneNumberController,
              "Phone Number",
              "Enter your phone number",
              Icons.phone,
              customError: _phoneError,
              onChanged: (value) async {
                if (value.length >= 10) {
                  final isAvailable = await _checkDuplicatePhone(value);
                  setState(() {
                    _phoneError = isAvailable ? null : 'Nomor telepon sudah digunakan';
                  });
                } else {
                  setState(() {
                    _phoneError = null;
                  });
                }
              },
            ),
            _gap(),
            _buildPasswordField(_passwordController, "Password"),
            _gap(),
            _buildPasswordField(
              _confirmPasswordController,
              "Confirm Password",
              isConfirm: true,
            ),
            _gap(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: _isLoading 
                    ? CircularProgressIndicator(color: Colors.white)
                    : const Padding(
                        padding: EdgeInsets.all(10.0),
                        child: Text(
                          'Register',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                onPressed: _isLoading ? null : () async {
                  if (_formKey.currentState?.validate() ?? false) {
                    // Check for custom errors
                    if (_usernameError != null || _emailError != null || _phoneError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Mohon perbaiki error yang ada'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      // Final validation - check duplikasi sekali lagi
                      final isUsernameAvailable = await _checkDuplicateUsername(_usernameController.text.trim());
                      if (!isUsernameAvailable) {
                        setState(() {
                          _usernameError = 'Username sudah digunakan';
                          _isLoading = false;
                        });
                        return;
                      }

                      final isEmailAvailable = await _checkDuplicateEmail(_emailController.text.trim());
                      if (!isEmailAvailable) {
                        setState(() {
                          _emailError = 'Email sudah terdaftar';
                          _isLoading = false;
                        });
                        return;
                      }

                      final isPhoneAvailable = await _checkDuplicatePhone(_phoneNumberController.text.trim());
                      if (!isPhoneAvailable) {
                        setState(() {
                          _phoneError = 'Nomor telepon sudah digunakan';
                          _isLoading = false;
                        });
                        return;
                      }

                      // Buat objek permintaan register
                      final registerRequest = RegisterRequest(
                        name: _nameController.text.trim(),
                        username: _usernameController.text.trim(),
                        email: _emailController.text.trim(),
                        password: _passwordController.text,
                        phoneNumber: _phoneNumberController.text.trim(),
                      );

                      // Panggil service untuk register
                      await AuthService.register(registerRequest);

                      setState(() {
                        _isLoading = false;
                      });

                      // Tampilkan dialog sukses
                      _showSuccessDialog();
                    } catch (e) {
                      setState(() {
                        _isLoading = false;
                      });

                      // Extract meaningful error message
                      String errorMessage = e.toString();
                      if (errorMessage.contains('Username sudah digunakan')) {
                        setState(() {
                          _usernameError = 'Username sudah digunakan';
                        });
                      } else if (errorMessage.contains('Email sudah terdaftar')) {
                        setState(() {
                          _emailError = 'Email sudah terdaftar';
                        });
                      } else if (errorMessage.contains('Nomor telepon sudah digunakan')) {
                        setState(() {
                          _phoneError = 'Nomor telepon sudah digunakan';
                        });
                      } else if (errorMessage.contains('timeout')) {
                        errorMessage = 'Koneksi timeout, coba lagi';
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Registrasi gagal: $errorMessage'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            _gap(),
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                children: [
                  const TextSpan(text: "Already have an account? "),
                  WidgetSpan(
                    child: InkWell(
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: const Text(
                        'Login',
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

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool isEmail = false,
    String? customError,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Mohon isi $label';
        }
        
        // ENHANCED VALIDATION per field
        if (label == "Username") {
          if (value.length < 3) {
            return 'Username minimal 3 karakter';
          }
          if (value.length > 20) {
            return 'Username maksimal 20 karakter';
          }
          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
            return 'Username hanya boleh huruf, angka, dan underscore';
          }
        }
        
        if (label == "Name") {
          if (value.length < 2) {
            return 'Nama minimal 2 karakter';
          }
          if (value.length > 50) {
            return 'Nama maksimal 50 karakter';
          }
          if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
            return 'Nama hanya boleh huruf dan spasi';
          }
        }
        
        if (label == "Phone Number") {
          if (value.length < 10) {
            return 'Nomor telepon minimal 10 digit';
          }
          if (value.length > 15) {
            return 'Nomor telepon maksimal 15 digit';
          }
          if (!RegExp(r'^[0-9+]+$').hasMatch(value)) {
            return 'Nomor telepon hanya boleh angka dan tanda +';
          }
        }
        
        if (isEmail && !RegExp(
          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
        ).hasMatch(value)) {
          return 'Format email tidak valid';
        }
        
        // Return custom error jika ada
        if (customError != null) {
          return customError;
        }
        
        return null;
      },
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white),
        border: const OutlineInputBorder(),
        labelStyle: const TextStyle(color: Colors.white),
        hintStyle: const TextStyle(color: Colors.white70),
        errorText: customError, // Tampilkan error kustom
        errorStyle: const TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _buildPasswordField(
    TextEditingController controller,
    String label, {
    bool isConfirm = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Mohon isi $label';
        }
        
        // UPDATED PASSWORD VALIDATION - error message yang lebih ringkas
        if (!isConfirm) {
          if (value.length < 8) {
            return 'Min 8 karakter';
          }
          if (value.length > 20) {
            return 'Max 20 karakter';
          }
          if (!RegExp(r'^(?=.*[A-Z]).*$').hasMatch(value)) {
            return 'Harus ada huruf besar';
          }
        }
        
        if (isConfirm && value != _passwordController.text) {
          return 'Password tidak cocok';
        }
        return null;
      },
      obscureText: !_isPasswordVisible,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: isConfirm 
            ? 'Konfirmasi password' 
            : '8-20 karakter, ada huruf besar',
        prefixIcon: const Icon(Icons.lock, color: Colors.white),
        border: const OutlineInputBorder(),
        labelStyle: const TextStyle(color: Colors.white),
        hintStyle: const TextStyle(color: Colors.white70, fontSize: 12),
        errorStyle: const TextStyle(
          color: Colors.red,
          fontSize: 12,
          height: 1.2, // Memberikan ruang lebih untuk error text
        ),
        errorMaxLines: 2, // Izinkan error text sampai 2 baris
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 16);
}