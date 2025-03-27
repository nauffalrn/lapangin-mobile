import 'package:flutter/material.dart';
import 'pembayaran.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class DetailPage extends StatefulWidget {
  final Map<String, dynamic> lapangan;

  DetailPage({required this.lapangan});

  @override
  _DetailPageState createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  DateTime? selectedDate;
  String? selectedTime;
  double? _distance;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      bool isBooked = widget.lapangan['bookedDates']?.contains(formattedDate) ?? false;
      print("Tanggal yang dipilih: $formattedDate");
      print("Sudah dipesan? $isBooked");
      if (!isBooked) {
        setState(() {
          selectedDate = picked;
          selectedTime = null; 
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tanggal ini sudah dipesan, silakan pilih tanggal lain.")),
        );
      }
    }
  }
  /* Icon Fasilitas */
  Map<String, IconData> facilityIcons = {
    "WiFi": Icons.wifi,
    "Toilet": Icons.bathroom,
    "Parkir": Icons.local_parking,
    "Air Minum": Icons.local_drink,
    "Ruang Tunggu": Icons.chair,
  };

  Future<void> _selectTime(BuildContext context) async {
    if (selectedDate == null) return;
    String selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
    List<String> availableTimes = widget.lapangan['availableTimes'] ?? [];
    List<String> bookedTimes = widget.lapangan['bookedTimes']?[selectedDateStr] ?? [];
    print("Waktu yang tersedia: $availableTimes");
    print("Waktu yang sudah dipesan pada $selectedDateStr: $bookedTimes");
    List<String> selectableTimes = availableTimes.where((time) => !bookedTimes.contains(time)).toList();

    if (selectableTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tidak ada jam tersedia untuk tanggal ini.")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: 300,
          child: Column(
            children: [
              Text("Pilih Jam", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: selectableTimes.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(selectableTimes[index]),
                      onTap: () {
                        setState(() {
                          selectedTime = selectableTimes[index];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openMap() async {
    String location = widget.lapangan['location'] ?? '';
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lokasi tidak tersedia.")),
      );
      return;
    }

    // Use Uri.encodeComponent to properly encode the location for URLs
    final encodedLocation = Uri.encodeComponent(location);
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$encodedLocation");
    
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tidak dapat membuka Maps.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      // Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }
      
      // Get current position
      Position position = await Geolocator.getCurrentPosition();
      
      // Get venue coordinates from the widget data
      double? venueLat = double.tryParse(widget.lapangan['latitude']?.toString() ?? '');
      double? venueLng = double.tryParse(widget.lapangan['longitude']?.toString() ?? '');
      
      if (venueLat != null && venueLng != null) {
        // Calculate distance in meters
        double distanceInMeters = Geolocator.distanceBetween(
          position.latitude, position.longitude,
          venueLat, venueLng
        );
        
        setState(() {
          _distance = distanceInMeters;
          _isLoadingLocation = false;
        });
      } else {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _openInGoogleMaps() async {
    double? venueLat = double.tryParse(widget.lapangan['latitude']?.toString() ?? '');
    double? venueLng = double.tryParse(widget.lapangan['longitude']?.toString() ?? '');
    
    if (venueLat != null && venueLng != null) {
      final url = 'https://www.google.com/maps/dir/?api=1&destination=$venueLat,$venueLng';
      if (await canLaunch(url)) {
        await launch(url);
      } else {
        throw 'Could not launch $url';
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Lapangan'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              widget.lapangan['image'] ?? 'assets/images/default.jpg',
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lapangan['name'] ?? 'Nama tidak tersedia',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange, size: 20),
                      SizedBox(width: 4),
                      Text(
                        widget.lapangan['rating'] ?? '0.0',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.lapangan['price'] ?? 'Harga tidak tersedia',
                    style: TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 16),
                  Text("Lokasi:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(
                    widget.lapangan['location'] ?? 'Lokasi tidak tersedia',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  if (_isLoadingLocation)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_distance != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "Jarak: ${_distance! < 1000 ? '${_distance!.toStringAsFixed(0)} meter' : '${(_distance! / 1000).toStringAsFixed(2)} km'}",
                        style: TextStyle(fontSize: 14, color: Colors.blue),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: _openInGoogleMaps,
                      icon: Icon(Icons.directions),
                      label: Text("Buka di Google Maps"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text("Tanggal dan Jam :", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _selectDate(context),
                        child: Text(selectedDate != null
                            ? DateFormat('dd MMM yyyy').format(selectedDate!)
                            : "Pilih Tanggal"),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: selectedDate == null ? null : () => _selectTime(context),
                        child: Text(selectedTime ?? "Pilih Jam"),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text("Fasilitas:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.lapangan['facilities'] != null
                        ? List.generate(
                            widget.lapangan['facilities'].length,
                            (index) {
                              String facility = widget.lapangan['facilities'][index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      facilityIcons[facility] ?? Icons.check, // Pakai ikon sesuai fasilitas, default ke check jika tidak ada
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      facility,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        : [
                            Row(
                              children: [
                                Icon(Icons.close, color: Colors.red),
                                SizedBox(width: 10),
                                Text("Tidak ada fasilitas", style: TextStyle(fontSize: 16)),
                              ],
                            ),
                          ],
                  ),


                  SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PembayaranPage()),
                        );
                      },
                      child: Text("Pesan Sekarang", style: TextStyle(color: Colors.white, fontSize: 16)),
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
}
