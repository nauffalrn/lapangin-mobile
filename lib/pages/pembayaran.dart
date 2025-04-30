import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/booking_model.dart';
import '../services/booking_services.dart';
import '../services/lapangan_services.dart';
import 'detail.dart';

class PembayaranPage extends StatefulWidget {
  final Booking booking;

  const PembayaranPage({Key? key, required this.booking}) : super(key: key);

  @override
  _PembayaranPageState createState() => _PembayaranPageState();
}

class _PembayaranPageState extends State<PembayaranPage> {
  final String nomorEwallet = "081293768288";
  File? _paymentProof;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _paymentProof = File(image.path);
      });
    }
  }

  Future<void> _uploadPaymentProof() async {
    if (_paymentProof == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Silakan pilih bukti pembayaran')));
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      await BookingService.uploadPayment(widget.booking.id!, _paymentProof!);

      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bukti pembayaran berhasil diunggah')),
      );

      // Kembali ke halaman riwayat
      Navigator.pushReplacementNamed(context, '/history');
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunggah bukti pembayaran: $e')),
      );
    }
  }

  Future<void> _cancelBooking({bool navigateBack = false}) async {
    // Jika dipanggil dari tombol Batal (bukan navigasi back), tampilkan konfirmasi
    if (!navigateBack) {
      // Tampilkan dialog konfirmasi seperti sebelumnya
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Batalkan Booking"),
            content: Text("Apakah Anda yakin ingin membatalkan booking ini?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text("Tidak"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text("Ya, Batalkan", style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      );

      if (confirm != true) return;
    }

    // Simpan lapanganId dari booking saat ini untuk navigasi nanti
    int? lapanganId = widget.booking.lapanganId;

    // Tampilkan loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Panggil API untuk membatalkan booking
      await BookingService.cancelBooking(widget.booking.id!);
      
      // Tutup loading dialog
      Navigator.of(context).pop();
      
      // Tampilkan notifikasi sukses
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking berhasil dibatalkan'))
      );
      
      // Arahkan kembali ke halaman detail lapangan jika lapanganId tersedia
      if (lapanganId != null) {
        // Ambil data lapangan terlebih dahulu
        try {
          final lapangan = await LapanganService.getLapanganById(lapanganId);
          
          // Navigasi ke halaman detail lapangan
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DetailPage(lapangan: lapangan),
            ),
          );
        } catch (e) {
          // Jika gagal mengambil data lapangan, kembali ke home
          print("Error fetching lapangan data: $e");
          Navigator.pushReplacementNamed(context, '/');
        }
      } else {
        // Jika tidak ada lapanganId, kembali ke halaman utama
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      // Tutup loading dialog
      Navigator.of(context).pop();
      
      // Tampilkan error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membatalkan booking: $e'))
      );
    }
  }

  Future<bool> _onWillPop() async {
    // Tampilkan dialog konfirmasi
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Batalkan Booking"),
          content: Text("Apakah anda ingin membatalkan booking dan kembali ke halaman sebelumnya?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Tidak"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("Ya, Batalkan", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Panggil fungsi untuk membatalkan booking dan mengembalikan true agar WillPopScope mengizinkan navigasi kembali
      await _cancelBooking(navigateBack: true);
      return true;
    }
    // Jika user tidak mengkonfirmasi, jangan izinkan navigasi kembali
    return false;
  }

  Future<void> _onBackPressed(BuildContext context) async {
    // Tampilkan dialog konfirmasi
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Batalkan Booking"),
          content: Text("Apakah anda ingin membatalkan booking dan kembali ke halaman sebelumnya?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Tidak"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text("Ya, Batalkan", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // Panggil fungsi untuk membatalkan booking
      await _cancelBooking(navigateBack: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Metode Pembayaran", style: TextStyle(color: Colors.white)),
          centerTitle: true,
          backgroundColor: Color(0xFF0A192F),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _onBackPressed(context),
          ),
        ),
        body: SingleChildScrollView( // Tambahkan SingleChildScrollView untuk mengatasi overflow
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tampilan detail booking yang dirapikan
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Detail Booking",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildDetailRow("ID Booking:", "#${widget.booking.id}"),
                      
                      // Tambahkan informasi nama lapangan
                      _buildDetailRow("Nama Lapangan:", "${widget.booking.namaLapangan ?? 'Tidak tersedia'}"),
                      
                      // Tambahkan informasi lokasi/alamat lapangan
                      _buildDetailRow("Lokasi:", "${widget.booking.lokasi ?? 'Tidak tersedia'}"),
                      
                      _buildDetailRow("Tanggal:", "${widget.booking.tanggal ?? 'Tidak tersedia'}"),
                      _buildDetailRow("Waktu:", _formatTimeSlots(widget.booking.waktu)),
                      
                      if (widget.booking.waktu != null)
                        _buildDetailRow("Jumlah Jam:", "${widget.booking.waktu!.split(',').length}"),
                      
                      // Tambahkan total harga jika tersedia
                      if (widget.booking.totalPrice != null)
                        _buildDetailRow("Total Harga:", "Rp ${widget.booking.totalPrice!.toStringAsFixed(0)}"),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 24),
              Text(
                "Pilih metode pembayaran:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              
              // Opsi pembayaran
              _buildPaymentOption(context, "QRIS", Icons.qr_code, 
                  () => _showQRISDialog(context)),
              _buildPaymentOption(context, "OVO", Icons.phone_android, 
                  () => _showEwalletDialog(context, "OVO")),
              _buildPaymentOption(context, "Dana", Icons.account_balance_wallet, 
                  () => _showEwalletDialog(context, "Dana")),
              _buildPaymentOption(context, "GoPay", Icons.payment, 
                  () => _showEwalletDialog(context, "GoPay")),
    
              SizedBox(height: 24),
              Text(
                "Unggah bukti pembayaran:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              
              // Bagian upload bukti pembayaran yang diperbaiki
              Container(
                width: double.infinity,
                child: Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Gambar bukti pembayaran dengan ukuran yang dibatasi
                      Container(
                        height: 240,
                        width: 260,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _paymentProof != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _paymentProof!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Belum ada gambar",
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                      ),
                      
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: Icon(Icons.photo_camera),
                        label: Text("Pilih Gambar"),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Tombol Cancel Booking
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ElevatedButton.icon(
                                onPressed: _cancelBooking,
                                icon: Icon(Icons.cancel, color: Colors.white),
                                label: Text("Batal", style: TextStyle(fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: Colors.red,
                                  minimumSize: Size(100, 50),
                                ),
                              ),
                            ),
                          ),
                          
                          // Tombol Kirim Bukti Pembayaran
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: ElevatedButton(
                                onPressed: _isUploading ? null : _uploadPaymentProof,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: Colors.blueAccent,
                                  minimumSize: Size(200, 50),
                                ),
                                child: _isUploading
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text("Kirim Bukti Pembayaran", style: TextStyle(fontSize: 16)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24), // Extra space at the bottom
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(
    BuildContext context,
    String method,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32, color: Colors.blueAccent),
        title: Text(
          method,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        onTap: onTap,
      ),
    );
  }

  void _showQRISDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("QRIS Payment"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Menggunakan Image.asset dengan nama file yang benar: qr-code.png
              Image.asset(
                "assets/qr-code.png", 
                width: 250, 
                height: 250,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 10),
              Text("Scan QR untuk membayar"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Tutup"),
            ),
          ],
        );
      },
    );
  }

  void _showEwalletDialog(BuildContext context, String method) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Pembayaran via $method"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Silakan transfer ke nomor berikut:"),
              SizedBox(height: 10),
              SelectableText(
                nomorEwallet,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: nomorEwallet));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Nomor $method disalin ke clipboard"),
                    ),
                  );
                },
                child: Text("Salin Nomor"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Tutup"),
            ),
          ],
        );
      },
    );
  }

  // Tambahkan method ini untuk menampilkan detail booking secara terstruktur
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
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tambahkan helper method untuk format waktu yang benar

  // Di class _PembayaranPageState, tambahkan helper method ini
  String _formatTimeSlots(String? timeString) {
    if (timeString == null || timeString.isEmpty) {
      return 'Tidak tersedia';
    }
    
    // Jika formatnya sudah benar (misal: "09:00-10:00, 11:00-12:00")
    if (timeString.contains("-")) {
      return timeString;
    }
    
    // Jika formatnya hanya waktu awal (misal: "09:00, 11:00")
    List<String> slots = timeString.split(", ");
    List<String> formattedSlots = slots.map((slot) {
      if (slot.contains("-")) return slot; // Sudah ada format awal-akhir
      
      String hourStr = slot.split(":")[0];
      int hour = int.parse(hourStr);
      int nextHour = hour + 1;
      return "$hourStr:00-$nextHour:00";
    }).toList();
    
    return formattedSlots.join(", ");
  }
}
