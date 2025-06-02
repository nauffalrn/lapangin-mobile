import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobile/services/auth_service.dart';
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

  // ALTERNATIF: Submit review dengan parameter yang konsisten
  static Future<void> submitReview({
    required int lapanganId,
    required int bookingId,
    required double rating,
    required String comment,
  }) async {
    try {
      print("Submitting review for booking $bookingId with rating $rating");
      print("Comment: $comment");

      // Kirim sebagai form data dengan semua parameter yang dibutuhkan
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/booking/review'),
        headers: {
          'Authorization': 'Bearer ${await AuthService.getToken()}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'bookingId': bookingId.toString(),
          'lapanganId': lapanganId.toString(), // Add lapanganId parameter
          'rating': rating.toInt().toString(),
          'komentar': comment,
        },
      );

      print("Review submission response: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] != true) {
          throw Exception(data['message'] ?? 'Failed to submit review');
        }
      } else {
        throw Exception('Failed to submit review: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print("Error submitting review: $e");
      throw e;
    }
  }
}
