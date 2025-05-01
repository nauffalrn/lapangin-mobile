import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../config/api_config.dart';

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
      // First try to load from SharedPreferences (faster)
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _username = prefs.getString('username') ?? '';
        _name = prefs.getString('name') ?? '';
        _email = prefs.getString('email') ?? '';
        _phoneNumber = prefs.getString('phone_number') ?? '';
        _profileImageUrl = prefs.getString('profile_image');
      });

      // Then try to fetch fresh data from server
      try {
        final profileData = await ProfileService.getUserProfile();
        
        // Update local storage with fresh data
        await prefs.setString('name', profileData['name'] ?? '');
        await prefs.setString('email', profileData['email'] ?? '');
        await prefs.setString('phone_number', profileData['phoneNumber'] ?? '');
        await prefs.setString('profile_image', profileData['profileImage'] ?? '');
        
        setState(() {
          _name = profileData['name'] ?? '';
          _email = profileData['email'] ?? '';
          _phoneNumber = profileData['phoneNumber'] ?? '';
          _profileImageUrl = profileData['profileImage'];
        });
      } catch (e) {
        // If server fetch fails, we already have data from SharedPreferences
        print('Could not refresh profile data: $e');
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data profil: $e'))
      );
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
        _isLoading = true;
      });
      
      print("About to upload image from path: ${pickedImage.path}");
      
      // Upload the image to your server
      final imageUrl = await ProfileService.uploadProfileImage(pickedImage.path);
      
      setState(() {
        _profileImageUrl = imageUrl;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto profil berhasil diperbarui'))
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _imageFile = null; // Reset the image file on error
      });
      
      // Check if it's an auth error
      if (e.toString().contains('login again') || e.toString().contains('Unauthorized')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sesi anda habis. Silakan login kembali.'))
        );
        // Logout and redirect to login
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil gambar: $e'))
        );
      }
    }
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
    try {
      await AuthService.logout();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal logout: $e'))
      );
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
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                GestureDetector(
                  onTap: _showImageSourceActionSheet,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFF0A192F),
                        backgroundImage: (_imageFile != null) 
                            ? FileImage(_imageFile!) 
                            : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                                ? NetworkImage(ApiConfig.getProfileImageUrl(_profileImageUrl)) as ImageProvider
                                : null,
                        child: (_imageFile == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                            ? Text(
                                _name.isNotEmpty ? _name[0].toUpperCase() : (_username.isNotEmpty ? _username[0].toUpperCase() : 'U'),
                                style: TextStyle(fontSize: 40, color: Colors.white),
                              )
                            : null,
                      ),
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                
                // Name display
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(Icons.badge, color: Color(0xFF0A192F)),
                    title: Text('Nama'),
                    subtitle: Text(_name),
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Username (read-only)
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(Icons.person, color: Color(0xFF0A192F)),
                    title: Text('Username'),
                    subtitle: Text(_username),
                  ),
                ),
                
                SizedBox(height: 10),
                
                // Email (display only)
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(Icons.email, color: Color(0xFF0A192F)),
                    title: Text('Email'),
                    subtitle: Text(_email),
                  ),
                ),
                
                SizedBox(height: 10),
                
                // Phone number (display only)
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(Icons.phone, color: Color(0xFF0A192F)),
                    title: Text('Nomor Telepon'),
                    subtitle: Text(_phoneNumber),
                  ),
                ),
                
                SizedBox(height: 10),
                
                // Change password option
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(Icons.lock, color: Color(0xFF0A192F)),
                    title: Text('Ubah Password'),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Navigate to change password screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fitur ini belum tersedia'))
                      );
                    },
                  ),
                ),
                
                SizedBox(height: 40),
                
                // Logout button
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
