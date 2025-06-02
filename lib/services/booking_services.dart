import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as Math;
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

  // Add this helper method to ensure date formats are consistent
  static String formatDateForBackend(String originalDate) {
    // Check if already in "YYYY-MM-DD" format
    if (originalDate.contains("-") && originalDate.split("-").length == 3) {
      return originalDate;
    }

    // Format: "1 Mei 2025" -> "2025-05-01"
    try {
      final parts = originalDate.split(" ");
      if (parts.length == 3) {
        final day = parts[0];
        final monthName = parts[1];
        final year = parts[2];

        // Convert month name to number
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
        final month = (months.indexOf(monthName) + 1).toString().padLeft(
          2,
          '0',
        );

        // Create "YYYY-MM-DD" format
        return "$year-$month-${day.padLeft(2, '0')}";
      }
    } catch (e) {
      print("Error formatting date: $e");
    }

    // Return original if conversion fails
    return originalDate;
  }

  // Update the createBooking method to ensure proper handling of created bookings

  static Future<Booking> createBooking(Booking booking) async {
    try {
      print("Creating booking for lapangan ID: ${booking.lapanganId}");

      // PERBAIKAN: Ganti ensureFreshToken() dengan getToken()
      final token = await AuthService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      // Format the date properly for the backend
      String formattedDate = formatDateForBackend(booking.tanggal ?? "");

      // Extract earliest and latest jam from jadwalList for time info
      int? earliestJam;
      int? latestJam;

      if (booking.jadwalList.isNotEmpty) {
        booking.jadwalList.forEach((item) {
          if (earliestJam == null || item.jam < earliestJam!) {
            earliestJam = item.jam;
          }
          if (latestJam == null || item.jam + 1 > latestJam!) {
            latestJam = item.jam + 1;
          }
        });

        // Set explicit jamMulai and jamSelesai
        booking.jamMulai = earliestJam;
        booking.jamSelesai = latestJam;

        // Create explicit waktu field
        booking.waktu =
            "${earliestJam.toString().padLeft(2, '0')}:00-${latestJam.toString().padLeft(2, '0')}:00";
      }

      // Fix the URL
      final String url = '${ApiConfig.baseUrl}/booking/create';

      // Create the booking request payload with explicit all fields to ensure consistency
      final Map<String, dynamic> requestBody = {
        'lapanganId': booking.lapanganId,
        'namaLapangan': booking.namaLapangan,
        'lokasi': booking.lokasi,
        'tanggal': formattedDate, // Use the formatted date
        'jamMulai': booking.jamMulai, // Add explicit time
        'jamSelesai': booking.jamSelesai, // Add explicit time
        'jadwalList':
            booking.jadwalList
                .map((item) => {'jam': item.jam, 'harga': item.harga})
                .toList(),
      };

      // Include promo code if available
      if (booking.kodePromo != null && booking.kodePromo!.isNotEmpty) {
        requestBody['kodePromo'] = booking.kodePromo;
      }

      print("Create booking request URL: $url");
      print("Request body: ${jsonEncode(requestBody)}");

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
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

        // Extract the created booking data properly
        Booking result;

        // Handle both success wrapper and direct response formats
        if (responseData is Map && responseData.containsKey('success')) {
          if (responseData['success'] != true) {
            throw Exception(
              responseData['message'] ?? 'Booking creation failed',
            );
          }

          final bookingData = responseData['data'];
          if (bookingData == null) {
            throw Exception('Invalid response format: missing data');
          }

          // Handle ID only response
          if (bookingData is int ||
              (bookingData is String && int.tryParse(bookingData) != null)) {
            // Create a booking object with ID but copy other fields from request
            int bookingId =
                bookingData is int ? bookingData : int.parse(bookingData);

            result = Booking(
              id: bookingId,
              lapanganId: booking.lapanganId,
              namaLapangan: booking.namaLapangan,
              lokasi: booking.lokasi,
              tanggal: booking.tanggal,
              jadwalList: booking.jadwalList,
              totalPrice: booking.totalPrice,
            );

            // Explicitly create the waktu field for consistency
            if (result.waktu == null && booking.jadwalList.isNotEmpty) {
              final sortedJadwal = List<JadwalItem>.from(booking.jadwalList)
                ..sort((a, b) => a.jam.compareTo(b.jam));

              // Find earliest and latest times
              final earliestJam = sortedJadwal.first.jam;
              final latestJam = sortedJadwal.last.jam + 1; // +1 for end time

              result.waktu =
                  "${earliestJam.toString().padLeft(2, '0')}:00-${latestJam.toString().padLeft(2, '0')}:00";
              result.jamMulai = earliestJam;
              result.jamSelesai = latestJam;
            }
          } else {
            // Full booking object response
            result = Booking.fromJson(bookingData);
          }
        } else {
          // Direct response format (unusual but handle it)
          result = Booking.fromJson(responseData);
        }

        // Ensure resulting booking has all needed fields
        if (result.waktu == null && booking.jadwalList.isNotEmpty) {
          // Sort jadwalList by time
          List<JadwalItem> sortedJadwal = List.from(booking.jadwalList);
          sortedJadwal.sort((a, b) => a.jam.compareTo(b.jam));

          // Calculate time range
          int firstHour = sortedJadwal.first.jam;
          int lastHour = sortedJadwal.last.jam + 1;
          result.waktu =
              "${firstHour.toString().padLeft(2, '0')}:00-${lastHour.toString().padLeft(2, '0')}:00";
          result.jamMulai = firstHour;
          result.jamSelesai = lastHour;
        }

        // Always save the created booking locally to ensure it appears in tracking
        await saveBookingLocally(result);

        print(
          "Created and saved booking ID ${result.id}, with waktu: ${result.waktu}",
        );
        return result;
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

  // Update getBookingHistory to handle more data formats

  static Future<List<Booking>> getBookingHistory() async {
    try {
      print("Fetching all bookings from backend...");
      
      final headers = await ApiConfig.getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/booking/all'), // Gunakan endpoint /all
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print("Booking history response status: ${response.statusCode}");
      print("Booking history response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          List<dynamic> bookingsJson = data['data'];
          
          // Parse setiap booking dengan preprocessing untuk memastikan format yang konsisten
          List<Booking> bookings = bookingsJson.map((json) {
            // Preprocess data untuk memastikan format yang konsisten
            Map<String, dynamic> processedJson = _preprocessBookingData(json);
            return Booking.fromJson(processedJson);
          }).toList();

          print("Successfully parsed ${bookings.length} bookings");
          
          // Debug: Print beberapa booking untuk verifikasi
          bookings.take(3).forEach((booking) {
            print("Booking ${booking.id}: ${booking.tanggal}, ${booking.waktu}, jamMulai: ${booking.jamMulai}, jamSelesai: ${booking.jamSelesai}");
          });

          return bookings;
        } else {
          print("API response success=false or data=null");
          return [];
        }
      } else {
        throw Exception('Failed to load booking history: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching booking history: $e");
      throw Exception('Failed to load booking history: $e');
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

  // Modify the uploadPayment method to save booking locally

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

    // Add payment proof file
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
      // Try to fetch and save the booking for local reference
      try {
        // First try to get it from history
        final allBookings = await getBookingHistory();
        final booking = allBookings.firstWhere(
          (b) => b.id == bookingId,
          orElse: () => throw Exception('Not found in history'),
        );
        await saveBookingLocally(booking); // Use the public method
      } catch (e) {
        print("Could not save booking locally after payment: $e");
      }

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
  static Future<void> cancelBooking(int bookingId) async {
    try {
      // PERBAIKAN: Ganti ensureFreshToken() dengan getToken()
      final token = await AuthService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('Authentication token not found. Please login again.');
      }

      final String url = '${ApiConfig.baseUrl}/booking/cancel/$bookingId';

      print("Cancel booking request URL: $url");
      print("Using HTTP DELETE method instead of POST");

      // Ubah metode HTTP dari POST menjadi DELETE
      final response = await http
          .delete(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout:
                () =>
                    throw TimeoutException(
                      'Request timeout. Please check your connection.',
                      const Duration(seconds: 15),
                    ),
          );

      print("Cancel booking response status: ${response.statusCode}");
      print("Cancel booking response body: ${response.body}");

      if (response.statusCode != 200) {
        final responseData = jsonDecode(response.body);
        final errorMessage =
            responseData['message'] ?? 'Failed to cancel booking';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print("Error canceling booking: $e");
      throw e;
    }
  }

  // Add this helper method to save booking data locally
  static Future<void> _saveBookingLocally(Booking booking) async {
    try {
      if (booking.id == null) return;

      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(booking.toJson());
      await prefs.setString('booking_${booking.id}', json);

      print("Saved booking ${booking.id} locally for fallback");
    } catch (e) {
      print("Error saving booking locally: $e");
    }
  }

  // Add this helper method to retrieve saved booking
  static Future<Booking> _getSavedBooking(int bookingId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('booking_${bookingId}');

    if (json == null) {
      throw Exception('No locally saved booking found');
    }

    print("Retrieved booking $bookingId from local storage");
    return Booking.fromJson(jsonDecode(json));
  }

  // Add these helper methods to the BookingService class (make them public by removing the underscore)

  static Future<void> saveBookingLocally(Booking booking) async {
    try {
      if (booking.id == null) {
        print("Warning: Attempted to save booking without an ID");
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // Create a clean version of the booking data for storage
      Map<String, dynamic> cleanData = {
        'id': booking.id,
        'lapanganId': booking.lapanganId,
        'namaLapangan': booking.namaLapangan,
        'lokasi': booking.lokasi,
        'tanggal': booking.tanggal,
        'waktu': booking.waktu,
        'totalPrice': booking.totalPrice,
        'jamMulai': booking.jamMulai,
        'jamSelesai': booking.jamSelesai,
      };

      // Add jadwalList if available
      if (booking.jadwalList.isNotEmpty) {
        cleanData['jadwalList'] =
            booking.jadwalList
                .map((item) => {'jam': item.jam, 'harga': item.harga})
                .toList();
      }

      // Add lapangan data if available
      if (booking.lapanganData != null) {
        cleanData['lapangan'] = booking.lapanganData;
      }

      final json = jsonEncode(cleanData);
      await prefs.setString('booking_${booking.id}', json);

      print("Successfully saved booking ${booking.id} locally");
    } catch (e) {
      print("Error saving booking locally: $e");
    }
  }

  static Future<Booking> getSavedBooking(int bookingId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('booking_${bookingId}');

    if (json == null) {
      throw Exception('No locally saved booking found');
    }

    print("Retrieved booking $bookingId from local storage");
    return Booking.fromJson(jsonDecode(json));
  }

  // Update the getBookingDetails method to fill in jamMulai and jamSelesai
  static Future<Booking> getBookingDetails(int bookingId) async {
    try {
      print("Fetching booking details for ID: $bookingId");

      final headers = await ApiConfig.getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/booking/$bookingId'),
        headers: headers,
      );

      print("Booking details response status: ${response.statusCode}");
      print("Booking details response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          var bookingData = data['data'];

          // Pastikan data lapangan termasuk koordinat
          if (bookingData['lapangan'] != null) {
            print("Lapangan data in booking: ${bookingData['lapangan']}");
          }

          final booking = Booking.fromJson(bookingData);

          // Debug koordinat
          print(
            "Booking parsed - Lat: ${booking.lapanganLatitude}, Lng: ${booking.lapanganLongitude}",
          );

          return booking;
        } else {
          throw Exception(data['message'] ?? 'Failed to get booking details');
        }
      } else {
        throw Exception('Failed to fetch booking: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching booking details: $e");
      throw e;
    }
  }

  // Update the fromJson method to parse jamMulai and jamSelesai
  static Booking parseJsonToBooking(Map<String, dynamic> json) {
    // Parse jamMulai and jamSelesai from the JSON
    int? jamMulai;
    int? jamSelesai;
    int? id;
    int? lapanganId;
    String? namaLapangan;
    String? lokasi;
    String? tanggal;
    String? waktu;
    double? totalPrice;
    Map<String, dynamic>? lapanganData;
    List<JadwalItem> jadwalItems = [];

    if (json['jamMulai'] != null) {
      jamMulai =
          json['jamMulai'] is int
              ? json['jamMulai']
              : int.tryParse(json['jamMulai'].toString());
    }

    if (json['jamSelesai'] != null) {
      jamSelesai =
          json['jamSelesai'] is int
              ? json['jamSelesai']
              : int.tryParse(json['jamSelesai'].toString());
    }

    // Get booking ID
    if (json['id'] != null) {
      id = json['id'] is int ? json['id'] : int.tryParse(json['id'].toString());
    }

    // Get lapanganId
    if (json['lapanganId'] != null) {
      lapanganId =
          json['lapanganId'] is int
              ? json['lapanganId']
              : int.tryParse(json['lapanganId'].toString());
    } else if (json['lapangan'] is Map && json['lapangan']['id'] != null) {
      lapanganId =
          json['lapangan']['id'] is int
              ? json['lapangan']['id']
              : int.tryParse(json['lapangan']['id'].toString());
    }

    // Process other fields...
    namaLapangan = json['namaLapangan']?.toString();
    lokasi = json['lokasi']?.toString();
    tanggal = json['tanggal']?.toString();
    waktu = json['waktu']?.toString();

    // Process totalPrice
    if (json['totalPrice'] != null) {
      if (json['totalPrice'] is double) {
        totalPrice = json['totalPrice'];
      } else if (json['totalPrice'] is int) {
        totalPrice = (json['totalPrice'] as int).toDouble();
      } else {
        totalPrice = double.tryParse(json['totalPrice'].toString());
      }
    }

    return Booking(
      id: id,
      lapanganId: lapanganId,
      namaLapangan: namaLapangan,
      lokasi: lokasi,
      tanggal: tanggal,
      waktu: waktu,
      jadwalList: jadwalItems,
      totalPrice: totalPrice,
      lapanganData: lapanganData,
      jamMulai: jamMulai,
      jamSelesai: jamSelesai,
    );
  }

  static Map<String, dynamic> _preprocessBookingData(
    Map<String, dynamic> rawData,
  ) {
    Map<String, dynamic> processed = Map<String, dynamic>.from(rawData);

    // Handle date format
    if (processed['bookingDate'] != null) {
      String dateStr = processed['bookingDate'].toString();

      // Extract time information from bookingDate if it exists
      if (dateStr.contains(":")) {
        try {
          // ISO format with T: "2025-05-01T15:00:00"
          if (dateStr.contains("T")) {
            final parts = dateStr.split("T");
            final datePart = parts[0]; // "2025-05-01"
            final timePart = parts[1]; // "15:00:00"

            // Extract hours for jamMulai/jamSelesai
            final timeComponents = timePart.split(":");
            if (timeComponents.isNotEmpty) {
              int jamMulai = int.parse(timeComponents[0]);
              processed['jamMulai'] = jamMulai;
              // Hanya set jamSelesai jika belum ada
              if (processed['jamSelesai'] == null) {
                processed['jamSelesai'] = jamMulai + 1; // Assuming 1-hour slots
              }
            }
          }
          // Standard format with space: "2025-05-01 15:00:00"
          else if (dateStr.contains(" ")) {
            final parts = dateStr.split(" ");
            final datePart = parts[0]; // "2025-05-01"
            final timePart = parts[1]; // "15:00:00"

            // Extract hours for jamMulai/jamSelesai
            final timeComponents = timePart.split(":");
            if (timeComponents.isNotEmpty) {
              int jamMulai = int.parse(timeComponents[0]);
              processed['jamMulai'] = jamMulai;
              // Hanya set jamSelesai jika belum ada
              if (processed['jamSelesai'] == null) {
                processed['jamSelesai'] = jamMulai + 1; // Assuming 1-hour slots
              }
            }

            // Also format for Indonesian display - Tanggal needs to be in the local format
            try {
              final dateComponents = datePart.split("-");
              if (dateComponents.length == 3) {
                final year = dateComponents[0];
                final month = int.parse(dateComponents[1]);
                final day = dateComponents[2];

                final months = [
                  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
                  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
                ];

                if (month >= 1 && month <= 12) {
                  processed['tanggal'] = "$day ${months[month - 1]} $year";
                }
              }
            } catch (e) {
              print("Error formatting date: $e");
            }
          }

          // Ensure waktu field is created if not present
          if (processed['waktu'] == null && 
              processed['jamMulai'] != null && 
              processed['jamSelesai'] != null) {
            int jamMulai = processed['jamMulai'];
            int jamSelesai = processed['jamSelesai'];
            processed['waktu'] = "${jamMulai.toString().padLeft(2, '0')}:00-${jamSelesai.toString().padLeft(2, '0')}:00";
          }
        } catch (e) {
          print("Error processing date format: $e");
        }
      }

      // If tanggal field is missing, use the date part of bookingDate
      if (processed['tanggal'] == null && dateStr.contains("-")) {
        try {
          // If we have ISO format with time, extract just the date
          String datePart = dateStr;
          if (dateStr.contains("T")) {
            datePart = dateStr.split("T")[0];
          } else if (dateStr.contains(" ")) {
            datePart = dateStr.split(" ")[0];
          }

          processed['tanggal'] = datePart;
        } catch (e) {
          print("Error extracting date part: $e");
        }
      }
    }

    // Handle lapangan data
    if (processed['lapangan'] != null && processed['lapangan'] is Map) {
      Map<String, dynamic> lapanganData = processed['lapangan'];
      
      // Extract lapangan fields to root level
      if (processed['namaLapangan'] == null && lapanganData['namaLapangan'] != null) {
        processed['namaLapangan'] = lapanganData['namaLapangan'];
      }
      
      if (processed['lokasi'] == null && lapanganData['alamatLapangan'] != null) {
        processed['lokasi'] = lapanganData['alamatLapangan'];
      }
      
      if (processed['lapanganId'] == null && lapanganData['id'] != null) {
        processed['lapanganId'] = lapanganData['id'];
      }
    }

    return processed;
  }

  // PERBAIKAN untuk method fromJson - hapus static dan perbaiki null safety
  static Booking fromJson(Map<String, dynamic> json) {
    // Debug log untuk melihat data mentah
    print("Parsing Booking from JSON with time data: jamMulai=${json['jamMulai']}, jamSelesai=${json['jamSelesai']}");

    // Parse jam mulai dengan pengecekan null safety
    int? jamMulai;
    if (json['jamMulai'] != null) {
      if (json['jamMulai'] is int) {
        jamMulai = json['jamMulai'];
      } else {
        jamMulai = int.tryParse(json['jamMulai'].toString());
      }
    }

    // Parse jam selesai dengan pengecekan null safety
    int? jamSelesai;
    if (json['jamSelesai'] != null) {
      if (json['jamSelesai'] is int) {
        jamSelesai = json['jamSelesai'];
      } else {
        jamSelesai = int.tryParse(json['jamSelesai'].toString());
      }
    }

    // Parse ID dengan null safety
    int? id;
    if (json['id'] != null) {
      if (json['id'] is int) {
        id = json['id'];
      } else {
        id = int.tryParse(json['id'].toString());
      }
    }

    // Parse lapanganId dengan null safety
    int? lapanganId;
    if (json['lapanganId'] != null) {
      if (json['lapanganId'] is int) {
        lapanganId = json['lapanganId'];
      } else {
        lapanganId = int.tryParse(json['lapanganId'].toString());
      }
    }

    // Parse totalPrice dengan null safety
    double? totalPrice;
    if (json['totalPrice'] != null) {
      if (json['totalPrice'] is double) {
        totalPrice = json['totalPrice'];
      } else if (json['totalPrice'] is int) {
        totalPrice = (json['totalPrice'] as int).toDouble();
      } else {
        totalPrice = double.tryParse(json['totalPrice'].toString());
      }
    }

    // Parse rating dengan null safety
    int? rating;
    if (json['rating'] != null) {
      if (json['rating'] is int) {
        rating = json['rating'];
      } else {
        rating = int.tryParse(json['rating'].toString());
      }
    }

    return Booking(
      id: id,
      lapanganId: lapanganId,
      namaLapangan: json['namaLapangan']?.toString(),
      lokasi: json['lokasi']?.toString(),
      tanggal: json['tanggal']?.toString(),
      waktu: json['waktu']?.toString(),
      rating: rating,
      review: json['review']?.toString(),
      reviewerName: json['reviewerName']?.toString(),
      reviewDate: json['reviewDate']?.toString(),
      jadwalList: json['jadwalList'] != null
          ? (json['jadwalList'] as List).map((e) => JadwalItem.fromJson(e)).toList()
          : [],
      status: json['status']?.toString(),
      totalPrice: totalPrice,
      lapanganData: json['lapangan'],
      jamMulai: jamMulai,
      jamSelesai: jamSelesai,
    );
  }

  // Tambahkan method _apiCall yang hilang
  static Future<Map<String, dynamic>> _apiCall(String method, String endpoint) async {
    try {
      final headers = await ApiConfig.getAuthHeaders();
      late http.Response response;
      
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: headers);
          break;
        case 'POST':
          response = await http.post(url, headers: headers);
          break;
        case 'PUT':
          response = await http.put(url, headers: headers);
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      print("API Call $method $endpoint - Status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('API call failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print("Error in API call $method $endpoint: $e");
      throw e;
    }
  }
}
