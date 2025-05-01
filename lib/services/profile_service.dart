import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:mobile/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ProfileService {
  // Fetch user profile data from the server
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      print("Fetching user profile data...");
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/profile/user'),
        headers: await ApiConfig.getAuthHeadersWithRefresh(), // Changed to use refresh method
      );
      
      print("Profile response status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Check if the response is a direct Customer object or wrapped in a Response object
        if (responseData is Map && responseData.containsKey('success')) {
          // It's wrapped in a Response object
          if (responseData['success'] == true && responseData['data'] != null) {
            final userData = responseData['data'];
            // Save the data to SharedPreferences for persistence
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('name', userData['name'] ?? '');
            await prefs.setString('username', userData['username'] ?? '');
            await prefs.setString('email', userData['email'] ?? '');
            await prefs.setString('phone_number', userData['phoneNumber'] ?? '');
            await prefs.setString('profile_image', userData['profileImage'] ?? '');
            
            return userData;
          } else {
            throw Exception(responseData['message'] ?? 'Failed to load profile data');
          }
        } else {
          // It's a direct Customer object
          // Save the data to SharedPreferences for persistence
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('name', responseData['name'] ?? '');
          await prefs.setString('username', responseData['username'] ?? '');
          await prefs.setString('email', responseData['email'] ?? '');
          await prefs.setString('phone_number', responseData['phoneNumber'] ?? '');
          await prefs.setString('profile_image', responseData['profileImage'] ?? '');
          
          return responseData;
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized, please login again');
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching user profile: $e");
      throw e;
    }
  }
  
  // Add this method to check token health directly
  static Future<bool> checkToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        print("No token found");
        return false;
      }
      
      print("Token for check: ${token.substring(0, min(10, token.length))}...");
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/profile/check-token'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      
      print("Token check response: ${response.statusCode}");
      print("Token check body: ${response.body}");
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true && data['data']['valid'] == true;
      }
      return false;
    } catch (e) {
      print("Error checking token: $e");
      return false;
    }
  }

  // Simplified version with better error handling and debug info
  static Future<void> updateUsername(String newUsername) async {
    try {
      print("Updating username to: $newUsername");
      
      // Get auth token directly without validation
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated. Please login first.');
      }
      
      print("Using token: ${token.substring(0, min(10, token.length))}...");
      
      // Debug request data
      final url = '${ApiConfig.baseUrl}/profile/update-username';
      print("URL: $url");
      print("Request body: ${jsonEncode({'username': newUsername})}");
      
      // Don't validate token, just send the request
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'username': newUsername}),
      ).timeout(Duration(seconds: 30));
      
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");
      
      if (response.statusCode == 200) {
        // Success - update SharedPreferences
        await prefs.setString('username', newUsername);
        print("Username updated successfully!");
      } else {
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print("Error updating username: $e");
      throw e;
    }
  }
  
  // Similar simplification for uploadProfileImage
  static Future<String> uploadProfileImage(String filePath) async {
    try {
      print("Uploading profile image: $filePath");
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated. Please login first.');
      }
      
      // Create multipart request
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('${ApiConfig.baseUrl}/profile/update-image')
      );
      
      // Add auth header - only Bearer token
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add file
      request.files.add(
        await http.MultipartFile.fromPath('image', filePath)
      );
      
      print("Sending request to: ${request.url}");
      print("With headers: ${request.headers}");
      
      // Send request with longer timeout
      var streamedResponse = await request.send().timeout(Duration(seconds: 60));
      var response = await http.Response.fromStream(streamedResponse);
      
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body.substring(0, min(100, response.body.length))}...");
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final imageUrl = responseData['data']['profileImage'] ?? '';
          await prefs.setString('profile_image', imageUrl);
          
          // Check if the response includes a new token and save it
          if (responseData['data']['token'] != null) {
            await prefs.setString('auth_token', responseData['data']['token']);
            AuthService.updateCachedToken(responseData['data']['token']);
          }
          
          return imageUrl;
        } else {
          throw Exception(responseData['message'] ?? 'Invalid response format');
        }
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      print("Error uploading profile image: $e");
      throw e;
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? phoneNumber,
  }) async {
    try {
      print("Updating profile data...");
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        throw Exception('Not authenticated. Please login first.');
      }
      
      final url = '${ApiConfig.baseUrl}/profile/update-profile';
      
      // Create form data
      var request = http.MultipartRequest('POST', Uri.parse(url));
      
      // Add auth header
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add fields if provided
      if (name != null && name.isNotEmpty) {
        request.fields['name'] = name;
      }
      
      if (email != null && email.isNotEmpty) {
        request.fields['email'] = email;
      }
      
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        request.fields['phoneNumber'] = phoneNumber;
      }
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      print("Update profile response status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final userData = responseData['data'];
          
          // Update SharedPreferences with new data
          if (name != null && name.isNotEmpty) {
            await prefs.setString('name', name);
          }
          
          if (email != null && email.isNotEmpty) {
            await prefs.setString('email', email);
          }
          
          if (phoneNumber != null && phoneNumber.isNotEmpty) {
            await prefs.setString('phone_number', phoneNumber);
          }
          
          return userData;
        } else {
          throw Exception(responseData['message'] ?? 'Invalid response format');
        }
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      print("Error updating profile: $e");
      throw e;
    }
  }
}