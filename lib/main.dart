import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/detection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/prediction_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CarCare - Adhitya Febrdiansyah',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const OnBoardingScreen(),
        '/detection': (context) => const DetectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        // '/prediction': (context) => const PredictionScreen(imageFile: null,),
      },
    );
  }
}
