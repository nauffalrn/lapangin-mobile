import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/review_model.dart';

class ReviewService {
  static Future<List<Review>> getReviewsByLapanganId(int lapanganId) async {
    try {
      print("Fetching reviews for lapangan ID: $lapanganId");

      // URL disesuaikan dengan endpoint backend
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/review/$lapanganId'),
      );

      print("Review response status: ${response.statusCode}");
      print("Review response body: ${response.body}");

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        List<dynamic> reviewsData;

        if (responseData is Map && responseData.containsKey('data')) {
          reviewsData = responseData['data'];
        } else if (responseData is List) {
          reviewsData = responseData;
        } else {
          print("Unexpected response format: $responseData");
          return [];
        }

        return reviewsData.map((json) => Review.fromJson(json)).toList();
      } else {
        print("Error fetching reviews: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Exception fetching reviews: $e");
      return [];
    }
  }
}
