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
      print("URL: ${ApiConfig.baseUrl}/review/$lapanganId");
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/review/$lapanganId'),
        headers: await ApiConfig.getAuthHeaders(), // Use auth headers if needed
      );
      
      // Debug
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...");
      
      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Review.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load reviews: ${response.statusCode}');
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
