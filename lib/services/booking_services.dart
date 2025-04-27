import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
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

  // Fix the createBooking method

  static Future<Booking> createBooking(Booking booking) async {
    try {
      // Get a fresh token directly to ensure it's valid
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }
      
      // Debug logging
      print("Creating booking with token: ${token.substring(0, min(10, token.length))}...");
      print("Request URL: ${ApiConfig.baseUrl}/api/booking/create");
      print("Request body: ${jsonEncode(booking.toJson())}");
      
      // Make sure URL is correct - remove /api if it's already in the baseUrl
      final String url = ApiConfig.baseUrl.endsWith('/api') 
          ? '${ApiConfig.baseUrl}/booking/create'
          : '${ApiConfig.baseUrl}/api/booking/create';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: jsonEncode(booking.toJson()),
      );

      print("Booking response status: ${response.statusCode}");
      print("Booking response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Check for different response formats
        if (responseData['success'] == true) {
          // Extract data - could be direct or nested
          final bookingData = responseData['data'];
          
          if (bookingData == null) {
            throw Exception('Invalid response format: missing data');
          }
          
          // Create booking from response data
          Booking result;
          
          // Handle both cases: bookingData as map or just an ID
          if (bookingData is int || bookingData is String) {
            // If only ID returned, create a minimal booking object
            result = Booking(
              id: int.parse(bookingData.toString()),
              lapanganId: booking.lapanganId,
              tanggal: booking.tanggal,
              jadwalList: booking.jadwalList,
            );
          } else {
            // Full booking object returned
            result = Booking.fromJson(bookingData);
          }
          
          // If waktu field is not set from API, create it from jadwalList
          if (result.waktu == null && result.jadwalList != null && result.jadwalList!.isNotEmpty) {
            // Sort jadwalList by time
            List<JadwalItem> sortedJadwal = List.from(result.jadwalList!);
            sortedJadwal.sort((a, b) => a.jam!.compareTo(b.jam!));
            
            // Create formatted time string (e.g., "09:00, 10:00, 11:00")
            List<String> timeSlots = sortedJadwal.map((item) => 
              "${item.jam.toString().padLeft(2, '0')}:00"
            ).toList();
            
            // Set the waktu field
            result.waktu = timeSlots.join(", ");
          }
          
          return result;
        } else {
          throw Exception(responseData['message'] ?? 'Booking creation failed');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to create booking: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print("Error creating booking: $e");
      throw e;
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
