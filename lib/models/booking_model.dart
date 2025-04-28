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
  final int? lapanganId;
  final String? namaLapangan;
  final String? lokasi;
  final String? tanggal;
  String? waktu;
  final int? rating;
  final String? review;
  final String? reviewerName;
  final String? reviewDate;
  final List<JadwalItem> jadwalList;
  final String? status;
  final double? totalPrice;
  final Map<String, dynamic>? lapanganData;

  Booking({
    this.id,
    this.lapanganId,
    this.namaLapangan,
    this.lokasi,
    this.tanggal,
    this.waktu,
    this.rating,
    this.review,
    this.reviewerName,
    this.reviewDate,
    this.jadwalList = const [],
    this.status,
    this.totalPrice,
    this.lapanganData,
  });

  Map<String, dynamic> toJson() {
    return {
      'lapanganId': lapanganId,
      'tanggal': tanggal,
      'jadwalList': jadwalList.map((item) => item.toJson()).toList(),
    };
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Handle jadwalList
    List<JadwalItem> jadwalItems = [];
    if (json['jadwalList'] != null && json['jadwalList'] is List) {
      jadwalItems =
          (json['jadwalList'] as List)
              .map((item) => JadwalItem.fromJson(item as Map<String, dynamic>))
              .toList();
    }

    // Simpan data lapangan lengkap (jika ada)
    Map<String, dynamic>? lapanganData;
    if (json['lapangan'] != null && json['lapangan'] is Map) {
      lapanganData = Map<String, dynamic>.from(json['lapangan'] as Map);
    }

    // Format tanggal
    String? tanggal;
    if (json['tanggal'] != null) {
      try {
        // Parse tanggal dari format YYYY-MM-DD ke DD Bulan YYYY
        String rawDate = json['tanggal'].toString();
        if (rawDate.contains("-")) {
          var dateParts = rawDate.split("-");
          if (dateParts.length == 3) {
            final months = [
              'Januari',
              'Februari',
              'Maret',
              'April',
              'Mei',
              'Juni',
              'Juli',
              'Agustus',
              'September',
              'Oktober',
              'November',
              'Desember',
            ];
            int year = int.parse(dateParts[0]);
            int month = int.parse(dateParts[1]);
            int day = int.parse(dateParts[2]);

            // Format: DD Bulan YYYY (tanpa strip)
            tanggal = "$day ${months[month - 1]} $year";
          } else {
            tanggal = rawDate;
          }
        } else {
          tanggal = rawDate;
        }
      } catch (e) {
        print("Error format tanggal: $e");
        tanggal = json['tanggal'].toString();
      }
    } else if (json['bookingDate'] != null) {
      try {
        String bookingDate = json['bookingDate'].toString();
        if (bookingDate.contains("T")) {
          var datePart = bookingDate.split("T")[0].split("-");
          if (datePart.length == 3) {
            final months = [
              'Januari',
              'Februari',
              'Maret',
              'April',
              'Mei',
              'Juni',
              'Juli',
              'Agustus',
              'September',
              'Oktober',
              'November',
              'Desember',
            ];
            int year = int.parse(datePart[0]);
            int month = int.parse(datePart[1]);
            int day = int.parse(datePart[2]);

            // Format: DD Bulan YYYY (tanpa strip)
            tanggal = "$day ${months[month - 1]} $year";
          } else {
            tanggal = bookingDate.split("T")[0];
          }
        } else {
          tanggal = bookingDate;
        }
      } catch (e) {
        print("Error parsing date: $e");
        tanggal = json['bookingDate'].toString();
      }
    }

    // Format waktu
    String? waktu;
    if (json['jamMulai'] != null && json['jamSelesai'] != null) {
      waktu = "${json['jamMulai']}:00 - ${json['jamSelesai']}:00";
    } else if (json['waktu'] != null) {
      waktu = json['waktu'].toString();
    }

    // Ekstrak data lapangan
    String? namaLapangan;
    String? lokasi;

    // Coba ambil dari objek lapangan dengan pengecekan yang lebih baik
    if (json['lapangan'] != null) {
      // Tangani kasus lapangan hanya berisi ID
      if (json['lapangan'] is int || json['lapangan'] is String) {
        // Lapangan hanya berupa ID, gunakan fallback dari property lain
      } else if (json['lapangan'] is Map) {
        // Lapangan berupa object Map
        Map<String, dynamic> lapangan =
            json['lapangan'] as Map<String, dynamic>;

        // Debug: Cetak seluruh data lapangan
        print("DEBUG DATA LAPANGAN: $lapangan");

        // Nama lapangan
        if (lapangan['namaLapangan'] != null) {
          namaLapangan = lapangan['namaLapangan'].toString();
        } else if (lapangan['nama'] != null) {
          namaLapangan = lapangan['nama'].toString();
        }

        // Lokasi/alamat - penting dari model backend
        if (lapangan['alamat'] != null) {
          lokasi = lapangan['alamat'].toString();
        } else if (lapangan['alamatLapangan'] != null) {
          // Tambahkan pengambilan dari alamatLapangan yang ternyata ada di JSON
          lokasi = lapangan['alamatLapangan'].toString();
        } else if (lapangan['lokasi'] != null) {
          lokasi = lapangan['lokasi'].toString();
        }
      }
    }

    // Fallback ke properti langsung jika tidak ada di objek lapangan
    if (namaLapangan == null) {
      namaLapangan =
          json['namaLapangan']?.toString() ??
          json['nama_lapangan']?.toString() ??
          'Lapangan tidak diketahui';
    }

    // Untuk lokasi, periksa lebih banyak kemungkinan nama field dari backend
    if (lokasi == null) {
      lokasi =
          json['lokasi']?.toString() ??
          json['alamat']?.toString() ??
          json['address']?.toString() ??
          (json['lapangan_alamat'] is String ? json['lapangan_alamat'] : null);
    }

    // Jika masih null, coba ekstrak dari booking_date untuk nama lapangan
    if (lokasi == null) {
      // Coba ambil alamat dari Lapangan
      if (json['lapangan'] != null && json['lapangan'] is Map) {
        var lapanganMap = json['lapangan'] as Map<String, dynamic>;
        lokasi = lapanganMap['alamat']?.toString();
      }

      // Jika masih null, gunakan namaLapangan
      if (lokasi == null || lokasi.isEmpty) {
        // Jangan gunakan nama lapangan sebagai fallback, biarkan null
        lokasi = null;
      }
    }

    // Handle review
    int? rating;
    String? review;
    String? reviewerName;
    String? reviewDate;

    if (json['review'] != null) {
      if (json['review'] is Map) {
        Map<String, dynamic> reviewMap = json['review'] as Map<String, dynamic>;

        // Rating
        if (reviewMap['rating'] != null) {
          if (reviewMap['rating'] is int) {
            rating = reviewMap['rating'] as int;
          } else {
            rating = int.tryParse(reviewMap['rating'].toString());
          }
        }

        // Review content
        if (reviewMap['komentar'] != null) {
          review = reviewMap['komentar'].toString();
        } else if (reviewMap['review'] != null) {
          review = reviewMap['review'].toString();
        } else if (reviewMap['comment'] != null) {
          review = reviewMap['comment'].toString();
        }

        // Reviewer name
        reviewerName = reviewMap['username']?.toString();

        // Review date - hilangkan pemisah T
        if (reviewMap['tanggalReview'] != null) {
          String rawDate = reviewMap['tanggalReview'].toString();
          // Koreksi untuk menggunakan replaceAll bukan replace
          if (rawDate.contains("T")) {
            reviewDate = rawDate.replaceAll("T", " ");
          } else {
            reviewDate = rawDate;
          }
        }
      } else {
        // Fallback jika review bukan Map
        review = json['review'].toString();
      }
    } else {
      // Data review langsung dari objek booking
      if (json['rating'] != null) {
        if (json['rating'] is int) {
          rating = json['rating'];
        } else {
          rating = int.tryParse(json['rating'].toString());
        }
      }

      review = json['komentar']?.toString() ?? json['review']?.toString();
      reviewerName =
          json['reviewerName']?.toString() ??
          json['username']?.toString() ??
          json['usernamePengreview']?.toString();
      reviewDate =
          json['reviewDate']?.toString() ?? json['tanggalReview']?.toString();
    }

    // Debugger untuk melihat nilai lokasi
    print("Booking ID: ${json['id']}");
    print("Nama Lapangan: $namaLapangan");
    print("Lokasi final: $lokasi");

    return Booking(
      id:
          json['id'] is int
              ? json['id']
              : json['id'] is String
              ? int.tryParse(json['id'].toString())
              : null,
      lapanganId: json['lapanganId'] ?? json['lapangan_id'],
      namaLapangan: namaLapangan,
      lokasi: lokasi,
      tanggal: tanggal,
      waktu: waktu,
      rating: rating,
      review: review,
      reviewerName: reviewerName,
      reviewDate: reviewDate,
      jadwalList: jadwalItems,
      status: json['status']?.toString(),
      totalPrice:
          json['totalPrice'] != null
              ? double.tryParse(json['totalPrice'].toString())
              : null,
      lapanganData: lapanganData, // Simpan data lapangan lengkap
    );
  }
}
