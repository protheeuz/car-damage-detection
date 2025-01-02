import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://192.168.20.136:5000';
  // static const String _baseUrl = 'http://10.0.2.2:5000';  // Untuk Android Emulator
  // static const String _baseUrl = 'http://localhost:5000';  // Untuk iOS Simulator
  // static const String _baseUrl = 'http://ip:5000';  // Untuk device fisik

  /// Mengirim gambar ke model utk mendapatkan hasil deteksi kerusakan
  static Future<Map<String, dynamic>> sendImageToModel(File imageFile) async {
    final url = Uri.parse('$_baseUrl/detect_damage');
    final request = http.MultipartRequest('POST', url)
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ));

    try {
      final streamedResponse = await request.send();
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
    } catch (e) {
      throw Exception('Error saat mengirim gambar: $e');
    }
  }

  /// Mengkonversi base64 string ke Image
  static Image? base64ToImage(String base64String) {
    try {
      return Image.memory(base64Decode(base64String));
    } catch (e) {
      print('Error converting base64 to image: $e');
      return null;
    }
  }
}