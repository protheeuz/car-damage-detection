import 'dart:io';
import 'package:camera/camera.dart';
import 'package:camera_360/camera_360.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import '../services/api_service.dart';
import 'prediction_screen.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  late AnimationController _animationController;
  bool _isLoading = false;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    if (cameras != null && cameras!.isNotEmpty) {
      _cameraController = CameraController(cameras![0], ResolutionPreset.max);
      try {
        await _cameraController?.initialize();
        setState(() {
          _isCameraInitialized = true;
        });
      } catch (e) {
        _showErrorDialog('Failed to initialize camera: $e');
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Fungsi untuk pengambilan gambar panorama 360 menggunakan camera_360
  Future<void> _startPanoramaCapture() async {
    // Gunakan widget Camera360 untuk menampilkan kamera panorama
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text("Panoramic Capture")),
          body: Camera360(
            userLoadingText: "Menyiapkan panorama...",
            userHelperText: "Arahkan kamera ke titik",
            userHelperTiltLeftText: "Miring ke kiri",
            userHelperTiltRightText: "Miring ke kanan",
            userSelectedCameraKey:
                2, // Pilih kamera dengan wide angle, jika tersedia
            cameraSelectorShow: true,
            cameraSelectorInfoPopUpShow: true,
            cameraSelectorInfoPopUpContent: const Text(
              "Pilih kamera dengan sudut pandang terlebar di bawah ini.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xffEFEFEF)),
            ),
            cameraNotReadyContent: const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                child: Text(
                  "Kamera belum siap.",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            onCaptureEnded: (data) {
              if (data['success'] == true) {
                XFile panorama = data['panorama'];
                print("Final image returned: ${panorama.toString()}");
                _navigateToPredictionScreen(File(panorama.path), data);
              } else {
                print("Final image failed");
              }
            },
            onCameraChanged: (cameraKey) {
              print("Camera changed ${cameraKey.toString()}");
            },
            onProgressChanged: (newProgressPercentage) {
              debugPrint(
                  "'Panorama360': Progress changed: $newProgressPercentage");
            },
          ),
        ),
      ),
    );
  }

  void _navigateToPredictionScreen(
      File imageFile, Map<String, dynamic> predictionResult) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PredictionScreen(
          imageFile: imageFile,
          predictionResult: predictionResult,
        ),
      ),
    );
  }

  Future<void> _predictFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      await _showVehicleInputDialog(imageFile);
    }
  }

  Future<void> _predictFromCamera() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      if (_isCapturing) {
        _showErrorDialog("Sedang mengambil gambar, harap tunggu...");
        return;
      }
      setState(() {
        _isCapturing = true;
      });
      try {
        final imageFile = await _cameraController!.takePicture();
        setState(() {
          _isCapturing = false;
        });
        await _showVehicleInputDialog(File(imageFile.path));
      } catch (e) {
        setState(() {
          _isCapturing = false;
        });
        _showErrorDialog("Gagal mengambil gambar dari kamera: $e");
      }
    } else {
      _showErrorDialog("Kamera belum terhubung atau tidak dapat diakses");
    }
  }

  Future<void> _showVehicleInputDialog(File imageFile) async {
    final TextEditingController platNomorController = TextEditingController();
    final TextEditingController tahunKendaraanController =
        TextEditingController();
    String selectedModel = "Honda";

    bool isFormValid() {
      return platNomorController.text.trim().isNotEmpty &&
          selectedModel.isNotEmpty &&
          tahunKendaraanController.text.trim().isNotEmpty &&
          RegExp(r'^\d{4}$').hasMatch(tahunKendaraanController.text.trim());
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Masukkan Data Kendaraan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: platNomorController,
                decoration: const InputDecoration(
                  labelText: "Plat Nomor",
                  hintText: "Contoh: B 1234 TYX",
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedModel,
                items: const [
                  DropdownMenuItem(value: "Honda", child: Text("Honda")),
                  DropdownMenuItem(value: "Toyota", child: Text("Toyota")),
                  DropdownMenuItem(
                      value: "Mitsubishi", child: Text("Mitsubishi")),
                  DropdownMenuItem(value: "Hyundai", child: Text("Hyundai")),
                  DropdownMenuItem(value: "Wuling", child: Text("Wuling")),
                  DropdownMenuItem(value: "Lainnya", child: Text("Lainnya")),
                ],
                onChanged: (value) {
                  selectedModel = value!;
                },
                decoration: const InputDecoration(labelText: "Model Kendaraan"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tahunKendaraanController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Tahun Kendaraan",
                  hintText: "Contoh: 2023",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () async {
                final platNomor = platNomorController.text.trim();
                final tahunKendaraan = tahunKendaraanController.text.trim();

                if (platNomor.isEmpty ||
                    selectedModel.isEmpty ||
                    tahunKendaraan.isEmpty) {
                  _showErrorDialog("Semua field harus diisi!");
                  return;
                }

                Navigator.pop(context);

                bool isVehicleSaved = await _apiService.addVehicle(
                  platNomor,
                  selectedModel,
                  int.parse(tahunKendaraan),
                );

                if (isVehicleSaved) {
                  try {
                    final prediction =
                        await _apiService.detectDamage(imageFile);
                    _navigateToPredictionScreen(imageFile, prediction!);
                  } catch (e) {
                    _showErrorDialog("Gagal melakukan pendeteksian: $e");
                  }
                } else {
                  _showErrorDialog("Gagal menyimpan data kendaraan.");
                }
              },
              child: const Text("Lanjutkan"),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final frameWidth = screenWidth * 0.95;
    final frameHeight = frameWidth * 1.60;
    const framePadding = 30.0;

    return Scaffold(
      backgroundColor: Colors.greenAccent,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                height: 120,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      spreadRadius: 2,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Pilih melalui Kamera & Galeri',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isCameraInitialized)
                      Center(
                        child: SizedBox(
                          width: frameWidth - framePadding * 3,
                          height: frameHeight - framePadding * 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      )
                    else
                      const Center(child: CircularProgressIndicator()),
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final scale = 1.0 + (_animationController.value * 0.05);
                        return Align(
                          alignment: Alignment.center,
                          child: Transform.scale(
                            scale: scale,
                            child: CustomPaint(
                              size: Size(frameWidth, frameHeight),
                              painter: FramePainter(padding: framePadding),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Container(
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      spreadRadius: 2,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Image.asset(
                        'assets/icons/gallery.png',
                        width: 30,
                        height: 30,
                      ),
                      onPressed: _predictFromGallery,
                    ),
                    IconButton(
                      icon: Image.asset(
                        'assets/icons/camera-switch.png',
                        width: 30,
                        height: 30,
                      ),
                      onPressed: () {
                        if (cameras != null && cameras!.length > 1) {
                          final cameraIndex =
                              cameras!.indexOf(_cameraController!.description);
                          final newIndex = (cameraIndex + 1) % cameras!.length;
                          _cameraController = CameraController(
                              cameras![newIndex], ResolutionPreset.max);
                          _cameraController!.initialize().then((_) {
                            if (!mounted) return;
                            setState(() {});
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 628,
            left: MediaQuery.of(context).size.width / 2 - 35,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        spreadRadius: 2,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Image.asset(
                      'assets/icons/scan.png',
                      width: 25,
                      height: 25,
                    ),
                    onPressed: _predictFromCamera,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: MediaQuery.of(context).size.width / 2 - 35,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        spreadRadius: 2,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Image.asset(
                      'assets/icons/panoramic.png',
                      width: 30,
                      height: 30,
                    ),
                    onPressed:
                        _startPanoramaCapture,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FramePainter extends CustomPainter {
  final double padding;

  FramePainter({this.padding = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const cornerLength = 30.0;

    canvas.drawLine(Offset(padding, padding),
        Offset(padding + cornerLength, padding), paint);
    canvas.drawLine(Offset(padding, padding),
        Offset(padding, padding + cornerLength), paint);

    canvas.drawLine(Offset(size.width - padding, padding),
        Offset(size.width - padding - cornerLength, padding), paint);
    canvas.drawLine(Offset(size.width - padding, padding),
        Offset(size.width - padding, padding + cornerLength), paint);

    canvas.drawLine(Offset(padding, size.height - padding),
        Offset(padding, size.height - padding - cornerLength), paint);
    canvas.drawLine(Offset(padding, size.height - padding),
        Offset(padding + cornerLength, size.height - padding), paint);

    canvas.drawLine(
        Offset(size.width - padding, size.height - padding),
        Offset(size.width - padding - cornerLength, size.height - padding),
        paint);
    canvas.drawLine(
        Offset(size.width - padding, size.height - padding),
        Offset(size.width - padding, size.height - padding - cornerLength),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
