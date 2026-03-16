import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:intl/intl.dart';

=======
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_service.dart';
>>>>>>> 90cc72584c540e8d03c0d23fd3012d700a73a45b
import '../models/employee.dart';
import '../connection_status_indicator.dart';
import '../screens/verification_page.dart';
import 'home_page.dart';

class TimeInPage extends StatefulWidget {
  final Employee employee;
  const TimeInPage({super.key, required this.employee});

  @override
  State<TimeInPage> createState() => _TimeInPageState();
}

class _TimeInPageState extends State<TimeInPage> {
<<<<<<< HEAD
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  String? _timeIn;
  String? _timeOut;
  bool _isLoading = true;
  bool _isSigningOut = false;
=======
  late Timer timer;
  StreamSubscription? attendanceListener;

  DateTime now = DateTime.now();
  DateTime? timeInRecorded;
  DateTime? timeOutRecorded;

  bool loadingAttendance = true;
  double progressValue = 0.0;
  List<String> logs = [];
  bool isProcessing = false;
>>>>>>> 90cc72584c540e8d03c0d23fd3012d700a73a45b

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD

    _getTodaysAttendance();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
=======
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
>>>>>>> 90cc72584c540e8d03c0d23fd3012d700a73a45b
    });
    _listenAttendance();
  }

  @override
  void dispose() {
<<<<<<< HEAD
    _clockTimer?.cancel();
    super.dispose();
  }

  /// Fetch today's attendance
  Future<void> _getTodaysAttendance() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final docId = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final docSnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .doc(user.uid)
          .collection('attendance')
          .doc(docId)
          .get();

      if (!mounted) return;

      if (docSnapshot.exists) {
        final data = docSnapshot.data();

        setState(() {
          _timeIn = _formatTimestamp(data?['timeIn']);
          _timeOut = _formatTimestamp(data?['timeOut']);
        });
      } else {
        setState(() {
          _timeIn = null;
          _timeOut = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching attendance: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load attendance data.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Format Firestore timestamp
  String? _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;

    if (timestamp is Timestamp) {
      return DateFormat('h:mm a').format(timestamp.toDate());
    }

    return null;
  }

  /// Handle Time-Out
  Future<void> _handleTimeOut() async {
    if (_timeOut != null) return;

    setState(() => _isSigningOut = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('User not authenticated.');
      }

      final docId = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await FirebaseFirestore.instance
          .collection('employees')
          .doc(user.uid)
          .collection('attendance')
          .doc(docId)
          .update({
        'timeOut': FieldValue.serverTimestamp(),
      });

      await _getTodaysAttendance();
    } catch (e) {
      debugPrint('Error timing out: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error recording time-out.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  /// Navigate to verification page
  void _navigateToVerification() async {
    if (_timeIn != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already timed in today.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationPage(employee: widget.employee),
      ),
    );

    _getTodaysAttendance();
  }

  /// Live clock format
  String _formatLiveClock(DateTime time) {
    return DateFormat('h:mm:ss a').format(time);
=======
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
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  // =====================================================
  // HANDLE TIME IN
  // =====================================================
  Future<void> handleTimeIn() async {
    logs.clear();
    progressValue = 0.0;
    setState(() => isProcessing = true);

    _addLog("Recording Time In...");
    await _animateFixedDuration(const Duration(seconds: 1));
    await _recordTimeIn();
    _addLog("Clock in recorded successfully ✅");

    setState(() => isProcessing = false);
  }

  // =====================================================
  // HANDLE TIME OUT (USING LOCATION SERVICE)
  // =====================================================
  Future<void> handleTimeOut() async {
    logs.clear();
    progressValue = 0.0;
    setState(() => isProcessing = true);

    _addLog("Verifying GPS location...");
    await _animateFixedDuration(const Duration(seconds: 1));

    try {
      final result = await LocationService().verifyLocation();
      _addLog("GPS: ${result.position.latitude}, ${result.position.longitude}");
      _addLog("Distance: ${result.distance.toStringAsFixed(2)} meters");

      if (!result.inRange) {
        _showOutOfRangeDialog(result.distance);
        setState(() => isProcessing = false);
        return;
      }

      _addLog("Within allowed range ✅");
      await _recordTimeOut(result);
      _addLog("Clock out recorded successfully ✅");

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(employee: widget.employee)),
      );
    } catch (e) {
      _showErrorDialog("Location Error", e.toString().replaceAll("Exception:", ""));
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
        .collection("attendance")
        .doc(widget.employee.attendanceId)
        .update({"timeIn": FieldValue.serverTimestamp(), "status": "Timed In"});
  }

  Future<void> _recordTimeOut(LocationResult result) async {
    await FirebaseFirestore.instance
        .collection("attendance")
        .doc(widget.employee.attendanceId)
        .update({
      "timeOut": FieldValue.serverTimestamp(),
      "status": "Timed Out",
      "coords": {
        "lat": result.position.latitude,
        "lng": result.position.longitude,
        "distance": result.distance,
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
        title: const Text("Out of Range", style: TextStyle(color: Colors.red)),
        content: Text("You are ${distance.toStringAsFixed(2)} meters away from the office."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
>>>>>>> 90cc72584c540e8d03c0d23fd3012d700a73a45b
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
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
<<<<<<< HEAD
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomePage(employee: widget.employee),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(20),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dashboard, color: Colors.black87),
                    SizedBox(width: 8),
                    Text(
                      'Go to Dashboard',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
=======
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
          const Text("Check-In Portal", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text(formatTime(now), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xff6366F1))),
          const SizedBox(height: 25),
          Text("Welcome, ${widget.employee.name}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 25),
          _timeDisplay("Time In", timeInRecorded),
          const SizedBox(height: 10),
          _timeDisplay("Time Out", timeOutRecorded),
          const SizedBox(height: 30),
          LinearProgressIndicator(value: progressValue, minHeight: 8),
          const SizedBox(height: 20),
          Column(children: logs.map((e) => Text("> $e", style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))).toList()),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text("Time In"),
                  onPressed: timeInRecorded != null || isProcessing ? null : handleTimeIn,
>>>>>>> 90cc72584c540e8d03c0d23fd3012d700a73a45b
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text("Time Out"),
                  onPressed: timeInRecorded == null || timeOutRecorded != null || isProcessing ? null : handleTimeOut,
                ),
              ),
            ],
          ),
<<<<<<< HEAD

          const Positioned(
            top: 60,
            right: 20,
            child: ConnectionStatusIndicator(),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
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
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Check-In Portal',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Current Time',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _formatLiveClock(_now),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff6366F1),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Welcome, ${widget.employee.name}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 25),
                          _buildTimeDisplayCard(),
                          const SizedBox(height: 30),
                          _buildActionButtons(),
                        ],
                      ),
              ),
