import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class MapsService {
  // Method untuk membuka lokasi di Google Maps (menampilkan rute tanpa navigasi otomatis)
  static Future<void> openInGoogleMapsWithLocation({
    required BuildContext context,
    required double? latitude,
    required double? longitude,
    String? placeName,
  }) async {
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Koordinat lokasi tidak tersedia')),
      );
      return;
    }

    try {
      print(
        "Attempting to open Google Maps location view: $latitude, $longitude",
      );
      print("Place name: $placeName");

      // List of URLs untuk menampilkan lokasi dengan nama tempat (bukan koordinat)
      List<String> urlsToTry = [];

      // Jika ada nama tempat, prioritaskan pencarian berdasarkan nama dengan koordinat sebagai referensi
      if (placeName != null && placeName.isNotEmpty) {
        String encodedPlaceName = Uri.encodeComponent(placeName);

        urlsToTry.addAll([
          // URL yang menampilkan rute ke nama tempat (seperti di gambar contoh)
          'https://www.google.com/maps/dir/?api=1&destination=$encodedPlaceName&travelmode=driving',
          // URL pencarian dengan nama tempat
          'https://www.google.com/maps/search/?api=1&query=$encodedPlaceName',
          // URL dengan nama tempat dan koordinat untuk akurasi
          'https://www.google.com/maps/search/?api=1&query=$encodedPlaceName+$latitude,$longitude',
          // URL sederhana dengan nama tempat
          'https://maps.google.com/?q=$encodedPlaceName',
        ]);
      }

      // URL fallback dengan koordinat jika nama tempat tidak ada atau gagal
      urlsToTry.addAll([
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        'https://www.google.com/maps/@$latitude,$longitude,15z',
        'https://maps.google.com/?q=$latitude,$longitude',
        'geo:$latitude,$longitude?z=15',
      ]);

      bool success = false;
      String lastError = '';

      for (String url in urlsToTry) {
        try {
          print("Trying URL: $url");
          final uri = Uri.parse(url);

          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            success = true;
            print("Successfully opened: $url");
            break;
          } else {
            print("Cannot launch URL: $url");
          }
        } catch (e) {
          lastError = e.toString();
          print("Error with URL $url: $e");
          continue;
        }
      }

      if (!success) {
        throw Exception(
          'Tidak dapat membuka Google Maps. Error terakhir: $lastError',
        );
      }
    } catch (e) {
      print("Error opening Google Maps: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka Google Maps: $e'),
          action: SnackBarAction(
            label: 'Salin Nama',
            onPressed: () {
              // Copy place name to clipboard as fallback
              final placeToCopy = placeName ?? '$latitude, $longitude';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Nama tempat disalin: $placeToCopy')),
              );
            },
          ),
        ),
      );
    }
  }

  // Method yang sudah ada untuk navigasi (digunakan di detail page)
  static Future<void> openInGoogleMaps({
    required BuildContext context,
    required double? latitude,
    required double? longitude,
    String? placeName,
  }) async {
    // Method ini tetap ada untuk navigasi langsung jika diperlukan
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Koordinat lokasi tidak tersedia')),
      );
      return;
    }

    try {
      print(
        "Attempting to open Google Maps with coordinates: $latitude, $longitude",
      );

      // Dapatkan lokasi pengguna saat ini untuk navigasi yang akurat
      Position? currentPosition;
      try {
        // Cek permission lokasi
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          // Dapatkan lokasi saat ini dengan akurasi tinggi
          currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          );
          print(
            "Current user location: ${currentPosition.latitude}, ${currentPosition.longitude}",
          );
        }
      } catch (e) {
        print("Could not get current location: $e");
        // Lanjutkan tanpa lokasi saat ini
      }

      // List of URLs to try in order of preference
      List<String> urlsToTry = [];

      // Jika ada lokasi pengguna, gunakan navigasi dengan koordinat saja (tanpa nama tempat)
      if (currentPosition != null) {
        urlsToTry.addAll([
          // URL navigasi dengan koordinat saja
          'https://www.google.com/maps/dir/${currentPosition.latitude},${currentPosition.longitude}/$latitude,$longitude',
          // Geo scheme dengan navigasi
          'google.navigation:q=$latitude,$longitude&mode=d',
          // Intent untuk Google Maps app dengan navigasi
          'geo:${currentPosition.latitude},${currentPosition.longitude}?q=$latitude,$longitude',
        ]);
      }

      // Tambahkan URL fallback dengan koordinat saja
      urlsToTry.addAll([
        // URL navigasi standar (Google akan coba deteksi lokasi otomatis)
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
        // URL pencarian lokasi dengan koordinat saja
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        // URL direct ke koordinat
        'https://www.google.com/maps/@$latitude,$longitude,15z',
        // URL sederhana
        'https://maps.google.com/?q=$latitude,$longitude',
      ]);

      bool success = false;
      String lastError = '';

      for (String url in urlsToTry) {
        try {
          print("Trying URL: $url");
          final uri = Uri.parse(url);

          if (await canLaunchUrl(uri)) {
            await launchUrl(
              uri,
              mode:
                  url.startsWith('geo:') || url.startsWith('google.navigation:')
                      ? LaunchMode.externalApplication
                      : LaunchMode.externalApplication,
            );
            success = true;
            print("Successfully opened: $url");
            break;
          } else {
            print("Cannot launch URL: $url");
          }
        } catch (e) {
          lastError = e.toString();
          print("Error with URL $url: $e");
          continue;
        }
      }

      if (!success) {
        throw Exception(
          'Tidak dapat membuka Google Maps. Error terakhir: $lastError',
        );
      }
    } catch (e) {
      print("Error opening Google Maps: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka Google Maps: $e'),
          action: SnackBarAction(
            label: 'Salin Koordinat',
            onPressed: () {
              // Copy coordinates to clipboard as fallback
              final coordinates = '$latitude, $longitude';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Koordinat disalin: $coordinates')),
              );
            },
          ),
        ),
      );
    }
  }

  // Method alternatif untuk membuka dengan nama tempat
  static Future<void> openInGoogleMapsWithQuery({
    required BuildContext context,
    required String query,
  }) async {
    try {
      print("Opening Google Maps with query: $query");

      // Encode query untuk URL
      String encodedQuery = Uri.encodeComponent(query);

      // Daftar URL yang akan dicoba (prioritaskan nama tempat)
      List<String> urls = [
        // URL untuk menampilkan rute ke nama tempat
        'https://www.google.com/maps/dir/?api=1&destination=$encodedQuery&travelmode=driving',
        // URL pencarian dengan nama tempat
        'https://www.google.com/maps/search/?api=1&query=$encodedQuery',
        // URL sederhana
        'https://maps.google.com/?q=$encodedQuery',
        // Geo scheme (fallback)
        'geo:0,0?q=$encodedQuery',
      ];

      bool opened = false;
      for (String url in urls) {
        print("Trying to open: $url");

        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          opened = true;
          print("Successfully opened: $url");
          break;
        }
      }

      if (!opened) {
        // Fallback ke browser
        String browserUrl =
            'https://www.google.com/maps/search/?api=1&query=$encodedQuery';
        await launchUrl(
          Uri.parse(browserUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      print("Error opening Google Maps: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka Google Maps: ${e.toString()}')),
      );
    }
  }
}
