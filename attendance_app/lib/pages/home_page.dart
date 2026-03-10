import 'dart:async';
import 'package:flutter/material.dart';
import '../models/employee.dart';
import 'login_page.dart';
import 'timein_page.dart';
import '../pages/attendance_log.dart';
import '../pages/payroll_page.dart';
import '../pages/leave_page.dart';
import '../pages/profile_page.dart';
import '../pages/announcements_page.dart';
import '../pages/events_page.dart';

class HomePage extends StatefulWidget {
  final Employee employee;
  const HomePage({super.key, required this.employee});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;
  late Timer _statusTimer;
  
  bool isTimedIn = false; 
  String currentStatus = "Not Timed In";
  Color statusColor = Colors.grey;

  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color bgColor = Color(0xFFF2F3F7);
  static const Color presentColor = Color(0xFF4CAF50);
  static const Color absentColor = Color(0xFFFF5252);
  static const Color lateColor = Color(0xFFFFAB40);
  static const Color leaveColor = Color(0xFFBA68C8);

  @override
  void initState() {
    super.initState();
    _updateTimeStatus();
    // Refresh status every 30 seconds to keep "Early/Present/Late" accurate
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _updateTimeStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer.cancel();
    super.dispose();
  }

  void _updateTimeStatus() {
    if (!isTimedIn) {
      setState(() {
        currentStatus = "Timed In";
        statusColor = Colors.green;
      });
      return;
    }

    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;

    setState(() {
      if (hour < 8) {
        currentStatus = "Early";
        statusColor = Colors.blueAccent;
      } else if (hour == 8 && minute <= 15) {
        currentStatus = "Present";
        statusColor = presentColor;
      } else if (hour >= 8 && hour < 17) {
        currentStatus = "Late";
        statusColor = lateColor;
      } else {
        currentStatus = "Shift Ended";
        statusColor = Colors.grey;
      }
    });
  }

  Map<String, dynamic> _getActivityStatus(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == "--:--") {
      return {"text": "Absent", "color": absentColor};
    }
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (hour < 8) return {"text": "Early", "color": Colors.blueAccent};
      if (hour == 8 && minute <= 15) return {"text": "Present", "color": presentColor};
      if (hour >= 17) return {"text": "Ended", "color": Colors.grey};
      return {"text": "Late", "color": lateColor};
    } catch (e) {
      return {"text": "Absent", "color": absentColor};
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Icon(Icons.logout_rounded, color: absentColor, size: 50),
              SizedBox(height: 15),
              Text("Are you sure?", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "You will need to login again to access your dashboard.",
            textAlign: TextAlign.center, // FIXED: Changed to TextAlign.center
            style: TextStyle(color: Colors.grey),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: absentColor, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (_) => const LoginPage()), 
                  (route) => false
                );
              },
              child: const Text("Logout", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget dashboardBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Employee: ${widget.employee.name}", 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text("Location: Company A", 
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              // --- Status Badge ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1),
                ),
                child: Row(
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: statusColor),
                    const SizedBox(width: 6),
                    Text(currentStatus, 
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.6,
            children: [
              _buildStatCard("Present", "20", Icons.check_circle_outline, presentColor),
              _buildStatCard("Absent", "1", Icons.error_outline, absentColor),
              _buildStatCard("Late", "2", Icons.access_time, lateColor),
              _buildStatCard("Leave", "3", Icons.edit_calendar_outlined, leaveColor),
            ],
          ),
          const SizedBox(height: 20),
          _buildWorkingHourCard(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildSmallInfoCard("Announcements", Icons.campaign_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsPage())))),
              const SizedBox(width: 15),
              Expanded(child: _buildSmallInfoCard("Events", Icons.event_note_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventsPage())))),
            ],
          ),
          const SizedBox(height: 25),
          const Text("Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildActivityItem("Krestyan Stick", "08:05", "03-03-2026"),
          _buildActivityItem("Rexter Balmonte", "08:45", "03-03-2026"),
          _buildActivityItem("Raymond Gallego", "07:50", "03-03-2026"),
          _buildActivityItem("Juan Dela Cruz", "--:--", "03-03-2026"), 
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
          const Spacer(),
          Center(child: Text(count, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildWorkingHourCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)]),
      child: Column(
        children: [
          const Row(children: [Icon(Icons.hourglass_bottom_rounded, size: 20), SizedBox(width: 10), Text("Working Hour Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeIndicator("Office Time", "9 hr", presentColor),
              _buildTimeIndicator("Working Time", "3 hrs 20 min.", absentColor),
            ],
          ),
          const SizedBox(height: 15),
          Stack(
            children: [
              Container(height: 12, decoration: BoxDecoration(color: presentColor, borderRadius: BorderRadius.circular(10))),
              FractionallySizedBox(widthFactor: 0.37, child: Container(height: 12, decoration: BoxDecoration(color: absentColor, borderRadius: BorderRadius.circular(10)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeIndicator(String label, String value, Color color) {
    return Row(children: [CircleAvatar(radius: 5, backgroundColor: color), const SizedBox(width: 6), Text("$label: ", style: const TextStyle(fontSize: 12, color: Colors.black54)), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]);
  }

  Widget _buildSmallInfoCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, color: Colors.orange, size: 18), const SizedBox(width: 5), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
            const SizedBox(height: 5),
            const Text("View latest updates...", style: TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 5),
            const Align(alignment: Alignment.centerRight, child: Text("View all", style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String name, String time, String date) {
    final statusData = _getActivityStatus(time);
    final Color color = statusData['color'];
    final bool isAbsent = statusData['text'] == "Absent";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 5)]),
      child: Row(
        children: [
          CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.1), child: Icon(Icons.person_outline, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)), 
                Text(isAbsent ? "Date: $date" : "In: $time - $date", style: const TextStyle(fontSize: 11, color: Colors.grey))
              ]
            )
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), 
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), 
            child: Text(statusData['text'], style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))
          ),
        ],
      ),
    );
  }

  Widget getSelectedPage() {
    switch (currentIndex) {
      case 0: return dashboardBody();
      case 1: return const PayrollPage();
      case 2: return const LeavePage();
      case 3: return const AttendanceLogPage();
      case 4: return const ProfilePage();
      default: return dashboardBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: bgColor,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none_rounded), onPressed: () {}),
          IconButton(icon: const Icon(Icons.logout), onPressed: _showLogoutDialog),
          const SizedBox(width: 10),
        ],
      ),
      body: getSelectedPage(),
      floatingActionButton: FloatingActionButton(
        elevation: 6,
        backgroundColor: primaryColor,
        shape: const CircleBorder(),
        onPressed: () async {
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => TimeInPage(employee: widget.employee))
          );
          
          if (result == true) {
            setState(() {
              isTimedIn = true;
              _updateTimeStatus();
            });
          }
        },
        child: const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.payments_outlined), label: "Payroll"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: "Leave"),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), label: "Logs"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ), 
    );
  }
}