import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'firebase_options.dart';

// Screens
import 'screens/splash_anim.dart';
import 'pages/login_page.dart'; // Ensure this path is correct
import '../screens/admin/admin_panel.dart';   // ✅ Import your new Admin Panel

// Utils
import 'utils/session_manager.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Initialize Supabase
  await Supabase.initialize(
    url: 'https://vftmdeyhzelcfhqkicxh.supabase.co',
    anonKey: 'sb_publishable_46MY-f8b2FSvtFUNIJqJFw_AAt_dhxz',
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
        fontFamily: 'Inter', // Optional: Use Inter or Helvetica for that agency look
      ),
      
      // ⭐ THE UPDATE: SessionManager protects the entire app
      builder: (context, child) {
        return SessionManager(
          timeout: const Duration(minutes: 30),
          child: child!,
        );
      },

      // Define your routes for easy navigation
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashAnim(),
        '/login': (context) => const LoginPage(), // Assuming you have a LoginPage
        '/admin': (context) => const AdminPanel(), // ✅ Register the Admin Panel
      },
    );
  }
}