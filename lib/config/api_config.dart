import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'dart:math';

class ApiConfig {
  static const baseUrl = "http://192.168.192.186:8181/api";

  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return "";
    return "$baseUrl/lapangan/image/$imagePath";
  }

  static Future<String> getImageUrlWithToken(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return "";
    final token = await AuthService.getToken();
    return "$baseUrl/lapangan/image/$imagePath?token=$token";
  }

  // Profile image URL dengan token
  static Future<String> getProfileImageUrl(String? imageName) async {
    if (imageName == null || imageName.isEmpty) return "";

    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty) {
      return "$baseUrl/profile/images/$imageName?token=$token";
    }

    return "$baseUrl/profile/images/$imageName";
  }

  // Synchronous version for backward compatibility
  static String getProfileImageUrlSync(String? imageName) {
    if (imageName == null || imageName.isEmpty) return "";
    return "$baseUrl/profile/images/$imageName";
  }

  static Future<String> getProfileImageUrlWithToken(String? imageName) async {
    if (imageName == null || imageName.isEmpty) return "";
    final token = await AuthService.getToken();
    return "$baseUrl/profile/images/$imageName?token=$token";
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      print("WARNING: getAuthHeaders found no auth token!");
      return {
        'Content-Type': 'application/json',
      }; // Return headers tanpa Authorization
    }

    final tokenLength = token.length;
    final previewLength = min(10, tokenLength);
    final tokenPreview =
        tokenLength > 0 ? token.substring(0, previewLength) : 'empty';
    print("Using auth token in getAuthHeaders: $tokenPreview...");

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  // Headers untuk image loading
  static Future<Map<String, String>> getImageHeaders() async {
    final token = await AuthService.getToken();
    if (token == null) {
      return {};
    }

    return {'Authorization': 'Bearer $token', 'Accept': 'image/*'};
  }

  static Future<Map<String, String>> getAuthHeadersForMultipart() async {
    final token = await AuthService.getToken();
    if (token == null) {
      print("WARNING: getAuthHeaders found no auth token!");
      return {};
    }

    final tokenLength = token.length;
    final previewLength = min(10, tokenLength);
    final tokenPreview =
        tokenLength > 0 ? token.substring(0, previewLength) : 'empty';
    print("Using auth token for multipart: $tokenPreview...");

    return {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
  }

  // PERBAIKAN: Ganti ensureFreshToken() dengan getToken()
  static Future<Map<String, String>> getAuthHeadersWithRefresh() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      print("WARNING: No auth token found!");
      throw Exception('Not authenticated. Please login first.');
    }

    final tokenLength = token.length;
    final previewLength = min(10, tokenLength);
    final tokenPreview =
        tokenLength > 0 ? token.substring(0, previewLength) : 'empty';
    print("Using auth token: $tokenPreview...");

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String getReviewsUrl(int lapanganId) {
    return "$baseUrl/booking/reviews/$lapanganId";
  }

  static String getAddReviewUrl() {
    return "$baseUrl/review";
  }
}
