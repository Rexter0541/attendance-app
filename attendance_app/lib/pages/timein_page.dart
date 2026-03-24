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

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
    _listenAttendance();
  }

  @override
  void dispose() {
    timer.cancel();
    attendanceListener?.cancel();
    super.dispose();
  }

  // =====================================================
  // LISTEN TO ATTENDANCE DOCUMENT
  // =====================================================
  Future<void> _listenAttendance() async {
    if (widget.employee.attendanceId == null) {
      loadingAttendance = false;
      return;
    }

    attendanceListener = FirebaseFirestore.instance
        .collection('attendance')
        .doc(widget.employee.attendanceId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data();
      if (!mounted) return;

      setState(() {
        timeInRecorded = data?['timeIn'] != null
            ? (data!['timeIn'] as Timestamp).toDate()
            : null;
        timeOutRecorded = data?['timeOut'] != null
            ? (data!['timeOut'] as Timestamp).toDate()
            : null;
        loadingAttendance = false;
      });
    });
  }

  // =====================================================
  // FORMAT TIME
  // =====================================================
  String formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  // =====================================================
  // HANDLE TIME IN
  // =====================================================
  Future<void> handleTimeIn() async {
    logs.clear();
    progressValue = 0.0;
    setState(() => isProcessing = true);

    _addLog('Recording Time In...');
    await _animateFixedDuration(const Duration(seconds: 1));
    await _recordTimeIn();
    _addLog('Clock in recorded successfully ✅');

    setState(() => isProcessing = false);
  }

  // =====================================================
  // HANDLE TIME OUT (USING LOCATION SERVICE)
  // =====================================================
  Future<void> handleTimeOut() async {
    logs.clear();
    progressValue = 0.0;
    setState(() => isProcessing = true);

    _addLog('Verifying GPS location...');
    await _animateFixedDuration(const Duration(seconds: 1));

    try {
      final result = await LocationService().verifyLocation();
      _addLog('GPS: ${result.position.latitude}, ${result.position.longitude}');
      _addLog('Distance: ${result.distance.toStringAsFixed(2)} meters');

      if (!result.inRange) {
        _showOutOfRangeDialog(result.distance);
        setState(() => isProcessing = false);
        return;
      }

      _addLog('Within allowed range ✅');
      await _recordTimeOut(result);
      _addLog('Clock out recorded successfully ✅');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(employee: widget.employee)),
      );
    } catch (e) {
      _showErrorDialog('Location Error', e.toString().replaceAll('Exception:', ''));
    }

    setState(() => isProcessing = false);
  }

  // =====================================================
  // PROGRESS ANIMATION
  // =====================================================
  Future<void> _animateFixedDuration(Duration duration) async {
    final steps = 50;
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

  // =====================================================
  // FIRESTORE FUNCTIONS
  // =====================================================
  Future<void> _recordTimeIn() async {
    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(widget.employee.attendanceId)
        .update({'timeIn': FieldValue.serverTimestamp(), 'status': 'Timed In'});

    // Create a notification for time-in
    final now = DateTime.now();
    final officialStart = DateTime(now.year, now.month, now.day, 8, 15); // 8:15 AM threshold
    final isLate = now.isAfter(officialStart);

    final title = isLate ? 'You are Late' : 'Time-In Successful';
    final body = isLate
        ? 'You clocked in at ${DateFormat('h:mm a').format(now)}. Please be mindful of your schedule.'
        : 'You clocked in at ${DateFormat('h:mm a').format(now)}. Have a productive day!';
    final type = isLate ? 'attendance_late' : 'attendance_present';

    await FirebaseFirestore.instance.collection('notifications').add({
      'recipientId': widget.employee.id,
      'title': title,
      'body': body,
      'type': type,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _recordTimeOut(LocationResult result) async {
    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(widget.employee.attendanceId)
        .update({
      'timeOut': FieldValue.serverTimestamp(),
      'status': 'Timed Out',
      'coords': {
        'lat': result.position.latitude,
        'lng': result.position.longitude,
        'distance': result.distance,
      }
    });
  }

  // =====================================================
  // DIALOGS
  // =====================================================
  void _showOutOfRangeDialog(double distance) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
        title: Text(title, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    if (loadingAttendance) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xffF3F4F6),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildCard(),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(blurRadius: 15, color: Colors.black.withAlpha(20))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Check-In Portal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text(formatTime(now), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xff6366F1))),
          const SizedBox(height: 25),
          Text('Welcome, ${widget.employee.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 25),
          _timeDisplay('Time In', timeInRecorded),
          const SizedBox(height: 10),
          _timeDisplay('Time Out', timeOutRecorded),
          const SizedBox(height: 30),
          LinearProgressIndicator(value: progressValue, minHeight: 8),
          const SizedBox(height: 20),
          Column(children: logs.map((e) => Text('> $e', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))).toList()),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Time In'),
                  onPressed: timeInRecorded != null || isProcessing ? null : handleTimeIn,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Time Out'),
                  onPressed: timeInRecorded == null || timeOutRecorded != null || isProcessing ? null : handleTimeOut,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.dashboard),
              label: const Text('Dashboard'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => HomePage(employee: widget.employee)));
              },
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        Text(time == null ? '--:--' : formatTime(time),
            style: TextStyle(fontSize: 16, color: time == null ? Colors.grey : Colors.green, fontWeight: FontWeight.bold)),
      ],
    );
  }
}