import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../models/employee.dart';
import 'package:intl/intl.dart';
import 'home_page.dart';

class TimeInPage extends StatefulWidget {
  final Employee employee;
  const TimeInPage({super.key, required this.employee});

  @override
  State<TimeInPage> createState() => _TimeInPageState();
}

class _TimeInPageState extends State<TimeInPage> {
  late Timer timer;
  StreamSubscription? attendanceListener;

  DateTime now = DateTime.now();
  DateTime? timeInRecorded;
  DateTime? timeOutRecorded;

  bool loadingAttendance = true;
  double progressValue = 0.0;
  List<String> logs = [];
  bool isProcessing = false;
  bool otRequested = false;
  bool isLate = false; 

  String? _activeAttendanceDocId;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => now = DateTime.now());
        _checkShiftExpiry(); 
      }
    });

    _initAttendanceSession();
  }

  @override
  void dispose() {
    timer.cancel();
    attendanceListener?.cancel();
    super.dispose();
  }

  void _checkShiftExpiry() {
    if (timeInRecorded != null && timeOutRecorded == null && !isProcessing) {
      final difference = DateTime.now().difference(timeInRecorded!);
      if (difference.inHours >= 8) {
        _addLog('8-hour shift limit reached. Auto-timing out...');
        handleTimeOut(); 
      }
    }
  }

  Future<void> _initAttendanceSession() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('employeeId', isEqualTo: widget.employee.id)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _activeAttendanceDocId = snapshot.docs.first.id;
        _listenAttendance(_activeAttendanceDocId!);
      } else {
        if (mounted) setState(() => loadingAttendance = false);
      }
    } catch (e) {
      debugPrint('Error finding session: $e');
      if (mounted) setState(() => loadingAttendance = false);
    }
  }

  void _listenAttendance(String attendanceId) {
    attendanceListener?.cancel();
    attendanceListener = FirebaseFirestore.instance
        .collection('attendance')
        .doc(attendanceId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) {
        setState(() => loadingAttendance = false);
        return;
      }
      
      final data = doc.data();
      setState(() {
        timeInRecorded = data?['timeIn'] != null ? (data!['timeIn'] as Timestamp).toDate() : null;
        timeOutRecorded = data?['timeOut'] != null ? (data!['timeOut'] as Timestamp).toDate() : null;
        otRequested = data?['isOTRequested'] ?? false;
        isLate = data?['isLate'] ?? false; 
        loadingAttendance = false;
      });
    });
  }

  String formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> handleTimeIn() async {
    if (isProcessing) return;
    logs.clear();
    progressValue = 0.0;
    setState(() => isProcessing = true);

    _addLog('Verifying server time...');
    await _animateFixedDuration(const Duration(seconds: 1));
    
    try {
      final docId = _activeAttendanceDocId ?? 
                    FirebaseFirestore.instance.collection('attendance').doc().id;
      _activeAttendanceDocId = docId;

      // Logic: Late if after 9:00 AM
      final bool lateArrival = DateTime.now().hour >= 9;

      if (lateArrival && mounted) {
        _showLateSnackBar(); // Show the pop-up notification
      }

      await FirebaseFirestore.instance.collection('attendance').doc(docId).set({
        'employeeId': widget.employee.id,
        'employeeName': widget.employee.name,
        'timeIn': FieldValue.serverTimestamp(), 
        'deviceTimeIn': DateTime.now().toIso8601String(), 
        'status': 'Timed In',
        'isOTRequested': false,
        'isLate': lateArrival, 
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _addLog('Time-In Secured ✅');
      _listenAttendance(docId);
    } catch (e) {
      _showErrorDialog('Sync Error', 'Failed to connect to Firestore.');
    }
    
    setState(() => isProcessing = false);
  }

  void _showLateSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Late Arrival Detected', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> handleTimeOut() async {
    if (isProcessing) return; 
    logs.clear();
    progressValue = 0.0;
    setState(() => isProcessing = true);

    _addLog('Verifying GPS location...');
    await _animateFixedDuration(const Duration(seconds: 1));

    try {
      final result = await LocationService().verifyLocation();
      _addLog('Distance: ${result.distance.toStringAsFixed(2)}m');

      if (!result.inRange) {
        _showOutOfRangeDialog(result.distance);
        setState(() => isProcessing = false);
        return;
      }

      bool eligibleForOT = false;
      if (timeInRecorded != null) {
        eligibleForOT = DateTime.now().difference(timeInRecorded!).inHours >= 8;
      }

      bool finalOTChoice = false;
      if (eligibleForOT && !otRequested) {
        finalOTChoice = await _showOTRequestDialog() ?? false;
      }

      _addLog('Updating attendance record...');
      await _recordTimeOut(result, finalOTChoice);
      _addLog('Clock out successful ✅');

      if (!mounted) return;
      _navigateToHome();
    } catch (e) {
      _showErrorDialog('Location Error', e.toString());
    }

    if (mounted) setState(() => isProcessing = false);
  }

  Future<void> _recordTimeOut(LocationResult result, bool requestOT) async {
    final docId = _activeAttendanceDocId ?? widget.employee.attendanceId;
    if (docId == null) {
      _addLog('Error: Attendance record ID not found.');
      return;
    }

    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(docId)
        .update({
      'timeOut': FieldValue.serverTimestamp(),
      'deviceTimeOut': DateTime.now().toIso8601String(),
      'status': 'Timed Out',
      'isOTRequested': requestOT,
      'otStatus': requestOT ? 'Pending Approval' : 'N/A',
      'coords': {
        'lat': result.position.latitude,
        'lng': result.position.longitude,
        'distance': result.distance,
      }
    });
  }

  Future<bool?> _showOTRequestDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Shift Completed'),
        content: const Text('You have exceeded 8 hours. Would you like to submit an Overtime (O.T.) request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('SUBMIT O.T.', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _animateFixedDuration(Duration duration) async {
    const steps = 50;
    final interval = (duration.inMilliseconds / steps).round();
    for (int i = 1; i <= steps; i++) {
      if (!mounted) return;
      await Future.delayed(Duration(milliseconds: interval));
      setState(() => progressValue = i / steps);
    }
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() => logs.insert(0, message));
  }

  void _showOutOfRangeDialog(double distance) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Out of Range', style: TextStyle(color: Colors.red)),
        content: Text('You are ${distance.toStringAsFixed(2)} meters away from the office.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _navigateToHome() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(employee: widget.employee)));
  }

  @override
  Widget build(BuildContext context) {
    if (loadingAttendance) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
      );
    }

    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateToHome(); 
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B)),
            onPressed: _navigateToHome,
          ),
          title: const Text('Attendance Check-In',
              style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: Stack( 
          children: [
            Positioned(
              top: -100, right: -50,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4F46E5).withAlpha(20),
                  boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withAlpha(20), blurRadius: 100, spreadRadius: 40)],
                ),
              ),
            ),
            Positioned(
              bottom: 50, left: -50,
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF818CF8).withAlpha(20),
                  boxShadow: [BoxShadow(color: const Color(0xFF818CF8).withAlpha(20), blurRadius: 80, spreadRadius: 30)],
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildCard(),
                        if (otRequested || isLate) ...[
                          const SizedBox(height: 15),
                          Wrap( // Wrap used for better spacing on small screens
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              if (isLate) _buildWarningBadge('Late Arrival'),
                              if (otRequested) _buildOTBadge(),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.withAlpha(50))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildOTBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.orange.withAlpha(25), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.withAlpha(50))),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: Colors.orange, size: 18),
          SizedBox(width: 8),
          Text('O.T. Filed', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF818CF8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withAlpha(102), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Current Time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70)),
          const SizedBox(height: 5),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: DateFormat('h:mm:ss').format(now), style: const TextStyle(fontSize: 58, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                TextSpan(text: DateFormat(' a').format(now), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white.withAlpha(204), letterSpacing: 1)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withAlpha(51), borderRadius: BorderRadius.circular(20)),
            child: Text('Hello, ${widget.employee.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
          ),
          const SizedBox(height: 30),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withAlpha(51))),
            child: Column(
              children: [
                _timeDisplay('Time In', timeInRecorded),
                const Divider(color: Colors.white24, height: 20),
                _timeDisplay('Time Out', timeOutRecorded),
              ],
            ),
          ),

          const SizedBox(height: 30),

          if (progressValue > 0 && progressValue < 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: LinearProgressIndicator(value: progressValue, minHeight: 6, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), borderRadius: BorderRadius.circular(10)),
            ),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF4F46E5), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('TIME IN', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: timeInRecorded != null || isProcessing ? null : handleTimeIn,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('TIME OUT', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: timeInRecorded == null || timeOutRecorded != null || isProcessing ? null : handleTimeOut,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (logs.isNotEmpty)
            Container(
              height: 80, width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withAlpha(51), borderRadius: BorderRadius.circular(12)),
              child: ListView(
                children: logs.map((e) => Text('> $e', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white70))).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeDisplay(String label, DateTime? time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.white70)),
        Text(time == null ? '--:--' : formatTime(time), style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}