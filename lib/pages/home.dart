import 'package:flutter/material.dart';
import 'profile.dart';
import 'detail.dart';
import '../widgets/bottom_navbar.dart';
import '../services/lapangan_services.dart';
import '../models/lapangan_model.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/promo_service.dart';
import '../models/promo_model.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Lapangan> lapanganList = [];
  List<Lapangan> _filteredLapanganList = [];
  bool _isLoading = false;
  int jumlahTampil = 4;
  
  // Tambahkan variabel untuk promo
  List<Promo> _availablePromos = [];
  bool _isLoadingPromos = false;
  Set<int> _claimedPromoIds = {};

  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLapangan();
    _fetchPromos();
    _loadClaimedPromos();
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
  
  // Method untuk mengambil promo yang tersedia
  Future<void> _fetchPromos() async {
    setState(() {
      _isLoadingPromos = true;
    });
    
    try {
      final promos = await PromoService.getActivePromos();
      
      // Filter hanya promo yang masih valid
      final validPromos = promos.where((promo) => promo.isValid).toList();
      
      setState(() {
        _availablePromos = validPromos;
        _isLoadingPromos = false;
      });
    } catch (e) {
      print("Error fetching promos: $e");
      setState(() {
        _isLoadingPromos = false;
      });
    }
  }
  
  // Method untuk memuat promo yang sudah diklaim
  Future<void> _loadClaimedPromos() async {
    // Cek apakah user sudah login
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) return;
    
    try {
      // Coba ambil promo yang sudah diklaim
      final claimedPromos = await PromoService.getUserClaimedPromos();
      
      // Simpan ID promo yang sudah diklaim
      setState(() {
        _claimedPromoIds = claimedPromos.map((promo) => promo.id).toSet();
      });
      
      // Simpan ke SharedPreferences untuk persistensi
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('claimed_promo_ids', 
        _claimedPromoIds.map((id) => id.toString()).toList());
    } catch (e) {
      print("Error loading claimed promos: $e");
      
      // Fallback ke data tersimpan lokal
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList('claimed_promo_ids') ?? [];
      setState(() {
        _claimedPromoIds = savedIds.map((id) => int.parse(id)).toSet();
      });
    }
  }
  
  // Method untuk mengklaim promo
  Future<void> _claimPromo(Promo promo) async {
    // Cek apakah user sudah login
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silakan login terlebih dahulu untuk mengklaim promo'))
      );
      
      // Navigasi ke halaman login
      Navigator.pushNamed(context, '/login');
      return;
    }
    
    // Tampilkan loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Klaim promo
      final success = await PromoService.claimPromo(promo.kodePromo);
      
      // Tutup dialog loading
      Navigator.pop(context);
      
      if (success) {
        // Tambahkan ID promo ke set promo yang sudah diklaim
        setState(() {
          _claimedPromoIds.add(promo.id);
        });
        
        // Simpan ke SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('claimed_promo_ids', 
          _claimedPromoIds.map((id) => id.toString()).toList());
        
        // Tampilkan pesan sukses
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promo berhasil diklaim! Gunakan saat booking lapangan.'),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      // Tutup dialog loading
      Navigator.pop(context);
      
      // Tampilkan pesan error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengklaim promo: ${e.toString()}'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents back navigation
      onPopInvokedWithResult: (didPop, result) {
        // Updated callback with result parameter
        if (didPop) {
          // This won't be called when canPop is false
          return;
        }
        // You could show a dialog here if needed
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
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
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(),
                    
                    // Tambahkan tampilan untuk lapangan tidak ditemukan
                    if (_searchQuery.isNotEmpty && _filteredLapanganList.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            SizedBox(height: 40),
                            Icon(
                              Icons.search_off,
                              size: 70,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Lapangan Tidak Ditemukan",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Coba masukkan kata kunci lain",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            SizedBox(height: 40),
                          ],
                        ),
                      )
                    else
                      // Tampilan konten yang sudah ada
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPromoDiscount(),
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
                  ],
                ),
              ),
        bottomNavigationBar: const CustomBottomNavigationBar(currentIndex: 0),
      ),
    );
  }

  // Update this method to show the actual profile picture
  Widget _buildProfileIcon() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => ProfilePage()),
        ).then((_) {
          // Refresh when coming back from profile
          setState(() {});
        });
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16.0),
        child: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 30, color: Color(0xFF0A192F)),
              );
            }
            
            final prefs = snapshot.data!;
            final profileImage = prefs.getString('profile_image');
            
            return CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              backgroundImage: profileImage != null && profileImage.isNotEmpty
                  ? NetworkImage(ApiConfig.getProfileImageUrl(profileImage))
                  : null,
              child: profileImage == null || profileImage.isEmpty
                  ? Icon(Icons.person, size: 30, color: Color(0xFF0A192F))
                  : null,
            );
          },
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
              fontSize: title == "Lapangan Rating Tertinggi" ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          TextButton(
            onPressed: () {
              // Navigate to a dedicated page for all listings instead of modifying state
              if (title == "Rekomendasi Lapangan") {
                _showAllRecommendedFields();
              } else if (title == "Lapangan Rating Tertinggi") {
                _showAllHighestRatedFields();
              }
            },
            child: Text(
              "Lihat Semua",
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: title == "Lapangan Rating Tertinggi" ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Add this new method to show all recommended fields in a new screen
  void _showAllRecommendedFields() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(_searchQuery.isEmpty ? "Rekomendasi Lapangan" : "Hasil Pencarian"),
            backgroundColor: Color(0xFF0A192F),
            foregroundColor: Colors.white,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: _filteredLapanganList.length, // Use filtered list instead of full list
              itemBuilder: (context, index) {
                return _buildLapanganCard(_filteredLapanganList[index]);
              },
            ),
          ),
        ),
      ),
    );
  }

  // Add this helper method to show all highest-rated fields in a new screen
  void _showAllHighestRatedFields() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text("Lapangan Rating Tertinggi"),
            backgroundColor: Color(0xFF0A192F),
            foregroundColor: Colors.white,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: _getSortedByRating(_filteredLapanganList).length,
              itemBuilder: (context, index) {
                return _buildLapanganCard(_getSortedByRating(_filteredLapanganList)[index]);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridList(List<Lapangan> lapangans) {
    return GridView.builder(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
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
            jumlahTampil = lapanganList.length;
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
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: lapanganList.length,
        itemBuilder: (context, index) {
          return _buildHorizontalLapanganCard(lapanganList[index]);
        },
      ),
    );
  }

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
        width: 160,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
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
              child: lapangan.gambar != null && lapangan.gambar!.isNotEmpty
                  ? Image.network(
                      ApiConfig.getImageUrl(lapangan.gambar),
                      height: 90,
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
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lapangan.nama,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.orange,
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        "${lapangan.rating?.toStringAsFixed(1) ?? '0.0'} (${lapangan.reviews ?? 0})",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Rp ${lapangan.hargaSewa.toStringAsFixed(0)}/jam',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
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
              child: lapangan.gambar != null && lapangan.gambar!.isNotEmpty
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
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
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
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Ubah method untuk membangun widget promo
  Widget _buildPromoDiscount() {
    if (_isLoadingPromos) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12.0),
        ),
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Filter promo yang belum diklaim
    final availablePromos = _availablePromos
        .where((promo) => !_claimedPromoIds.contains(promo.id))
        .toList();
    
    if (availablePromos.isEmpty) {
      return SizedBox.shrink(); // Tidak tampilkan apa-apa jika tidak ada promo
    }
    
    // Ambil promo pertama yang belum diklaim untuk ditampilkan
    final promo = availablePromos.first;
    
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
              children: [
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
                  "Diskon ${promo.diskonPersen.toStringAsFixed(0)}% untuk pemesanan Anda",
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
                Text(
                  "Berlaku hingga ${_formatDate(promo.tanggalSelesai)}",
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
            onPressed: () => _claimPromo(promo),
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
  
  // Helper method untuk format tanggal
  String _formatDate(DateTime date) {
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return "${date.day} ${monthNames[date.month - 1]} ${date.year}";
  }

  void _usePromoCode() async {
    String userId = 'current-user-id';

    try {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Promo berhasil diklaim! Diskon akan diterapkan pada pemesanan Anda selanjutnya.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
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
        _filteredLapanganList = lapanganList
            .where(
              (lapangan) => lapangan.nama.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList();
      }
      
      // Reset jumlahTampil to default when searching
      jumlahTampil = 4;
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
    List<Lapangan> sortedList = List.from(lapangans);
    sortedList.sort((a, b) {
      double ratingA = a.rating ?? 0.0;
      double ratingB = b.rating ?? 0.0;
      return ratingB.compareTo(ratingA);
    });
    return sortedList;
  }
}
