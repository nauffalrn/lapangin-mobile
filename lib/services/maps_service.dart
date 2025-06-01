import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class MapsService {
  // Validasi koordinat untuk memastikan koordinat valid
  static bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;

    // Koordinat valid untuk Indonesia:
    // Latitude: -11 sampai 6 (dari Pulau Rote sampai Pulau We)
    // Longitude: 95 sampai 141 (dari Sabang sampai Merauke)
    return lat >= -11.0 && lat <= 6.0 && lng >= 95.0 && lng <= 141.0;
  }

  // Method untuk membuka lokasi di Google Maps dengan validasi koordinat
  static Future<void> openInGoogleMapsWithLocation({
    required BuildContext context,
    required double? latitude,
    required double? longitude,
    String? placeName,
  }) async {
    print("Attempting to open Google Maps...");
    print("Received coordinates: lat=$latitude, lng=$longitude");
    print("Place name: $placeName");

    // Validasi koordinat
    if (!_isValidCoordinate(latitude, longitude)) {
      print("Invalid coordinates detected, using place name search instead");

      if (placeName != null && placeName.isNotEmpty) {
        await openInGoogleMapsWithQuery(
          context: context,
          query: placeName,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Koordinat lokasi tidak valid dan nama tempat tidak tersedia')),
        );
      }
      return;
    }

    try {
      print("Using validated coordinates: $latitude, $longitude");

      // List of URLs dengan prioritas koordinat yang valid
      List<String> urlsToTry = [];

      // Jika ada nama tempat, kombinasikan dengan koordinat untuk akurasi
      if (placeName != null && placeName.isNotEmpty) {
        String encodedPlaceName = Uri.encodeComponent(placeName);
        urlsToTry.addAll([
          // URL pencarian dengan nama tempat dan koordinat untuk verifikasi
          'https://www.google.com/maps/search/?api=1&query=$encodedPlaceName+near+$latitude,$longitude',
          // URL rute ke koordinat dengan nama sebagai label
          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
          // URL pencarian nama tempat saja
          'https://www.google.com/maps/search/?api=1&query=$encodedPlaceName',
        ]);
      }

      // URL fallback dengan koordinat
      urlsToTry.addAll([
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        'https://www.google.com/maps/@$latitude,$longitude,15z',
        'https://maps.google.com/?q=$latitude,$longitude',
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
        throw Exception('Tidak dapat membuka Google Maps. Error: $lastError');
      }
    } catch (e) {
      print("Error opening Google Maps: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka Google Maps: $e'),
          action: SnackBarAction(
            label: 'Coba Nama',
            onPressed: () {
              if (placeName != null && placeName.isNotEmpty) {
                openInGoogleMapsWithQuery(context: context, query: placeName);
              }
            },
          ),
        ),
      );
    }
  }

  // Method untuk navigasi (masih menggunakan koordinat jika valid)
  static Future<void> openInGoogleMaps({
    required BuildContext context,
    required double? latitude,
    required double? longitude,
    String? placeName,
  }) async {
    // Validasi koordinat terlebih dahulu
    if (!_isValidCoordinate(latitude, longitude)) {
      print("Invalid coordinates for navigation, using place name search");

      if (placeName != null && placeName.isNotEmpty) {
        await openInGoogleMapsWithQuery(
          context: context,
          query: placeName,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Koordinat tidak valid untuk navigasi')),
        );
      }
      return;
    }

    try {
      print("Starting navigation to: $latitude, $longitude");

      // Dapatkan lokasi pengguna untuk navigasi yang akurat
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
          print("Current location: ${currentPosition.latitude}, ${currentPosition.longitude}");
        }
      } catch (e) {
        print("Could not get current location: $e");
      }

      List<String> urlsToTry = [];

      // Jika ada lokasi pengguna, gunakan navigasi dengan koordinat
      if (currentPosition != null) {
        urlsToTry.addAll([
          'https://www.google.com/maps/dir/${currentPosition.latitude},${currentPosition.longitude}/$latitude,$longitude',
          'google.navigation:q=$latitude,$longitude&mode=d',
        ]);
      }

      // URL navigasi standar
      urlsToTry.addAll([
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        'https://maps.google.com/?q=$latitude,$longitude',
      ]);

      bool success = false;
      for (String url in urlsToTry) {
        try {
          print("Trying navigation URL: $url");
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            success = true;
            break;
          }
        } catch (e) {
          print("Error with navigation URL $url: $e");
          continue;
        }
      }

      if (!success) {
        throw Exception('Tidak dapat memulai navigasi');
      }
    } catch (e) {
      print("Error in navigation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memulai navigasi: $e')),
      );
    }
  }

  // Method untuk pencarian berdasarkan nama/query
  static Future<void> openInGoogleMapsWithQuery({
    required BuildContext context,
    required String query,
  }) async {
    try {
      print("Opening Google Maps with query: $query");

      // Encode query untuk URL
      String encodedQuery = Uri.encodeComponent(query);

      // Daftar URL yang akan dicoba dengan prioritas pencarian nama
      List<String> urls = [
        // URL pencarian dengan nama tempat (prioritas utama)
        'https://www.google.com/maps/search/?api=1&query=$encodedQuery',
        // URL rute ke nama tempat
        'https://www.google.com/maps/dir/?api=1&destination=$encodedQuery&travelmode=driving',
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
        String browserUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedQuery';
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
