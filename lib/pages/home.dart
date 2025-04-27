import 'package:flutter/material.dart';
import 'profile.dart';
import 'detail.dart';
import '../widgets/bottom_navbar.dart';
import '../services/lapangan_services.dart';
import '../models/lapangan_model.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Lapangan> lapanganList = [];
  List<Lapangan> _filteredLapanganList = [];
  bool _isLoading = false;
  int jumlahTampil = 4;

  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLapangan();
  }

  // Tambahkan error handling yang lebih baik di bagian _fetchLapangan()
  Future<void> _fetchLapangan() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await LapanganService.getAllLapangan();
      setState(() {
        lapanganList = data;
        _filteredLapanganList = data;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching lapangan: $e");
      setState(() {
        _isLoading = false;
        lapanganList = []; // Set empty list to prevent errors
        _filteredLapanganList = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil data lapangan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0A192F),
        elevation: 0,
        title: const Text(
          'Home',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [_buildProfileIcon()],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPromoDiscount(),
                    _buildSearchBar(),
                    _buildSectionHeader(context, "Rekomendasi Lapangan"),
                    _buildGridList(
                      _filteredLapanganList.take(jumlahTampil).toList(),
                    ),
                    if (jumlahTampil < _filteredLapanganList.length)
                      _buildLoadMoreButton(),
                    const SizedBox(height: 20),
                    _buildSectionHeader(context, "Lapangan Rating Tertinggi"),
                    _buildHorizontalLazyList(
                      _getSortedByRating(_filteredLapanganList),
                    ),
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
      itemBuilder:
          (BuildContext context) => [
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
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.person, size: 30, color: Colors.blue);
                  },
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
          Text(
            title,
            style: TextStyle(
              fontSize:
                  title == "Lapangan Rating Tertinggi"
                      ? 18
                      : 20, // Ukuran lebih kecil untuk rating tertinggi
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          TextButton(
            onPressed: () {},
            child: Text(
              "Lihat Semua",
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize:
                    title == "Lapangan Rating Tertinggi"
                        ? 12
                        : 14, // Ukuran lebih kecil untuk rating tertinggi
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridList(List<Lapangan> lapangans) {
    return GridView.builder(
      physics:
          NeverScrollableScrollPhysics(), // Supaya tidak bentrok dengan ScrollView utama
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 kolom dalam 1 baris
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: lapangans.length,
      itemBuilder: (context, index) {
        return _buildLapanganCard(lapangans[index]);
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
        child: Text(
          "Muat Lebih Banyak",
          style: TextStyle(color: Colors.blueAccent, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildHorizontalLazyList(List<Lapangan> lapanganList) {
    return Container(
      height: 200, // Ukuran lebih kecil (dari 230 menjadi 200)
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: lapanganList.length,
        itemBuilder: (context, index) {
          return _buildHorizontalLapanganCard(lapanganList[index]);
        },
      ),
    );
  }

  // Tambahkan metode baru untuk card horizontal (mencegah overflow)
  Widget _buildHorizontalLapanganCard(Lapangan lapangan) {
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
        width: 160, // Lebih kecil (dari 180 menjadi 160)
        margin: const EdgeInsets.only(
          right: 10,
        ), // Margin lebih kecil (dari 12 menjadi 10)
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2, // Lebih kecil (dari 3 menjadi 2)
              blurRadius: 5, // Lebih kecil (dari 6 menjadi 5)
              offset: const Offset(0, 3), // Lebih kecil (dari 0,4 menjadi 0,3)
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child:
                  lapangan.gambar != null && lapangan.gambar!.isNotEmpty
                      ? Image.network(
                        ApiConfig.getImageUrl(lapangan.gambar),
                        height: 90, // Lebih kecil (dari 100 menjadi 90)
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/logo.png',
                            height: 90,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          );
                        },
                      )
                      : Image.asset(
                        'assets/logo.png',
                        height: 90,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
            ),
            Padding(
              padding: const EdgeInsets.all(
                8.0,
              ), // Lebih kecil (dari 10 menjadi 8)
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lapangan.nama,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12, // Lebih kecil (dari 14 menjadi 12)
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3), // Lebih kecil (dari 4 menjadi 3)
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.orange,
                        size: 12, // Lebih kecil (dari 14 menjadi 12)
                      ), // Standardized size
                      const SizedBox(width: 2),
                      Text(
                        "${lapangan.rating?.toStringAsFixed(1) ?? '0.0'} (${lapangan.reviews ?? 0})", // Menampilkan jumlah reviews
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ), // Lebih kecil (dari 12 menjadi 10)
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3), // Lebih kecil (dari 4 menjadi 3)
                  Text(
                    'Rp ${lapangan.hargaSewa.toStringAsFixed(0)}/jam',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                      fontSize: 10, // Lebih kecil (dari 12 menjadi 10)
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

  Widget _buildLapanganCard(Lapangan lapangan) {
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child:
                  lapangan.gambar != null && lapangan.gambar!.isNotEmpty
                      ? FutureBuilder<Map<String, String>>(
                        future: ApiConfig.getAuthHeaders(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Container(
                              height: 100,
                              width: double.infinity,
                              color: Colors.grey.shade200,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          return Image.network(
                            ApiConfig.getImageUrl(lapangan.gambar),
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            headers: snapshot.data,
                            errorBuilder: (context, error, stackTrace) {
                              print("Error loading image: $error");
                              return Image.asset(
                                'assets/logo.png',
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              );
                            },
                          );
                        },
                      )
                      : Image.asset(
                        'assets/logo.png',
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
                    lapangan.nama,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis, // Truncate text that's too long
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        // Gunakan rating dari model lapangan atau default jika null
                        lapangan.rating != null
                            ? lapangan.rating!.toStringAsFixed(1)
                            : '0.0',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Rp ${lapangan.hargaSewa.toStringAsFixed(0)}/jam',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 13, // Lebih kecil untuk menghindari overflow
                    ),
                    maxLines: 1, // Ensure single line
                    overflow: TextOverflow.ellipsis, // Truncate if too long
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
                  style: TextStyle(fontSize: 14, color: Colors.white),
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
          content: Text(
            'Promo berhasil diklaim! Diskon akan diterapkan pada pemesanan Anda selanjutnya.',
          ),
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
        _filteredLapanganList =
            lapanganList
                .where(
                  (lapangan) =>
                      lapangan.nama.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      lapangan.jenis.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      lapangan.alamat.toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
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
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Icon(
                Icons.search_rounded,
                color: Color(0xFF0A192F),
                size: 24,
              ),
            ),
            suffixIcon:
                _searchQuery.isNotEmpty
                    ? InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () {
                        _searchController.clear();
                        _searchLapangan('');
                        FocusScope.of(context).unfocus();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.close,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ),
                    )
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 16,
            ),
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

  List<Lapangan> _getSortedByRating(List<Lapangan> lapangans) {
    // Create a copy to avoid modifying the original list
    List<Lapangan> sortedList = List.from(lapangans);
    // Sort by rating in descending order (highest first)
    sortedList.sort((a, b) {
      double ratingA = a.rating ?? 0.0;
      double ratingB = b.rating ?? 0.0;
      return ratingB.compareTo(ratingA);
    });
    return sortedList;
  }
}
