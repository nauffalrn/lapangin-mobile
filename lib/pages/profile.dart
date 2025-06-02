import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../config/api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _username = '';
  String _name = '';
  String _email = '';
  String _phoneNumber = '';
  String? _profileImageUrl;
  bool _isLoading = true;
  File? _imageFile;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // LOAD data dari SharedPreferences dulu
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _username = prefs.getString('username') ?? '';
        _name = prefs.getString('name') ?? '';
        _email = prefs.getString('email') ?? '';
        _phoneNumber = prefs.getString('phone_number') ?? '';
        _profileImageUrl = prefs.getString('profile_image');
      });

      print("=== LOADING USER DATA ===");
      print("From SharedPreferences - Username: $_username, Name: $_name");
      print("Profile Image URL: $_profileImageUrl");

      // REFRESH dari database untuk mendapatkan data terbaru
      try {
        final token = await AuthService.getToken();
        if (token != null && token.isNotEmpty) {
          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/profile/user'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          );

          print("Profile refresh response status: ${response.statusCode}");
          print("Profile refresh response body: ${response.body}");

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['success'] == true && data['data'] != null) {
              final userData = data['data'];
              final serverUsername = userData['username'];

              // PERBAIKAN KRITIS: Validasi user yang sama
              if (_username != serverUsername) {
                print(
                  "User mismatch! Local: $_username, Server: $serverUsername",
                );
                // Logout paksa dan redirect ke login
                await AuthService.logout();
                Navigator.pushReplacementNamed(context, '/login');
                return;
              }

              // SELECTIVE SYNC - hanya update yang perlu dan valid
              bool needsUpdate = false;

              // Check profile image changes
              if (userData['profileImage'] != _profileImageUrl) {
                setState(() {
                  _profileImageUrl = userData['profileImage'];
                });

                // Update SharedPreferences untuk profile image
                if (userData['profileImage'] != null &&
                    userData['profileImage'].toString().isNotEmpty) {
                  await prefs.setString(
                    'profile_image',
                    userData['profileImage'],
                  );
                } else {
                  await prefs.remove('profile_image');
                }

                needsUpdate = true;
                print("Profile image synced: ${userData['profileImage']}");
              }

              // Sync other data if needed (nama, email, phone) dengan validasi
              if (userData['name'] != null && userData['name'] != _name) {
                setState(() {
                  _name = userData['name'];
                });
                await prefs.setString('name', userData['name']);
                needsUpdate = true;
                print("Name synced: ${userData['name']}");
              }

              if (userData['email'] != null && userData['email'] != _email) {
                setState(() {
                  _email = userData['email'];
                });
                await prefs.setString('email', userData['email']);
                needsUpdate = true;
                print("Email synced: ${userData['email']}");
              }

              if (userData['phoneNumber'] != null &&
                  userData['phoneNumber'] != _phoneNumber) {
                setState(() {
                  _phoneNumber = userData['phoneNumber'];
                });
                await prefs.setString('phone_number', userData['phoneNumber']);
                needsUpdate = true;
                print("Phone synced: ${userData['phoneNumber']}");
              }

              if (needsUpdate) {
                print("Profile data synchronized with server");
              } else {
                print("Local profile data is up to date");
              }
            }
          } else if (response.statusCode == 401) {
            print("Token expired during profile refresh");
            await AuthService.logout();
            Navigator.pushReplacementNamed(context, '/login');
            return;
          }
        }
      } catch (e) {
        print('Profile refresh error (non-critical): $e');
        // Tidak throw error, karena data lokal sudah di-load
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading profile: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedImage == null) return;

      setState(() {
        _imageFile = File(pickedImage.path);
        _isUploadingImage = true;
      });

      print("=== UPLOADING PROFILE IMAGE ===");
      print("Image path: ${pickedImage.path}");

      final imageUrl = await ProfileService.uploadProfileImage(
        pickedImage.path,
      );

      setState(() {
        _profileImageUrl = imageUrl;
        _isUploadingImage = false;
      });

      print("=== UPLOAD SUCCESSFUL ===");
      print("Image URL: $imageUrl");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto profil berhasil diperbarui'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
        _imageFile = null;
      });

      print("=== UPLOAD FAILED ===");
      print("Error: $e");

      if (e.toString().contains('login again') ||
          e.toString().contains('Session expired')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sesi anda habis. Silakan login kembali.')),
        );
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah foto profil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProfileImage() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Color(0xFF0A192F),
          child:
              _imageFile != null
                  ? ClipOval(
                    child: Image.file(
                      _imageFile!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  )
                  : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                  ? FutureBuilder<Map<String, String>>(
                    future: ApiConfig.getAuthHeaders(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircularProgressIndicator(color: Colors.white);
                      }

                      return ClipOval(
                        child: Image.network(
                          ApiConfig.getProfileImageUrlSync(_profileImageUrl!),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          headers: snapshot.data ?? {},
                          errorBuilder: (context, error, stackTrace) {
                            print("Error loading profile image: $error");
                            return Text(
                              _name.isNotEmpty
                                  ? _name[0].toUpperCase()
                                  : (_username.isNotEmpty
                                      ? _username[0].toUpperCase()
                                      : 'U'),
                              style: TextStyle(
                                fontSize: 40,
                                color: Colors.white,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return CircularProgressIndicator(
                              color: Colors.white,
                            );
                          },
                        ),
                      );
                    },
                  )
                  : Text(
                    _name.isNotEmpty
                        ? _name[0].toUpperCase()
                        : (_username.isNotEmpty
                            ? _username[0].toUpperCase()
                            : 'U'),
                    style: TextStyle(fontSize: 40, color: Colors.white),
                  ),
        ),
        if (_isUploadingImage)
          Positioned.fill(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.black54,
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        if (!_isUploadingImage)
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
          ),
      ],
    );
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.camera_alt, color: Color(0xFF0A192F)),
                title: Text('Ambil Foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: Color(0xFF0A192F)),
                title: Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konfirmasi Logout'),
          content: Text('Apakah Anda yakin ingin keluar dari akun?'),
          actions: [
            TextButton(
              child: Text('Batal'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Ya, Keluar'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      try {
        print("Logging out - profile data will be preserved");

        await AuthService.logout(); // HANYA hapus token

        // Navigasi ke login tanpa clear route
        Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal logout: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pengaturan Profil", style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF0A192F),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 20),
                    GestureDetector(
                      onTap:
                          _isUploadingImage
                              ? null
                              : _showImageSourceActionSheet,
                      child: _buildProfileImage(),
                    ),
                    SizedBox(height: 10),

                    Card(
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(Icons.badge, color: Color(0xFF0A192F)),
                        title: Text('Nama'),
                        subtitle: Text(_name),
                      ),
                    ),

                    SizedBox(height: 20),

                    Card(
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(Icons.person, color: Color(0xFF0A192F)),
                        title: Text('Username'),
                        subtitle: Text(_username),
                      ),
                    ),

                    SizedBox(height: 10),

                    Card(
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(Icons.email, color: Color(0xFF0A192F)),
                        title: Text('Email'),
                        subtitle: Text(_email),
                      ),
                    ),

                    SizedBox(height: 10),

                    Card(
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(Icons.phone, color: Color(0xFF0A192F)),
                        title: Text('Nomor Telepon'),
                        subtitle: Text(_phoneNumber),
                      ),
                    ),

                    SizedBox(height: 40),

                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: Icon(Icons.logout),
                      label: Text("Keluar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 50),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
    );
  }
}
