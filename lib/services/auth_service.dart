import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Tambahkan import untuk min()
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/auth_model.dart';

class AuthService {
  static String? _token;

  static Future<String?> getToken() async {
    if (_token != null) return _token;

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  // Tambahkan metode ini untuk mendapatkan token dengan persistensi yang lebih baik
  static Future<String?> getTokenWithRefresh() async {
    // Coba ambil token yang ada
    final token = await getToken();

    // Jika token ada, gunakan
    if (token != null && token.isNotEmpty) {
      return token;
    }

    // Coba refresh token jika tidak ada
    final success = await reAuthenticate();
    if (success) {
      return getToken();
    }

    // Jika refresh gagal, kembalikan null
    return null;
  }

  // Metode ini akan dipanggil di semua service yang memerlukan autentikasi
  static Future<Map<String, String>> getAuthHeadersWithRefresh() async {
    final token = await getTokenWithRefresh();

    if (token == null || token.isEmpty) {
      return {'Content-Type': 'application/json'};
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  static Future<User> register(RegisterRequest request) async {
    print(
      "Mengirim permintaan register ke: ${ApiConfig.baseUrl}/auth/register",
    );
    print("Request body: ${jsonEncode(request.toJson())}");

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
          'Gagal mendaftar: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print("Register exception: $e");
      throw Exception('Gagal mendaftar: $e');
    }
  }

  static Future<void> login(LoginRequest loginRequest) async {
    try {
      // Debug logging
      print("Login attempt for user: ${loginRequest.username}");
      print("API URL: ${ApiConfig.baseUrl}/auth/login");
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': loginRequest.username,
          'password': loginRequest.password,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );

      print("Response status code: ${response.statusCode}");
      print("Response body: ${response.body}");

      // Check response size before processing
      if (response.contentLength != null && response.contentLength! > 10 * 1024 * 1024) {
        throw Exception('Response too large (${response.contentLength! ~/ (1024 * 1024)} MB)');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Save user data based on your Customer model structure
        final prefs = await SharedPreferences.getInstance();
        
        // Store all user fields from your Customer model
        if (data.containsKey('data') && data['data'] != null) {
          var userData = data['data'];
          prefs.setString('auth_token', userData['token'] ?? '');
          prefs.setString('user_id', userData['id']?.toString() ?? '');
          prefs.setString('username', userData['username'] ?? '');
          prefs.setString('name', userData['name'] ?? '');
          prefs.setString('email', userData['email'] ?? '');
          prefs.setString('phone_number', userData['phoneNumber'] ?? '');
          prefs.setString('profile_image', userData['profileImage'] ?? '');
        }
        
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid username or password');
      } else {
        throw Exception('Authentication failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print("Login exception: $e");
      throw e;
    }
  }

  static Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('email');
  }

  static Future<bool> reAuthenticate() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Dapatkan token yang tersimpan
      final token = prefs.getString('auth_token');
      if (token != null) {
        _token = token;
        return true; // Token sudah ada, gunakan saja
      }

      // Jika tidak ada token, coba login kembali dengan username
      final String? username = prefs.getString('username');
      if (username == null) {
        return false;
      }

      // Kita tidak menyimpan password hash, jadi tidak bisa re-login otomatis
      // User perlu login manual kembali
      return false;
    } catch (e) {
      print("Re-authentication failed: $e");
      return false;
    }
  }
}
