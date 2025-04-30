import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../models/lapangan_model.dart';
import '../models/booking_model.dart';
import '../services/booking_services.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart'; // Tambahkan import yang diperlukan
import 'pembayaran.dart';
import '../models/review_model.dart';
import '../services/review_services.dart';

class DetailPage extends StatefulWidget {
  final Lapangan lapangan;

  DetailPage({required this.lapangan});

  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  DateTime? selectedDate;
  List<Map<String, dynamic>> _selectedTimeSlots = [];
  double? _distance;
  bool _isLoadingLocation = false;
  bool _isLoadingSlots = false;
  String? _scheduleError; // Tambahkan variabel yang hilang
  List<Map<String, dynamic>> _timeSlots = [];
  List<Review> _reviews = [];
  bool _isLoadingReviews = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchReviews(); // Tambahkan ini
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        // Clear selected time slots when date changes
        _selectedTimeSlots = [];
      });

      // Fetch available time slots for the selected date
      _fetchAvailableTimeSlots(picked);
    }
  }

  Future<void> _fetchAvailableTimeSlots(DateTime date) async {
    setState(() {
      _isLoadingSlots = true;
      _timeSlots = [];
    });

    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);
      final slotsData = await BookingService.getJadwal(
        widget.lapangan.id,
        formattedDate,
      );

      // Get current time
      final now = DateTime.now();
      final isToday =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      // Process all slots with their status
      List<Map<String, dynamic>> processedSlots = [];

      for (var slot in slotsData) {
        // Parse time string like "08:00" into hours
        String waktu = slot['waktu']?.toString() ?? "";
        if (waktu.isNotEmpty) {
          int hourValue = int.parse(waktu.split(':')[0]);
          bool isPast = isToday && hourValue <= now.hour;
          bool isAvailable = slot['tersedia'] == true;

          // Add to processed slots
          processedSlots.add({
            'waktu': waktu,
            'isPast': isPast,
            'isAvailable': isAvailable,
            'harga': slot['harga'],
          });
        }
      }

      // Sort by time
      processedSlots.sort((a, b) {
        int hourA = int.parse(a['waktu'].split(':')[0]);
        int hourB = int.parse(b['waktu'].split(':')[0]);
        return hourA.compareTo(hourB);
      });

      setState(() {
        _timeSlots = processedSlots;
        _isLoadingSlots = false;
      });
    } catch (e) {
      print("Error fetching available time slots: $e");
      setState(() {
        _isLoadingSlots = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengambil jadwal: $e')));
    }
  }

  // Update _selectTime method to support multiple selections
  void _selectTime(BuildContext context) {
    if (_timeSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak ada slot waktu tersedia'))
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        // Create a StatefulBuilder to handle state changes within the bottom sheet
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.all(16),
              height: 400, // Make it taller to fit more content
              child: Column(
                children: [
                  Text(
                    "Pilih Jam",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Anda dapat memilih lebih dari satu jam",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _timeSlots.length,
                      itemBuilder: (context, index) {
                        final slot = _timeSlots[index];
                        final bool isPast = slot['isPast'] ?? false;
                        final bool isAvailable = slot['isAvailable'] ?? true;
                        
                        // Check if this slot is selected
                        final bool isSelected = _selectedTimeSlots.any(
                          (selectedSlot) => selectedSlot['waktu'] == slot['waktu']
                        );

                        // Determine text color based on status
                        Color? textColor;
                        if (!isAvailable) {
                          textColor = Colors.red;
                        } else if (isPast) {
                          textColor = Colors.grey;
                        }

                        return CheckboxListTile(
                          title: Text(
                            slot['waktu'],
                            style: TextStyle(
                              color: textColor ?? (isSelected ? Colors.blue : null),
                              fontWeight: isAvailable && !isPast
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            isAvailable
                                ? "Rp${slot['harga'].toString()}/jam"
                                : "Sudah dipesan",
                            style: TextStyle(color: textColor),
                          ),
                          value: isSelected,
                          onChanged: isAvailable && !isPast
                              ? (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      // Add to selected slots
                                      _selectedTimeSlots.add(slot);
                                    } else {
                                      // Remove from selected slots
                                      _selectedTimeSlots.removeWhere(
                                        (selectedSlot) => selectedSlot['waktu'] == slot['waktu']
                                      );
                                    }
                                  });
                                  
                                  // Also update the parent state
                                  this.setState(() {});
                                }
                              : null,
                          activeColor: Colors.blue,
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${_selectedTimeSlots.length} jam dipilih",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Total: Rp${_calculateTotalPrice()}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _selectedTimeSlots.isNotEmpty
                        ? () {
                            Navigator.pop(context);
                            this.setState(() {});
                          }
                        : null,
                    child: Text("Konfirmasi Pilihan"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  // Add a helper method to calculate total price
  String _calculateTotalPrice() {
    double total = 0;
    for (var slot in _selectedTimeSlots) {
      var price = slot['harga'];
      if (price is int) {
        total += price.toDouble();
      } else if (price is double) {
        total += price;
      }
    }
    return total.toStringAsFixed(0);
  }

  // Add a method to get formatted selected time slots for display
  String get _formattedSelectedTimes {
    if (_selectedTimeSlots.isEmpty) return "Pilih Jam";
    
    // Sort slots by time
    List<Map<String, dynamic>> sortedSlots = List.from(_selectedTimeSlots);
    sortedSlots.sort((a, b) {
      int hourA = int.parse(a['waktu'].split(':')[0]);
      int hourB = int.parse(b['waktu'].split(':')[0]);
      return hourA.compareTo(hourB);
    });
    
    // Create text with format: "09:00-10:00, 11:00-12:00, 13:00-14:00"
    return sortedSlots.map((slot) {
      String startHour = slot['waktu'];
      int hour = int.parse(startHour.split(':')[0]);
      String endHour = "${hour + 1}:00";
      return "$startHour-$endHour";
    }).join(", ");
  }

  // Update the _createBooking method with better error handling

Future<void> _createBooking() async {
  if (selectedDate == null || _selectedTimeSlots.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Silakan pilih tanggal dan minimal 1 jam'))
    );
    return;
  }

  try {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    // Create jadwalItems from selected slots
    List<JadwalItem> jadwalItems = [];
    
    // IMPORTANT: DO NOT sort slots - preserve the original selection order
    // This prevents backend from assuming consecutive slots
    for (var slot in _selectedTimeSlots) {
      // Extract hour from time string
      int jamBooking = int.parse(slot['waktu'].split(':')[0]);
      
      // Get price from slot
      var hargaValue = slot['harga'];
      double harga = hargaValue is int ? hargaValue.toDouble() : 
                     hargaValue is double ? hargaValue : 
                     widget.lapangan.hargaSewa;
                     
      jadwalItems.add(JadwalItem(jam: jamBooking, harga: harga));
    }

    // PERBAIKAN: Tambahkan nama lapangan dan lokasi dari widget lapangan
    // Hitung totalPrice
    double totalPrice = 0;
    for (var item in jadwalItems) {
      totalPrice += item.harga;
    }
    
    final booking = Booking(
      lapanganId: widget.lapangan.id,
      namaLapangan: widget.lapangan.nama, // Tambahkan nama lapangan
      lokasi: widget.lapangan.alamat,     // Tambahkan alamat/lokasi
      tanggal: DateFormat('yyyy-MM-dd').format(selectedDate!),
      jadwalList: jadwalItems,
      totalPrice: totalPrice  // Tambahkan total price sejak awal
    );
    
    print("Creating booking for lapangan ID: ${booking.lapanganId}");
    print("Lapangan name: ${booking.namaLapangan}");
    print("Location: ${booking.lokasi}");
    print("Date: ${booking.tanggal}");
    print("Time slots: ${jadwalItems.length} slots");
    
    // Create the booking with direct token handling
    final result = await BookingService.createBooking(booking);

    // Close loading dialog
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Navigate to payment page with booking data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PembayaranPage(booking: result),
      ),
    ).then((value) {
      // Refresh state when returning from payment page
      setState(() {
        _selectedTimeSlots = [];
        selectedDate = null;
      });
    });
  } catch (e) {
    // Close loading dialog
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    String errorMessage = e.toString().toLowerCase();
    
    print("Booking error: $errorMessage");
    
    // Check for different authentication error patterns
    if (errorMessage.contains('login') || 
        errorMessage.contains('auth') ||
        errorMessage.contains('unauth') ||
        errorMessage.contains('expired') ||
        errorMessage.contains('token')) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sesi anda habis. Silakan login kembali'))
      );
      
      // Logout and redirect to login
      await AuthService.logout();
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat booking: $e'))
      );
    }
  }
}

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition();

      // Get venue coordinates from the widget data
      double? venueLat = widget.lapangan.latitude;
      double? venueLng = widget.lapangan.longitude;

      if (venueLat != null && venueLng != null) {
        // Calculate distance in meters
        double distanceInMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          venueLat,
          venueLng,
        );

        setState(() {
          _distance = distanceInMeters;
          _isLoadingLocation = false;
        });
      } else {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _openInGoogleMaps() async {
    if (widget.lapangan.latitude != null && widget.lapangan.longitude != null) {
      final url =
          'https://www.google.com/maps/dir/?api=1&destination=${widget.lapangan.latitude},${widget.lapangan.longitude}';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch $url';
      }
    }
  }

  Future<void> _fetchReviews() async {
    setState(() {
      _isLoadingReviews = true;
    });

    try {
      print("Fetching reviews for lapangan: ${widget.lapangan.id}");
      
      // Add a catch block for timeouts
      final reviews = await ReviewService.getReviewsByLapanganId(
        widget.lapangan.id,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print("Review fetch timed out");
          return [];
        },
      );
      
      print("Fetched ${reviews.length} reviews");
      
      // Make sure widget is still mounted before updating state
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      print("Error fetching reviews: $e");
      if (mounted) {
        setState(() {
          _reviews = []; 
          _isLoadingReviews = false;
        });
        
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load reviews: ${e.toString().split('\n').first}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detail Lapangan')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.lapangan.gambar != null && widget.lapangan.gambar!.isNotEmpty
                ? FutureBuilder<Map<String, String>>(
                  future: ApiConfig.getAuthHeaders(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        width: double.infinity,
                        height: 250,
                        color: Colors.grey.shade200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    return Image.network(
                      ApiConfig.getImageUrl(widget.lapangan.gambar),
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                      headers: snapshot.data,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/logo.png',
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                        );
                      },
                    );
                  },
                )
                : Image.asset(
                  'assets/logo.png',
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lapangan.nama,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange, size: 20),
                      SizedBox(width: 4),
                      Text(
                        widget.lapangan.rating != null 
                          ? widget.lapangan.rating!.toStringAsFixed(1) 
                          : '0.0',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '(${widget.lapangan.reviews ?? 0} reviews)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Rp ${widget.lapangan.hargaSewa.toStringAsFixed(0)}/jam',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Lokasi:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    widget.lapangan.alamat,
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  if (_isLoadingLocation)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_distance != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Jarak: ${_distance! < 1000 ? '${_distance!.toStringAsFixed(0)} meter' : '${(_distance! / 1000).toStringAsFixed(2)} km'}",
                        style: TextStyle(fontSize: 14, color: Colors.blue),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ElevatedButton.icon(
                      onPressed:
                          widget.lapangan.latitude != null
                              ? _openInGoogleMaps
                              : null,
                      icon: Icon(Icons.directions),
                      label: Text("Buka di Google Maps"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // BAGIAN BOOKING BARU - menggantikan bagian "Tanggal dan Jam" lama
                  _buildBookingSection(),
                  
                  SizedBox(height: 16),
                  Text(
                    "Deskripsi:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.lapangan.deskripsi,
                    style: TextStyle(fontSize: 16),
                  ),
                  
                  // Single Reviews Section - formatted like in the image
                  SizedBox(height: 24),
                  Text(
                    'Reviews',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  
                  // Replace the overall rating row with just a message if needed
                  _isLoadingReviews
                    ? Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _reviews.isEmpty
                      ? Text(
                          'Belum ada ulasan',
                          style: TextStyle(color: Colors.grey),
                        )
                      : SizedBox(), // Empty SizedBox instead of showing rating again
                      
                  // Individual reviews list
                  SizedBox(height: 16),
                  _reviews.isEmpty 
                    ? SizedBox() // Don't show duplicate "no reviews" message
                    : Column(
                        children: _reviews
                          .map((review) => _buildReviewItem(
                            review.username,
                            review.rating,
                            review.comment,
                            review.formattedDate ?? '', // Add the date here
                          ))
                          .toList(),
                      ),
                      
                  // Tombol booking lama dihapus
                  SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for review items
  Widget _buildReviewItem(String name, double rating, String comment, [String? date]) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Username on left side with fallback
              Text(
                name.isNotEmpty ? name : "Anonymous",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              // Date on right side
              if (date != null && date.isNotEmpty)
                Text(
                  date,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
            ],
          ),
          SizedBox(height: 4),
          // Star rating with number
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 16),
              SizedBox(width: 4),
              Text(
                rating.isNaN ? "0.0" : rating.toStringAsFixed(1),
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: 8),
          // Comment
          Text(
            comment.isNotEmpty ? comment : "No comment provided",
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Pindahkan _buildBookingSection ke dalam kelas
  Widget _buildBookingSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Booking",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            // Tanggal
            Text(
              "Pilih Tanggal:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedDate == null
                          ? "Pilih Tanggal"
                          : "${DateFormat('dd MMMM yyyy').format(selectedDate!)}",
                      style: TextStyle(fontSize: 16),
                    ),
                    Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Jadwal
            Text(
              "Pilih Jam:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            _isLoadingSlots
                ? Center(child: CircularProgressIndicator())
                : _scheduleError != null
                    ? Center(
                        child: Text(
                          _scheduleError!,
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _buildTimeSlotGrid(),
            
            SizedBox(height: 16),
            
            // Jadwal terpilih dan total harga
            _buildSelectedTimeAndTotalPrice(),
            
            SizedBox(height: 16),
            
            // Tombol booking
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedTimeSlots.isEmpty || selectedDate == null)
                    ? null
                    : _createBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0A192F),
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  "Book Sekarang",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tambahkan metode untuk menampilkan grid waktu yang terlewat
  Widget _buildTimeSlotGrid() {
    // Implementasi sesuai kebutuhan, misalnya:
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.5,
      ),
      itemCount: _timeSlots.length,
      itemBuilder: (context, index) {
        final slot = _timeSlots[index];
        final bool isPast = slot['isPast'] ?? false;
        final bool isAvailable = slot['isAvailable'] ?? true;
        
        // Check if this slot is selected
        final bool isSelected = _selectedTimeSlots.any(
          (selectedSlot) => selectedSlot['waktu'] == slot['waktu']
        );

        return InkWell(
          onTap: isAvailable && !isPast 
            ? () {
                setState(() {
                  if (isSelected) {
                    // Remove if already selected
                    _selectedTimeSlots.removeWhere(
                      (selectedSlot) => selectedSlot['waktu'] == slot['waktu']
                    );
                  } else {
                    // Add if not selected
                    _selectedTimeSlots.add(slot);
                  }
                });
              }
            : null,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected 
                ? Colors.blue.withOpacity(0.2)
                : isAvailable && !isPast 
                  ? Colors.white
                  : Colors.grey.withOpacity(0.1),
              border: Border.all(
                color: isSelected 
                  ? Colors.blue 
                  : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    slot['waktu'],
                    style: TextStyle(
                      color: !isAvailable 
                        ? Colors.red
                        : isPast 
                          ? Colors.grey
                          : isSelected
                            ? Colors.blue
                            : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    isAvailable 
                      ? "Rp.${slot['harga']}"
                      : "Booked",
                    style: TextStyle(
                      fontSize: 12,
                      color: !isAvailable 
                        ? Colors.red
                        : isPast 
                          ? Colors.grey
                          : isSelected
                            ? Colors.blue
                            : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Tambahkan method untuk menampilkan jadwal dan harga
  Widget _buildSelectedTimeAndTotalPrice() {
    // Jika tidak ada waktu yang dipilih
    if (_selectedTimeSlots.isEmpty) {
      return Text(
        "Jadwal: Pilih Jam",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      );
    }
    
    // Hitung total harga
    double totalPrice = 0;
    for (var slot in _selectedTimeSlots) {
      if (slot.containsKey('harga')) {
        var hargaValue = slot['harga'];
        double harga = hargaValue is int ? hargaValue.toDouble() : 
                       hargaValue is double ? hargaValue : 0.0;
        totalPrice += harga;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Jadwal: ${_formattedSelectedTimes}",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Text(
          "Total: Rp ${totalPrice.toStringAsFixed(0)}",
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold, 
            color: Colors.green[700]
          ),
        ),
      ],
    );
  }
}
