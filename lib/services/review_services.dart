import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/review_model.dart';
import '../config/api_config.dart';

class ReviewService {
  // Fetch reviews for a specific venue
  static Future<List<Review>> getReviewsByLapanganId(int lapanganId, {int page = 1, int size = 5}) async {
    try {
      // Create a paginated URL
      final url = Uri.parse('${ApiConfig.baseUrl}/booking/reviews/$lapanganId?page=$page&size=$size');
      print("Fetching reviews from: $url");
      
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final dynamic rawData = jsonDecode(response.body);
        
        // Handle different response formats
        List<dynamic> reviewsJson;
        if (rawData is Map && rawData.containsKey('data')) {
          reviewsJson = rawData['data'];
        } else if (rawData is List) {
          reviewsJson = rawData;
        } else {
          throw Exception('Unexpected response format from server');
        }
        
        // Parse reviews
        return reviewsJson.map((json) => Review.fromJson(json)).toList();
      } else {
        print("Error response: ${response.statusCode} - ${response.body}");
        return []; // Return empty list instead of throwing to prevent UI issues
      }
    } catch (e) {
      print("Error fetching reviews: $e");
      return []; // Return empty list for network errors
    }
  }

  // Submit a review (optional - if you need this functionality)
  static Future<void> submitReview({
    required int lapanganId,
    required int bookingId, // Add this parameter
    required double rating,
    required String comment,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.getAddReviewUrl()), // Use your config method
        headers: await ApiConfig.getAuthHeaders(),
        body: jsonEncode({
          'lapangan': {'id': lapanganId},
          'booking': {'id': bookingId},
          'rating': rating,
          'komentar': comment, // Changed from 'comment' to 'komentar'
          'tanggalReview': DateTime.now().toIso8601String(),
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
