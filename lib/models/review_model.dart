class Review {
  final String username;
  final double rating;
  final String comment;
  final String? createdAt; // ISO format date from API

  Review({
    required this.username,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  // Format the date as "DD Month YYYY" in Indonesian
  String? get formattedDate {
    if (createdAt == null) return null;

    try {
      final date = DateTime.parse(createdAt!);
      
      // List of Indonesian month names
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      print("Error formatting date: $e for value: $createdAt");
      return createdAt;
    }
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    // Simplified parsing - match fields from ReviewDTO
    return Review(
      username: json['username'] ?? 'Anonymous',
      rating: json['rating'] is int ? (json['rating'] as int).toDouble() : 0.0,
      comment: json['komentar'] ?? '',
      createdAt: json['tanggalReview']?.toString(),
    );
  }
}
