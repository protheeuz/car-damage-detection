import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class PredictionScreen extends StatelessWidget {
  final File imageFile;
  final Map<String, dynamic> predictionResult;

  const PredictionScreen({
    super.key,
    required this.imageFile,
    required this.predictionResult,
  });

  @override
  Widget build(BuildContext context) {
    final List<dynamic> daftarKerusakan = predictionResult['daftar_kerusakan'] ?? [];
    final Map<String, dynamic> evaluationMetrics = predictionResult['evaluation_metrics'] ?? {};

    const List<String> damageLabels = [
      'retak', 'penyok', 'pecah kaca', 'lampu rusak', 'goresan', 'ban kempes'
    ];

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 4,
        title: const Text(
          'Hasil Deteksi Kerusakan',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(40),
            bottomRight: Radius.circular(40),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Frame for result image with bounding boxes
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.4,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: predictionResult['gambar_hasil'] != null
                    ? Image.memory(
                        base64Decode(predictionResult['gambar_hasil']),
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        imageFile,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Result Label
            const Text(
              'Hasil Deteksi:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Frame for detection results
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waktu Proses: ${predictionResult['waktu_proses'] ?? 'Unknown'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Jumlah Kerusakan: ${predictionResult['jumlah_kerusakan'] ?? '0'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Detail Kerusakan:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Menggunakan ListView untuk daftar kerusakan
                  ListView.builder(
                    shrinkWrap: true, // Agar tidak memperluas ukuran layar
                    physics: const NeverScrollableScrollPhysics(), // Tidak ada scroll tambahan
                    itemCount: daftarKerusakan.length,
                    itemBuilder: (context, index) {
                      final kerusakan = daftarKerusakan[index];
                      // Menampilkan rentang harga estimasi
                      String hargaEstimasi = kerusakan['harga_estimasi'] ?? 'Harga tidak tersedia';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tipe: ${kerusakan['tipe_kerusakan'] ?? 'Tidak Diketahui'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                'Tingkat Keparahan: ${kerusakan['tingkat_keparahan'] ?? 'Tidak Diketahui'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              Text(
                                'Confidence: ${kerusakan['confidence'] ?? 'Tidak Diketahui'}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Menampilkan rentang harga estimasi
                              Text(
                                'Harga Estimasi: $hargaEstimasi',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tabel Evaluasi Model
            if (evaluationMetrics.isNotEmpty) ...[
              const Text(
                'Evaluasi Model:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // Display Confusion Matrix as a Table inside SingleChildScrollView for horizontal scrolling
              if (evaluationMetrics['confusion_matrix'] != null) ...[
                const Text('Confusion Matrix:'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: List.generate(
                      damageLabels.length,
                      (index) => DataColumn(
                        label: Text(
                          damageLabels[index],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    rows: List.generate(
                      evaluationMetrics['confusion_matrix'].length,
                      (rowIndex) => DataRow(
                        cells: List.generate(
                          evaluationMetrics['confusion_matrix'][rowIndex].length,
                          (colIndex) => DataCell(
                            Text(
                              evaluationMetrics['confusion_matrix'][rowIndex][colIndex].toString(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              // Tampilkan metrik lainnya
              DataTable(
                columns: const [
                  DataColumn(label: Text('Metrik')),
                  DataColumn(label: Text('Nilai')),
                ],
                rows: [
                  DataRow(cells: [
                    const DataCell(Text('Akurasi')),
                    DataCell(Text(evaluationMetrics['accuracy'].toStringAsFixed(4))),
                  ]),
                  DataRow(cells: [
                    const DataCell(Text('Presisi')),
                    DataCell(Text(evaluationMetrics['precision'].toStringAsFixed(4))),
                  ]),
                  DataRow(cells: [
                    const DataCell(Text('Recall')),
                    DataCell(Text(evaluationMetrics['recall'].toStringAsFixed(4))),
                  ]),
                  DataRow(cells: [
                    const DataCell(Text('F1-Score')),
                    DataCell(Text(evaluationMetrics['f1_score'].toStringAsFixed(4))),
                  ]),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}