import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ProfileService {
  // Fetch user profile data from the server
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/profile/user'),
        headers: await ApiConfig.getAuthHeaders(),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching user profile: $e");
      throw e;
    }
  }
  
  // Update username
  static Future<void> updateUsername(String newUsername) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/profile/update-username'),
        headers: await ApiConfig.getAuthHeaders(),
        body: jsonEncode({'username': newUsername}),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to update username: ${response.statusCode}');
      }
    } catch (e) {
      print("Error updating username: $e");
      throw e;
    }
  }
  
  // Upload profile image
  static Future<String> uploadProfileImage(String filePath) async {
    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('${ApiConfig.baseUrl}/profile/update-image')
      );
      
      // Add headers
      final headers = await ApiConfig.getAuthHeaders();
      request.headers.addAll(headers);
      
      // Add file
      request.files.add(
        await http.MultipartFile.fromPath('image', filePath)
      );
      
      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final imageUrl = data['data']['profileImage'] ?? '';
        return imageUrl;
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      print("Error uploading profile image: $e");
      throw e;
    }
  }
}