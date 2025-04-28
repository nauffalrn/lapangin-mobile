import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../models/booking_model.dart';
import '../services/booking_services.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Metode Pembayaran", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Color(0xFF0A192F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tampilkan detail booking
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Detail Booking",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text("ID Booking: #${widget.booking.id}"),
                    Text("Tanggal: ${widget.booking.tanggal}"),
                    
                    // Display the time slots
                    Text("Waktu: ${widget.booking.waktu}"),
                    
                    // Display the number of hours
                    if (widget.booking.waktu != null) 
                      Text("Jumlah Jam: ${widget.booking.waktu!.split(',').length}"),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              "Pilih metode pembayaran:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildPaymentOption(
              context,
              "QRIS",
              Icons.qr_code,
              () => _showQRISDialog(context),
            ),
            _buildPaymentOption(
              context,
              "OVO",
              Icons.phone_android,
              () => _showEwalletDialog(context, "OVO"),
            ),
            _buildPaymentOption(
              context,
              "Dana",
              Icons.account_balance_wallet,
              () => _showEwalletDialog(context, "Dana"),
            ),
            _buildPaymentOption(
              context,
              "GoPay",
              Icons.payment,
              () => _showEwalletDialog(context, "GoPay"),
            ),

            SizedBox(height: 20),
            Text(
              "Unggah bukti pembayaran:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Center(
              child:
                  _paymentProof != null
                      ? Container(
                        height: 200,
                        width: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Image.file(_paymentProof!, fit: BoxFit.cover),
                      )
                      : Container(
                        height: 200,
                        width: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      ),
            ),
            SizedBox(height: 10),
            Center(
              child: ElevatedButton(
                onPressed: _pickImage,
                child: Text("Pilih Gambar"),
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadPaymentProof,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  backgroundColor: Colors.blueAccent,
                ),
                child:
                    _isUploading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text("Kirim Bukti Pembayaran"),
              ),
            ),
          ],
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
              Image.asset("assets/qris_example.png", width: 200, height: 200),
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
}
