import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/auth_model.dart';

class AuthService {
  static String? _token;

  static Future<String?> getToken() async {
    if (_token != null && _token!.isNotEmpty) return _token;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null || token.isEmpty) {
      print("No token found in SharedPreferences");
      return null;
    }

    _token = token;
    return _token;
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    print(
      "Token saved successfully: ${token.substring(0, min(10, token.length))}...",
    );
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
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

  // Update method login dengan proteksi data yang lebih baik:
  static Future<void> login(LoginRequest loginRequest) async {
    try {
      print("=== LOGIN PROCESS START ===");
      print("Username: ${loginRequest.username}");

      // BERSIHKAN cache token yang mungkin corrupt
      _token = null;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(loginRequest.toJson()),
      );

      print("Login response status: ${response.statusCode}");
      print("Login response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          print("Login response data: ${data['data']}");

          final responseData = data['data'];
          final token = responseData['token'];

          if (token == null || token.isEmpty) {
            print("Token tidak ditemukan dalam respon");
            throw Exception('Token tidak ditemukan dalam respon');
          }

          // SIMPAN TOKEN DULU
          await saveToken(token);
          print("Token saved successfully");

          final prefs = await SharedPreferences.getInstance();

          // PERBAIKAN KRITIS: CEK APAKAH INI USER YANG BERBEDA
          final currentStoredUsername = prefs.getString('username');
          final newUsername = responseData['user']?['username'];

          bool isDifferentUser =
              currentStoredUsername != null &&
              newUsername != null &&
              currentStoredUsername != newUsername;

          if (isDifferentUser) {
            print("=== DIFFERENT USER DETECTED ===");
            print("Previous user: $currentStoredUsername");
            print("New user: $newUsername");

            // HAPUS SEMUA DATA USER SEBELUMNYA
            await prefs.remove('username');
            await prefs.remove('name');
            await prefs.remove('email');
            await prefs.remove('phone_number');
            await prefs.remove(
              'profile_image',
            ); // PENTING: Hapus profile image user lama

            print("Cleared previous user data");
          }

          // UPDATE USER DATA DENGAN DATA BARU
          if (responseData['user'] != null) {
            final userData = responseData['user'];

            // Update user data dengan aman
            if (userData['username'] != null) {
              await prefs.setString('username', userData['username']);
              print("Updated username: ${userData['username']}");
            }

            if (userData['name'] != null) {
              await prefs.setString('name', userData['name']);
              print("Updated name: ${userData['name']}");
            }

            if (userData['email'] != null) {
              await prefs.setString('email', userData['email']);
              print("Updated email: ${userData['email']}");
            }

            if (userData['phoneNumber'] != null) {
              await prefs.setString('phone_number', userData['phoneNumber']);
              print("Updated phone_number: ${userData['phoneNumber']}");
            }

            // PERBAIKAN KRITIS: Profile image handling yang benar
            if (userData['profileImage'] != null &&
                userData['profileImage'].toString().isNotEmpty &&
                userData['profileImage'].toString() != 'null') {
              // User ini memang punya profile image
              await prefs.setString('profile_image', userData['profileImage']);
              print(
                "Set profile image for this user: ${userData['profileImage']}",
              );
            } else {
              // User ini tidak punya profile image
              await prefs.remove('profile_image');
              print("This user has no profile image - cleared storage");
            }
          }

          print('=== LOGIN SUCCESSFUL ===');
          print(
            'Token saved: ${_token!.substring(0, min(10, _token!.length))}...',
          );
        } else {
          throw Exception(data['message'] ?? 'Login gagal');
        }
      } else {
        final errorData = json.decode(response.body);
        String errorMessage =
            errorData['message'] ?? 'Login gagal: ${response.statusCode}';
        print("=== LOGIN FAILED ===");
        print("Error message: $errorMessage");
        throw Exception(errorMessage);
      }
    } catch (e) {
      print("=== LOGIN ERROR ===");
      print("Error: $e");
      throw e;
    }
  }

  // PERBAIKAN: Logout yang HANYA menghapus token
  static Future<void> logout({bool clearAllData = false}) async {
    try {
      print("Starting logout process...");

      if (clearAllData) {
        await clearAllUserData();
      } else {
        _token = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
      }

      print("User logged out successfully");
    } catch (e) {
      print("Error during logout: $e");
    }
  }

  static Future<void> clearAllUserData() async {
    try {
      print("Clearing all user data...");

      _token = null;
      final prefs = await SharedPreferences.getInstance();

      // Hapus semua data terkait user
      await prefs.remove('auth_token');
      await prefs.remove('username');
      await prefs.remove('name');
      await prefs.remove('email');
      await prefs.remove('phone_number');
      await prefs.remove('profile_image');

      // Hapus juga data lain yang mungkin ada
      await prefs.remove('claimed_promo_ids');

      print("All user data cleared successfully");
    } catch (e) {
      print("Error clearing user data: $e");
    }
  }

  static void updateCachedToken(String token) {
    _token = token;
    print(
      "Token updated in cache: ${token.substring(0, min(10, token.length))}...",
    );
  }
}
