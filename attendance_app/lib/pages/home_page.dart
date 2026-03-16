import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import 'login_page.dart';
import 'timein_page.dart';
import '../pages/attendance_log.dart';
import '../pages/payroll_page.dart';
import '../pages/leave_page.dart';
import '../pages/profile_page.dart';
import 'announcements_page.dart';
import 'events_page.dart';

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
  Map<String, String> _employeeNames = {};
  String currentStatus = 'Loading...';
  Color statusColor = Colors.grey;

  final List<String> _pageTitles = [
    'Dashboard',
    'Payroll',
    'Leaves',
    'Attendance Logs',
    'Profile',
  ];

  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color bgColor = Color(0xFFF2F3F7);
  static const Color presentColor = Color(0xFF4CAF50);
  static const Color absentColor = Color(0xFFFF5252);
  static const Color lateColor = Color(0xFFFFAB40);
  static const Color leaveColor = Color(0xFFBA68C8);

  @override
  void initState() {
    super.initState();
    _fetchEmployeeNames();
    _checkTodaysAttendance();
    // Refresh status every 30 seconds.
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        // If timed in, update the status (e.g., from "Early" to "Present").
        // No need to re-check Firestore every 30s.
        if (isTimedIn) _updateTimeStatus();
      }
    });
  }

  @override
  void dispose() {
    _statusTimer.cancel();
    super.dispose();
  }

  /// Fetches all employee names and stores them in a map for easy lookup.
  Future<void> _fetchEmployeeNames() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('employees').get();
      final names = {for (var doc in snapshot.docs) doc.id: doc.data()['name'] as String};
      if (mounted) {
        setState(() => _employeeNames = names);
      }
    } catch (e) {
      debugPrint('Error fetching employee names: $e');
    }
  }

  /// Fetches attendance from Firestore to determine if the user is timed in.
  Future<void> _checkTodaysAttendance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => isTimedIn = false);
        _updateTimeStatus();
        return;
      }

      final docId = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final docSnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .doc(user.uid)
          .collection('attendance')
          .doc(docId)
          .get();

      if (mounted) {
        final data = docSnapshot.data();
        final hasTimedIn = docSnapshot.exists && data?['timeIn'] != null;
        final hasTimedOut = data?['timeOut'] != null;

        setState(() {
          // The user is considered "active" if they have timed in but not timed out.
          isTimedIn = hasTimedIn && !hasTimedOut;
        });
      }
    } catch (e) {
      debugPrint('Error checking attendance: $e');
      if (mounted) setState(() => isTimedIn = false);
    } finally {
      if (mounted) _updateTimeStatus();
    }
  }

  void _updateTimeStatus() {
    // This logic runs only if the user is currently timed in.
    if (isTimedIn) {
      final now = DateTime.now();
      final hour = now.hour;
      final minute = now.minute;

      setState(() {
        if (hour < 8) {
          currentStatus = 'Early';
          statusColor = Colors.blueAccent;
        } else if (hour == 8 && minute <= 15) {
          currentStatus = 'Present';
          statusColor = presentColor;
        } else if (hour >= 8 && hour < 17) {
          currentStatus = 'Late';
          statusColor = lateColor;
        } else {
          currentStatus = 'Shift Ended';
          statusColor = Colors.grey;
        }
      });
    } else {
      // If not timed in, set a clear status.
      setState(() {
        currentStatus = 'Not Timed In';
        statusColor = Colors.grey;
      });
    }
  }

  Map<String, dynamic> _getActivityStatus(Timestamp? timeIn, Timestamp? timeOut) {
  if (timeIn == null) return {'text': 'Absent', 'color': absentColor};

  DateTime time = timeIn.toDate();

  final hour = time.hour;
  final minute = time.minute;

  if (hour < 8) return {'text': 'Early', 'color': Colors.blueAccent};
  if (hour == 8 && minute <= 15) return {'text': 'Present', 'color': presentColor};
  return {'text': 'Late', 'color': lateColor};
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
            Text('Are you sure?', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        content: const Text('You will need to login again to access your dashboard.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
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
              child: const Text('Logout', style: TextStyle(color: Colors.white)),
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
                  Text('Employee: ${widget.employee.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('Location: Company A',
                      style: TextStyle(color: Colors.grey, fontSize: 13))
                ],
              ),
              // --- Status Badge ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha:0.15),
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
              _buildStatCard('Present', '20', Icons.check_circle_outline, presentColor),
              _buildStatCard('Absent', '1', Icons.error_outline, absentColor),
              _buildStatCard('Late', '2', Icons.access_time, lateColor),
              _buildStatCard('Leave', '3', Icons.edit_calendar_outlined, leaveColor),
            ],
          ),
          const SizedBox(height: 20),
          _buildWorkingHourCard(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildSmallInfoCard('Announcements', Icons.campaign_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsPage())))),
              const SizedBox(width: 15),
              Expanded(child: _buildSmallInfoCard('Events', Icons.event_note_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventsPage())))),
            ],
          ),
          const SizedBox(height: 25),
          const Text('Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildRecentActivityList(),
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
          const Row(children: [Icon(Icons.hourglass_bottom_rounded, size: 20), SizedBox(width: 10), Text('Working Hour Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeIndicator('Office Time', '9 hr', presentColor),
              _buildTimeIndicator('Working Time', '3 hrs 20 min.', absentColor),
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
    return Row(children: [CircleAvatar(radius: 5, backgroundColor: color), const SizedBox(width: 6), Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.black54)), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]);
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
            const Text('View latest updates...', style: TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 5),
            const Align(alignment: Alignment.centerRight, child: Text('View all', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String name, Timestamp? timeIn, Timestamp? timeOut) {
  final statusData = _getActivityStatus(timeIn, timeOut);
  final Color color = statusData['color'];
  final bool isAbsent = statusData['text'] == 'Absent';

  final String timeStr = timeIn != null ? DateFormat('h:mm a').format(timeIn.toDate()) : '--:--';
  final String dateStr = timeIn != null ? DateFormat('MM-dd-yyyy').format(timeIn.toDate()) : '--';

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 5)],
    ),
    child: Row(
      children: [
        CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.1), child: Icon(Icons.person_outline, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)), 
              Text(isAbsent ? 'Date: $dateStr' : 'In: $timeStr - $dateStr', style: const TextStyle(fontSize: 11, color: Colors.grey))
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

  Widget _buildRecentActivityList() {
  // Show a loader while employee names are being fetched.
  if (_employeeNames.isEmpty) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  return FutureBuilder<List<Widget>>(
    future: _fetchRecentActivities(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        debugPrint('Error fetching recent activity: ${snapshot.error}');
        return const Center(child: Text('Error fetching recent activity.'));
      }
      final activityList = snapshot.data ?? [];
      if (activityList.isEmpty) {
        return const Center(child: Text('No recent activity from other employees.'));
      }
      return Column(children: activityList);
    },
  );
}

