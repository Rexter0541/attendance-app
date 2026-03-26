// ignore_for_file: prefer_single_quotes

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/login_page.dart';
import '../pages/home_page.dart';
import '../models/employee.dart';

class SplashAnim extends StatefulWidget {
  const SplashAnim({super.key});

  @override
  State<SplashAnim> createState() => _SplashAnimState();
}

class _SplashAnimState extends State<SplashAnim> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;
  late Animation<double> _textOpacity;

  static const Color kPrimaryText = Color(0xFF1E293B);
  static const Color kAccentColor = Color(0xFF4F46E5);
  static const Color kBgTop = Color(0xFFF8FAFC);
  static const Color kBgBottom = Color(0xFFEEF2FF);

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 0.9, curve: Curves.easeIn)),
    );

    _mainController.forward();
    _runNavigation();
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.05);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeTween = Tween<double>(begin: 0.0, end: 1.0);

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: SlideTransition(
            position: animation.drive(tween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 800),
    );
  }

  // =====================================================
  // 🧭 CRITICAL UPDATE: Navigation Logic
  // =====================================================
  Future<void> _runNavigation() async {
    // 1. Instantly check SharedPreferences before the animation delay
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    final int? lastTimestamp = prefs.getInt('last_action_timestamp');
    bool sessionExpired = false;

    if (lastTimestamp != null) {
      final lastAction = DateTime.fromMillisecondsSinceEpoch(lastTimestamp);
      final difference = DateTime.now().difference(lastAction);
      
      // If time has passed (using your 5s test duration)
      if (difference >= const Duration(seconds: 5)) { 
        sessionExpired = true;
      }
    }

    // 2. Clear state IMMEDIATELY if expired
    if (sessionExpired) {
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('userId');
      await prefs.remove('userName');
      await prefs.remove('last_action_timestamp');
    }

    // 3. Now wait for the splash delay
    await Future.delayed(const Duration(seconds: 4));
    
    if (!mounted) return;

    // 4. Final Decision
    // We re-check the key. If we cleared it in Step 2, this will be false.
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn && !sessionExpired) {
      final String? savedId = prefs.getString('userId');
      final String? savedName = prefs.getString('userName');

      if (savedId != null && savedName != null) {
        Navigator.of(context).pushReplacement(
          _createRoute(HomePage(
            employee: Employee(id: savedId, name: savedName),
          )),
        );
        return;
      }
    }

    // 5. Force Login
    Navigator.of(context).pushReplacement(_createRoute(const LoginPage()));
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBgTop, kBgBottom],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlideTransition(
              position: _logoSlide,
              child: FadeTransition(
                opacity: _logoOpacity,
                child: _buildProLogo(),
              ),
            ),
            const SizedBox(height: 50),
            FadeTransition(
              opacity: _textOpacity,
              child: Column(
                children: [
                  const Text(
                    'ATTENDANCE APP',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 10.0,
                      color: kPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 40,
                    child: LinearProgressIndicator(
                      backgroundColor: kAccentColor.withAlpha(26),
                      color: kAccentColor,
                      minHeight: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProLogo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: kPrimaryText.withAlpha(20),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: kAccentColor.withAlpha(13),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: 100,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}