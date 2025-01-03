import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import '../services/api_service.dart';
import 'prediction_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  late AnimationController _animationController;
  bool _isLoading = false; // Flag untuk loading animasi
  bool _isCameraInitialized = false; // Flag untuk mengetahui status kamera

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    // Inisialisasi AnimationController
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

  void _navigateToPredictionScreen(File imageFile, Map<String, dynamic> predictionResult) {
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
      final file = File(pickedFile.path);
      setState(() {
        _isLoading = true;
      });
      try {
        final prediction = await ApiService.sendImageToModel(file);
        setState(() {
          _isLoading = false;
        });
        _navigateToPredictionScreen(file, prediction);
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog(e.toString());
      }
    }
  }

  Future<void> _predictFromCamera() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      setState(() {
        _isLoading = true;
      });
      try {
        final file = await _cameraController!.takePicture();
        final prediction = await ApiService.sendImageToModel(File(file.path));
        setState(() {
          _isLoading = false;
        });
        _navigateToPredictionScreen(File(file.path), prediction);
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog(e.toString());
      }
    } else {
      _showErrorDialog('Kamera belum terhubung atau tidak dapat diakses');
    }
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
    final frameWidth = screenWidth * 0.95; // Lebar frame kamera
    final frameHeight = frameWidth * 1.60; // Tinggi frame kamera (4:3)
    const framePadding = 30.0; // Padding antara frame dan kamera

    return Scaffold(
      backgroundColor: Colors.greenAccent,
      body: Stack(
        children: [
          // Layout utama (kamera + navbar)
          Column(
            children: [
              // Custom AppBar
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
              // Camera Preview with Frame
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Camera Preview
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
                    // Overlay with animated frame
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final scale = 1.0 + (_animationController.value * 0.05); // Animasi skala
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
              // Bottom Navbar
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
                    // Open Gallery Button
                    IconButton(
                      icon: Image.asset(
                        'assets/icons/gallery.png',
                        width: 30,
                        height: 30,
                      ),
                      onPressed: _predictFromGallery,
                    ),
                    // Switch Camera Button
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
          // Animasi loading dengan overlay blur
          if (_isLoading)
            Stack(
              children: [
                // Blur background
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
                // Loading animation
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Lottie.asset(
                      'assets/animations/loading-animation.json',
                      width: 150,
                      height: 150,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Custom Painter for Frame Lines
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

    // Korner atas kiri
    canvas.drawLine(Offset(padding, padding),
        Offset(padding + cornerLength, padding), paint);
    canvas.drawLine(Offset(padding, padding),
        Offset(padding, padding + cornerLength), paint);

    // Korner atas kanan
    canvas.drawLine(Offset(size.width - padding, padding),
        Offset(size.width - padding - cornerLength, padding), paint);
    canvas.drawLine(Offset(size.width - padding, padding),
        Offset(size.width - padding, padding + cornerLength), paint);

    // Korner bawah kiri
    canvas.drawLine(Offset(padding, size.height - padding),
        Offset(padding, size.height - padding - cornerLength), paint);
    canvas.drawLine(Offset(padding, size.height - padding),
        Offset(padding + cornerLength, size.height - padding), paint);

    // Korner bawah kanan
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