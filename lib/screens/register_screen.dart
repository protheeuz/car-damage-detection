import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:debenih_release/services/api_service.dart';
import 'package:debenih_release/widgets/customcircular.dart';

import '../constant.dart';
import '../constants/constants.dart';
import '../widgets/customcircular.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _namaLengkapController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final ApiService _apiService = ApiService();

  Future<void> _register() async {
  String username = _usernameController.text.trim();
  String namaLengkap = _namaLengkapController.text.trim();
  String password = _passwordController.text.trim();

  if (username.isEmpty || namaLengkap.isEmpty || password.isEmpty) {
    _showCupertinoDialog("Error", "Semua field harus diisi");
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    bool success = await _apiService.register(username, namaLengkap, password);
    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      _showCupertinoDialog(
          "Error", "Registrasi gagal. Username sudah digunakan.");
    }
  } catch (e) {
    _showCupertinoDialog(
        "Error", "Terjadi kesalahan saat registrasi. Silakan coba lagi.");
  }

  setState(() {
    _isLoading = false;
  });
}


  void _showCupertinoDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  height: 50,
                ),
                const Text(
                  "Daftar",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 25,
                    fontFamily: 'Poppins',
                  ),
                ),
                Image.asset(
                  "assets/images/register.jpg",
                  height: 250,
                  width: double.infinity,
                ),
                const Text(
                  "Buat akun baru di sini",
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  "Username",
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.black12,
                      ),
                      color: Colors.grey[100],
                      borderRadius:
                          const BorderRadius.all(Radius.circular(10))),
                  child: TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Masukkan Username',
                        contentPadding: EdgeInsets.all(10)),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  "Nama Lengkap",
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.black12,
                      ),
                      color: Colors.grey[100],
                      borderRadius:
                          const BorderRadius.all(Radius.circular(10))),
                  child: TextField(
                    controller: _namaLengkapController,
                    decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Masukkan Nama Lengkap',
                        contentPadding: EdgeInsets.all(10)),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  "Kata Sandi",
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Poppins',
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.black12,
                      ),
                      color: Colors.grey[100],
                      borderRadius:
                          const BorderRadius.all(Radius.circular(10))),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Masukkan Kata Sandi',
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 15, horizontal: 10),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                _isLoading
                    ? const Center(
                        child: CustomCircularProgressIndicator(
                          imagePath: 'assets/logo/circularcustom.png', size:25
                        ),
                      )
                    : InkWell(
                        onTap: _register,
                        borderRadius: BorderRadius.circular(5.0),
                        child: Container(
                          height: 45,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5.0),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF5B86E5),
                                Color(0xFF36D1DC)
                              ], // Biru ke Ungu
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                offset: Offset(0, 4),
                                blurRadius: 5.0,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "Daftar",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                const SizedBox(
                  height: 8,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Sudah punya akun? ",
                      style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                          fontFamily: 'Poppins',
                          color: Colors.grey),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()));
                      },
                      child: const Text(
                        "Masuk di sini ",
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: kPrimaryColor,
                      ),
                    ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}