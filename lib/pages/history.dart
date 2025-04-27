import 'package:flutter/material.dart';
import '../widgets/bottom_navbar.dart';
import '../models/booking_model.dart';
import '../services/booking_services.dart';
import '../config/api_config.dart';
import 'pembayaran.dart';

class HistoryBookingPage extends StatefulWidget {
  @override
  _HistoryBookingPageState createState() => _HistoryBookingPageState();
}

class _HistoryBookingPageState extends State<HistoryBookingPage> {
  List<Booking> _bookings = [];
  List<bool> _expandedList = [];
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
      final bookings = await BookingService.getBookingHistory();
      setState(() {
        _bookings = bookings;
        _expandedList = List.generate(bookings.length, (index) => false);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil riwayat booking: $e')),
      );
    }
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
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Riwayat Pemesanan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _bookings.isEmpty
                        ? Expanded(
                          child: Center(
                            child: Text(
                              'Belum ada riwayat pemesanan',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                        : Expanded(
                          child: ListView.builder(
                            itemCount: _bookings.length,
                            itemBuilder: (context, index) {
                              final booking = _bookings[index];
                              return Card(
                                elevation: 3,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    ListTile(
                                      contentPadding: const EdgeInsets.all(
                                        16.0,
                                      ),
                                      leading: const Icon(
                                        Icons.sports_soccer,
                                        color: Color(0xFF0A192F),
                                      ),
                                      title: Text(
                                        'Booking #${booking.id}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Tanggal: ${booking.tanggal} | Waktu: ${booking.waktu}',
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(
                                          _expandedList[index]
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: Colors.grey,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _expandedList[index] =
                                                !_expandedList[index];
                                          });
                                        },
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      height: _expandedList[index] ? null : 0,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                          vertical: 8.0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Harga: Rp ${booking.totalHarga?.toStringAsFixed(0) ?? "0"}',
                                              style: TextStyle(
                                                color: Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              'Status: ${booking.statusPembayaran ?? "Menunggu Pembayaran"}',
                                              style: TextStyle(
                                                color:
                                                    booking.statusPembayaran ==
                                                            "Lunas"
                                                        ? Colors.green
                                                        : Colors.orange,
                                              ),
                                            ),
                                            if (booking.statusPembayaran !=
                                                "Lunas")
                                              ElevatedButton(
                                                onPressed: () {
                                                  // Navigasi ke halaman pembayaran dengan data booking
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder:
                                                          (context) =>
                                                              PembayaranPage(
                                                                booking:
                                                                    booking,
                                                              ),
                                                    ),
                                                  );
                                                },
                                                child: Text(
                                                  "Upload Bukti Pembayaran",
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                  ],
                ),
              ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 1),
    );
  }
}
