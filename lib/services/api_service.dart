import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

import '../models/user_model.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.2:5000';
  final storage = const FlutterSecureStorage();

  final StreamController<Map<String, dynamic>> _detectionController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get detectionStream =>
      _detectionController.stream;

  Future<UserModel?> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('${baseUrl}login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await storage.write(key: 'access_token', value: data['access_token']);
      return UserModel.fromJson(data);
    } else {
      return null;
    }
  }

  Future<bool> register(
      String username, String namaLengkap, String password) async {
    final response = await http.post(
      Uri.parse('${baseUrl}register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'nama_lengkap': namaLengkap,
        'password': password,
      }),
    );

    return response.statusCode == 201;
  }


  Future<void> logout() async {
    await storage.delete(key: 'access_token');
  }

  Future<void> saveDetectionResults(
      UserModel user, Map<String, int> detectionCounts) async {
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      return;
    }

    final response = await http.post(
      Uri.parse('${baseUrl}save_detection_results'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'detection_counts': detectionCounts,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal menyimpan hasil deteksi');
    }
  }


  Future<Map<String, dynamic>?> getUserStatistics(String userId) async {
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      return null;
    }

    final response = await http.get(
      Uri.parse('${baseUrl}user_statistics'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to fetch user statistics');
    }
  }

  Future<List<Map<String, dynamic>>> getUserReports(String userId) async {
    final token = await storage.read(key: 'access_token');
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/user_reports?user_id=$userId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to load reports');
    }
  }

  static Future<Map<String, dynamic>> sendImageToModel(File imageFile) async {
    final url = Uri.parse('$baseUrl/detect_damage');
    
    // Validasi ukuran file sebelum dikirim
    if (await _isFileTooLarge(imageFile)) {
      throw Exception('File terlalu besar, harap pilih gambar yang lebih kecil.');
    }

    final request = http.MultipartRequest('POST', url)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      // Menambahkan timeout untuk request
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Validasi response
        if (data['status'] == 'success') {
          return {
            'status': data['status'],
            'waktu_proses': data['waktu_proses'],
            'jumlah_kerusakan': data['jumlah_kerusakan'],
            'daftar_kerusakan': data['daftar_kerusakan'],
            'gambar_hasil': data['gambar_hasil'], 
          };
        } else {
          throw Exception('Gagal mendapatkan prediksi: ${data['pesan']}');
        }
      } else {
        throw Exception('Gagal mendapatkan prediksi. Status code: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Pastikan server berjalan dan dapat diakses.');
    }
  }


  /// Mengecek apakah file terlalu besar untuk dikirim
  static Future<bool> _isFileTooLarge(File imageFile) async {
    final fileSize = await imageFile.length();
    const maxSize = 5 * 1024 * 1024; 
    return fileSize > maxSize;
  }

  /// Mengkonversi base64 string ke Image
  static Image? base64ToImage(String base64String) {
    try {
      return Image.memory(base64Decode(base64String));
    } catch (e) {
      debugPrint('Error converting base64 to image: $e');
      return null;
    }
  }
}