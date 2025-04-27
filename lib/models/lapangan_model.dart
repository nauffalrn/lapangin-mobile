class Lapangan {
  final int id;
  final String nama;
  final String jenis;
  final String alamat;
  final String deskripsi;
  final double hargaSewa;
  final String? gambar;
  final double? rating;
  final int? reviews; // Tambahkan field reviews
  final double? latitude;
  final double? longitude;

  Lapangan({
    required this.id,
    required this.nama,
    required this.jenis,
    required this.alamat,
    required this.deskripsi,
    required this.hargaSewa,
    this.gambar,
    this.rating,
    this.reviews,
    this.latitude,
    this.longitude,
  });

  factory Lapangan.fromJson(Map<String, dynamic> json) {
    return Lapangan(
      id: json['id'] is String ? int.parse(json['id']) : (json['id'] ?? 0),
      nama: json['namaLapangan'] ?? '',
      jenis: json['cabangOlahraga'] ?? '',
      alamat: json['alamatLapangan'] ?? json['city'] ?? '',
      deskripsi: json['facilities'] ?? '',
      hargaSewa:
          json['price'] != null
              ? (json['price'] is int
                  ? json['price'].toDouble()
                  : double.tryParse(json['price'].toString()) ?? 0.0)
              : 0.0,
      gambar: json['image'],
      rating:
          json['rating'] != null
              ? double.tryParse(json['rating'].toString())
              : 0.0,
      reviews:
          json['reviews'] is int
              ? json['reviews']
              : (json['reviews'] != null
                  ? int.tryParse(json['reviews'].toString())
                  : 0),
      latitude:
          json['latitude'] != null
              ? double.tryParse(json['latitude'].toString())
              : null,
      longitude:
          json['longitude'] != null
              ? double.tryParse(json['longitude'].toString())
              : null,
    );
  }
}
