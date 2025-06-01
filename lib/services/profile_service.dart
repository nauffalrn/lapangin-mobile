import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ProfileService {
  // PERBAIKAN KRITIS: Upload HANYA image, JANGAN sentuh data user lain
  static Future<String> uploadProfileImage(String imagePath) async {
    try {
      print("Starting profile image upload from: $imagePath");

      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required. Please login again.');
      }

      final url = '${ApiConfig.baseUrl}/profile/update-image';
      print("Upload URL: $url");

      var request = http.MultipartRequest('POST', Uri.parse(url));

      // HANYA set authorization header
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // PERBAIKAN: PASTIKAN HANYA file image yang dikirim
      var file = await http.MultipartFile.fromPath(
        'image', // Field name untuk image
        imagePath,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(file);

      // JANGAN tambahkan field lain yang bisa mengubah data user
      // JANGAN kirim: name, email, phoneNumber, username, password

      final tokenPreview = token.length > 10 ? token.substring(0, 10) : token;
      print("Sending request with token: $tokenPreview...");
      print("ONLY sending image file, no other user data");

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("Upload response status: ${response.statusCode}");
      print("Upload response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          String imageUrl = responseData['data']['profileImage'];

          // PERBAIKAN: HANYA simpan profile image ke SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profile_image', imageUrl);

          print("SUCCESS: ONLY updated profile_image: $imageUrl");
          print("User data (name, email, phone, username) NOT TOUCHED");

          return imageUrl;
        } else {
          throw Exception(responseData['message'] ?? 'Upload failed');
        }
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Upload failed with status: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print("Error uploading profile image: $e");
      throw e;
    }
  }

  // Method untuk mendapatkan profil TANPA mengubah apa-apa
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required. Please login again.');
      }

      final url = '${ApiConfig.baseUrl}/profile/user';
      print("Fetching profile from: $url");

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      print("Profile response status: ${response.statusCode}");
      print("Profile response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true && responseData['data'] != null) {
          var userData = responseData['data'];

          // PERBAIKAN: JANGAN auto-update SharedPreferences
          // Biarkan data existing tetap utuh
          print("Profile data fetched successfully, keeping local data intact");

          return userData;
        } else {
          throw Exception(
            responseData['message'] ?? 'Failed to load profile data',
          );
        }
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to fetch profile: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching profile: $e");
      throw e;
    }
  }
}
