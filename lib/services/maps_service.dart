import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class MapsService {
  static Future<void> openInGoogleMaps({
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

      // Dapatkan lokasi pengguna untuk navigasi yang lebih akurat
      Position? currentPosition;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          );
        }
      } catch (e) {
        print("Could not get current location for query: $e");
      }

      List<String> urlsToTry = [];

      final encodedQuery = Uri.encodeComponent(query);

      // Jika ada lokasi saat ini, buat URL navigasi
      if (currentPosition != null) {
        urlsToTry.addAll([
          'https://www.google.com/maps/dir/${currentPosition.latitude},${currentPosition.longitude}/$encodedQuery',
          'geo:${currentPosition.latitude},${currentPosition.longitude}?q=$encodedQuery',
        ]);
      }

      // URL fallback
      urlsToTry.addAll([
        'https://www.google.com/maps/search/?api=1&query=$encodedQuery',
        'https://maps.google.com/?q=$encodedQuery',
        'geo:0,0?q=$encodedQuery',
      ]);

      bool success = false;

      for (String url in urlsToTry) {
        try {
          print("Trying query URL: $url");
          final uri = Uri.parse(url);

          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            success = true;
            print("Successfully opened query: $url");
            break;
          }
        } catch (e) {
          print("Error with query URL $url: $e");
          continue;
        }
      }

      if (!success) {
        throw Exception('Tidak dapat membuka Google Maps dengan pencarian');
      }
    } catch (e) {
      print("Error opening Google Maps with query: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuka Google Maps: $e')));
    }
  }
}
