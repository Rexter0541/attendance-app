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
  
  // UI Constants (Modern Design System)
  static const Color bgColor = Color(0xFFF8F9FC);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF1E293B);
  
  // Status Colors
  static const Color presentColor = Color(0xFF10B981); // Emerald
  static const Color absentColor = Color(0xFFEF4444);  // Red
  static const Color lateColor = Color(0xFFF59E0B);    // Amber
  static const Color leaveColor = Color(0xFF8B5CF6);   // Violet

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

  Widget dashboardBody(Employee displayEmployee) {
    // Determine greeting based on time
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Custom Header (Replaces AppBar)
          SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(greeting,
                          style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(displayEmployee.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: textColor)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildNotificationBell(displayEmployee),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                      ]),
                      child: IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Colors.grey),
                        onPressed: _showLogoutDialog,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // Working Timer Card
          _buildWorkingHourCard(),
          
          const SizedBox(height: 25),
          
          // Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard('On Time/Present', presentCount.toString(), Icons.check_circle_rounded, presentColor),
              _buildStatCard('Absent', absentCount.toString(), Icons.cancel_rounded, absentColor),
              _buildStatCard('Late', lateCount.toString(), Icons.access_time, lateColor),
              _buildStatCard('Leave', leaveCount.toString(), Icons.edit_calendar_outlined, leaveColor),
            ],
          ),
          
          const SizedBox(height: 25),

          // Quick Actions
          Row(
            children: [
              Expanded(
                  child: _buildSmallInfoCard(
                      'Announcements',
                      Icons.campaign_rounded,
                      Colors.blueAccent,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnnouncementsPage()))
                  )),
              const SizedBox(width: 15),
              Expanded(
                  child: _buildSmallInfoCard(
                      'Events',
                      Icons.event_note_rounded,
                      Colors.pinkAccent,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EventsPage()))
                  )),
            ],
          ),
          const SizedBox(height: 25),
          const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 10),
          isLoadingActivities 
            ? const Center(child: CircularProgressIndicator(color: primaryColor))
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

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const Spacer(),
          Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildWorkingHourCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeIndicator('Shift', '8h 00m', Colors.white70),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildTimeIndicator('Worked', _getWorkingDurationText(), Colors.white),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            children: [
              // Background bar
              Container(
                  height: 8, decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(10))),
              
              // Progress bar capped at maxOTMinutes (600)
              FractionallySizedBox(
                widthFactor: _getWorkingProgress(),
                child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                    )),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Status', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  currentStatus.toUpperCase(), 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTimeIndicator(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
      ]
    );
  }

  Widget _buildSmallInfoCard(String title, IconData icon, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [iconColor, iconColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: iconColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  Text('View all', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.9))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String name, String time, String date, String statusText, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            Text('In: $time • $date', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)))
          ])),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(statusText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))),
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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

  Widget getSelectedPage(Employee displayEmployee) {
    switch (currentIndex) {
      case 0: return dashboardBody(displayEmployee);
      case 1: return PayrollPage(employee: displayEmployee, currentStatus: currentStatus, statusColor: statusColor);
      case 2: return LeavePage(employee: displayEmployee, currentStatus: currentStatus, statusColor: statusColor);
      case 3: return AttendanceLogPage(employee: displayEmployee, currentStatus: currentStatus, statusColor: statusColor);
      case 4: return ProfilePage(employee: displayEmployee);
      default: return dashboardBody(displayEmployee);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we are on the dashboard (index 0), we hide the AppBar because we use a custom header.
    // For other pages (like Payroll), they have their own AppBars, so we also hide the global one to avoid double AppBars.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('employees').doc(widget.employee.id).snapshots(),
      builder: (context, snapshot) {
        // Use the stream data to update the employee object locally
        Employee displayEmployee = widget.employee;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayEmployee = Employee(
            id: widget.employee.id,
            name: data['name'] ?? widget.employee.name,
            attendanceId: widget.employee.attendanceId,
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              // AMBIENT BACKGROUND LAYER
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF8F9FC),
                      Color(0xFFE0E7FF),
                    ],
                  ),
                ),
              ),
              // Top Right Glow
              Positioned(
                top: -100,
                right: -50,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withOpacity(0.08),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.08),
                        blurRadius: 100,
                        spreadRadius: 40,
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom Left Glow
              Positioned(
                bottom: 100,
                left: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF818CF8).withOpacity(0.08),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF818CF8).withOpacity(0.08),
                        blurRadius: 80,
                        spreadRadius: 30,
                      ),
                    ],
                  ),
                ),
              ),

              // MAIN CONTENT (Dashboard or Selected Page)
              getSelectedPage(displayEmployee),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            elevation: 6,
            backgroundColor: primaryColor,
            shape: const CircleBorder(),
            onPressed: () async {
              await Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => TimeInPage(employee: displayEmployee))
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
    );
  }

  Widget _buildNotificationBell(Employee displayEmployee) {
    final user = FirebaseAuth.instance.currentUser;
    
    Widget bellIcon = Container(
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
         BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
      ]),
      child: IconButton(
        icon: const Icon(Icons.notifications_none_rounded),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(employee: displayEmployee, currentStatus: currentStatus, statusColor: statusColor))),
      ),
    );

    if (user == null) {
      return bellIcon;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            bellIcon,
            if (unreadCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(unreadCount.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        );
      },
    );
  }
}