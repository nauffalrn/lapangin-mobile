import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/review_model.dart';
import '../config/api_config.dart';

class ReviewService {
  // Fetch reviews for a specific venue
  static Future<List<Review>> getReviewsByLapanganId(int lapanganId) async {
    try {
      // Debug
      print("Fetching reviews for lapangan ID: $lapanganId");
      
      // Make sure this path matches your ReviewApiController endpoint
      final url = '${ApiConfig.baseUrl}/review/$lapanganId';
      print("URL: $url");
      
      // Add timeout to prevent infinite loading
      final response = await http.get(
        Uri.parse(url),
        headers: await ApiConfig.getAuthHeaders(), // Use auth headers if needed
      ).timeout(Duration(seconds: 10));
      
      // Debug
      print("Response status: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          print("Response body is empty");
          return [];
        }
        
        print("Response body: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...");
        
        try {
          List<dynamic> jsonList = jsonDecode(response.body);
          return jsonList.map((json) => Review.fromJson(json)).toList();
        } catch (e) {
          print("JSON parsing error: $e");
          return [];
        }
      } else {
        print("Server error: ${response.statusCode}");
        print("Error body: ${response.body}");
        return [];
      }
    } catch (e) {
      print("Error fetching reviews: $e");
      // Return empty list instead of throwing to prevent UI blocking
      return [];
    }
  }
  
  // Submit a review (optional - if you need this functionality)
  static Future<void> submitReview({
    required int lapanganId,
    required double rating,
    required String comment,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/review'),
        headers: await ApiConfig.getAuthHeaders(),
        body: jsonEncode({
          'lapanganId': lapanganId,
          'rating': rating,
          'comment': comment,
        }),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to submit review: ${response.statusCode}');
      }
    } catch (e) {
      print("Error submitting review: $e");
      throw e;
    }
  }
}
