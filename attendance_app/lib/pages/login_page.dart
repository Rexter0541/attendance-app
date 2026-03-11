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

  /// LOGIN FUNCTION
  Future<void> login() async {
    if (userController.text.isEmpty || passController.text.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      /// 1️⃣ Firebase login
      UserCredential credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: userController.text.trim(),
        password: passController.text.trim(),
      );

      String uid = credential.user!.uid;

      debugPrint("Logged in UID: $uid");

      /// 2️⃣ Get employee profile from Firestore
      DocumentSnapshot employeeDoc = await FirebaseFirestore.instance
          .collection("employees")
          .doc(uid)
          .get();

      if (!employeeDoc.exists) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        _showError("Employee profile not found");
        return;
      }

      Employee employee = Employee(
        name: employeeDoc["name"] ?? "Employee",
      );

      if (!mounted) return;

      /// 3️⃣ Navigate to verification page
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
    } catch (e, stack) {
      debugPrint("Login error: $e\n$stack");
      _showError("Login failed. Check credentials or connection.");
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// HANDLE AUTH ERRORS
  void _handleAuthError(String code) {
    String message;

    switch (code) {
      case 'user-not-found':
        message = "User not found";
        break;
      case 'wrong-password':
        message = "Wrong password";
        break;
      case 'invalid-email':
        message = "Invalid email";
        break;
      case 'invalid-credential':
        message = "Invalid credentials";
        break;
      default:
        message = "Login failed. Please try again.";
    }

    _showError(message);
  }

  /// SHOW ERROR SNACKBAR
  void _showError(String message) {
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
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 14,
                ),
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
                      color: Colors.black.withAlpha(13),
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
                                color: Colors.white,
                              )
                            : const Text(
                                "SIGN IN",
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

  Widget _buildLabel(String label) {
  return Text(
    label, // ✅ use passed value
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