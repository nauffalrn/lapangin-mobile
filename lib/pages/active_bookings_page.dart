import 'package:flutter/material.dart';
import 'dart:async';
import '../models/booking_model.dart';
import '../services/booking_services.dart';
import '../widgets/bottom_navbar.dart';
import '../services/auth_service.dart';
import 'tracking_booking.dart';

class ActiveBookingsPage extends StatefulWidget {
  @override
  _ActiveBookingsPageState createState() => _ActiveBookingsPageState();
}

class _ActiveBookingsPageState extends State<ActiveBookingsPage> {
  List<Booking> _activeBookings = [];
  List<Booking> _upcomingBookings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Initial data fetch
    _fetchActiveBookings();
    
    // Set up periodic refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Timer.periodic(Duration(seconds: 60), (_) {
        if (mounted) {
          print("Auto-refreshing active bookings");
          _fetchActiveBookings();
        }
      });
    });
  }

  @override
  void dispose() {
    // Cancel any ongoing operations if needed
    super.dispose();
  }

  Future<void> _fetchActiveBookings() async {
  if (!mounted) return;
  
  List<Booking> activeList = [];
  List<Booking> upcomingList = [];
  
  try {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Silakan login untuk melihat booking Anda";
      });
      return;
    }

    final allBookings = await BookingService.getBookingHistory();
    if (!mounted) return;
    
    print("RAW BOOKING DATA FROM SERVER:");
    for (final booking in allBookings) {
      print("===== BOOKING ${booking.id} =====");
      print("Tanggal: ${booking.tanggal}");
      print("Waktu: ${booking.waktu}");
      print("JamMulai: ${booking.jamMulai}");
      print("JamSelesai: ${booking.jamSelesai}");
    }
    
    final now = DateTime.now();
    print("Current time: $now");
    print("Found ${allBookings.length} bookings in history");
    
    for (final booking in allBookings) {
      await BookingService.saveBookingLocally(booking);
      
      if (!isBookingValid(booking)) {
        print("Skipping invalid booking ${booking.id}");
        continue;
      }

      final bookingInfo = getBookingDateTimes(booking);
      if (bookingInfo == null) {
        print("Could not parse date/time for booking ${booking.id}, skipping");
        continue;
      }
      
      final startTime = bookingInfo['start'] as DateTime;
      final endTime = bookingInfo['end'] as DateTime;
      
      print("COMPARING TIME: Booking ${booking.id}");
      print("  Start: ${startTime}");
      print("  End: ${endTime}");
      print("  Now: ${now}");
      
      // Toleransi 1 menit untuk menghindari masalah precision
      final tolerance = Duration(minutes: 1);
      
      // LOGIKA BARU: Lebih ketat dalam kategorisasi
      if (now.isAfter(startTime.subtract(tolerance)) && now.isBefore(endTime.add(tolerance))) {
        // Currently active booking - sedang berlangsung
        print("Booking ${booking.id} is ACTIVE (ongoing)");
        activeList.add(booking);
      } 
      else if (now.isBefore(startTime.subtract(tolerance))) {
        // Future booking - belum dimulai
        print("Booking ${booking.id} is UPCOMING (future)");
        upcomingList.add(booking);
      } 
      else {
        // Past booking - sudah selesai
        print("Booking ${booking.id} is PAST (completed)");
      }
    }
    
    // Sort by date (closest first)
    activeList.sort((a, b) {
      final aInfo = getBookingDateTimes(a);
      final bInfo = getBookingDateTimes(b);
      if (aInfo == null || bInfo == null) return 0;
      return (aInfo['start'] as DateTime).compareTo(bInfo['start'] as DateTime);
    });
    
    upcomingList.sort((a, b) {
      final aInfo = getBookingDateTimes(a);
      final bInfo = getBookingDateTimes(b);
      if (aInfo == null || bInfo == null) return 0;
      return (aInfo['start'] as DateTime).compareTo(bInfo['start'] as DateTime);
    });
    
    if (!mounted) return;
    
    setState(() {
      _activeBookings = activeList;
      _upcomingBookings = upcomingList;
      _isLoading = false;
    });
    
    print("FINAL RESULT:");
    print("Active bookings: ${activeList.length}");
    activeList.forEach((booking) => print(" - ID ${booking.id}: ${booking.namaLapangan}, ${booking.tanggal}, ${booking.waktu}"));
    
    print("Upcoming bookings: ${upcomingList.length}");
    upcomingList.forEach((booking) => print(" - ID ${booking.id}: ${booking.namaLapangan}, ${booking.tanggal}, ${booking.waktu}"));
    
  } catch (e) {
    if (!mounted) return;
    
    print("ERROR in _fetchActiveBookings: $e");
    print("FINAL COUNTS - Active: ${activeList.length}, Upcoming: ${upcomingList.length}");
    
    setState(() {
      _errorMessage = 'Gagal memuat booking aktif: $e';
      _isLoading = false;
    });
  }
}

  // Helper to check if booking is ended
  bool isBookingEnded(Booking booking) {
    final bookingInfo = getBookingDateTimes(booking);
    if (bookingInfo == null) return true; // Consider as ended if can't parse
    
    final endTime = bookingInfo['end'] as DateTime;
    return DateTime.now().isAfter(endTime);
  }

  // Update the getBookingDateTimes method for better timezone handling
  Map<String, DateTime>? getBookingDateTimes(Booking booking) {
  if (booking.tanggal == null) return null;
  
  try {
    print("PARSING BOOKING: ${booking.id} - ${booking.tanggal} - ${booking.waktu ?? 'no waktu'} - JamMulai: ${booking.jamMulai}, JamSelesai: ${booking.jamSelesai}");
    
    DateTime bookingDate;
    
    // PRIORITAS 1: Parse format database langsung (ISO format dengan timezone)
    if (booking.tanggal!.contains("T") || booking.tanggal!.contains(" ")) {
      try {
        // Handle format seperti "2025-01-01 11:42:41" atau "2025-01-01T11:42:41"
        String dateTimeString = booking.tanggal!;
        
        // Normalize format
        if (dateTimeString.contains(" ")) {
          dateTimeString = dateTimeString.replaceAll(" ", "T");
        }
        
        // Parse as UTC then convert to local
        DateTime utcDateTime;
        if (dateTimeString.endsWith("Z")) {
          utcDateTime = DateTime.parse(dateTimeString);
        } else {
          utcDateTime = DateTime.parse(dateTimeString + "Z");
        }
        
        // Convert to local timezone
        bookingDate = utcDateTime.toLocal();
        
        print("Parsed UTC datetime ${booking.tanggal} to local: ${bookingDate}");
        
        // Extract time dari database jika ada jam_mulai dan jam_selesai
        int startHour = booking.jamMulai ?? bookingDate.hour;
        int endHour = booking.jamSelesai ?? (startHour + 1);
        
        // Override jam dengan jam_mulai/jam_selesai dari database
        final startDateTime = DateTime(
          bookingDate.year, bookingDate.month, bookingDate.day,
          startHour, 0
        );
        
        final endDateTime = DateTime(
          bookingDate.year, bookingDate.month, bookingDate.day,
          endHour, 0
        );
        
        print("Final booking times: Start=$startDateTime, End=$endDateTime");
        
        return {
          'start': startDateTime,
          'end': endDateTime,
        };
        
      } catch (e) {
        print("Error parsing ISO format: $e");
        // Fallback ke parsing lama
      }
    }
    
    // PRIORITAS 2: Format display "1 Mei 2025"
    if (booking.tanggal!.contains(" ") && !booking.tanggal!.contains("-")) {
      final dateComponents = booking.tanggal!.split(" ");
      if (dateComponents.length == 3) {
        final day = int.parse(dateComponents[0]);
        
        final months = [
          'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
          'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
        ];
        final month = months.indexOf(dateComponents[1]) + 1;
        if (month == 0) {
          print("Invalid month name: ${dateComponents[1]}");
          return null;
        }
        
        final year = int.parse(dateComponents[2]);
        bookingDate = DateTime(year, month, day);
      } else {
        return null;
      }
    }
    // PRIORITAS 3: Format "2025-01-01"
    else if (booking.tanggal!.contains("-") && !booking.tanggal!.contains(" ")) {
      bookingDate = DateTime.parse(booking.tanggal!);
    } else {
      return null;
    }
    
    // Extract time information
    int startHour = 0;
    int startMinute = 0;
    int endHour = 0;
    int endMinute = 0;
    
    // PRIORITAS 1: Gunakan jam_mulai dan jam_selesai dari database
    if (booking.jamMulai != null && booking.jamSelesai != null) {
      startHour = booking.jamMulai!;
      endHour = booking.jamSelesai!;
      print("Using database jam_mulai/jam_selesai: $startHour-$endHour");
    }
    // PRIORITAS 2: Parse dari waktu string
    else if (booking.waktu != null) {
      try {
        if (booking.waktu!.contains("-")) {
          final timeParts = booking.waktu!.split("-");
          final startTimePart = timeParts[0].trim();
          final endTimePart = timeParts[1].trim();
          
          final startTimePieces = startTimePart.split(":");
          startHour = int.parse(startTimePieces[0]);
          startMinute = startTimePieces.length > 1 ? int.parse(startTimePieces[1]) : 0;
          
          final endTimePieces = endTimePart.split(":");
          endHour = int.parse(endTimePieces[0]);
          endMinute = endTimePieces.length > 1 ? int.parse(endTimePieces[1]) : 0;
        } else {
          final timeParts = booking.waktu!.split(":");
          startHour = int.parse(timeParts[0]);
          startMinute = timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
          endHour = startHour + 1;
          endMinute = startMinute;
        }
        
        // Update booking object
        booking.jamMulai = startHour;
        booking.jamSelesai = endHour;
      } catch (e) {
        print("Error parsing time from waktu: $e");
        return null;
      }
    }
    
    // Create proper DateTime objects
    final startDateTime = DateTime(
      bookingDate.year, bookingDate.month, bookingDate.day,
      startHour, startMinute
    );
    
    final endDateTime = DateTime(
      bookingDate.year, bookingDate.month, bookingDate.day,
      endHour, endMinute
    );
    
    print("Final parsed datetime: Start=$startDateTime, End=$endDateTime");
    return {
      'start': startDateTime,
      'end': endDateTime,
    };
  } catch (e) {
    print("Error parsing booking dates: $e");
    return null;
  }
}

  bool isBookingValid(Booking booking) {
    if (booking.id == null || booking.tanggal == null) {
      print("Invalid booking: missing id or tanggal");
      return false;
    }
    
    // Enhanced validation - accept bookings with either waktu OR jam fields
    bool hasTimeInfo = false;
    
    // Check if we have waktu string
    if (booking.waktu != null && booking.waktu!.isNotEmpty) {
      hasTimeInfo = true;
    }
    
    // Check if we have jam_mulai and jam_selesai from database
    if (booking.jamMulai != null && booking.jamSelesai != null) {
      hasTimeInfo = true;
    }
    
    // Check if tanggal contains datetime info
    if (booking.tanggal!.contains("T") || booking.tanggal!.contains(" ")) {
      hasTimeInfo = true;
    }
    
    if (!hasTimeInfo) {
      print("Invalid booking ${booking.id}: no time information available");
      return false;
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking Booking', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF0A192F),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchActiveBookings,
            color: Colors.white,
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: TextStyle(color: Colors.red)))
              : _buildBookingList(),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }

  Widget _buildBookingList() {
    if (_activeBookings.isEmpty && _upcomingBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Anda tidak memiliki booking aktif',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Coba booking lapangan untuk memulai',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchActiveBookings,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Active bookings section
          if (_activeBookings.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
              child: Text(
                'Sedang Berlangsung',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800
                ),
              ),
            ),
            ..._activeBookings.map((booking) => _buildBookingCard(booking, true)),
            SizedBox(height: 24),
          ],
          
          // Upcoming bookings section - THIS SHOWS FUTURE BOOKINGS
          // Make sure this section is properly implemented and visible
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              'Yang Akan Datang',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800
              ),
            ),
          ),
          if (_upcomingBookings.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 12.0, bottom: 16.0),
              child: Text(
                'Tidak ada booking mendatang',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            )
          else
            ..._upcomingBookings.map((booking) => _buildBookingCard(booking, false)),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, bool isActive) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TrackingBookingPage(bookingId: booking.id!),
            ),
          ).then((_) => _fetchActiveBookings()); // Refresh on return
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.shade600 : Color(0xFF0A192F),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    booking.tanggal ?? 'Tanggal tidak tersedia',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    isActive ? Icons.play_circle_filled : Icons.schedule,
                    color: Colors.white, 
                    size: 20
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Venue name
                  Text(
                    booking.namaLapangan ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  // Time
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        booking.waktu ?? 'N/A',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  
                  // Location
                  if (booking.lokasi != null && booking.lokasi!.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.lokasi!,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                    
                  SizedBox(height: 12),
                  
                  // Track button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrackingBookingPage(bookingId: booking.id!),
                          ),
                        ).then((_) => _fetchActiveBookings());
                      },
                      icon: Icon(Icons.track_changes),
                      label: Text("Track Detail"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive ? Colors.green : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}