import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import '../models/booking_model.dart';
import 'auth_service.dart';

class BookingService {
  static Future<Map<String, String>> _getAuthHeader() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Booking> createBooking(Booking booking) async {
    try {
      // Gunakan metode baru dengan refresh token otomatis
      final headers = await AuthService.getAuthHeadersWithRefresh();

      print("Membuat booking: ${ApiConfig.baseUrl}/booking/create");
      print("Request: ${jsonEncode(booking.toJson())}");

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/booking/create'),
        headers: headers,
        body: jsonEncode(booking.toJson()),
      );

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Booking.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
          'Gagal membuat booking: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print("Error creating booking: $e");
      throw Exception('Gagal membuat booking: $e');
    }
  }

  // Modifikasi fungsi getBookingHistory
  static Future<List<Booking>> getBookingHistory() async {
    try {
      // Get token directly, don't use the refresh method
      final token = await AuthService.getToken();

      if (token == null || token.isEmpty) {
        print("No token available for booking history");
        return [];
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      print("Mengambil riwayat booking: ${ApiConfig.baseUrl}/booking/history");
      print("Headers: $headers");
      print("Token being used: $token");

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/booking/history'),
        headers: headers,
      );

      print("Response status history: ${response.statusCode}");
      print("Response body history: ${response.body}");

      if (response.statusCode == 200) {
        // Handle response format
        var responseData = jsonDecode(response.body);
        List<dynamic> data;

        if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'];
        } else if (responseData is List) {
          data = responseData;
        } else {
          print("Unexpected data format: $responseData");
          return [];
        }

        return data.map((json) => Booking.fromJson(json)).toList();
      } else {
        print("Error status code: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error mengambil riwayat booking: $e");
      // Return empty instead of throwing
      return [];
    }
  }

  static Future<List<dynamic>> getJadwal(int lapanganId, String tanggal) async {
    try {
      print(
        "Mengambil jadwal: ${ApiConfig.baseUrl}/booking/jadwal?lapanganId=$lapanganId&tanggal=$tanggal",
      );

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/booking/jadwal?lapanganId=$lapanganId&tanggal=$tanggal',
        ),
      );

      print("Status response jadwal: ${response.statusCode}");
      print("Response body jadwal: ${response.body}");

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);

        // Handle berbagai kemungkinan format response
        if (data is Map && data.containsKey('data')) {
          return data['data'] as List<dynamic>;
        } else if (data is List) {
          return data;
        } else {
          return [];
        }
      } else {
        throw Exception('Gagal mengambil jadwal: ${response.statusCode}');
      }
    } catch (e) {
      print("Error getting jadwal: $e");
      throw Exception('Gagal mengambil jadwal: $e');
    }
  }

  static Future<Map<String, dynamic>> uploadPayment(
    int bookingId,
    File paymentProof,
  ) async {
    final token = await AuthService.getToken();

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/booking/payment/upload'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    request.fields['bookingId'] = bookingId.toString();

    // Tambahkan file bukti pembayaran
    var stream = http.ByteStream(paymentProof.openRead());
    var length = await paymentProof.length();

    var multipartFile = http.MultipartFile(
      'file',
      stream,
      length,
      filename: paymentProof.path.split('/').last,
      contentType: MediaType('image', 'jpeg'),
    );

    request.files.add(multipartFile);

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Gagal mengunggah bukti pembayaran: ${response.body}');
    }
  }
}
