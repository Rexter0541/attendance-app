import 'dart:async';
import 'package:flutter/material.dart';
import '../pages/login_page.dart';

class SplashLocationPage extends StatefulWidget {
  const SplashLocationPage({super.key});

  @override
  State<SplashLocationPage> createState() => _SplashLocationPageState();
}

class _SplashLocationPageState extends State<SplashLocationPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rippleAnimation;
  late Animation<double> _iconAnimation;
  late Animation<double> _rotationAnimation;

  bool _showLogo = true;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _iconAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _rotationAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    _runAppSequence();
  }

  Future<void> _runAppSequence() async {
    // Initial logo display
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _showLogo = false);

    // Scanning phase
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() => _isSuccess = true);

    // Brief pause on success before navigation
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
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
            colors: [Color(0xFFF8FAFC), Color(0xFFDFE7EF)],
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: _showLogo ? _buildLogoView() : _buildLocationView(),
        ),
      ),
    );
  }

  Widget _buildLogoView() {
    return Column(
      key: const ValueKey('logo_view'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 10,
              )
            ],
          ),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1000),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Image.asset('assets/icon/app_icon.png', width: 160),
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          'ATTENDANCE APP',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 50,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationView() {
    return Column(
      key: const ValueKey('location_view'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Scanner Animation Section
        SizedBox(
          height: 220,
          width: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!_isSuccess)
                ...List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _rippleAnimation,
                    builder: (context, child) {
                      double delay = index * 0.3;
                      double progress =
                          (_rippleAnimation.value + delay) % 1.0;

                      return Container(
                        width: 200 * progress,
                        height: 200 * progress,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF6C63FF)
                                .withValues(alpha: 1 - progress),
                            width: 2,
                          ),
                        ),
                      );
                    },
                  );
                }),

              if (!_isSuccess)
                RotationTransition(
                  turns: _rotationAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6C63FF),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),

              ScaleTransition(
                scale: _iconAnimation,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isSuccess
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Icon(
                      _isSuccess
                          ? Icons.verified_rounded
                          : Icons.location_on_rounded,
                      key: ValueKey(_isSuccess),
                      color: _isSuccess
                          ? Colors.green
                          : const Color(0xFF6C63FF),
                      size: 60,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 50),

        // Static Text Section (No animation rebuild)
        Text(
          _isSuccess ? 'Identity Verified' : 'Securing Location',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _isSuccess
                ? Colors.green.shade700
                : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSuccess ? 'Welcome back!' : 'Syncing with company server...',
          style: TextStyle(
            fontSize: 14,
            color: Colors.blueGrey.shade400,
          ),
        ),
      ],
    );
  }
}