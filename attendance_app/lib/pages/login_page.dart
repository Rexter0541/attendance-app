import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee.dart';
import '../screens/verification_page.dart';
import '../connection_status_indicator.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final userController = TextEditingController();
  final passController = TextEditingController();

  bool _isLoading = false;

  static const Color backgroundColor = Color(0xFFF8FAFC);

  // =====================================================
  // LOGIN FUNCTION (UNCHANGED)
  // =====================================================
  Future<void> login() async {
    if (userController.text.isEmpty || passController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: userController.text.trim(),
        password: passController.text.trim(),
      );

      String uid = credential.user!.uid;

      DocumentSnapshot employeeDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(uid)
          .get();

      if (!employeeDoc.exists) {
        _showError("Employee profile not found");
        setState(() => _isLoading = false);
        return;
      }

      Employee employee = Employee(
        id: uid,
        name: employeeDoc["name"] ?? "Employee",
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) =>
              VerificationPage(employee: employee),
          transitionsBuilder: (context, anim, secAnim, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e.code);
    } catch (e) {
      _showError("Login failed. Check credentials or connection.");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _handleAuthError(String code) {
    String message;
    switch (code) {
      case 'user-not-found':
        message = 'User not found';
        break;
      case 'wrong-password':
        message = 'Wrong password';
        break;
      case 'invalid-email':
        message = 'Invalid email';
        break;
      default:
        message = 'Login failed. Please try again.';
    }
    _showError(message);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  void dispose() {
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              // ⭐ ANIMATED ICON (MATCHING SPLASH SCREEN)
              _buildAnimatedHeaderIcon(),

              const SizedBox(height: 15),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(width: 12),
                  ConnectionStatusIndicator(),
                ],
              ),

              const Text(
                'Sign in to continue',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Email'),
                    const SizedBox(height: 8),

                    _buildTextField(
                      controller: userController,
                      hint: 'Enter email',
                      icon: Icons.person_outline_rounded,
                    ),

                    const SizedBox(height: 20),

                    _buildLabel('Password'),
                    const SizedBox(height: 8),

                    _buildTextField(
                      controller: passController,
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                    ),

                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'SIGN IN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
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
    );
  }

  // =====================================================
  // NEW ANIMATED ICON BUILDER
  // =====================================================
  Widget _buildAnimatedHeaderIcon() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E293B).withAlpha(15),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: child,
          ),
        );
      },
      child: Image.asset('assets/icon/app_icon.png', width: 80),
    );
  }

  // =====================================================
  // INPUT WIDGETS (UNCHANGED)
  // =====================================================
  Widget _buildLabel(String label) => Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B),
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) =>
      TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none, // Kept UI clean
          ),
        ),
      );
}