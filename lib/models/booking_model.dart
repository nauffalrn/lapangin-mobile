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

  // Tambahkan method ini ke class JadwalItem
  String get formattedTime {
    String startHour = jam.toString().padLeft(2, '0');
    String endHour = (jam + 1).toString().padLeft(2, '0');
    return "$startHour:00 - $endHour:00";
  }
}

class Booking {
  final int? id;
  final int? lapanganId;
  String? namaLapangan; // Ubah dari final menjadi mutable
  String? lokasi; // Ubah dari final menjadi mutable
  final String? tanggal;
  String? waktu;
  final int? rating;
  final String? review;
  final String? reviewerName;
  final String? reviewDate;
  final List<JadwalItem> jadwalList;
  final String? status;
  double? totalPrice;  // Buat mutable agar bisa diubah
  final Map<String, dynamic>? lapanganData;
  
  // Tambahan untuk promo
  String? kodePromo;
  double? diskonPersen;
  double? hargaAsli;
  double? hargaDiskon;  // Add this property
  
  // Add these missing fields
  int? jamMulai;
  int? jamSelesai;

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
    this.kodePromo,
    this.diskonPersen,
    this.hargaAsli,
    this.hargaDiskon,  // Add this to the constructor parameters
    this.jamMulai,
    this.jamSelesai,
  });

  // Update the applyPromo method to also set hargaDiskon
  void applyPromo(String kodePromo, double diskonPersen) {
    this.kodePromo = kodePromo;
    this.diskonPersen = diskonPersen;
    
    if (totalPrice != null) {
      // Simpan harga asli jika belum ada
      if (this.hargaAsli == null) {
        this.hargaAsli = totalPrice;
      }
      
      // PERBAIKAN: Selalu hitung diskon berdasarkan harga asli
      final double discount = (this.hargaAsli! * diskonPersen) / 100;
      this.totalPrice = this.hargaAsli! - discount;
      
      // Set hargaDiskon to the new discounted price
      this.hargaDiskon = this.totalPrice;
    }
  }

  // Update resetPromo to also reset hargaDiskon
  void resetPromo() {
    if (this.hargaAsli != null) {
      // Kembalikan total harga ke harga asli
      this.totalPrice = this.hargaAsli;
    }
    
    // Reset kode promo dan persentase diskon
    this.kodePromo = null;
    this.diskonPersen = null;
    this.hargaDiskon = null;  // Also reset hargaDiskon
  }

  // Tambahkan method untuk menghitung total harga
  double calculateTotalPrice() {
    double total = 0;
    for (var item in jadwalList) {
      total += item.harga;
    }
    return total;
  }

  // Modifikasi method toJson untuk menambahkan flag dan struktur yang lebih jelas
  Map<String, dynamic> toJson() {
    // Membuat array timeSlots yang lebih eksplisit
    List<Map<String, dynamic>> individualSlots = jadwalList.map((item) {
      return {
        'jam': item.jam,
        'jamMulai': item.jam,
        'jamSelesai': item.jam + 1,
        'harga': item.harga,
        'waktu': "${item.jam.toString().padLeft(2, '0')}:00-${(item.jam + 1).toString().padLeft(2, '0')}:00"
      };
    }).toList();

    // Format waktu yang eksplisit sebagai array terpisah (tidak digabungkan dalam satu string)
    List<String> timeSlots = jadwalList.map((item) {
      String startHour = item.jam.toString().padLeft(2, '0');
      String endHour = (item.jam + 1).toString().padLeft(2, '0');
      return "$startHour:00-$endHour:00";
    }).toList();

    Map<String, dynamic> json = {
      'lapanganId': lapanganId,
      'namaLapangan': namaLapangan, 
      'lokasi': lokasi,
      'tanggal': tanggal,
      'jadwalList': jadwalList.map((item) => item.toJson()).toList(),
      'timeSlots': timeSlots, // Array of individual time slots as strings
      'individualSlots': individualSlots, // Array of detailed slot objects
      'isConsecutive': false, // Explicit flag saying these are separate slots
      'isMultipleSlots': jadwalList.length > 1, // Another flag for clarity
      'totalSlots': jadwalList.length // Include total slot count
    };
    
    // Tambahkan kode promo jika ada
    if (kodePromo != null && kodePromo!.isNotEmpty) {
      json['kodePromo'] = kodePromo;
    }
    
    // Inside the toJson method, add the hargaDiskon field to the json map:
    if (hargaDiskon != null) {
      json['hargaDiskon'] = hargaDiskon;
    }
    
    return json;
  }

  // Update the fromJson method in the Booking class to better handle backend data

  factory Booking.fromJson(Map<String, dynamic> json) {
    print("Parsing booking data: $json"); // Add this debug log
    
    // Handle jadwalList
    List<JadwalItem> jadwalItems = [];
    if (json['jadwalList'] != null && json['jadwalList'] is List) {
      jadwalItems = (json['jadwalList'] as List)
          .map((item) => JadwalItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }
  
    // Handle date formats properly
    String? tanggal;
    if (json['bookingDate'] != null) {
      try {
        // Format for Java LocalDateTime: "yyyy-MM-ddTHH:mm:ss"
        String dateStr = json['bookingDate'].toString();
        
        // If there's a T in the date, it's an ISO format
        if (dateStr.contains("T")) {
          final dateComponents = dateStr.split("T")[0].split("-");
          if (dateComponents.length == 3) {
            final months = [
              'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
              'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
            ];
            int year = int.parse(dateComponents[0]);
            int month = int.parse(dateComponents[1]);
            int day = int.parse(dateComponents[2]);
            
            tanggal = "$day ${months[month-1]} $year";
          }
        }
      } catch (e) {
        print("Error parsing booking date: $e");
        tanggal = json['bookingDate'].toString();
      }
    } else if (json['tanggal'] != null) {
      tanggal = json['tanggal'].toString();
    }
  
    // Calculate time range
    String? waktu;
    int? jamMulai;
    int? jamSelesai;
    
    if (json['jamMulai'] != null && json['jamSelesai'] != null) {
      jamMulai = json['jamMulai'] is int ? json['jamMulai'] : int.tryParse(json['jamMulai'].toString()) ?? 0;
      jamSelesai = json['jamSelesai'] is int ? json['jamSelesai'] : int.tryParse(json['jamSelesai'].toString()) ?? 0;
      waktu = "${jamMulai.toString().padLeft(2, '0')}:00-${jamSelesai.toString().padLeft(2, '0')}:00";
    } else if (json['waktu'] != null) {
      waktu = json['waktu'].toString();
    }
  
    // Extract venue name and location from either lapangan object or direct properties
    String? namaLapangan;
    String? lokasi;
    Map<String, dynamic>? lapanganData;
  
    if (json['lapangan'] != null) {
      if (json['lapangan'] is Map) {
        lapanganData = Map<String, dynamic>.from(json['lapangan'] as Map);
        namaLapangan = lapanganData['namaLapangan']?.toString();
        
        // Try different field names for location
        lokasi = lapanganData['alamatLapangan']?.toString() ?? 
                lapanganData['alamat']?.toString() ??
                lapanganData['address']?.toString();
      }
    }
  
    // Fallback values from direct properties
    namaLapangan ??= json['namaLapangan']?.toString();
    lokasi ??= json['lokasi']?.toString() ?? json['alamat']?.toString();
    
    // Get total price
    double? totalPrice;
    if (json['totalPrice'] != null) {
      if (json['totalPrice'] is double) {
        totalPrice = json['totalPrice'];
      } else if (json['totalPrice'] is int) {
        totalPrice = (json['totalPrice'] as int).toDouble();
      } else {
        totalPrice = double.tryParse(json['totalPrice'].toString());
      }
    }
    
    // Get discounted price if available
    double? hargaDiskon;
    if (json['hargaDiskon'] != null) {
      if (json['hargaDiskon'] is double) {
        hargaDiskon = json['hargaDiskon'];
      } else if (json['hargaDiskon'] is int) {
        hargaDiskon = (json['hargaDiskon'] as int).toDouble();
      } else {
        hargaDiskon = double.tryParse(json['hargaDiskon'].toString());
      }
    }
    
    // Get booking ID - make sure to handle numeric or string IDs
    int? id;
    if (json['id'] != null) {
      if (json['id'] is int) {
        id = json['id'];
      } else {
        id = int.tryParse(json['id'].toString());
      }
    }
  
    // Get lapanganId - similar approach to handling ID
    int? lapanganId;
    if (json['lapanganId'] != null) {
      lapanganId = json['lapanganId'] is int ? json['lapanganId'] : int.tryParse(json['lapanganId'].toString());
    } else if (json['lapangan'] is Map && json['lapangan']['id'] != null) {
      lapanganId = json['lapangan']['id'] is int ? json['lapangan']['id'] : int.tryParse(json['lapangan']['id'].toString());
    }
    
    print("Parsed booking - ID: $id, Tanggal: $tanggal, Waktu: $waktu, Venue: $namaLapangan");
  
    return Booking(
      id: id,
      lapanganId: lapanganId,
      namaLapangan: namaLapangan,
      lokasi: lokasi,
      tanggal: tanggal,
      waktu: waktu,
      jadwalList: jadwalItems,
      totalPrice: totalPrice,
      lapanganData: lapanganData,
      jamMulai: jamMulai,
      jamSelesai: jamSelesai,
      hargaDiskon: hargaDiskon,
    );
  }
}
