import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';

// Screens
import 'screens/splash_anim.dart';
import 'pages/login_page.dart';
import 'screens/admin/admin_panel.dart';

// Utils
import 'utils/session_manager.dart';

// ✅ Sync this value between Splash and SessionManager
const Duration kSessionTimeout = Duration(minutes: 10); // 10 minutes

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Workforce Attendance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      
      builder: (context, child) {
        return SessionManager(
          timeout: kSessionTimeout, // ✅ Using the global constant
          child: child!,
        );
      },

      initialRoute: '/',
      routes: {
        '/': (context) => const SplashAnim(),
        '/login': (context) => const LoginPage(),
        '/admin': (context) => const AdminPanel(),
      },
    );
  }
}