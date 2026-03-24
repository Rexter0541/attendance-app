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
  
  Widget _getSelectedPage(int index) {
    switch (index) {
      case 0:
        return HomePage(employee: widget.employee);
      case 1:
        return PayrollPage(
            employee: widget.employee,
            currentStatus: 'Inactive', // Default value
            statusColor: Colors.grey);
      case 2:
        return LeavePage(
            employee: widget.employee,
            currentStatus: 'Inactive', // Default value
            statusColor: Colors.grey);
      case 3:
        return AttendanceLogPage(
            employee: widget.employee,
            currentStatus: 'Inactive', // Default value
            statusColor: Colors.grey);
      case 4:
        return ProfilePage(employee: widget.employee);
      default:
        return HomePage(employee: widget.employee);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getSelectedPage(index),

      bottomNavigationBar: BottomNavigationBar(
  currentIndex: index,
  onTap: (i) => setState(() => index = i),

  backgroundColor: Colors.black,   // ✅ navbar background
  selectedItemColor: Colors.white, // ✅ selected icon/text
  unselectedItemColor: Colors.grey,// ✅ unselected color
  type: BottomNavigationBarType.fixed,

  items: const [
    BottomNavigationBarItem(
        icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(
        icon: Icon(Icons.payments), label: 'Payroll'),
    BottomNavigationBarItem(
        icon: Icon(Icons.event), label: 'Leave'),
    BottomNavigationBarItem(
        icon: Icon(Icons.list), label: 'Logs'),
    BottomNavigationBarItem(
        icon: Icon(Icons.person), label: 'Profile'),
  ],
),
    );
  }
}