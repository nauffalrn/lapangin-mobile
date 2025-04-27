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

  Booking({
    this.id,
    required this.lapanganId,
    required this.tanggal,
    required this.jadwalList,
    this.kodePromo,
    this.statusPembayaran,
    this.buktiPembayaran,
    this.totalHarga,
  });

  // Tambahkan getter untuk mendapatkan waktu yang diformat dari jadwalList
  String get waktu {
    if (jadwalList.isEmpty) return "Tidak ada jadwal";

    // Urutkan jadwal berdasarkan jam
    List<JadwalItem> sortedJadwal = List.from(jadwalList)
      ..sort((a, b) => a.jam.compareTo(b.jam));

    // Format jam ke string seperti "14:00"
    List<String> times = sortedJadwal.map((item) => "${item.jam}:00").toList();

    // Gabungkan dengan koma
    return times.join(", ");
  }

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
