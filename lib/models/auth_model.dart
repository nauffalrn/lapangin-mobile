class User {
  final int? id;
  final String? name;
  final String? username;
  final String? email;
  final String? phoneNumber;
  final String? token;

  User({
    this.id,
    this.name,
    this.username,
    this.email,
    this.phoneNumber,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      // Cek struktur response
      if (json.containsKey('token')) {
        // Response dari login API
        return User(
          id: json['id'] ?? json['userId'],
          username: json['username'],
          email: json['email'],
          name: json['name'],
          token: json['token'],
          phoneNumber: json['phoneNumber'],
        );
      } else if (json.containsKey('user')) {
        // Format alternatif
        var userData = json['user'];
        return User(
          id: userData['id'] ?? userData['userId'],
          username: userData['username'],
          email: userData['email'],
          name: userData['name'],
          phoneNumber: userData['phoneNumber'],
          token: json['token'],
        );
      } else {
        // Fallback
        print("Warning: Unknown API response structure: $json");
        return User(
          id: json['id'] ?? json['userId'],
          username: json['username'],
          email: json['email'],
          name: json['name'],
          phoneNumber: json['phoneNumber'],
          token: json['token'],
        );
      }
    } catch (e) {
      print("Error parsing user data: $e, JSON: $json");
      rethrow;
    }
  }
}

class LoginRequest {
  final String username;
  final String password;

  LoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() {
    return {'username': username, 'password': password};
  }
}

class RegisterRequest {
  final String name;
  final String username;
  final String email;
  final String password;
  final String phoneNumber;

  RegisterRequest({
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    required this.phoneNumber,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'username': username,
      'email': email,
      'password': password,
      'phoneNumber': phoneNumber,
    };
  }
}
