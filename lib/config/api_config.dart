import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'dart:math';

class ApiConfig {
  // Jika dijalankan di perangkat fisik
  static const baseUrl = "http://192.168.107.186:8181/api";

  // Perbaikan URL gambar - mencoba URL alternatif
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return "";

    // Coba URL tanpa path /files/ - dari controllernya langsung
    return "$baseUrl/lapangan/image/$imagePath";
  }

  // Method untuk mendapatkan URL gambar dengan token
  static Future<String> getImageUrlWithToken(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return "";

    final token = await AuthService.getToken();
    return "$baseUrl/lapangan/image/$imagePath?token=$token";
  }

  // Add a specific method for profile images that uses the correct path
  static String getProfileImageUrl(String? imageName) {
    if (imageName == null || imageName.isEmpty) return "";
    
    // Use the correct path that matches your backend storage location
    return "$baseUrl/profile/images/$imageName";
  }

  // Helper untuk mengambil headers dengan token
  // Update the getAuthHeaders method to add session cookie support if needed
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await AuthService.getToken();
    if (token == null) {
      // Untuk debugging
      print("WARNING: getAuthHeaders found no auth token!");
      // Kembalikan header tanpa token
      return {'Content-Type': 'application/json'};
    }

    // Untuk debugging
    print(
      "Using auth token in getAuthHeaders: ${token.substring(0, min(10, token.length))}...",
    );

    // Tambahkan Accept header
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  // Use this method instead of the regular getAuthHeaders for critical operations
  static Future<Map<String, String>> getAuthHeadersWithRefresh() async {
    final token =
        await AuthService.ensureFreshToken(); // This validates the token
    if (token == null || token.isEmpty) {
      print("WARNING: No auth token found after refresh attempt!");
      throw Exception('Not authenticated. Please login first.');
    }

    print(
      "Using auth token after refresh: ${token.substring(0, min(10, token.length))}...",
    );
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Method to fetch reviews for a specific lapangan
  static String getReviewsUrl(int lapanganId) {
    return "$baseUrl/booking/reviews/$lapanganId";
  }

  // Method to post a new review
  static String getAddReviewUrl() {
    return "$baseUrl/review";
  }
}
