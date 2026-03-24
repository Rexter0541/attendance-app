import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';

class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Wala pang user → punta sa login
      return const LoginPage();
    } else {
      // May user → kunin ang employee data
      return FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('employees').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const LoginPage();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final employee = Employee(
            id: snapshot.data!.id,
            name: data['name'] ?? 'No Name',
            attendanceId: data['attendanceId'],
          );

          return HomePage(employee: employee);
        },
      );
    }
  }
}