import 'package:flutter/material.dart';
import 'screens/splash_location.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Workforce Attendance',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashLocationPage(),
    );
  }
}