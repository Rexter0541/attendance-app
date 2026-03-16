// ignore_for_file: prefer_single_quotes

import 'dart:async';
import 'package:flutter/material.dart';
import '../pages/login_page.dart';

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

  // 🎨 OFFICIAL LGU PALETTE (Trustworthy Slate & Deep Indigo)
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

    // 1. Logo fades in
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    // 2. Logo slides up slightly (Elegant, not bouncy)
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );

    // 3. Text fades in later
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 0.9, curve: Curves.easeIn)),
    );

    _mainController.forward();
    _runNavigation();
  }

  // =====================================================
  // ⚡ CUSTOM SMOOTH TRANSITION ROUTE
  // =====================================================

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.05); // Subtle slide up
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
      transitionDuration: const Duration(milliseconds: 800), // Slightly slower for splash exit
    );
  }

  Future<void> _runNavigation() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    // Updated to use the smooth transition helper
    Navigator.of(context).pushReplacement(
      _createRoute(const LoginPage()),
    );
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
            // 🚀 STAGE 1: LOGO
            SlideTransition(
              position: _logoSlide,
              child: FadeTransition(
                opacity: _logoOpacity,
                child: _buildProLogo(),
              ),
            ),

            const SizedBox(height: 50),

            // 🚀 STAGE 2: TEXT & ACCENT
            FadeTransition(
              opacity: _textOpacity,
              child: Column(
                children: [
                  const Text(
                    "ATTENDANCE APP",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 10.0, // Clean, airy spacing
                      color: kPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Small clean progress indicator instead of a static bar
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
          // Multi-layered shadow for high-end depth
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