// ignore_for_file: prefer_single_quotes

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
  bool _obscurePassword = true;

  Future<String> _getDeviceName() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        WebBrowserInfo webBrowserInfo = await deviceInfo.webBrowserInfo;
        return 'Web: ${webBrowserInfo.browserName.name}';
      } else if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.model} (${androidInfo.hardware})';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} [${iosInfo.utsname.machine}]';
      }
    } catch (e) {
      debugPrint('Device Info Error: $e');
    }
    return 'Generic Device';
  }

  Future<void> login() async {
    if (userController.text.isEmpty || passController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: userController.text.trim(),
        password: passController.text.trim(),
      );

      String uid = credential.user!.uid;
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // Get Device Info for Logging
      String deviceName = await _getDeviceName();
      DateTime now = DateTime.now();

      // Data to sync to Firestore
      Map<String, dynamic> loginData = {
        'lastLoginDate': Timestamp.fromDate(now),
        'lastLoginDevice': deviceName,
      };

      await prefs.setString('deviceName', deviceName);
      await prefs.setInt('last_action_timestamp', now.millisecondsSinceEpoch);

      // --- CHECK ADMIN COLLECTION ---
      DocumentSnapshot adminDoc = await FirebaseFirestore.instance.collection('Admin').doc(uid).get();

      if (adminDoc.exists) {
        // Update Admin's login info in Firestore
        await FirebaseFirestore.instance.collection('Admin').doc(uid).update(loginData);

        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', uid);
        await prefs.setString('userName', adminDoc.get('name') ?? 'Administrator');
        await prefs.setString('userRole', 'admin');

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/admin');
        return;
      }

      // --- CHECK EMPLOYEES COLLECTION ---
      DocumentSnapshot employeeDoc = await FirebaseFirestore.instance.collection('employees').doc(uid).get();

      if (employeeDoc.exists) {
        // Update Employee's login info in Firestore
        await FirebaseFirestore.instance.collection('employees').doc(uid).update(loginData);

        String name = employeeDoc.get('name') ?? 'Employee';
        String role = (employeeDoc.get('role') ?? 'employee').toString().toLowerCase();

        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', uid);
        await prefs.setString('userName', name);
        await prefs.setString('userRole', role);

        Employee employee = Employee(id: uid, name: name);

        if (!mounted) return;

        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => VerificationPage(employee: employee),
              transitionsBuilder: (context, anim, secAnim, child) => FadeTransition(opacity: anim, child: child),
            ),
          );
        }
      } else {
        _showError('User profile not found in database');
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e.code);
    } catch (e) {
      _showError('Login failed. Check credentials or connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAuthError(String code) {
    String message;
    switch (code) {
      case 'user-not-found': message = 'User not found'; break;
      case 'wrong-password': message = 'Wrong password'; break;
      case 'invalid-email': message = 'Invalid email'; break;
      default: message = 'Login failed. Please try again.';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              _buildAnimatedHeaderIcon(),
              const SizedBox(height: 15),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Welcome Back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                  SizedBox(width: 12),
                  ConnectionStatusIndicator(),
                ],
              ),
              const Text('Sign in to continue', style: TextStyle(color: Colors.blueGrey, fontSize: 14)),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Email'),
                    const SizedBox(height: 8),
                    _buildTextField(controller: userController, hint: 'Enter email', icon: Icons.person_outline_rounded),
                    const SizedBox(height: 20),
                    _buildLabel('Password'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: passController,
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
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

  Widget _buildAnimatedHeaderIcon() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, value, child) => Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white, 
          shape: BoxShape.circle, 
          boxShadow: [BoxShadow(color: const Color(0xFF1E293B).withAlpha(13), blurRadius: 25, offset: const Offset(0, 10))]
        ),
        child: Image.asset('assets/icon/app_icon.png', width: 80, errorBuilder: (c, e, s) => const Icon(Icons.business, size: 50)),
      ),
    );
  }

  Widget _buildLabel(String label) => Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)));

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon, bool obscureText = false, Widget? suffixIcon}) => 
    TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
}