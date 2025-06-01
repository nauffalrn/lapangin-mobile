import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/widgets/bottom_navbar.dart';
import '../models/booking_model.dart';
import '../services/booking_services.dart';
import '../config/api_config.dart';
import 'detail.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/maps_service.dart';

class TrackingBookingPage extends StatefulWidget {
  final int bookingId;

  const TrackingBookingPage({Key? key, required this.bookingId})
    : super(key: key);

  @override
  _TrackingBookingPageState createState() => _TrackingBookingPageState();
}

class _TrackingBookingPageState extends State<TrackingBookingPage> {
  Booking? _booking;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;
  bool _isBookingActive = false;

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails();

    // Set up a timer to refresh booking status every minute
    _refreshTimer = Timer.periodic(Duration(minutes: 1), (_) {
      _checkBookingStatus();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchBookingDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print("Attempting to fetch booking details for ID: ${widget.bookingId}");

      Booking? booking;

      // First try local storage (fastest) - use the public method
      try {
        booking = await BookingService.getSavedBooking(widget.bookingId);
        print("Found booking ${widget.bookingId} in local storage");
      } catch (e) {
        print("Not found in local storage: $e");

        // Try direct endpoint
        try {
          booking = await BookingService.getBookingDetails(widget.bookingId);
        } catch (apiError) {
          print("Error with direct booking fetch: $apiError");

          // Finally try getting it from history
          try {
            final allBookings = await BookingService.getBookingHistory();

            booking = allBookings.firstWhere(
              (b) => b.id == widget.bookingId,
              orElse: () => throw Exception('Booking not found in history'),
            );

            // Save for future reference - use the public method
            await BookingService.saveBookingLocally(booking);
          } catch (historyError) {
            throw Exception('Booking could not be found: $historyError');
          }
        }
      }

      setState(() {
        _booking = booking;
        _isLoading = false;
        _checkBookingStatus();
      });
    } catch (e) {
      print("Final error in fetch booking details: $e");
      setState(() {
        _errorMessage = 'Gagal memuat detail booking: $e';
        _isLoading = false;
      });

      // Show error dialog with option to go back
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text("Error"),
              content: Text(
                "Tidak dapat menemukan booking. Periksa riwayat booking Anda.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/active-bookings');
                  },
                  child: Text("Kembali"),
                ),
              ],
            ),
      );
    }
  }

  bool isBookingEnded(Booking booking) {
    final bookingInfo = getBookingDateTimes(booking);
    if (bookingInfo == null) return false;

    final endTime = bookingInfo['end'] as DateTime;
    return DateTime.now().isAfter(endTime);
  }

  Map<String, DateTime>? getBookingDateTimes(Booking booking) {
    if (booking.tanggal == null || booking.waktu == null) return null;

    try {
      // Parse the date (format: "1 Mei 2025")
      final dateComponents = booking.tanggal!.split(" ");
      if (dateComponents.length != 3) return null;

      final day = int.parse(dateComponents[0]);

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
      final month = months.indexOf(dateComponents[1]) + 1;
      if (month == 0) return null;

      final year = int.parse(dateComponents[2]);

      // Parse times from time slots
      final timeSlots = booking.waktu!.split(", ");
      if (timeSlots.isEmpty) return null;

      // Get first slot for start time
      final firstTimeSlot = timeSlots.first;
      final startTimeStr = firstTimeSlot.split("-").first.trim();
      final startTimeParts = startTimeStr.split(":");
      final startHour = int.parse(startTimeParts[0]);
      final startMinute =
          startTimeParts.length > 1 ? int.parse(startTimeParts[1]) : 0;

      // Get last slot for end time
      final lastTimeSlot = timeSlots.last;
      final endTimeStr = lastTimeSlot.split("-").last.trim();
      final endTimeParts = endTimeStr.split(":");
      final endHour = int.parse(endTimeParts[0]);
      final endMinute =
          endTimeParts.length > 1 ? int.parse(endTimeParts[1]) : 0;

      return {
        'start': DateTime(year, month, day, startHour, startMinute),
        'end': DateTime(year, month, day, endHour, endMinute),
      };
    } catch (e) {
      print("Error parsing booking dates: $e");
      return null;
    }
  }

  void _checkBookingStatus() {
    if (_booking == null) return;

    // Parse booking date and time
    final tanggalStr = _booking!.tanggal; // Format: "1 Mei 2025"

    if (_booking!.waktu == null || tanggalStr == null) {
      setState(() {
        _isBookingActive = false;
      });
      return;
    }

    try {
      // Extract all time slots
      List<String> timeSlots;
      if (_booking!.waktu!.contains(",")) {
        timeSlots = _booking!.waktu!.split(",").map((s) => s.trim()).toList();
      } else {
        timeSlots = [_booking!.waktu!.trim()];
      }

      if (timeSlots.isEmpty) {
        setState(() {
          _isBookingActive = false;
        });
        return;
      }

      // Parse the date string
      // Split the date components
      final dateComponents = tanggalStr.split(" ");
      if (dateComponents.length != 3) throw Exception("Invalid date format");

      final day = int.parse(dateComponents[0]);

      // Convert month name to month number
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
      final month = months.indexOf(dateComponents[1]) + 1;
      if (month == 0) throw Exception("Invalid month name");

      final year = int.parse(dateComponents[2]);

      final bookingDate = DateTime(year, month, day);

      // Get the first slot for start time
      final firstTimeSlot = timeSlots.first;
      final startTimeStr = firstTimeSlot.split("-").first.trim();

      // Parse the start time (format: "17:00")
      int startHour = 0;
      int startMinute = 0;
      final startTimeParts = startTimeStr.split(":");
      startHour = int.parse(startTimeParts[0]);
      startMinute =
          startTimeParts.length > 1 ? int.parse(startTimeParts[1]) : 0;

      // Get the last time slot to determine end time
      final lastTimeSlot = timeSlots.last;
      final endTimeStr = lastTimeSlot.split("-").last.trim();

      // Parse the end time (format: "17:00")
      int endHour = 0;
      int endMinute = 0;
      final endTimeParts = endTimeStr.split(":");
      endHour = int.parse(endTimeParts[0]);
      endMinute = endTimeParts.length > 1 ? int.parse(endTimeParts[1]) : 0;

      // Create DateTime objects for booking start and end
      final bookingStartTime = DateTime(
        bookingDate.year,
        bookingDate.month,
        bookingDate.day,
        startHour,
        startMinute,
      );

      final bookingEndTime = DateTime(
        bookingDate.year,
        bookingDate.month,
        bookingDate.day,
        endHour,
        endMinute,
      );

      // Get current time
      final now = DateTime.now();

      print("Booking start: ${bookingStartTime.toString()}");
      print("Booking end: ${bookingEndTime.toString()}");
      print("Current time: ${now.toString()}");
      print(
        "Is booking active: ${now.isAfter(bookingStartTime) && now.isBefore(bookingEndTime)}",
      );

      // Check if booking is ongoing (current time is between start and end time)
      setState(() {
        _isBookingActive =
            now.isAfter(bookingStartTime) && now.isBefore(bookingEndTime);
      });

      // If booking has ended, navigate back to history
      if (now.isAfter(bookingEndTime)) {
        // Add a small delay to allow the UI to update
        Future.delayed(Duration(seconds: 1), () {
          _showBookingCompleteDialog();
        });
      }
    } catch (e) {
      print("Error checking booking status: $e");
      setState(() {
        _isBookingActive = false;
      });
    }
  }

  void _showBookingCompleteDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Booking Selesai"),
          content: Text(
            "Booking Anda telah selesai dan dipindahkan ke riwayat.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/history');
              },
              child: Text("Lihat Riwayat"),
            ),
          ],
        );
      },
    );
  }

  // Update method _openInGoogleMaps untuk konsisten dengan detail page
  Future<void> _openInGoogleMaps() async {
    print("Opening Google Maps from tracking page...");
    print("Booking data: ${_booking?.lapanganData}");
    print("Latitude: ${_booking?.lapanganLatitude}");
    print("Longitude: ${_booking?.lapanganLongitude}");
    print("Nama lapangan: ${_booking?.namaLapangan}");
    print("Lokasi: ${_booking?.lokasi}");

    // Dapatkan koordinat dari booking
    double? lat = _booking?.lapanganLatitude;
    double? lng = _booking?.lapanganLongitude;

    // Buat nama tempat lengkap untuk pencarian
    String placeName = "${_booking?.namaLapangan ?? ''} ${_booking?.lokasi ?? ''}".trim();

    // Gunakan method yang sudah diupdate dengan validasi koordinat
    await MapsService.openInGoogleMapsWithLocation(
      context: context,
      latitude: lat,
      longitude: lng,
      placeName: placeName.isNotEmpty ? placeName : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tracking Booking", style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF0A192F),
        iconTheme: IconThemeData(color: Colors.white),
        // Remove the custom leading widget and let Flutter handle it automatically
        automaticallyImplyLeading: true,
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              )
              : _buildBookingDetails(),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }

  Widget _buildBookingDetails() {
    if (_booking == null) {
      return Center(child: Text("Data booking tidak ditemukan"));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Card(
            elevation: 4,
            color:
                _isBookingActive ? Colors.green.shade50 : Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _isBookingActive ? Colors.green : Colors.blue,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _isBookingActive
                        ? Icons.play_circle_filled
                        : Icons.schedule,
                    size: 40,
                    color: _isBookingActive ? Colors.green : Colors.blue,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isBookingActive
                              ? "Sedang Berlangsung"
                              : "Akan Berlangsung",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                _isBookingActive ? Colors.green : Colors.blue,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _isBookingActive
                              ? "Booking Anda sedang aktif"
                              : "Booking akan aktif pada waktu terjadwal",
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Booking Details
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Detail Booking",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  _buildDetailRow("ID Booking", "#${_booking!.id}"),
                  _buildDetailRow("Status Pembayaran", "Lunas"),
                  Divider(height: 24),
                  _buildDetailRow(
                    "Tanggal",
                    _booking!.tanggal ?? "Tidak tersedia",
                  ),
                  _buildDetailRow("Waktu", _booking!.waktu ?? "Tidak tersedia"),
                  _buildDetailRow(
                    "Durasi",
                    "${_calculateBookingDuration()} jam",
                  ),
                  if (_booking!.kodePromo != null &&
                      _booking!.kodePromo!.isNotEmpty) ...[
                    _buildDetailRow(
                      "Harga Awal",
                      "Rp ${_booking!.totalPrice?.toStringAsFixed(0) ?? '0'}",
                    ),
                    _buildDetailRow("Kode Promo", _booking!.kodePromo ?? "-"),
                    _buildDetailRow("Total Harga", _getDiscountedPriceText()),
                  ] else ...[
                    _buildDetailRow(
                      "Total Harga",
                      "Rp ${_booking!.totalPrice?.toStringAsFixed(0) ?? '0'}",
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Lapangan Details
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Detail Lapangan",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  _buildDetailRow(
                    "Nama",
                    _booking!.namaLapangan ?? "Tidak tersedia",
                  ),
                  _buildDetailRow(
                    "Alamat",
                    _booking!.lokasi ?? "Tidak tersedia",
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _openInGoogleMaps, // Selalu aktif karena ada fallback
                      icon: Icon(Icons.directions),
                      label: Text("Buka di Google Maps"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Instructions
          Card(
            elevation: 2,
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        "Informasi",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    "• Harap datang 15 menit sebelum waktu booking",
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "• Tunjukkan bukti booking ini kepada penjaga",
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "• Status booking akan otomatis diperbarui",
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Update the _buildDetailRow to handle both String and Widget values
  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child:
                value is String
                    ? Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    )
                    : value, // Use the widget directly if it's not a string
          ),
        ],
      ),
    );
  }

  String _calculateBookingDuration() {
    if (_booking == null) return "0";

    // Try to calculate from jadwalList first (most accurate)
    if (_booking!.jadwalList.isNotEmpty) {
      return _booking!.jadwalList.length.toString();
    }

    // If jadwalList is empty, try to calculate from jamMulai and jamSelesai
    if (_booking!.jamMulai != null && _booking!.jamSelesai != null) {
      final duration = _booking!.jamSelesai! - _booking!.jamMulai!;
      return duration.toString();
    }

    // Last resort: try to parse from waktu string
    if (_booking!.waktu != null) {
      try {
        final waktuParts = _booking!.waktu!.split("-");
        if (waktuParts.length == 2) {
          final startTimePart = waktuParts[0].trim();
          final endTimePart = waktuParts[1].trim();

          final startHour = int.parse(startTimePart.split(":")[0]);
          final endHour = int.parse(endTimePart.split(":")[0]);

          return (endHour - startHour).toString();
        }
      } catch (e) {
        print("Error calculating duration from waktu: $e");
      }
    }

    // If all else fails
    return "0";
  }

  String _formatPriceWithDiscount() {
    if (_booking == null) return "Rp 0";

    // Get the base price and formatted string
    double basePrice = _booking!.totalPrice ?? 0;
    String formattedBasePrice = "Rp ${basePrice.toStringAsFixed(0)}";

    // Check if there was a promo applied
    if (_booking!.kodePromo != null &&
        _booking!.kodePromo!.isNotEmpty &&
        _booking!.diskonPersen != null) {
      // Calculate the discounted price
      double discountAmount = basePrice * (_booking!.diskonPersen! / 100);
      double finalPrice = basePrice - discountAmount;

      // Format with strikethrough on original price
      return "Rp ${finalPrice.toStringAsFixed(0)} (${_booking!.diskonPersen}% off)";
    } else if (_booking!.hargaDiskon != null && _booking!.hargaDiskon! > 0) {
      // If we already have final discounted price saved
      return "Rp ${_booking!.hargaDiskon!.toStringAsFixed(0)}";
    }

    // No discount applied
    return formattedBasePrice;
  }

  Widget _getDiscountedPriceText() {
    if (_booking == null) return Text("Rp 0");

    double basePrice = _booking!.totalPrice ?? 0;
    double discountedPrice = basePrice;
    String discountInfo = "";

    // Calculate discounted price if we have discount percentage
    if (_booking!.diskonPersen != null) {
      double discountAmount = basePrice * (_booking!.diskonPersen! / 100);
      discountedPrice = basePrice - discountAmount;
      discountInfo = " (${_booking!.diskonPersen}% off)";
    }
    // Or use pre-calculated hargaDiskon if available
    else if (_booking!.hargaDiskon != null && _booking!.hargaDiskon! > 0) {
      discountedPrice = _booking!.hargaDiskon!;
      // Calculate percentage for display
      double discountPercent =
          ((basePrice - discountedPrice) / basePrice) * 100;
      discountInfo = " (${discountPercent.toStringAsFixed(0)}% off)";
    }

    // Return a rich text with the discounted price
    return RichText(
      text: TextSpan(
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        children: [
          TextSpan(
            text: "Rp ${discountedPrice.toStringAsFixed(0)}",
            style: TextStyle(color: Colors.green),
          ),
          TextSpan(
            text: discountInfo,
            style: TextStyle(color: Colors.green.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
