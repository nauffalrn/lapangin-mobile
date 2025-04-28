import 'dart:async';
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
      // Use ensureFreshToken instead of directly getting from SharedPreferences
      final token = await AuthService.ensureFreshToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      // Debug logging
      print(
        "Creating booking with token: ${token.substring(0, min(10, token.length))}...",
      );
      print("Request URL: ${ApiConfig.baseUrl}/api/booking/create");
      print("Request body: ${jsonEncode(booking.toJson())}");

      // Always use the full path with /api prefix to be consistent
      final String url = '${ApiConfig.baseUrl}/api/booking/create';

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: jsonEncode(booking.toJson()),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout:
                () =>
                    throw TimeoutException(
                      'Connection timed out. Please try again.',
                    ),
          );

      print("Booking response status: ${response.statusCode}");
      print("Booking response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Check for different response formats
        if (responseData is Map && responseData.containsKey('success')) {
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
            if (result.waktu == null && result.jadwalList.isNotEmpty) {
              // Sort jadwalList by time
              List<JadwalItem> sortedJadwal = List.from(result.jadwalList);
              sortedJadwal.sort((a, b) => a.jam.compareTo(b.jam));

              // Create formatted time string (e.g., "09:00, 10:00, 11:00")
              List<String> timeSlots =
                  sortedJadwal
                      .map(
                        (item) => "${item.jam.toString().padLeft(2, '0')}:00",
                      )
                      .toList();

              // Set the waktu field
              result.waktu = timeSlots.join(", ");
            }

            return result;
          } else {
            throw Exception(
              responseData['message'] ?? 'Booking creation failed',
            );
          }
        } else {
          // Direct response (no success field)
          try {
            final result = Booking.fromJson(responseData);

            // If waktu field is not set from API, create it from jadwalList
            if (result.waktu == null && result.jadwalList.isNotEmpty) {
              // Sort jadwalList by time
              List<JadwalItem> sortedJadwal = List.from(result.jadwalList);
              sortedJadwal.sort((a, b) => a.jam.compareTo(b.jam));

              // Create formatted time string (e.g., "09:00, 10:00, 11:00")
              List<String> timeSlots =
                  sortedJadwal
                      .map(
                        (item) => "${item.jam.toString().padLeft(2, '0')}:00",
                      )
                      .toList();

              // Set the waktu field
              result.waktu = timeSlots.join(", ");
            }

            return result;
          } catch (e) {
            print("Error parsing booking: $e");
            throw Exception('Failed to parse booking data: $e');
          }
        }
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Failed to create booking: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print("Error creating booking: $e");
      throw e;
    }
  }

  // Modifikasi fungsi getBookingHistory
  static Future<List<Booking>> getBookingHistory() async {
    try {
      // Check if user is logged in first
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        print("No token available for booking history");
        throw Exception('Anda harus login terlebih dahulu');
      }

      // Use AuthHeadersWithRefresh instead of regular headers to ensure token is fresh
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/booking/history'),
        headers: await ApiConfig.getAuthHeadersWithRefresh(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Debug the response
        print(
          "Booking history response: ${response.body.substring(0, min(100, response.body.length))}...",
        );

        if (data['success'] == true && data['data'] != null) {
          List<dynamic> bookings = data['data'];
          return bookings.map((item) => Booking.fromJson(item)).toList();
        } else {
          print("API returned success=false or no data: ${data['message']}");
          return [];
        }
      } else {
        print("Error fetching booking history. Status: ${response.statusCode}");
        print("Error body: ${response.body}");
        throw Exception('Failed to load booking history');
      }
    } catch (e) {
      print("Exception in getBookingHistory: $e");
      throw e;
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
