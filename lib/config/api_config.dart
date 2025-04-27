import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'dart:math';

class ApiConfig {
  // Jika dijalankan di perangkat fisik
  static const baseUrl = "http://192.168.100.5:8181/api";

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

  // Helper untuk mengambil headers dengan token
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await AuthService.getToken();
    if (token == null) {
      print("WARNING: No auth token found!");
      return {'Content-Type': 'application/json'};
    }

    print("Using auth token: ${token.substring(0, min(10, token.length))}...");
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}
