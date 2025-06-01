import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/lapangan_model.dart';
import 'dart:math';

class LapanganService {
  static Future<List<Lapangan>> getAllLapangan() async {
    try {
      print("Mengambil data lapangan dari: ${ApiConfig.baseUrl}/lapangan");

      // Gunakan headers dengan token
      final headers = await ApiConfig.getAuthHeaders();

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/lapangan'),
        headers: headers,
      );

      print("Status response: ${response.statusCode}");
      print(
        "Response body: ${response.body.substring(0, min(100, response.body.length))}...",
      );

      if (response.statusCode == 200) {
        try {
          var responseData = jsonDecode(response.body);
          List<Lapangan> result = [];

          print("Response type: ${responseData.runtimeType}");
          print("Response data: $responseData");

          // Handle berbagai format response
          if (responseData is List) {
            result = responseData.map((json) => Lapangan.fromJson(json)).toList();
          }
          // Response dalam bentuk objek dengan property data
          else if (responseData is Map && responseData.containsKey('data')) {
            List<dynamic> data = responseData['data'];
            result = data.map((json) => Lapangan.fromJson(json)).toList();
          }
          // Format lain
          else {
            print("Unexpected response format: $responseData");
            result = [];
          }

          print("Berhasil parse ${result.length} lapangan");
          return result;
        } catch (e) {
          print("Error parsing response: $e");
          throw Exception('Error parsing data: $e');
        }
      } else {
        throw Exception('Gagal mengambil data: ${response.statusCode}');
      }
    } catch (e) {
      print("Error di getAllLapangan: $e");
      throw Exception('Gagal mengambil data: $e');
    }
  }

  static Future<Lapangan> getLapanganById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/lapangan/$id'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Lapangan.fromJson(data['data']);
        } else {
          throw Exception('Lapangan tidak ditemukan');
        }
      } else {
        throw Exception('Gagal mengambil data lapangan');
      }
    } catch (e) {
      print("Error in getLapanganById: $e");
      throw Exception('Gagal mengambil data lapangan: $e');
    }
  }

  static Future<List<Lapangan>> searchLapangan(String keyword) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/lapangan/search?keyword=$keyword'),
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);

        // Handle berbagai format response
        if (responseData is Map && responseData.containsKey('data')) {
          List<dynamic> data = responseData['data'];
          return data.map((json) => Lapangan.fromJson(json)).toList();
        } else if (responseData is List) {
          return responseData.map((json) => Lapangan.fromJson(json)).toList();
        } else {
          throw Exception('Format response tidak sesuai');
        }
      } else {
        throw Exception('Gagal mencari lapangan: ${response.statusCode}');
      }
    } catch (e) {
      print("Error di searchLapangan: $e");
      throw Exception('Gagal mencari lapangan: $e');
    }
  }
}
