class Promo {
  final int id;
  final String kodePromo;
  final double diskonPersen;
  final DateTime tanggalMulai;
  final DateTime tanggalSelesai;
  final bool isClaimedByUser;

  Promo({
    required this.id,
    required this.kodePromo,
    required this.diskonPersen,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    this.isClaimedByUser = false,
  });

  // Memeriksa apakah promo masih valid
  bool get isValid {
    final now = DateTime.now();
    return now.isAfter(tanggalMulai) && 
           now.isBefore(tanggalSelesai);
  }

  factory Promo.fromJson(Map<String, dynamic> json) {
    return Promo(
      id: json['id'],
      kodePromo: json['kodePromo'],
      diskonPersen: json['diskonPersen'] is int 
          ? (json['diskonPersen'] as int).toDouble() 
          : json['diskonPersen'],
      tanggalMulai: DateTime.parse(json['tanggalMulai']),
      tanggalSelesai: DateTime.parse(json['tanggalSelesai']),
      isClaimedByUser: json['isClaimedByUser'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kodePromo': kodePromo,
      'diskonPersen': diskonPersen,
      'tanggalMulai': tanggalMulai.toIso8601String(),
      'tanggalSelesai': tanggalSelesai.toIso8601String(),
      'isClaimedByUser': isClaimedByUser,
    };
  }
}