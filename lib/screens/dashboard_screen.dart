import 'package:car_damage_detection/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'detection_screen.dart';
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String namaLengkap = "Pengguna";
  String role = "Unknown";
  bool isLoading = true;
  String selectedRole = 'admin';

  List<Map<String, dynamic>> detectionResults = [];

  Map<String, List<String>> roleAccess = {
    'pemilik': ["Dashboard", "Riwayat", "Atur Pengguna"],
    'montir': ["Riwayat"],
    'admin': ["Dashboard", "Deteksi", "Riwayat", "Atur Pengguna"],
    'pelanggan': ["Dashboard","Deteksi", "Riwayat"],
  };

  Map<String, List<String>> dashboardMenuAccess = {
    'pemilik': ["Riwayat Hasil", "Atur Pengguna", "Keluar"],
    'montir': ["Riwayat Hasil", "Keluar"],
    'admin': ["Pendeteksian", "Riwayat Hasil", "Atur Pengguna", "Keluar"],
    'pelanggan': ["Pendeteksian", "Riwayat Hasil", "Keluar"],
  };

  List<String> get availableCategories {
    return roleAccess[role.toLowerCase()] ?? [];
  }

  List<Map<String, String>> get availableDashboardMenu {
    final allowedMenuItems = dashboardMenuAccess[role.toLowerCase()] ?? [];
    return dashboardMenu
        .where((menu) => allowedMenuItems.contains(menu["label"]))
        .toList();
  }

  final List<String> categories = [
    "Dashboard",
    "Deteksi",
    "Riwayat",
    "Atur Pengguna"
  ];
  int selectedCategoryIndex = 0;

  final List<Map<String, String>> dashboardMenu = [
    {"icon": "assets/images/menu1.png", "label": "Pendeteksian"},
    {"icon": "assets/images/menu2.png", "label": "Riwayat Hasil"},
    {"icon": "assets/images/menu3.png", "label": "Atur Pengguna"},
    {"icon": "assets/images/menu4.png", "label": "Keluar"},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDetectionResults();
  }

  void _handleMenuTap(String? label) {
    if (label == "Pendeteksian") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DetectionScreen()),
      );
    } else if (label == "Riwayat Hasil") {
      setState(() {
        selectedCategoryIndex = 2;
      });
    } else if (label == "Atur Pengguna") {
      setState(() {
        selectedCategoryIndex = 3;
      });
    } else if (label == "Keluar") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else if (label == "Menu 4") {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Fitur Belum Tersedia"),
            content: const Text("Fitur ini sedang dalam pengembangan."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Menu $label diklik!")),
      );
    }
  }

  Future<void> _loadUserData() async {
    final storedName = await _storage.read(key: 'nama_lengkap') ?? "Guest";
    final storedRole = await _storage.read(key: 'role') ?? "Unknown";

    setState(() {
      namaLengkap = storedName;
      role = storedRole;
      // Set initial selected category based on role
      if (!availableCategories.contains(categories[selectedCategoryIndex])) {
        selectedCategoryIndex = categories.indexOf(availableCategories.first);
      }
    });
  }

  Future<void> _loadDetectionResults() async {
    final results = await ApiService().getDetectionResults();
    if (results != null) {
      setState(() {
        detectionResults = results;
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 100,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.black,
                ),
                children: [
                  TextSpan(
                    text: "Haloooo,\n",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: namaLengkap,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              role, // Role pengguna
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Kategori",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  categories.length,
                  (index) => availableCategories.contains(categories[index])
                      ? GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedCategoryIndex = index;
                            });
                          },
                          child: _CategoryButton(
                            title: categories[index],
                            isActive: selectedCategoryIndex == index,
                          ),
                        )
                      : const SizedBox(), // Hide unavailable categories
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _buildContentBasedOnRole(),
            ),
            // Expanded(
            //   child: selectedCategoryIndex == 0
            //       ? _buildDashboardMenu()
            //       : selectedCategoryIndex == 1
            //           ? _buildDetectionResults()
            //           : selectedCategoryIndex == 2
            //               ? _buildHistoryResults()
            //               : _buildManageUser(),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardMenu() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: availableDashboardMenu.length,
      itemBuilder: (context, index) {
        final item = availableDashboardMenu[index];
        return GestureDetector(
          onTap: () {
            _handleMenuTap(item["label"]);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey[300]!,
                  blurRadius: 6,
                  spreadRadius: 2,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  item["icon"]!,
                  height: 60,
                  width: 60,
                ),
                const SizedBox(height: 8),
                Text(
                  item["label"]!,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentBasedOnRole() {
    // Check if current category is accessible for current role
    if (!availableCategories.contains(categories[selectedCategoryIndex])) {
      return const Center(
        child: Text(
          "Anda tidak memiliki akses ke halaman ini",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    switch (selectedCategoryIndex) {
      case 0: // Dashboard
        return _buildDashboardMenu();
      case 1: // Deteksi
        return _buildDetectionResults();
      case 2: // Riwayat
        return _buildHistoryResults();
      case 3: // Atur Pengguna
        return _buildManageUser();
      default:
        return const SizedBox();
    }
  }

  Widget _buildDetectionResults() {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DetectionScreen(),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          "Mulai Deteksi",
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildManageUser() {
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController namaLengkapController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tambah Pengguna Baru",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            _buildCustomTextField(
              controller: usernameController,
              label: "Username",
              hint: "Masukkan username",
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildCustomTextField(
              controller: namaLengkapController,
              label: "Nama Lengkap",
              hint: "Masukkan nama lengkap",
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 16),
            _buildCustomTextField(
              controller: passwordController,
              label: "Password",
              hint: "Masukkan password",
              icon: Icons.lock_outline,
              obscureText: true,
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: InputDecoration(
                labelText: "Pilih Peran",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedRole,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text("Admin")),
                    DropdownMenuItem(value: 'montir', child: Text("Montir")),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() {
                        selectedRole = value; // Update state here
                      });
                      print("Dropdown berubah: $selectedRole"); // Debug log
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  print("Role yang dipilih: $selectedRole"); // Debug log
                  final result = await ApiService().addUser(
                    usernameController.text,
                    namaLengkapController.text,
                    passwordController.text,
                    selectedRole,
                  );
                  if (result) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("User berhasil ditambahkan!")),
                    );
                    usernameController.clear();
                    namaLengkapController.clear();
                    passwordController.clear();
                    setState(() {
                      selectedRole = 'admin'; // Reset to default after success
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Gagal menambahkan user.")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.person_2_outlined),
                label: const Text(
                  "Tambah User",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      style: GoogleFonts.poppins(fontSize: 14),
    );
  }

  Widget _buildHistoryResults() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (detectionResults.isEmpty) {
      return const Center(
        child: Text(
          "Belum ada data riwayat deteksi.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text("No.")),
          DataColumn(label: Text("Model Kendaraan")),
          DataColumn(label: Text("Tahun Kendaraan")),
          DataColumn(label: Text("Plat Nomor")),
          DataColumn(label: Text("Kerusakan")),
          DataColumn(label: Text("Waktu")),
        ],
        rows: List.generate(
          detectionResults.length,
          (index) {
            final item = detectionResults[index];
            return DataRow(cells: [
              DataCell(Text("${index + 1}")),
              DataCell(Text(item["model_kendaraan"])),
              DataCell(Text(item["tahun_kendaraan"].toString())),
              DataCell(Text(item["plat_nomor"])),
              DataCell(Text(item["kerusakan"])),
              DataCell(Text(item["waktu"])),
            ]);
          },
        ),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  final String title;
  final bool isActive;

  const _CategoryButton({
    required this.title,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: DottedBorder(
        color: isActive ? Colors.greenAccent : Colors.grey,
        borderType: BorderType.RRect,
        dashPattern: const [6, 3],
        radius: const Radius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.green : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: isActive ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
