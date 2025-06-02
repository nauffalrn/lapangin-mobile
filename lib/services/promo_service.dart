import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/promo_model.dart';
import 'auth_service.dart';

class PromoService {
  // PERBAIKAN: Mengambil daftar promo aktif dengan better error handling
  static Future<List<Promo>> getActivePromos() async {
    try {
      print("=== FETCHING ACTIVE PROMOS ===");

      final url = '${ApiConfig.baseUrl}/promo';
      print("Request URL: $url");

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      print("Promo API response status: ${response.statusCode}");
      print("Promo API response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseBody = response.body;

        dynamic jsonData;
        try {
          jsonData = jsonDecode(responseBody);
        } catch (e) {
          print("Error parsing JSON: $e");
          throw Exception('Invalid JSON response from server');
        }

        // Handle different response structures from backend
        List<dynamic> promoData;
        if (jsonData is List) {
          // Direct array response
          promoData = jsonData;
          print("Response is direct array");
        } else if (jsonData is Map && jsonData['data'] != null) {
          // Wrapped response with 'data' field
          promoData = jsonData['data'] as List;
          print("Response has 'data' wrapper");
        } else if (jsonData is Map &&
            jsonData['success'] == true &&
            jsonData['data'] != null) {
          // Success wrapper with data
          promoData = jsonData['data'] as List;
          print("Response has 'success' and 'data' wrapper");
        } else {
          print("Unexpected response structure: $jsonData");
          return [];
        }

        print("Parsing ${promoData.length} promo items");

        final promos = <Promo>[];
        for (int i = 0; i < promoData.length; i++) {
          try {
            final promoJson = promoData[i];
            print("Parsing promo $i: $promoJson");

            final promo = Promo.fromJson(promoJson);
            promos.add(promo);

            print(
              "Successfully parsed promo: ${promo.kodePromo} - ${promo.diskonPersen}% - Valid: ${promo.isValid}",
            );
          } catch (e) {
            print("Error parsing promo item $i: $e");
            print("Promo data: ${promoData[i]}");
            // Continue with other promos instead of failing completely
          }
        }

        print(
          "Successfully parsed ${promos.length} promos out of ${promoData.length}",
        );
        return promos;
      } else {
        print("Failed to fetch promos: ${response.statusCode}");
        print("Error response: ${response.body}");
        return []; // Return empty list instead of throwing
      }
    } catch (e) {
      print("Error getting active promos: $e");
      return []; // Return empty list instead of throwing
    }
  }

  // PERBAIKAN: Mengklaim promo dengan better error handling
  static Future<bool> claimPromo(String kodePromo) async {
    try {
      print("=== CLAIMING PROMO: $kodePromo ===");

      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Tidak ada token. Silakan login terlebih dahulu.');
      }

      print(
        "Using token: ${token.substring(0, token.length > 10 ? 10 : token.length)}...",
      );

      final url = '${ApiConfig.baseUrl}/promo/claim';
      print("Claim URL: $url");

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: {'kodePromo': kodePromo},
          )
          .timeout(Duration(seconds: 15));

      print("Claim promo response status: ${response.statusCode}");
      print("Claim promo response body: ${response.body}");

      if (response.statusCode == 200) {
        // Parse response to check for success
        try {
          final responseData = jsonDecode(response.body);
          if (responseData is Map && responseData.containsKey('success')) {
            final isSuccess = responseData['success'] == true;
            print("Claim result: $isSuccess");
            return isSuccess;
          }
        } catch (e) {
          print("Response is not JSON, assuming success based on status code");
        }
        return true;
      } else if (response.statusCode == 401) {
        await AuthService.logout();
        throw Exception('Sesi habis. Silakan login kembali.');
      } else {
        final errorMessage = response.body;
        print("Failed to claim promo: $errorMessage");

        // Try to parse error message from JSON
        try {
          final errorData = jsonDecode(errorMessage);
          if (errorData is Map && errorData['message'] != null) {
            throw Exception(errorData['message']);
          }
        } catch (e) {
          // If not JSON, use raw response
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      print("Error claiming promo: $e");
      throw e;
    }
  }

  // PERBAIKAN: Mengecek promo yang sudah diklaim dengan endpoint yang benar
  static Future<List<Promo>> getUserClaimedPromos() async {
    try {
      print("=== FETCHING USER CLAIMED PROMOS ===");

      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        print("No token found, returning empty list");
        return [];
      }

      print(
        "Using token: ${token.substring(0, token.length > 10 ? 10 : token.length)}...",
      );

      // PERBAIKAN: Gunakan endpoint yang benar dari backend
      final url = '${ApiConfig.baseUrl}/promo/claimed';
      print("User claimed promos URL: $url");

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 10));

      print("User promos response status: ${response.statusCode}");
      print("User promos response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseBody = response.body;

        dynamic jsonData;
        try {
          jsonData = jsonDecode(responseBody);
        } catch (e) {
          print("Error parsing user promos JSON: $e");
          return [];
        }

        // Handle different response structures
        List<dynamic> promoData;
        if (jsonData is List) {
          promoData = jsonData;
        } else if (jsonData is Map && jsonData['data'] != null) {
          promoData = jsonData['data'] as List;
        } else {
          print("Unexpected user promos response structure: $jsonData");
          return [];
        }

        final promos = <Promo>[];
        for (int i = 0; i < promoData.length; i++) {
          try {
            final promo = Promo.fromJson(promoData[i]);
            promos.add(promo);
            print("Parsed claimed promo: ${promo.kodePromo} (ID: ${promo.id})");
          } catch (e) {
            print("Error parsing claimed promo item $i: $e");
          }
        }

        print("Successfully parsed ${promos.length} claimed promos");
        return promos;
      } else if (response.statusCode == 401) {
        print("Unauthorized access to user promos");
        await AuthService.logout();
        return [];
      } else {
        print("Failed to fetch user promos: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error getting user promos: $e");
      return [];
    }
  }

  // Method yang sudah ada untuk apply promo to booking
  static Future<Map<String, dynamic>> applyPromoToBooking(
    int bookingId,
    String kodePromo,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Tidak ada token. Silakan login terlebih dahulu.');
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/booking/apply-promo'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {'bookingId': bookingId.toString(), 'kodePromo': kodePromo},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Gagal menerapkan promo: ${response.body}');
      }
    } catch (e) {
      print("Error applying promo: $e");
      throw e;
    }
  }
}
