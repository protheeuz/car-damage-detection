import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.20.136:5000';
  final storage = const FlutterSecureStorage();

  /// Login Endpoint
  Future<UserModel?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      // Print detailed response information for debugging
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Print decoded data for debugging
        print('Decoded data: $data');

        // Validate required fields exist
        if (data['access_token'] == null ||
            data['nama_lengkap'] == null ||
            data['role'] == null) {
          print('Missing required fields in response');
          return null;
        }

        // Store the token and user info
        await storage.write(key: 'access_token', value: data['access_token']);
        await storage.write(key: 'nama_lengkap', value: data['nama_lengkap']);
        await storage.write(key: 'role', value: data['role']);

        // Create and return user model
        return UserModel.fromJson(data);
      } else {
        print('Login failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      print('Error during login: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Register Endpoint (Pelanggan Only)
  Future<bool> register(
      String username, String namaLengkap, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'nama_lengkap': namaLengkap,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      print('Register failed: ${response.statusCode} - ${response.body}');
      return false;
    }
  }

  /// Logout - Hapus Access Token dari Storage
  Future<void> logout() async {
    await storage.delete(key: 'access_token');
  }

  /// Save Detection Results Endpoint
  Future<bool> saveDetectionResults(Map<String, int> detectionCounts) async {
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      print('Access token not found!');
      return false;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/save_detection_results'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'detection_counts': detectionCounts,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      print(
          'Failed to save detection results: ${response.statusCode} - ${response.body}');
      return false;
    }
  }

  Future<bool> addVehicle(
      String platNomor, String modelKendaraan, int tahunKendaraan) async {
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      print('Access token not found!');
      return false;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/add_vehicle'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'plat_nomor': platNomor,
        'model_kendaraan': modelKendaraan,
        'tahun_kendaraan': '$tahunKendaraan',
      }),
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      print('Failed to add vehicle: ${response.statusCode} - ${response.body}');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getVehicle() async {
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      print('Access token not found!');
      return null;
    }

    final response = await http.get(
      Uri.parse('$baseUrl/get_vehicle'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print('Failed to get vehicle: ${response.statusCode} - ${response.body}');
      return null;
    }
  }

  Future<bool> updateVehicle(
      String platNomor, String modelKendaraan, int tahunKendaraan) async {
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      print('Access token not found!');
      return false;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/update_vehicle'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'plat_nomor': platNomor,
        'model_kendaraan': modelKendaraan,
        'tahun_kendaraan': tahunKendaraan,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      print(
          'Failed to update vehicle: ${response.statusCode} - ${response.body}');
      return false;
    }
  }

  /// Detect Damage Endpoint
  /// Detect Damage Endpoint
Future<Map<String, dynamic>?> detectDamage(File imageFile) async {
  final token = await storage.read(key: 'access_token');
  if (token == null) {
    throw Exception('Token tidak ditemukan. Harap login ulang.');
  }

  print('Mengirim gambar ke API...');
  final request =
      http.MultipartRequest('POST', Uri.parse('$baseUrl/detect_damage'));

  request.headers.addAll({
    'Authorization': 'Bearer $token',
  });

  request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

  try {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('Response Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      // Print the response for debugging
      print('Decoded response: $data');

      if (data['status'] == 'success') {
        // Check for detection results, including price range
        var daftarKerusakan = data['daftar_kerusakan'] as List;
        for (var damage in daftarKerusakan) {
          if (damage['harga_estimasi'] is String) {
            // If harga_estimasi is a string (e.g., "Harga tidak tersedia")
            continue;
          }
          // If harga_estimasi is a range, split it to make it more readable
          if (damage['harga_estimasi'] != null) {
            String hargaEstimasi = damage['harga_estimasi'];
            damage['harga_estimasi'] = 'Rp $hargaEstimasi';
          }
        }

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
      throw Exception(
          'Gagal mendapatkan prediksi. Status code: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error during detection: $e');
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

  static Future<Map<String, dynamic>> sendImageToModel(File imageFile) async {
    final url = Uri.parse('$baseUrl/detect_damage');

    // Validasi ukuran file sebelum dikirim
    if (await _isFileTooLarge(imageFile)) {
      throw Exception(
          'File terlalu besar, harap pilih gambar yang lebih kecil.');
    }

    final request = http.MultipartRequest('POST', url)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      // Menambahkan timeout untuk request
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
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
        throw Exception(
            'Gagal mendapatkan prediksi. Status code: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception(
          'Tidak dapat terhubung ke server. Pastikan server berjalan dan dapat diakses.');
    }
  }

  Future<List<Map<String, dynamic>>?> getDetectionResults() async {
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      print('Access token not found!');
      return null;
    }

    final response = await http.get(
      Uri.parse('$baseUrl/get_detection_results'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['data']);
    } else {
      print('Failed to get detection results: ${response.statusCode}');
      return null;
    }
  }

  Future<bool> addUser(
    String username,
    String namaLengkap,
    String password,
    String role,
  ) async {
    final token = await storage.read(key: 'access_token');
    if (token == null) {
      print('Access token not found!');
      return false;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/add_user'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'nama_lengkap': namaLengkap,
        'password': password,
        'role': role,
      }),
    );

    return response.statusCode == 201;
  }
}
