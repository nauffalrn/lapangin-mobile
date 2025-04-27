class Review {
  final int id;
  final int userId;
  final String username; // Pastikan field ini ada di response
  final int lapanganId;
  final double rating;
  final String comment;
  final String createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.username,
    required this.lapanganId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id:
          json['id'] is String
              ? int.parse(json['id'].toString())
              : (json['id'] ?? 0),
      userId:
          json['userId'] is String
              ? int.parse(json['userId'].toString())
              : (json['userId'] ?? 0),
      username:
          json['username'] ??
          json['user']?['username'] ??
          'Unknown User', // Coba ambil dari nested user object jika ada
      lapanganId:
          json['lapanganId'] is String
              ? int.parse(json['lapanganId'].toString())
              : (json['lapanganId'] ?? 0),
      rating:
          json['rating'] != null
              ? double.parse(json['rating'].toString())
              : 0.0,
      comment: json['comment'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }
}