/// Fetches the most recent activity from other employees without requiring a composite index.
Future<List<Widget>> _fetchRecentActivities() async {
  final List<Widget> recentActivityWidgets = [];

  try {
    for (var entry in _employeeNames.entries) {
      final employeeId = entry.key;
      final employeeName = entry.value;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .doc(employeeId)
          .collection('attendance')
          .orderBy('timeIn', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        final Timestamp? timeInTimestamp = data['timeIn'];
        final Timestamp? timeOutTimestamp = data['timeOut'];

        recentActivityWidgets.add(_buildActivityItem(employeeName, timeInTimestamp, timeOutTimestamp));
      }
    }
  } catch (e) {
    debugPrint('Error fetching recent activities: $e');
  }

  return recentActivityWidgets;
}

  Widget getSelectedPage() {
    switch (currentIndex) {
      case 0: return dashboardBody();
      case 1:
        return PayrollPage(
            employee: widget.employee,
            currentStatus: currentStatus,
            statusColor: statusColor);
      case 2:
        return LeavePage(
            employee: widget.employee,
            currentStatus: currentStatus,
            statusColor: statusColor);
      case 3:
        return AttendanceLogPage(
            employee: widget.employee,
            currentStatus: currentStatus,
            statusColor: statusColor);
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
        title: Text(_pageTitles[currentIndex], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
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
          await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => TimeInPage(employee: widget.employee))
          );
          // After returning, refresh the attendance status from the database.
          _checkTodaysAttendance();
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
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.payments_outlined), label: 'Payroll'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Leave'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), label: 'Logs'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ), 
    );
  }
}
