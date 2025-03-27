import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PembayaranPage extends StatelessWidget {
  final String nomorEwallet = "081293768288";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
            appBar: AppBar(
        title: Text(
          "Metode Pembayaran",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF0A192F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Pilih metode pembayaran:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            _buildPaymentOption(context, "QRIS", Icons.qr_code, () => _showQRISDialog(context)),
            _buildPaymentOption(context, "OVO", Icons.phone_android, () => _showEwalletDialog(context, "OVO")),
            _buildPaymentOption(context, "Dana", Icons.account_balance_wallet, () => _showEwalletDialog(context, "Dana")),
            _buildPaymentOption(context, "GoPay", Icons.payment, () => _showEwalletDialog(context, "GoPay")),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(BuildContext context, String method, IconData icon, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32, color: Colors.blueAccent),
        title: Text(method, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
              SelectableText(nomorEwallet, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: nomorEwallet));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Nomor $method disalin ke clipboard")),
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
