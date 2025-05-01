import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile/widgets/bottom_navbar.dart';
import '../models/booking_model.dart';
import '../services/booking_services.dart';
import '../config/api_config.dart';
import 'detail.dart';
import 'package:url_launcher/url_launcher.dart';

class TrackingBookingPage extends StatefulWidget {
  final int bookingId;

  const TrackingBookingPage({Key? key, required this.bookingId}) : super(key: key);

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
        builder: (context) => AlertDialog(
          title: Text("Error"),
          content: Text("Tidak dapat menemukan booking. Periksa riwayat booking Anda."),
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
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
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
      final startMinute = startTimeParts.length > 1 ? int.parse(startTimeParts[1]) : 0;
      
      // Get last slot for end time
      final lastTimeSlot = timeSlots.last;
      final endTimeStr = lastTimeSlot.split("-").last.trim();
      final endTimeParts = endTimeStr.split(":");
      final endHour = int.parse(endTimeParts[0]);
      final endMinute = endTimeParts.length > 1 ? int.parse(endTimeParts[1]) : 0;
      
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
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
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
      startMinute = startTimeParts.length > 1 ? int.parse(startTimeParts[1]) : 0;

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
      print("Is booking active: ${now.isAfter(bookingStartTime) && now.isBefore(bookingEndTime)}");

      // Check if booking is ongoing (current time is between start and end time)
      setState(() {
        _isBookingActive = now.isAfter(bookingStartTime) && now.isBefore(bookingEndTime);
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
          content: Text("Booking Anda telah selesai dan dipindahkan ke riwayat."),
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

  Future<void> _openInGoogleMaps() async {
    if (_booking?.lapanganData != null) {
      final lapanganData = _booking!.lapanganData!;
      final double? lat = lapanganData['latitude'] is String 
          ? double.tryParse(lapanganData['latitude']) 
          : lapanganData['latitude']?.toDouble();
      final double? lng = lapanganData['longitude'] is String 
          ? double.tryParse(lapanganData['longitude']) 
          : lapanganData['longitude']?.toDouble();

      if (lat != null && lng != null) {
        final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          throw 'Could not launch $url';
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Koordinat lokasi tidak tersedia'))
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data lokasi tidak tersedia'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tracking Booking", style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF0A192F),
        iconTheme: IconThemeData(color: Colors.white),
        // Override the back button behavior
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Navigate to active-bookings instead of going back
            Navigator.pushReplacementNamed(context, '/active-bookings');
          },
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
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
            color: _isBookingActive ? Colors.green.shade50 : Colors.blue.shade50,
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
                    _isBookingActive ? Icons.play_circle_filled : Icons.schedule,
                    size: 40,
                    color: _isBookingActive ? Colors.green : Colors.blue,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isBookingActive ? "Sedang Berlangsung" : "Akan Berlangsung",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _isBookingActive ? Colors.green : Colors.blue,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _isBookingActive 
                              ? "Booking Anda sedang aktif" 
                              : "Booking akan aktif pada waktu terjadwal",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  _buildDetailRow("Tanggal", _booking!.tanggal ?? "Tidak tersedia"),
                  _buildDetailRow("Waktu", _booking!.waktu ?? "Tidak tersedia"),
                  _buildDetailRow("Durasi", "${_booking!.jadwalList.length} jam"),
                  _buildDetailRow("Total Harga", "Rp ${_booking!.totalPrice?.toStringAsFixed(0) ?? '0'}"),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 20),
          
          // Lapangan Details
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  _buildDetailRow("Nama", _booking!.namaLapangan ?? "Tidak tersedia"),
                  _buildDetailRow("Alamat", _booking!.lokasi ?? "Tidak tersedia"),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openInGoogleMaps,
                    icon: Icon(Icons.directions),
                    label: Text("Buka di Google Maps"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 44),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          color: Colors.blue.shade800
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

  Widget _buildDetailRow(String label, String value) {
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
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}