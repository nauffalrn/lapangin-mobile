class Lapangan {
  final int id;
  final String nama;
  final String? city;
  final String? image;
  final double? price;
  final double? rating;
  final int? reviews;
  final String? cabangOlahraga;
  final String? alamat;
  final String? facilities;
  final String? jamBuka;
  final String? jamTutup;
  final double? latitude;
  final double? longitude;

  Lapangan({
    required this.id,
    required this.nama,
    this.city,
    this.image,
    this.price,
    this.rating,
    this.reviews,
    this.cabangOlahraga,
    this.alamat,
    this.facilities,
    this.jamBuka,
    this.jamTutup,
    this.latitude,
    this.longitude,
  });

  // Tambahkan getter untuk kompatibilitas dengan kode yang ada
  String? get gambar => image;
  double? get hargaSewa => price;

  factory Lapangan.fromJson(Map<String, dynamic> json) {
    return Lapangan(
      id: json['id'] ?? 0,
      nama: json['nama_lapangan'] ?? json['namaLapangan'] ?? '',
      city: json['city'],
      image: json['image'] ?? json['gambar'],
      price: json['price']?.toDouble() ?? json['hargaSewa']?.toDouble(),
      rating: json['rating']?.toDouble(),
      reviews: json['reviews'],
      cabangOlahraga: json['cabang_olahraga'] ?? json['cabangOlahraga'],
      alamat: json['alamat_lapangan'] ?? json['alamatLapangan'],
      facilities: json['facilities'],
      jamBuka: json['jam_buka'] ?? json['jamBuka'],
      jamTutup: json['jam_tutup'] ?? json['jamTutup'],
      // Perbaikan parsing koordinat
      latitude: _parseCoordinate(json['latitude']),
      longitude: _parseCoordinate(json['longitude']),
    );
  }

  // Helper method untuk parsing koordinat
  static double? _parseCoordinate(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        print("Error parsing coordinate: $value - $e");
        return null;
      }
    }

    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama_lapangan': nama,
      'city': city,
      'image': image,
      'price': price,
      'rating': rating,
      'reviews': reviews,
      'cabang_olahraga': cabangOlahraga,
      'alamat_lapangan': alamat,
      'facilities': facilities,
      'jam_buka': jamBuka,
      'jam_tutup': jamTutup,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
