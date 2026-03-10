import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee.dart';
import '../screens/verification_page.dart';

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

  /// ✅ FIREBASE LOGIN
  Future<void> login() async {
    if (userController.text.isEmpty || passController.text.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    setState(() => _isLoading = true);

    try {
      /// 1️⃣ Login using Firebase Authentication
      UserCredential credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: userController.text.trim(),
        password: passController.text.trim(),
      );

      String uid = credential.user!.uid;

      /// 2️⃣ Get employee info from Firestore
      DocumentSnapshot employeeDoc = await FirebaseFirestore.instance
          .collection("employees")
          .doc(uid)
          .get();

      if (!employeeDoc.exists) {
        throw Exception("Employee profile not found");
      }

      Employee employee = Employee(
        name: employeeDoc["name"],
      );

      if (!mounted) return;

      /// 3️⃣ Navigate to Verification Page
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) =>
              VerificationPage(employee: employee),
          transitionsBuilder: (context, anim, secondaryAnim, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Login failed";

      if (e.code == 'user-not-found') {
        message = "User not found";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email";
      }

      _showError(message);
    } catch (e) {
      _showError(e.toString());
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              Image.asset('assets/icon/app_icon.png', width: 100),
              const SizedBox(height: 15),
              const Text(
                "Welcome Back",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Text(
                "Sign in to continue",
                style: TextStyle(color: Colors.blueGrey, fontSize: 14),
              ),
              const SizedBox(height: 40),

              /// LOGIN CARD
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Email"),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: userController,
                      hint: "Enter email",
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel("Password"),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: passController,
                      hint: "••••••••",
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
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                "SIGN IN",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1),
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

 Widget _buildLabel(String label) {
  return Text(
    label,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1E293B),
    ),
  );
 }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}