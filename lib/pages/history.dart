import 'package:flutter/material.dart';
import '../widgets/bottom_navbar.dart';

class HistoryBookingPage extends StatefulWidget {
  @override
  _HistoryBookingPageState createState() => _HistoryBookingPageState();
}

class _HistoryBookingPageState extends State<HistoryBookingPage> {
  List<bool> _expandedList = List.generate(5, (index) => false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: const Color(0xFF0A192F),
          leading: Padding(
            padding: const EdgeInsets.only(left: 8.0), // Jarak dari tepi kiri
            child: Image.asset(
              'assets/logo.png', // Path ke file logo
              width: 40, // Ukuran logo
              height: 40,
            ),
          ),
          title: const Text(
            'History Booking',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true, // Pastikan teks berada di tengah
        ),
      ),
      body: Padding(
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
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.all(16.0),
                          leading: const Icon(
                            Icons.sports_soccer,
                            color: Color(0xFF0A192F),
                          ),
                          title: Text(
                            'Lapangan Futsal #${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'Tanggal: 2025-03-26 | Waktu: 18:00 - 19:00',
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
                                _expandedList[index] = !_expandedList[index];
                              });
                            },
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: _expandedList[index] ? null : 0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Lokasi: Lapangan ABC, Kota XYZ',
                                  style: TextStyle(color: Colors.black87),
                                ),
                                Text(
                                  'Harga: Rp 150.000',
                                  style: TextStyle(color: Colors.black87),
                                ),
                                Text(
                                  'Status: Berhasil',
                                  style: TextStyle(color: Colors.green),
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
