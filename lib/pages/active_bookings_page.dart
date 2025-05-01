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
    
    // Define lists outside the try/catch blocks so they're accessible in both
    List<Booking> activeList = [];
    List<Booking> upcomingList = [];
    
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Check login status first
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = "Silakan login untuk melihat booking Anda";
        });
        return;
      }

      // Fetch all bookings
      final allBookings = await BookingService.getBookingHistory();
      if (!mounted) return;
      
      // Add this after the getBookingHistory call
      print("RAW BOOKING DATA FROM SERVER:");
      for (final booking in allBookings) {
        print("===== BOOKING ${booking.id} =====");
        print("Tanggal: ${booking.tanggal}");
        print("Waktu: ${booking.waktu}");
        print("JamMulai: ${booking.jamMulai}");
        print("JamSelesai: ${booking.jamSelesai}");
        print("Data type checks: ");
        print("- tanggal is ${booking.tanggal?.runtimeType}");
        print("- waktu is ${booking.waktu?.runtimeType}");
        print("- jamMulai is ${booking.jamMulai?.runtimeType}");
        print("- jamSelesai is ${booking.jamSelesai?.runtimeType}");
      }
      
      // Current time for comparisons
      final now = DateTime.now();
      
      print("Found ${allBookings.length} bookings in history");
      
      // Process bookings - reuse the lists defined outside
      for (final booking in allBookings) {
        // Save booking locally to improve tracking performance
        await BookingService.saveBookingLocally(booking);
        
        // Skip invalid bookings
        if (!isBookingValid(booking)) {
          print("Skipping invalid booking ${booking.id}");
          continue;
        }
        
        // Parse the booking date and time
        final bookingInfo = getBookingDateTimes(booking);
        if (bookingInfo == null) {
          print("Could not parse date/time for booking ${booking.id}, skipping");
          continue;
        }
        
        final startTime = bookingInfo['start'] as DateTime;
        final endTime = bookingInfo['end'] as DateTime;
        
        // Get current time in local timezone
        final now = DateTime.now();
        
        print("COMPARING TIME: Booking ${booking.id}, Start: ${startTime}, End: ${endTime}, Now: ${now}");
        print("Local date check - Booking day: ${startTime.day}/${startTime.month}, Today: ${now.day}/${now.month}");
        
        // Enhanced comparison that's more tolerant of slight time differences
        // A booking is considered active if current time is within start and end times
        if (now.isAfter(startTime) && now.isBefore(endTime)) {
          // Currently active booking
          print("Booking ${booking.id} is ACTIVE");
          activeList.add(booking);
        } 
        // A booking is upcoming if it's in the future (start time is after now)
        else if (now.isBefore(startTime)) {
          // Future booking - will happen later
          print("Booking ${booking.id} is UPCOMING");
          upcomingList.add(booking);
        } 
        // Otherwise, it's a past booking (end time is before now)
        else {
          print("Booking ${booking.id} is PAST");
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
      
      print("Active bookings: ${activeList.length}, Upcoming: ${upcomingList.length}");
      
      // Add this to debug each upcoming booking
      if (upcomingList.isNotEmpty) {
        print("UPCOMING BOOKINGS DETAILS:");
        for (var booking in upcomingList) {
          print("- ID: ${booking.id}, Lapangan: ${booking.namaLapangan}");
          print("  Tanggal: ${booking.tanggal}, Waktu: ${booking.waktu}");
        }
      }
    } catch (e) {
      if (!mounted) return;
      
      // ADDED: Print the total upcoming and active bookings for debugging
      // Now the lists are accessible here
      print("\n===== ACTIVE BOOKINGS DEBUGGING =====");
      print("ACTIVE COUNT: ${activeList.length}");
      activeList.forEach((booking) => print(" - ID ${booking.id}: ${booking.namaLapangan}, ${booking.tanggal}, ${booking.waktu}"));
      
      print("\nUPCOMING COUNT: ${upcomingList.length}");
      upcomingList.forEach((booking) => print(" - ID ${booking.id}: ${booking.namaLapangan}, ${booking.tanggal}, ${booking.waktu}"));
      print("=====================================\n");
      
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
      
      // First check if the date string has a UTC timestamp format
      if (booking.tanggal!.contains("-") && booking.tanggal!.contains(":")) {
        // Handle formats like "2025-05-02 04:00:00"
        try {
          // Parse the raw datetime string
          String dateTimeString = booking.tanggal!;
          
          // Convert to DateTime (in UTC)
          DateTime utcDateTime = DateTime.parse(dateTimeString.replaceAll(' ', 'T') + 'Z');
          
          // Convert to local time
          DateTime localDateTime = utcDateTime.toLocal();
          
          print("Converted UTC date ${dateTimeString} to local: ${localDateTime}");
          
          // Extract time information for hour checks
          int startHour = 0;
          int startMinute = 0;
          int endHour = 0;
          int endMinute = 0;
          
          // If we have specific booking start/end times, use those
          if (booking.jamMulai != null && booking.jamSelesai != null) {
            startHour = booking.jamMulai!;
            endHour = booking.jamSelesai!;
          } 
          // Otherwise extract from the datetime
          else {
            startHour = localDateTime.hour;
            startMinute = localDateTime.minute;
            endHour = startHour + 1;  // Assume 1-hour booking
            endMinute = startMinute;
            
            // Update the booking object with the correct times
            booking.jamMulai = startHour;
            booking.jamSelesai = endHour;
            
            // Create or update the waktu field
            booking.waktu = "${startHour.toString().padLeft(2, '0')}:00-${endHour.toString().padLeft(2, '0')}:00";
          }
          
          // Create start and end DateTimes
          final startDateTime = DateTime(
            localDateTime.year, localDateTime.month, localDateTime.day, startHour, startMinute
          );
          
          final endDateTime = DateTime(
            localDateTime.year, localDateTime.month, localDateTime.day, endHour, endMinute
          );
          
          print("TIMEZONE ADJUSTED - Start: $startDateTime, End: $endDateTime");
          
          return {
            'start': startDateTime,
            'end': endDateTime,
          };
        } catch (e) {
          print("Error parsing ISO datetime: $e");
          // Fall through to other parsing methods
        }
      }
      
      // Rest of your existing parsing logic for other formats
      // ...
      
      DateTime bookingDate;
      
      // FIXED: Handle ISO format date with time (2025-05-02 15:00:00)
      if (booking.tanggal!.contains(" ") && booking.tanggal!.contains("-")) {
        // Format: "2025-05-02 15:00:00"
        try {
          final dateParts = booking.tanggal!.split(' ');
          final dateStr = dateParts[0]; // "2025-05-02"
          final dateComponents = dateStr.split('-');
          
          if (dateComponents.length == 3) {
            final year = int.parse(dateComponents[0]);
            final month = int.parse(dateComponents[1]);
            final day = int.parse(dateComponents[2]);
            bookingDate = DateTime(year, month, day);
            
            // If we have a time part, try to extract hours
            if (dateParts.length > 1) {
              final timeStr = dateParts[1]; // "15:00:00"
              final timeParts = timeStr.split(':');
              if (timeParts.length >= 2) {
                // Set or override jamMulai and jamSelesai
                booking.jamMulai = int.parse(timeParts[0]);
                booking.jamSelesai = booking.jamMulai! + 1;
                
                // Set or update waktu field
                booking.waktu = "${booking.jamMulai.toString().padLeft(2, '0')}:00-${booking.jamSelesai.toString().padLeft(2, '0')}:00";
              }
            }
          } else {
            throw Exception("Invalid date format");
          }
        } catch (e) {
          print("Error parsing datetime: $e");
          return null;
        }
      }
      else if (booking.tanggal!.contains("T")) {
        // ISO format: "2025-05-01T00:00:00"
        bookingDate = DateTime.parse(booking.tanggal!).toLocal();
      } else if (booking.tanggal!.contains("-")) {
        // Format: "2025-05-01"
        bookingDate = DateTime.parse(booking.tanggal!);
      } else {
        // Format: "1 Mei 2025"
        final dateComponents = booking.tanggal!.split(" ");
        if (dateComponents.length != 3) {
          print("Invalid date format: ${booking.tanggal}");
          return null;
        }
        
        final day = int.parse(dateComponents[0]);
        
        // Convert month name to number
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
      }
      
      // Extract hours directly from booking_date if it has time component
      int startHour = 0;
      int startMinute = 0;
      int endHour = 0;
      int endMinute = 0;
      
      // Use jamMulai/jamSelesai if available (highest priority)
      if (booking.jamMulai != null && booking.jamSelesai != null) {
        startHour = booking.jamMulai!;
        endHour = booking.jamSelesai!;
        print("Using jamMulai/jamSelesai: $startHour-$endHour");
      }
      // Otherwise parse from waktu string if available
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
          
          // Update jamMulai and jamSelesai for future reference
          booking.jamMulai = startHour;
          booking.jamSelesai = endHour;
        } catch (e) {
          print("Error parsing time from waktu: $e");
          return null;
        }
      }
      
      // Create proper DateTime objects with the parsed values
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
    // Check for required fields
    if (booking.id == null || booking.tanggal == null) {
      print("Invalid booking: missing id or tanggal");
      return false;
    }
    
    // ENHANCED: If booking_date contains time information, that's enough
    if (booking.tanggal!.contains(":")) {
      return true;
    }
    
    // Check if we can determine the booking time
    if ((booking.waktu == null && booking.jamMulai == null) || 
        (booking.waktu == null && booking.jamSelesai == null)) {
      print("Invalid booking: can't determine booking time");
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