import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ ADD THIS
import 'firebase_options.dart';
import 'screens/auth_checker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase init (existing mo)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Supabase init (ADD THIS)
  await Supabase.initialize(
    url: 'https://bullixmbvbtbcbujssjl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1bGxpeG1idmJ0YmNidWpzc2psIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM2MzA3MzksImV4cCI6MjA4OTIwNjczOX0.SgOgtO4eDw_8ZzMgvvpgWEi6V8HDb5oTISos_NOx474',
  );

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
      home: const AuthChecker(),
    );
  }
}