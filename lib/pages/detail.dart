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
  String? selectedTime;
  double? _distance;
  bool _isLoadingLocation = false;
  bool _isLoadingSlots = false;
  List<Map<String, dynamic>> _timeSlots =
      []; // Ubah untuk menyimpan data lengkap slot
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
        selectedTime = null; // Reset selected time when date changes
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

  void _selectTime(BuildContext context) {
    if (_timeSlots.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tidak ada slot waktu tersedia')));
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: 300,
          child: Column(
            children: [
              Text(
                "Pilih Jam",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _timeSlots.length,
                  itemBuilder: (context, index) {
                    final slot = _timeSlots[index];
                    final bool isPast = slot['isPast'] ?? false;
                    final bool isAvailable = slot['isAvailable'] ?? true;

                    // Determine the color based on status
                    Color? textColor;
                    if (!isAvailable) {
                      textColor = Colors.red; // Already booked
                    } else if (isPast) {
                      textColor = Colors.grey; // Past time
                    }

                    return ListTile(
                      title: Text(
                        slot['waktu'],
                        style: TextStyle(
                          color: textColor,
                          fontWeight:
                              isAvailable && !isPast
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        isAvailable
                            ? "Tersedia - Rp${slot['harga'].toString()}"
                            : "Sudah dipesan",
                        style: TextStyle(color: textColor),
                      ),
                      enabled: isAvailable && !isPast,
                      onTap:
                          isAvailable && !isPast
                              ? () {
                                setState(() {
                                  selectedTime = slot['waktu'];
                                });
                                Navigator.pop(context);
                              }
                              : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Fungsi untuk membuat booking
  Future<void> _createBooking() async {
    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silakan pilih tanggal dan waktu')),
      );
      return;
    }

    try {
      // Tampilkan loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Konversi waktu dari string ke integer jam
      int jamBooking = int.parse(selectedTime!.split(':')[0]);

      // Cari harga dari slot yang dipilih
      double harga = 0;
      for (var slot in _timeSlots) {
        if (slot['waktu'] == selectedTime && slot['isAvailable']) {
          var hargaValue = slot['harga'];
          harga =
              hargaValue is int
                  ? hargaValue.toDouble()
                  : (hargaValue is double ? hargaValue : 0);
          break;
        }
      }

      // Jika harga tidak ditemukan, gunakan dari model lapangan
      if (harga == 0) {
        harga = widget.lapangan.hargaSewa;
      }

      // Buat item jadwal
      List<JadwalItem> jadwalItems = [
        JadwalItem(jam: jamBooking, harga: harga),
      ];

      final booking = Booking(
        lapanganId: widget.lapangan.id,
        tanggal: DateFormat('yyyy-MM-dd').format(selectedDate!),
        jadwalList: jadwalItems,
        kodePromo: null,
      );

      // Langsung gunakan service tanpa pengecekan token lagi
      // Jika token tidak valid, exception akan dilempar dan ditangani di catch block
      final result = await BookingService.createBooking(booking);

      // Tutup loading dialog
      Navigator.pop(context);

      // Navigasi ke halaman pembayaran dengan data booking
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PembayaranPage(booking: result),
        ),
      );
    } catch (e) {
      // Tutup loading dialog
      Navigator.pop(context);

      // Cek apakah error autentikasi
      if (e.toString().contains('login')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sesi anda habis. Silakan login kembali')),
        );
        // Navigasi ke login
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat booking: $e')));
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
      final reviews = await ReviewService.getReviewsByLapanganId(
        widget.lapangan.id,
      );
      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    } catch (e) {
      print("Error fetching reviews: $e");
      setState(() {
        _isLoadingReviews = false;
      });
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
                        '4.8', // Rating dari backend
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
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
                  Text(
                    "Tanggal dan Jam :",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _selectDate(context),
                        child: Text(
                          selectedDate != null
                              ? DateFormat('dd MMM yyyy').format(selectedDate!)
                              : "Pilih Tanggal",
                        ),
                      ),
                      SizedBox(width: 10),
                      _isLoadingSlots
                          ? CircularProgressIndicator(strokeWidth: 2)
                          : ElevatedButton(
                            onPressed:
                                selectedDate == null
                                    ? null
                                    : () => _selectTime(context),
                            child: Text(selectedTime ?? "Pilih Jam"),
                          ),
                    ],
                  ),
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
                  SizedBox(height: 15),
                  Text(
                    'Reviews',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  widget.lapangan.rating != null
                      ? Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          SizedBox(width: 5),
                          Text(
                            '${widget.lapangan.rating!.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            ' (${widget.lapangan.reviews ?? 0} reviews)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      )
                      : Text(
                        'Belum ada review',
                        style: TextStyle(color: Colors.grey),
                      ),
                  SizedBox(height: 10),
                  _isLoadingReviews
                      ? Center(child: CircularProgressIndicator())
                      : _reviews.isEmpty
                      ? Center(
                        child: Text(
                          "Belum ada ulasan",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : Column(
                        children:
                            _reviews
                                .map(
                                  (review) => _buildReviewItem(
                                    review.username,
                                    review.rating,
                                    review.comment,
                                  ),
                                )
                                .toList(),
                      ),
                  SizedBox(height: 20),
                  SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      onPressed:
                          selectedDate != null && selectedTime != null
                              ? _createBooking
                              : null,
                      child: Text(
                        "Pesan Sekarang",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  // Add Reviews Section
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Reviews",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "${widget.lapangan.rating?.toStringAsFixed(1) ?? '0.0'} (${widget.lapangan.reviews ?? 0} ulasan)",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                      ],
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

  // Helper method for review items
  Widget _buildReviewItem(String name, double rating, String comment) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Icon(Icons.star, color: Colors.orange, size: 14),
                  SizedBox(width: 2),
                  Text("$rating"),
                ],
              ),
            ],
          ),
          SizedBox(height: 5),
          Text(comment),
        ],
      ),
    );
  }
}
