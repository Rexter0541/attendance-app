import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../models/employee.dart';
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

  // =====================================================
  // Office Coordinates & Allowed Radius
  // =====================================================
  static const double officeLat = 16.026648547578503;
static const double officeLng = 120.42173542356102;
static const double allowedRadius = 30; // meters

  // =====================================================
  // GPS Animation & Logs
  // =====================================================
  double progressValue = 0.0;
  List<String> logs = [];
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();

    // Update current time every second
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });

    _listenTodayAttendance();
  }

  @override
  void dispose() {
    timer.cancel();
    attendanceListener?.cancel();
    super.dispose();
  }

  // =====================================================
  // REALTIME ATTENDANCE LISTENER
  // =====================================================
  Future<void> _listenTodayAttendance() async {
    final startOfDay = DateTime(now.year, now.month, now.day);

    final query = await FirebaseFirestore.instance
        .collection("attendance")
        .where("employeeId", isEqualTo: widget.employee.id)
        .where(
          "timestamp",
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .limit(1)
        .get();

    // CREATE IF NONE
    if (query.docs.isEmpty) {
      final newDoc =
          await FirebaseFirestore.instance.collection("attendance").add({
        "employeeId": widget.employee.id,
        "employeeName": widget.employee.name,
        "status": "Verified",
        "timestamp": FieldValue.serverTimestamp(),
        "timeIn": null,
        "timeOut": null,
        "coords": {
          "lat": null,
          "lng": null,
          "distance": null,
        },
      });

      widget.employee.attendanceId = newDoc.id;
    } else {
      widget.employee.attendanceId = query.docs.first.id;
    }

    // REALTIME LISTENER
    attendanceListener = FirebaseFirestore.instance
        .collection("attendance")
        .doc(widget.employee.attendanceId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;

      final data = doc.data();

      if (!mounted) return;

      setState(() {
        timeInRecorded = data?["timeIn"] != null
            ? (data!["timeIn"] as Timestamp).toDate()
            : null;

        timeOutRecorded = data?["timeOut"] != null
            ? (data!["timeOut"] as Timestamp).toDate()
            : null;

        loadingAttendance = false;
      });
    });
  }

  // =====================================================
  // FORMAT TIME
  // =====================================================
  String formatTime(DateTime time) {
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  // =====================================================
  // HANDLE TIME IN / TIME OUT WITH 1-SECOND ANIMATION FIRST
  // =====================================================
  Future<void> handleTimeIn() async {
    logs.clear();
    progressValue = 0.0;
    setState(() => isProcessing = true);

    _addLog("Checking GPS location for clock in...");

    // 1. Animate for 1 second
    await _animateFixedDuration(const Duration(seconds: 1));

    try {
      // 2. Get GPS after animation
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        officeLat,
        officeLng,
      );

      if (distance > allowedRadius) {
        _showOutOfRangeDialog(distance);
      } else {
        _addLog("Within office range ✅ (${distance.toStringAsFixed(2)} m)");

        // 3. Record time in
        await timeIn(position, distance);
        _addLog("Clock in recorded successfully ✅");
      }
    } catch (e) {
      _showErrorDialog("GPS Error", "Unable to get your location.");
    }

    setState(() => isProcessing = false);
  }

  Future<void> handleTimeOut() async {
    logs.clear();
    progressValue = 0.0;
    setState(() => isProcessing = true);

    _addLog("Checking GPS location for clock out...");

    // 1. Animate for 1 second
    await _animateFixedDuration(const Duration(seconds: 1));

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        officeLat,
        officeLng,
      );

      if (distance > allowedRadius) {
        _showOutOfRangeDialog(distance);
      } else {
        _addLog("Within office range ✅ (${distance.toStringAsFixed(2)} m)");

        await timeOut(position, distance);
        _addLog("Clock out recorded successfully ✅");

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(employee: widget.employee),
          ),
        );
      }
    } catch (e) {
      _showErrorDialog("GPS Error", "Unable to get your location.");
    }

    setState(() => isProcessing = false);
  }

  // Animate progress bar for fixed duration (e.g., 1 second)
  Future<void> _animateFixedDuration(Duration duration) async {
    final int steps = 50; // 50 updates
    final int intervalMs = (duration.inMilliseconds / steps).round();

    for (int i = 1; i <= steps; i++) {
      if (!mounted) return;
      await Future.delayed(Duration(milliseconds: intervalMs));
      setState(() => progressValue = i / steps);
    }
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      logs.insert(0, message);
    });
  }

  // =====================================================
  // ACTUAL TIME IN / TIME OUT FUNCTIONS
  // =====================================================
  Future<void> timeIn(Position position, double distance) async {
    await FirebaseFirestore.instance
        .collection("attendance")
        .doc(widget.employee.attendanceId)
        .update({
      "timeIn": FieldValue.serverTimestamp(),
      "status": "Timed In",
      "coords": {
        "lat": position.latitude,
        "lng": position.longitude,
        "distance": distance,
      },
    });
  }

  Future<void> timeOut(Position position, double distance) async {
    await FirebaseFirestore.instance
        .collection("attendance")
        .doc(widget.employee.attendanceId)
        .update({
      "timeOut": FieldValue.serverTimestamp(),
      "status": "Timed Out",
      "coords": {
        "lat": position.latitude,
        "lng": position.longitude,
        "distance": distance,
      },
    });
  }

  // =====================================================
  // OUT OF RANGE & ERROR DIALOGS
  // =====================================================
  void _showOutOfRangeDialog(double distance) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Out of Range", style: TextStyle(color: Colors.red)),
        content: Text(
            "You are ${distance.toStringAsFixed(2)} meters away from the office.\nYou must be within $allowedRadius meters to clock in/out."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title,
            style: const TextStyle(
                color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BUILD UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    if (loadingAttendance) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF3F4F6),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 15,
                      color: Colors.black.withAlpha(20),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Check-In Portal",
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      formatTime(now),
                      style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff6366F1)),
                    ),
                    const SizedBox(height: 25),
                    Text("Welcome, ${widget.employee.name}",
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 25),
                    _timeDisplay("Time In", timeInRecorded),
                    const SizedBox(height: 10),
                    _timeDisplay("Time Out", timeOutRecorded),
                    const SizedBox(height: 30),
                    LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                      color: const Color(0xFF6C63FF),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      children: logs
                          .map((e) => Text("> $e",
                              style: const TextStyle(
                                  fontSize: 11, fontFamily: 'monospace')))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text("Time In"),
                            onPressed: timeInRecorded != null || isProcessing
                                ? null
                                : handleTimeIn,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.logout),
                            label: const Text("Time Out"),
                            onPressed: timeInRecorded == null ||
                                    timeOutRecorded != null ||
                                    isProcessing
                                ? null
                                : handleTimeOut,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.dashboard),
                        label: const Text("Dashboard"),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  HomePage(employee: widget.employee),
                            ),
                          );
                        },
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

  Widget _timeDisplay(String label, DateTime? time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        Text(
          time == null ? "--:--" : formatTime(time),
          style: TextStyle(
              fontSize: 16,
              color: time == null ? Colors.grey : Colors.green,
              fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}