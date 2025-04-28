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

  // Perbaikan fungsi getBookingHistory
  static Future<List<Booking>> getBookingHistory() async {
    try {
      print("Mengambil riwayat booking...");

      // Pastikan token valid
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Silakan login terlebih dahulu');
      }

      // Gunakan path yang benar
      final url = '${ApiConfig.baseUrl}/booking/history';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print("Status response history: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          List<dynamic> bookingsData = data['data'];
          print("Berhasil mengambil ${bookingsData.length} booking");

          // Detail log untuk setiap booking
          for (int i = 0; i < bookingsData.length; i++) {
            print("===== BOOKING ${i + 1} =====");
            print("ID: ${bookingsData[i]['id']}");

            // Check lapangan object structure
            if (bookingsData[i]['lapangan'] != null) {
              print(
                "Lapangan type: ${bookingsData[i]['lapangan'].runtimeType}",
              );

              if (bookingsData[i]['lapangan'] is Map) {
                Map<String, dynamic> lapanganData = bookingsData[i]['lapangan'];
                print("  Lapangan data keys: ${lapanganData.keys.toList()}");
                print(
                  "  Lapangan nama: ${lapanganData['nama'] ?? lapanganData['namaLapangan'] ?? 'null'}",
                );
                print("  Lapangan alamat: ${lapanganData['alamat'] ?? 'null'}");
              }
            } else {
              print("Lapangan field is null");
            }

            // Check if there's a direct lokasi field
            print(
              "Direct lokasi field: ${bookingsData[i]['lokasi'] ?? 'null'}",
            );
            print(
              "Direct alamat field: ${bookingsData[i]['alamat'] ?? 'null'}",
            );
          }

          // Lanjutkan dengan kode asli
          List<Booking> bookings = [];
          for (var item in bookingsData) {
            try {
              // Log alamat dari data lapangan
              if (item['lapangan'] != null && item['lapangan'] is Map) {
                var lapanganMap = item['lapangan'] as Map<String, dynamic>;
                print("Alamat lapangan dari API: ${lapanganMap['alamat']}");
              }

              // Pastikan mempertahankan seluruh struktur data lapangan
              var processedItem = _preprocessBookingData(item);
              bookings.add(Booking.fromJson(processedItem));
            } catch (e) {
              print("Error processing booking item: $e");
            }
          }

          return bookings;
        } else {
          print("API mengembalikan success=false atau data kosong");
          return [];
        }
      } else if (response.statusCode == 401) {
        print("Token tidak valid: ${response.body}");
        throw Exception('Sesi Anda telah berakhir. Silakan login kembali.');
      } else {
        print("Error status: ${response.statusCode}, body: ${response.body}");
        return [];
      }
    } catch (e) {
      print("Exception dalam getBookingHistory: $e");
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

  // Tambahkan metode ini ke class BookingService:

  static Future<bool> submitReview(
    int bookingId,
    int rating,
    String comment,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Anda harus login terlebih dahulu');
      }

      print("Submitting review for booking $bookingId with rating $rating");
      print("Comment: $comment");

      // Sesuaikan dengan endpoint yang benar dari backend
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/booking/review'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'bookingId': bookingId,
          'rating': rating,
          'komentar': comment,
        }),
      );

      print("Review submission response: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      } else {
        throw Exception(
          'Failed to submit review: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print("Error submitting review: $e");
      throw e;
    }
  }

  // Tambahkan fungsi helper untuk mentransformasi data respons API

  // Tambahkan fungsi ini di class BookingService
  static Map<String, dynamic> _preprocessBookingData(
    Map<String, dynamic> rawData,
  ) {
    Map<String, dynamic> processed = Map.from(rawData);

    // Pastikan objek lapangan tetap dipertahankan jika ada
    if (processed['lapangan'] != null && processed['lapangan'] is Map) {
      // Objek lapangan sudah ada, jangan diubah
    }
    // Jika lapangan hanya berupa ID, kita perlu cek apakah bisa mendapatkan data lapangan
    else if (processed['lapanganId'] != null ||
        (processed['lapangan'] != null && processed['lapangan'] is! Map)) {
      // Untuk backend bisa diimplementasikan nanti
      // Di sini hanya set struktur dasar lapangan
      int lapanganId = processed['lapanganId'] ?? processed['lapangan'];
      processed['lapangan'] = {
        'id': lapanganId,
        'namaLapangan': processed['namaLapangan'],
        'alamat': processed['alamat'] ?? "Alamat tidak tersedia",
      };
    }

    // Format tanggal jika berupa ISO DateTime
    if (processed['bookingDate'] != null) {
      try {
        String rawDate = processed['bookingDate'].toString();
        if (rawDate.contains(' ')) {
          String dateOnly = rawDate.split(' ')[0];
          var dateParts = dateOnly.split(' ');
          if (dateParts.length == 3) {
            final months = [
              'Januari',
              'Februari',
              'Maret',
              'April',
              'Mei',
              'Juni',
              'Juli',
              'Agustus',
              'September',
              'Oktober',
              'November',
              'Desember',
            ];

            int year = int.parse(dateParts[0]);
            int month = int.parse(dateParts[1]);
            int day = int.parse(dateParts[2]);

            processed['tanggal'] = "$day-${months[month - 1]}-$year";
          } else {
            processed['tanggal'] = dateOnly;
          }
        }
      } catch (e) {
        print("Error processing date: $e");
      }
    }

    return processed;
  }
}
