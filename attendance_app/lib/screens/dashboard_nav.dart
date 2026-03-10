import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../pages/home_page.dart';
import '../pages/payroll_page.dart';
import '../pages/leave_page.dart';
import '../pages/attendance_log.dart';
import '../pages/profile_page.dart';

class Dashboard extends StatefulWidget {
  final Employee employee;

  const Dashboard({super.key, required this.employee});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {

  int index = 0;

  late final pages = [
    HomePage(employee: widget.employee),
    const PayrollPage(),
    const LeavePage(),
    const AttendanceLogPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],

      bottomNavigationBar: BottomNavigationBar(
  currentIndex: index,
  onTap: (i) => setState(() => index = i),

  backgroundColor: Colors.black,   // ✅ navbar background
  selectedItemColor: Colors.white, // ✅ selected icon/text
  unselectedItemColor: Colors.grey,// ✅ unselected color
  type: BottomNavigationBarType.fixed,

  items: const [
    BottomNavigationBarItem(
        icon: Icon(Icons.home), label: "Home"),
    BottomNavigationBarItem(
        icon: Icon(Icons.payments), label: "Payroll"),
    BottomNavigationBarItem(
        icon: Icon(Icons.event), label: "Leave"),
    BottomNavigationBarItem(
        icon: Icon(Icons.list), label: "Logs"),
    BottomNavigationBarItem(
        icon: Icon(Icons.person), label: "Profile"),
  ],
),
    );
  }
}