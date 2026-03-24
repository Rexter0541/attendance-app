// ignore_for_file: unused_import, unused_field

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import 'login_page.dart';
import '../pages/attendance_log.dart';
import '../pages/payroll_page.dart';
import '../pages/leave_page.dart';
import '../pages/profile_page.dart';
import '../pages/announcements_page.dart';
import '../pages/events_page.dart';
import '../pages/notifications_page.dart';
import '../pages/timein_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  final Employee employee;
  const HomePage({super.key, required this.employee});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;
  bool isTimedIn = false;
  String currentStatus = 'Not Timed In';
  Color statusColor = Colors.grey;

  int presentCount = 0;
  int absentCount = 0;
  int lateCount = 0;
  int leaveCount = 0;

  // --- Constants ---
  static const int shiftMinutes = 480; // 8 Hours (Regular)
  static const int maxOTMinutes = 600; // 10 Hours Total (8h + 2h OT)
  
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color bgColor = Color(0xFFF2F3F7);
  static const Color presentColor = Color(0xFF4CAF50);
  static const Color absentColor = Color(0xFFFF5252);
  static const Color lateColor = Color(0xFFFFAB40);
  static const Color leaveColor = Color(0xFFBA68C8);

  late StreamSubscription<QuerySnapshot> _activityListener;
  List<Map<String, dynamic>> recentActivities = [];
  bool isLoadingActivities = true;

  Timer? _refreshTimer;
  DateTime? todayTimeIn;
  DateTime? lastTimeOut;

  @override
  void initState() {
    super.initState();
    _checkTodayAttendance();
    _fetchAttendanceTotals();
    _listenToRecentActivities();

    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted && isTimedIn) {
        setState(() {
          _updateStatusLogic(todayTimeIn, lastTimeOut);
        });
      }
    });
  }

  @override
  void dispose() {
    _activityListener.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // --- DATA FETCHING & LOGIC ---

  Future<void> _fetchAttendanceTotals() async {
    try {
      final userId = widget.employee.id;
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('employeeId', isEqualTo: userId)
          .get();

      final leaveSnapshot = await FirebaseFirestore.instance
          .collection('leaves')
          .where('employeeId', isEqualTo: userId)
          .get();

      int p = 0;
      int l = 0;

      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data();
        final tIn = (data['timeIn'] as Timestamp?)?.toDate();
        if (tIn != null) {
          if (tIn.hour > 8 || (tIn.hour == 8 && tIn.minute > 15)) {
            l++;
          } else {
            p++;
          }
        }
      }

      if (mounted) {
        setState(() {
          presentCount = p;
          lateCount = l;
          leaveCount = leaveSnapshot.docs.length;
          absentCount = 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching totals: $e');
    }
  }

  Future<void> _checkTodayAttendance() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('employeeId', isEqualTo: widget.employee.id)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _syncStatusWithData(snapshot.docs.first.data());
      }
    } catch (e) {
      debugPrint('Check Attendance Error: $e');
    }
  }

  void _syncStatusWithData(Map<String, dynamic> data) {
    final ts = data['timestamp'] as Timestamp?;
    if (ts == null) return;

    final activityDate = ts.toDate();
    final now = DateTime.now();

    bool isToday = activityDate.year == now.year &&
        activityDate.month == now.month &&
        activityDate.day == now.day;

    if (isToday) {
      final tsIn = data['timeIn'] as Timestamp?;
      final tsOut = data['timeOut'] as Timestamp?;

      if (mounted) {
        setState(() {
          todayTimeIn = tsIn?.toDate();
          lastTimeOut = tsOut?.toDate();
          isTimedIn = tsOut == null;
          _updateStatusLogic(todayTimeIn, lastTimeOut);
        });
      }
    }
  }

  void _updateStatusLogic(DateTime? timeIn, DateTime? timeOut) {
    if (timeIn == null) {
      currentStatus = 'Not Timed In';
      statusColor = Colors.grey;
      return;
    }

    final now = DateTime.now();
    final endTime = timeOut ?? now;
    final totalWorkedMinutes = endTime.difference(timeIn).inMinutes;

    if (isTimedIn) {
      if (totalWorkedMinutes >= maxOTMinutes) {
        currentStatus = 'Max OT Reached';
        statusColor = Colors.redAccent;
        _handleAutoTimeout(); // Force stop the clock in DB
      } else if (totalWorkedMinutes >= shiftMinutes) {
        currentStatus = 'Overtime';
        statusColor = Colors.orangeAccent;
      } else {
        bool isLate = timeIn.hour > 8 || (timeIn.hour == 8 && timeIn.minute > 15);
        currentStatus = isLate ? 'Late' : 'Present';
        statusColor = isLate ? lateColor : presentColor;
      }
    } else {
      if (totalWorkedMinutes >= maxOTMinutes) {
        currentStatus = 'Max OT Completed';
        statusColor = Colors.green;
      } else {
        currentStatus = totalWorkedMinutes >= shiftMinutes ? 'Shift Completed' : 'Shift Ended';
        statusColor = totalWorkedMinutes >= shiftMinutes ? Colors.green : Colors.grey;
      }
    }
  }

  Future<void> _handleAutoTimeout() async {
    if (!isTimedIn) return;
    try {
      final userId = widget.employee.id;
      final now = DateTime.now();

      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('employeeId', isEqualTo: userId)
          .where('timeOut', isNull: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.update({
          'timeOut': Timestamp.fromDate(now),
          'status': 'Auto-Logged Out (Max OT)',
        });
        if (mounted) {
          setState(() {
            isTimedIn = false;
            lastTimeOut = now;
            _updateStatusLogic(todayTimeIn, now);
          });
        }
      }
    } catch (e) {
      debugPrint('Auto-Timeout Error: $e');
    }
  }

  void _listenToRecentActivities() {
    setState(() => isLoadingActivities = true);
    _activityListener = FirebaseFirestore.instance
        .collection('attendance')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final latestData = snapshot.docs.first.data();
        if (latestData['employeeId'] == widget.employee.id) {
          _syncStatusWithData(latestData);
        }
      }

      recentActivities = snapshot.docs.map((doc) {
        final data = doc.data();
        final tsIn = data['timeIn'] as Timestamp?;
        final tsOut = data['timeOut'] as Timestamp?;
        String timeStr = '--:--';
        String dateStr = '';
        if (tsIn != null) {
          final dt = tsIn.toDate();
          timeStr = DateFormat('HH:mm').format(dt);
          dateStr = DateFormat('MM-dd-yyyy').format(dt);
        }

        final statusData = _getActivityStatus(tsIn?.toDate(), tsOut?.toDate());
        return {
          'name': data['employeeName'] ?? 'Unknown',
          'time': timeStr,
          'date': dateStr,
          'statusText': statusData['text'],
          'statusColor': statusData['color'],
        };
      }).toList();

      if (mounted) setState(() => isLoadingActivities = false);
    });
  }

  Map<String, dynamic> _getActivityStatus(DateTime? tIn, DateTime? tOut) {
    if (tIn == null) return {'text': 'Absent', 'color': absentColor};
    final now = DateTime.now();
    final endTime = tOut ?? now;
    final diff = endTime.difference(tIn).inMinutes;

    if (diff >= shiftMinutes) return {'text': 'Completed', 'color': Colors.green};
    if (tOut != null) return {'text': 'Shift Ended', 'color': Colors.grey};

    if (tIn.hour < 8 || (tIn.hour == 8 && tIn.minute <= 15)) {
      return {'text': 'Present', 'color': presentColor};
    }
    return {'text': 'Late', 'color': lateColor};
  }

  // --- UI PROGRESS CALCULATIONS ---

  String _getWorkingDurationText() {
    if (todayTimeIn == null) return '0h 0m';
    DateTime end = isTimedIn ? DateTime.now() : (lastTimeOut ?? DateTime.now());
    int totalMinutes = end.difference(todayTimeIn!).inMinutes;

    // Logic: Stop the visible clock at 10 hours
    if (totalMinutes > maxOTMinutes) {
      totalMinutes = maxOTMinutes;
    }

    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  double _getWorkingProgress() {
    if (todayTimeIn == null) return 0.0;
    DateTime end = isTimedIn ? DateTime.now() : (lastTimeOut ?? DateTime.now());
    final diff = end.difference(todayTimeIn!);
    
    // Logic: Progress is now relative to the 10-hour max limit
    double percent = diff.inMinutes / maxOTMinutes; 
    return percent.clamp(0.0, 1.0); // Never let the bar go off-screen
  }

  // --- DASHBOARD UI ---

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
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              _buildStatusPill(),
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
              _buildStatCard('On Time/Present', presentCount.toString(), Icons.check_circle_outline, presentColor),
              _buildStatCard('Absent', absentCount.toString(), Icons.error_outline, absentColor),
              _buildStatCard('Late', lateCount.toString(), Icons.access_time, lateColor),
              _buildStatCard('Leave', leaveCount.toString(), Icons.edit_calendar_outlined, leaveColor),
            ],
          ),
          const SizedBox(height: 20),
          _buildWorkingHourCard(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildSmallInfoCard(
                      'Announcements',
                      Icons.campaign_outlined,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsPage())))),
              const SizedBox(width: 15),
              Expanded(
                  child: _buildSmallInfoCard(
                      'Events',
                      Icons.event_note_outlined,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventsPage())))),
            ],
          ),
          const SizedBox(height: 25),
          const Text('Company Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          isLoadingActivities 
            ? const Center(child: CircularProgressIndicator())
            : SizedBox(
                height: 300, // Ito yung "box limiter" para hindi humaba ang buong page
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: recentActivities.length,
                  itemBuilder: (context, index) {
                    final activity = recentActivities[index];
                    return _buildActivityItem(activity['name'], activity['time'], activity['date'], activity['statusText'], activity['statusColor']);
                  },
                ),
              ),
        ],
      ),
    );
  }

  // --- HELPER UI WIDGETS ---

  Widget _buildStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withAlpha(128), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: statusColor),
          const SizedBox(width: 6),
          Text(currentStatus, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
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
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold))
          ]),
          const Spacer(),
          Center(child: Text(count, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildWorkingHourCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10)]),
      child: Column(
        children: [
          const Row(children: [
            Icon(Icons.hourglass_bottom_rounded, size: 20, color: primaryColor),
            SizedBox(width: 10),
            Text('Working Hour Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
          ]),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeIndicator('Office Time', '8.0 hr', Colors.blueGrey),
              _buildTimeIndicator(isTimedIn ? 'Working Time' : 'Shift Ended', _getWorkingDurationText(),
                  isTimedIn ? (currentStatus == 'Overtime' ? Colors.orangeAccent : primaryColor) : Colors.grey),
            ],
          ),
          const SizedBox(height: 15),
          Stack(
            children: [
              // Background bar
              Container(
                  height: 12, decoration: BoxDecoration(color: Colors.grey.withAlpha(51), borderRadius: BorderRadius.circular(10))),
              
              // Progress bar capped at maxOTMinutes (600)
              FractionallySizedBox(
                widthFactor: _getWorkingProgress(),
                child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                        color: isTimedIn 
                          ? (currentStatus == 'Max OT Reached' ? Colors.redAccent : (currentStatus == 'Overtime' ? Colors.orangeAccent : primaryColor)) 
                          : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          if(isTimedIn) BoxShadow(color: (currentStatus == 'Overtime' ? Colors.orangeAccent : primaryColor).withAlpha(100), blurRadius: 6)
                        ]
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeIndicator(String label, String value, Color color) {
    return Row(children: [
      CircleAvatar(radius: 5, backgroundColor: color),
      const SizedBox(width: 6),
      Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.black54)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
    ]);
  }

  Widget _buildSmallInfoCard(String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10)]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Colors.orange, size: 18),
              const SizedBox(width: 5),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
            ]),
            const SizedBox(height: 5),
            const Text('View updates...', style: TextStyle(fontSize: 10, color: Colors.grey)),
            const Align(
                alignment: Alignment.centerRight,
                child: Text('View all', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String name, String time, String date, String statusText, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 5)]),
      child: Row(
        children: [
          CircleAvatar(
              radius: 20,
              backgroundColor: color.withAlpha(25),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('In: $time - $date', style: const TextStyle(fontSize: 11, color: Colors.grey))
          ])),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(20)),
              child: Text(statusText, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(children: [
          Icon(Icons.logout_rounded, color: absentColor, size: 50),
          SizedBox(height: 15),
          Text('Are you sure?', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
          'You will need to login again to access your dashboard.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: absentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              try {
                // 1. Clear Local Session Data
                final SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isLoggedIn', false);
                await prefs.remove('userId');
                await prefs.remove('userName');

                // 2. Sign out from Firebase
                await FirebaseAuth.instance.signOut();

                // ⭐ FIX: Check if the widget is still in the tree 
                // and if the dialog context is still valid
                if (!mounted || !dialogContext.mounted) return;

                // 3. Clear navigation stack and go to Login
                // Use 'context' (from the State) to navigate away from the page
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              } catch (e) {
                debugPrint('Logout Error: $e');
                // ⭐ FIX: Check dialogContext specifically before popping
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget getSelectedPage() {
    switch (currentIndex) {
      case 0: return dashboardBody();
      case 1: return PayrollPage(employee: widget.employee, currentStatus: currentStatus, statusColor: statusColor);
      case 2: return LeavePage(employee: widget.employee, currentStatus: currentStatus, statusColor: statusColor);
      case 3: return AttendanceLogPage(employee: widget.employee, currentStatus: currentStatus, statusColor: statusColor);
      case 4: return ProfilePage(employee: widget.employee);
      default: return dashboardBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        backgroundColor: bgColor,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          _buildNotificationBell(),
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
          _fetchAttendanceTotals();
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
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_none_rounded),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(employee: widget.employee, currentStatus: currentStatus, statusColor: statusColor))),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;

        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded),
              if (unreadCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 8)),
                  ),
                ),
            ],
          ),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(employee: widget.employee, currentStatus: currentStatus, statusColor: statusColor))),
        );
      },
    );
  }
}