class JadwalItem {
  final int jam;
  final double harga;

  JadwalItem({required this.jam, required this.harga});

  Map<String, dynamic> toJson() {
    return {'jam': jam, 'harga': harga};
  }

  factory JadwalItem.fromJson(Map<String, dynamic> json) {
    return JadwalItem(
      jam: json['jam'] ?? 0,
      harga:
          json['harga'] != null
              ? double.tryParse(json['harga'].toString()) ?? 0.0
              : 0.0,
    );
  }
}

class Booking {
  final int? id;
  final int lapanganId;
  final String tanggal;
  final List<JadwalItem> jadwalList;
  final String? kodePromo;
  final String? statusPembayaran;
  final String? buktiPembayaran;
  final double? totalHarga;
  String? waktu; // Changed from final to mutable

  Booking({
    this.id,
    required this.lapanganId,
    required this.tanggal,
    required this.jadwalList,
    this.kodePromo,
    this.statusPembayaran,
    this.buktiPembayaran,
    this.totalHarga,
    this.waktu,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    try {
      // Handle jadwalList yang mungkin null
      List<dynamic> jadwalData = json['jadwalList'] ?? [];
      List<JadwalItem> jadwal =
          jadwalData.map((item) => JadwalItem.fromJson(item)).toList();

      return Booking(
        id: json['id'],
        lapanganId: json['lapanganId'] ?? 0,
        tanggal: json['tanggal'] ?? '',
        jadwalList: jadwal,
        kodePromo: json['kodePromo'],
        statusPembayaran: json['statusPembayaran'],
        buktiPembayaran: json['buktiPembayaran'],
        totalHarga:
            json['totalHarga'] != null
                ? double.tryParse(json['totalHarga'].toString())
                : null,
        waktu: json['waktu'], // Make sure this is included
      );
    } catch (e) {
      print("Error parsing Booking: $e");
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'lapanganId': lapanganId,
      'tanggal': tanggal,
      'jadwalList': jadwalList.map((item) => item.toJson()).toList(),
      'kodePromo': kodePromo,
    };
  }
}
