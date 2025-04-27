import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../widgets/bottom_navbar.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _username = '';
  String _email = '';
  bool _isLoading = true;

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
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _username = prefs.getString('username') ?? 'User';
        _email = prefs.getString('email') ?? 'user@example.com';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat data profile: $e')));
    }
  }

  Future<void> _logout() async {
    try {
      await AuthService.logout();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal logout: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF0A192F),
        centerTitle: true,
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF0A192F),
                  child: Text(
                    _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
                    style: TextStyle(fontSize: 40, color: Colors.white),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  _username,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  _email,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                SizedBox(height: 40),
                ListTile(
                  leading: Icon(Icons.history),
                  title: Text("Riwayat Pemesanan"),
                  onTap: () {
                    Navigator.pushNamed(context, '/history');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.settings),
                  title: Text("Pengaturan"),
                  onTap: () {
                    // Navigate to settings page
                  },
                ),
                ListTile(
                  leading: Icon(Icons.help),
                  title: Text("Bantuan"),
                  onTap: () {
                    // Navigate to help page
                  },
                ),
                Spacer(),
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: Icon(Icons.logout),
                  label: Text("Logout"),
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
      // Pastikan currentIndex valid dan sesuai dengan jumlah items di CustomBottomNavigationBar
      bottomNavigationBar: CustomBottomNavigationBar(currentIndex: 3),
    );
  }
}
