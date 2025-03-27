import 'package:flutter/material.dart';
import 'profile.dart';
import 'detail.dart';
import '../widgets/bottom_navbar.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> lapanganList = [
    {"name": "Tennis Wira", "image": "assets/tenis_jakarta.jpg", "rating": "4.8 (120)", "price": "Rp 150.000/jam"},
    {"name": "Lapangan Basket B", "image": "assets/bultang_alya.jpg", "rating": "4.7 (98)", "price": "Rp 200.000/jam"},
    {"name": "Lapangan Badminton C", "image": "assets/basket_suna.jpg", "rating": "4.9 (150)", "price": "Rp 100.000/jam"},
    {"name": "Lapangan Tenis D", "image": "assets/futsal_mini.png", "rating": "4.6 (75)", "price": "Rp 180.000/jam"},
    {"name": "Lapangan Voli E", "image": "assets/golf_cheap.jpeg", "rating": "4.9 (60)", "price": "Rp 700.000/jam"},
  ];

  int jumlahTampil = 4; // Awalnya tampil 4 data saja

  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredLapanganList = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredLapanganList = List.from(lapanganList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0A192F),
        elevation: 0,
        title: const Text(
          'Home',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        actions: [_buildProfileIcon()], 
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPromoDiscount(),
            _buildSearchBar(),
            _buildSectionHeader(context, "Rekomendasi Lapangan"),
            _buildGridList(_filteredLapanganList.take(jumlahTampil).toList()),

            if (jumlahTampil < _filteredLapanganList.length) _buildLoadMoreButton(),

            const SizedBox(height: 20),
            _buildSectionHeader(context, "Lapangan Rating Tertinggi"),
            _buildHorizontalLazyList(_filteredLapanganList),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 0),
    );
  }

  Widget _buildProfileIcon() {
  return PopupMenuButton<String>(
    onSelected: (value) {
      if (value == "profile") {
        print("Navigasi ke halaman Edit Profil");
      } else if (value == "settings") {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfilePage()),
        );
      }
    },
    itemBuilder: (BuildContext context) => [

      const PopupMenuItem(value: "settings", child: Text("Settings")),
    ],
    child: Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white,
            child: ClipOval(
              child: Image.asset(
                'assets/yayaya.jpeg', // Ganti dengan gambar profil pengguna
                fit: BoxFit.cover,
                width: 44,
                height: 44,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          TextButton(
            onPressed: () {},
            child: const Text("Lihat Semua", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildGridList(List<Map<String, dynamic>> lapanganList) {
    return GridView.builder(
      physics: NeverScrollableScrollPhysics(), // Supaya tidak bentrok dengan ScrollView utama
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 kolom dalam 1 baris
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: lapanganList.length,
      itemBuilder: (context, index) {
        return _buildLapanganCard(lapanganList[index]);
      },
    );
  }

  Widget _buildLoadMoreButton() {
    return Center(
      child: TextButton(
        onPressed: () {
          setState(() {
            jumlahTampil = lapanganList.length; // Tampilkan semua data
          });
        },
        child: Text("Muat Lebih Banyak", style: TextStyle(color: Colors.blueAccent, fontSize: 16)),
      ),
    );
  }

  Widget _buildHorizontalLazyList(List<Map<String, dynamic>> lapanganList) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: lapanganList.length,
        itemBuilder: (context, index) {
          return _buildLapanganCard(lapanganList[index]);
        },
      ),
    );
  }

  Widget _buildLapanganCard(Map<String, dynamic> lapangan) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailPage(lapangan: lapangan),
          ),
        );
      },
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 3,
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Image.asset(
                lapangan['image'],
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lapangan['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        lapangan['rating'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    lapangan['price'],
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoDiscount() {
  // This should come from your user state/preferences
  bool promoAlreadyUsed = false; // Replace with actual state check
  
  // If user already used the promo, don't show anything
  if (promoAlreadyUsed) {
    return const SizedBox.shrink();
  }
  
  return Container(
    margin: const EdgeInsets.only(bottom: 16.0),
    padding: const EdgeInsets.all(16.0),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0A192F), Color(0xFF3498db)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black26,
          offset: Offset(0, 2),
          blurRadius: 6.0,
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Diskon Spesial! 🎉",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Diskon 15% untuk pemesanan pertama Anda",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              Text(
                "Hanya berlaku sekali!",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.yellow,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () {
            // Mark promo as used in database/shared preferences
            _usePromoCode();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF0A192F),
          ),
          child: const Text("Klaim"),
        ),
      ],
    ),
  );
}

void _usePromoCode() async {
  // Get current user ID from your auth system
  String userId = 'current-user-id'; // Replace with actual user ID
  
  try {
    // 1. Mark promo as used in your database
    // await FirebaseFirestore.instance.collection('users').doc(userId).update({
    //   'hasUsedPromo': true,
    // });
    
    // 2. Update local state to hide the promo banner
    setState(() {
      // Update local state to reflect promo is used
    });
    
    // 3. Show confirmation to user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Promo berhasil diklaim! Diskon akan diterapkan pada pemesanan Anda selanjutnya.'),
        backgroundColor: Colors.green,
      ),
    );
    
    // 4. Optional: Navigate to booking page with promo applied
    // Navigator.push(context, MaterialPageRoute(builder: (context) => BookingPage(promoApplied: true)));
  } catch (e) {
    // Handle error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gagal mengklaim promo: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

void _searchLapangan(String query) {
  setState(() {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredLapanganList = List.from(lapanganList);
    } else {
      _filteredLapanganList = lapanganList.where((lapangan) {
        return lapangan['name'].toLowerCase().contains(query.toLowerCase()) ||
               (lapangan['price'].toString().toLowerCase().contains(query.toLowerCase()));
      }).toList();
    }
  });
}

Widget _buildSearchBar() {
  return Container(
    margin: const EdgeInsets.only(bottom: 20.0, top: 10.0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.15),
          spreadRadius: 2,
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: TextField(
        controller: _searchController,
        onChanged: _searchLapangan,
        style: const TextStyle(fontSize: 16),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[100],
          hintText: 'Cari lapangan favorit kamu...',
          hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w400),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Icon(Icons.search_rounded, color: Color(0xFF0A192F), size: 24),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    _searchController.clear();
                    _searchLapangan('');
                    FocusScope.of(context).unfocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(Icons.close, color: Colors.grey[600], size: 20),
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Color(0xFF0A192F), width: 1.5),
          ),
        ),
      ),
    ),
  );
}
}
