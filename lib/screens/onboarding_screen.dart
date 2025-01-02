import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/permission_helper.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  _OnBoardingScreenState createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  late PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    _pageController = PageController(initialPage: 0);
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Fungsi untuk menangani logika setelah onboarding selesai
  Future<void> _onDone() async {
    final cameraStatus = await Permission.camera.request();
    final storageStatus = await Permission.storage.request();

    debugPrint('Camera permission status: $cameraStatus');
    debugPrint('Storage permission status: $storageStatus');

    if (cameraStatus.isGranted && storageStatus.isGranted) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (cameraStatus.isPermanentlyDenied ||
        storageStatus.isPermanentlyDenied) {
      openAppSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions are required to proceed.')),
      );
    }
  }

  /// Fungsi untuk langsung ke halaman terakhir saat tombol "Skip" ditekan
  void _skipToLastPage() {
    setState(() {
      _pageIndex = demoData.length - 1;
    });
    _pageController.jumpToPage(demoData.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: _pageIndex != demoData.length - 1
                    ? TextButton(
                        onPressed: _skipToLastPage,
                        child: const Text(
                          'Skip',
                          style: TextStyle(color: Colors.greenAccent),
                        ),
                      )
                    : const SizedBox(),
              ),
              Expanded(
                child: PageView.builder(
                  itemCount: demoData.length,
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _pageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) => OnBoardContent(
                    animation: demoData[index].animation,
                    title: demoData[index].title,
                    description: demoData[index].description,
                    isLast: index == demoData.length - 1,
                    onGetStarted: _onDone,
                  ),
                ),
              ),
              Row(
                children: [
                  ...List.generate(
                    demoData.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: DotIndicator(
                        isActive: index == _pageIndex,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_pageIndex != demoData.length - 1)
                    SizedBox(
                      height: 55,
                      width: 55,
                      child: InkWell(
                        onTap: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.ease,
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 55,
                          width: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Colors.green, Colors.lightGreen],
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DotIndicator extends StatelessWidget {
  const DotIndicator({
    super.key,
    this.isActive = false,
  });

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isActive ? 12 : 4,
      width: 4,
      decoration: BoxDecoration(
        color:
            isActive ? Colors.greenAccent : Colors.greenAccent.withOpacity(0.4),
        borderRadius: const BorderRadius.all(
          Radius.circular(12),
        ),
      ),
    );
  }
}

class OnBoard {
  final String animation, title, description;
  final bool isLast;

  OnBoard({
    required this.animation,
    required this.title,
    required this.description,
    this.isLast = false,
  });
}

final List<OnBoard> demoData = [
  OnBoard(
    animation: "assets/animations/animation1.json",
    title: "Deteksi Kerusakan Kendaraan\nMenggunakan Aplikasi Kami",
    description: "Unggah foto dan biarkan AI kami menganalisis kerusakan pada kendaraan Anda!",
  ),
  OnBoard(
    animation: "assets/animations/animation2.json",
    title: "Deteksi Berbagai Jenis\nKerusakan Kendaraan",
    description:
        "Cukup unggah foto, dan sistem kami akan mengidentifikasi jenis kerusakan seperti retak, penyok, pecah kaca, dan lainnya.",
  ),
  OnBoard(
    animation: "assets/animations/animation3.json",
    title: "Menggunakan Teknologi AI",
    description:
        "Sistem kami menggunakan machine learning untuk deteksi kerusakan yang akurat dan tingkat keparahannya.",
  ),
  OnBoard(
    animation: "",
    title: "Deteksi dan bantu\nKlasifikasi Kerusakan Kendaraan",
    description:
        "Cukup unggah foto, dan biarkan sistem kami memberikan analisis terbaik untuk mengetahui tingkat kerusakan pada kendaraan Anda!",
  ),
];

class OnBoardContent extends StatelessWidget {
  const OnBoardContent({
    super.key,
    required this.animation,
    required this.title,
    required this.description,
    this.isLast = false,
    this.onGetStarted,
  });

  final String animation, title, description;
  final bool isLast;
  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!isLast)
          Lottie.asset(
            animation,
            height: 280,
            width: 200,
          ),
        if (isLast)
          Image.asset(
            'assets/images/image1.png',
            height: 280,
            width: 200,
          ),
        const SizedBox(height: 50),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: Theme.of(context).textTheme.headlineSmall?.fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize,
          ),
        ),
        const SizedBox(height: 25),
        if (isLast)
          ElevatedButton(
            onPressed: onGetStarted,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'MULAI PENDETEKSIAN',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
      ],
    );
  }
}
