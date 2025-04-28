import 'package:flutter/material.dart';
import 'package:mobile/services/auth_service.dart';
import '../widgets/bottom_navbar.dart';
import '../models/booking_model.dart';
import '../services/booking_services.dart';
import 'dart:math';

class HistoryBookingPage extends StatefulWidget {
  @override
  _HistoryBookingPageState createState() => _HistoryBookingPageState();
}

class _HistoryBookingPageState extends State<HistoryBookingPage> {
  List<Booking> _bookings = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchBookingHistory();
  }

  Future<void> _fetchBookingHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Periksa token dulu sebelum request
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _isLoading = false;
        });

        // Navigasi ke login dengan pesan
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed('/login');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Silakan login terlebih dahulu')),
          );
        });
        return;
      }

      final bookings = await BookingService.getBookingHistory();
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Handle authentication errors specially
      if (e.toString().contains('login') ||
          e.toString().contains('Sesi') ||
          e.toString().contains('Unauthorized')) {
        // Navigasi ke login screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed('/login');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${e.toString().split(':').last.trim()}')),
          );
        });
      } else {
        // General error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat riwayat booking: ${e.toString().split(':').last.trim()}',
            ),
          ),
        );
      }
    }
  }

  void _showReviewDialog(BuildContext context, int bookingId) {
    int selectedRating = 5; // Default rating
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text('Berikan Review'),
                  content: Container(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Rating stars - perbaiki overflow dengan Wrap
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  selectedRating = index + 1;
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4.0,
                                ), // Sedikit lebih besar padding
                                child: Icon(
                                  index < selectedRating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 28, // Ukuran lebih besar
                                ),
                              ),
                            );
                          }),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: reviewController,
                          decoration: InputDecoration(
                            hintText: 'Tulis komentar Anda...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          // Aktifkan kode untuk mengirim review
                          await BookingService.submitReview(
                            bookingId,
                            selectedRating,
                            reviewController.text,
                          );

                          Navigator.pop(context); // Close dialog

                          // Refresh history
                          _fetchBookingHistory();

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Review berhasil dikirim!')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal mengirim review: $e'),
                            ),
                          );
                        }
                      },
                      child: Text('Kirim'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: const Color(0xFF0A192F),
          title: const Text(
            'History Booking',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
        ),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _bookings.isEmpty
              ? Center(
                child: Text(
                  'Belum ada riwayat pemesanan',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _bookings.length,
                itemBuilder: (context, index) {
                  final booking = _bookings[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header dengan tanggal saja (tanpa nomor)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF0A192F),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.end, // Rata kanan
                            children: [
                              Text(
                                booking.tanggal ?? 'Tanggal tidak tersedia',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
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
                              // Nama Lapangan
                              Text(
                                booking.namaLapangan ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),

                              // Lokasi - Tampilkan alamat dari lapangan
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      // Cek alamatLapangan yang sebenarnya ada di JSON
                                      booking.lapanganData != null &&
                                              booking.lapanganData!['alamatLapangan'] !=
                                                  null
                                          ? booking
                                              .lapanganData!['alamatLapangan']
                                              .toString()
                                          : booking.lapanganData != null &&
                                              booking.lapanganData!['alamat'] !=
                                                  null
                                          ? booking.lapanganData!['alamat']
                                              .toString()
                                          : booking.lokasi != null &&
                                              booking.lokasi!.isNotEmpty
                                          ? booking.lokasi!
                                          : "Lokasi tidak tersedia",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),

                              // Waktu
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    booking.waktu ?? 'N/A',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),

                              // Rating & Review - tidak berubah
                              if (booking.rating != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 16, // Ukuran lebih kecil
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '${booking.rating}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (booking.review != null &&
                                        booking.review!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          booking.review!,
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    if (booking.reviewerName != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4.0,
                                        ),
                                        child: Text(
                                          'Oleh: ${booking.reviewerName}${booking.reviewDate != null ? " pada ${booking.reviewDate?.replaceAll("T", " ")}" : ""}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              else
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed:
                                        () => _showReviewDialog(
                                          context,
                                          booking.id!,
                                        ),
                                    child: Text('Berikan Review'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }
}