=======
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.dashboard),
              label: const Text("Dashboard"),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => HomePage(employee: widget.employee)));
              },
>>>>>>> 90cc72584c540e8d03c0d23fd3012d700a73a45b
            ),
          ),
        ],
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildTimeDisplayCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffF3F4F6),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _buildTimeRow('Time In', _timeIn),
          const Divider(height: 25),
          _buildTimeRow('Time Out', _timeOut),
        ],
      ),
    );
  }

  Widget _buildTimeRow(String label, String? time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          time ?? '-- : --',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    bool hasTimedIn = _timeIn != null;
    bool hasTimedOut = _timeOut != null;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.login),
            label: const Text('Time In'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: hasTimedIn ? null : _navigateToVerification,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: ElevatedButton.icon(
            icon: _isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                    ),
                  )
                : const Icon(Icons.logout),
            label: const Text('Time Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffE9E5F3),
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: (hasTimedIn && !hasTimedOut && !_isSigningOut)
                ? _handleTimeOut
                : null,
          ),
        ),
=======
  Widget _timeDisplay(String label, DateTime? time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        Text(time == null ? "--:--" : formatTime(time),
            style: TextStyle(fontSize: 16, color: time == null ? Colors.grey : Colors.green, fontWeight: FontWeight.bold)),
>>>>>>> 90cc72584c540e8d03c0d23fd3012d700a73a45b
      ],
    );
  }
}