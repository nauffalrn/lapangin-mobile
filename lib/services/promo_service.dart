import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/promo_model.dart';
import 'auth_service.dart';

class PromoService {
  // Mengambil daftar promo aktif
  static Future<List<Promo>> getActivePromos() async {
    try {
      // Tidak perlu token untuk promo publik
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/promo'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Promo.fromJson(json)).toList();
      } else {
        throw Exception('Gagal mengambil promo: ${response.statusCode}');
      }
    } catch (e) {
      print("Error getting active promos: $e");
      throw e;
    }
  }

  // Mengklaim promo
  static Future<bool> claimPromo(String kodePromo) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Tidak ada token. Silakan login terlebih dahulu.');
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/promo/claim'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $token',
        },
        body: {
          'kodePromo': kodePromo,
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final errorMessage = response.body;
        throw Exception(errorMessage);
      }
    } catch (e) {
      print("Error claiming promo: $e");
      throw e;
    }
  }

  // Mengecek apakah promo sudah diklaim oleh user
  static Future<List<Promo>> getUserClaimedPromos() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        throw Exception('Tidak ada token. Silakan login terlebih dahulu.');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/booking/promos/customer'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Promo.fromJson(json)).toList();
      } else {
        throw Exception('Gagal mengambil promo user: ${response.statusCode}');
      }
    } catch (e) {
      print("Error getting user promos: $e");
      // Return empty list on error instead of throwing
      return [];
    }
  }

  // Menggunakan promo untuk booking
  static Future<Map<String, dynamic>> applyPromoToBooking(int bookingId, String kodePromo) async {
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
        body: {
          'bookingId': bookingId.toString(),
          'kodePromo': kodePromo,
        },
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