import 'package:debenih_release/constant.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:debenih_release/services/api_service.dart';
import 'package:debenih_release/widgets/customcircular.dart';

import '../constants/constants.dart';
import '../widgets/customcircular.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final ApiService _apiService = ApiService();
  final storage = const FlutterSecureStorage();

  Future<void> _login() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showCupertinoDialog("Error", "Username dan password tidak boleh kosong");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _apiService.login(username, password);
      if (user != null) {
        await storage.write(key: 'access_token', value: user.accessToken);
        await storage.write(key: 'user_id', value: user.userId.toString());
        await storage.write(key: 'username', value: user.username);
        await storage.write(key: 'nama_lengkap', value: user.namaLengkap);
        Navigator.pushReplacementNamed(context, '/home', arguments: user);
      } else {
        _showCupertinoDialog("Error", "Gagal login. Username atau password salah.");
      }
    } catch (e) {
      _showCupertinoDialog(
          "Error", "Terjadi kesalahan saat login. Silakan coba lagi.");
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
                  "Masuk",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 25,
                    fontFamily: 'Poppins',
                  ),
                ),
                Image.asset(
                  "assets/images/login.jpg",
                  height: 250,
                  width: double.infinity,
                ),
                const Text(
                  "Dapatkan akses login dari sini",
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
                            size: 20),
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
                            imagePath: 'assets/logo/circularcustom.png', size: 25),
                      )
                    : InkWell(
                        onTap: _login,
                        borderRadius: BorderRadius.circular(5.0),
                        child:Container(
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
                              "Masuk",
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
                  height: 20,
                ),
                Align(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Belum punya akun?",
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const RegisterScreen()));
                        },
                        child: const Text(
                          "Daftar di sini",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: kPrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}