import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/attendance_session.dart';
import '../models/employee.dart';
import '../pages/timein_page.dart';
import '../pages/login_page.dart';
import '../pages/home_page.dart';

import '../services/attendance_service.dart';
import '../services/location_service.dart';

class VerificationPage extends StatefulWidget {
  final Employee employee;

  const VerificationPage({super.key, required this.employee});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  // SERVICES
  final AttendanceService attendanceService = AttendanceService();
  final LocationService locationService = LocationService();

  int currentStep = 0;
  double progressValue = 0.0;
  List<String> logs = ["System Ready."];

  Position? userPosition;
  double distanceFromOffice = 0.0;
  bool inRange = false;

  Timer? progressTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkIfTimedIn();
      if (mounted) {
        _checkGPS();
      }
    });
  }

  @override
  void dispose() {
    progressTimer?.cancel();
    super.dispose();
  }

  // =====================================================
  // ⚡ CUSTOM SMOOTH TRANSITION ROUTE
  // =====================================================

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.05);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeTween = Tween<double>(begin: 0.0, end: 1.0);

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: SlideTransition(
            position: animation.drive(tween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }

  // =====================================================
  // ✅ CHECK EXISTING ATTENDANCE SESSION
  // =====================================================

  Future<void> _checkIfTimedIn() async {
    final AttendanceSession? session =
        await attendanceService.checkTodayAttendance(widget.employee);

    if (session != null) {
      widget.employee.attendanceId = session.id;

      distanceFromOffice = session.distance;
      inRange = true;

      _addLog("Existing attendance session restored.");

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        _createRoute(HomePage(employee: widget.employee)),
      );
    }
  }

  // =====================================================
  // GPS CHECK
  // =====================================================

  Future<void> _checkGPS() async {
    try {
      _addLog("Requesting location permission...");

      final result = await locationService.verifyLocation();

      if (!mounted) return;

      userPosition = result.position;
      distanceFromOffice = result.distance;
      inRange = result.inRange;

      _addLog(
          "Distance from office: ${distanceFromOffice.toStringAsFixed(2)} meters");

      if (!inRange) {
        _addLog("STATUS: OUT OF RANGE ❌");

        _showErrorDialog(
          "Out of Range",
          "You are ${distanceFromOffice.toStringAsFixed(2)}m away.\nAllowed: ${LocationService.allowedRadius} m",
        );
        return;
      }

      _addLog("STATUS: WITHIN OFFICE RANGE ✅");

      _updateProgress(0.33);

      await Future.delayed(const Duration(milliseconds: 800));

      _initiateQRStep();
    } catch (e) {
      _showErrorDialog("GPS Error", e.toString());
    }
  }

  // =====================================================
  // QR STEP
  // =====================================================

  void _initiateQRStep() async {
    bool start = await _showActionDialog(
      title: "Step 2: QR Scan",
      message: "Please align your employee QR code.",
      buttonText: "OPEN SCANNER",
      icon: Icons.qr_code_scanner,
      iconColor: const Color(0xFF6C63FF),
    );

    if (!mounted || !start) return;

    _addLog("Decrypting QR Signature...");
    _updateProgress(0.66);

    await Future.delayed(const Duration(seconds: 2));

    setState(() => currentStep = 1);

    _addLog("Identity Token Validated.");

    _initiatePhotoStep();
  }

  // =====================================================
  // FACE STEP
  // =====================================================

  void _initiatePhotoStep() async {
    bool start = await _showActionDialog(
      title: "Step 3: Face Capture",
      message: "Face the camera for biometric verification.",
      buttonText: "START CAPTURE",
      icon: Icons.face_unlock_outlined,
      iconColor: Colors.orange,
    );

    if (!mounted || !start) return;

    _addLog("Running Biometric Analysis...");
    _updateProgress(1.0);

    await Future.delayed(const Duration(seconds: 2));

    setState(() => currentStep = 2);

    _addLog("Facial Match Confirmed.");

    _finalizeVerification();
  }

  // =====================================================
  // SAVE ATTENDANCE
  // =====================================================

  Future<void> _saveAttendance() async {
    final attendanceId = await attendanceService.createAttendance(
      employee: widget.employee,
      lat: userPosition!.latitude,
      lng: userPosition!.longitude,
      distance: distanceFromOffice,
    );

    widget.employee.attendanceId = attendanceId;
  }

  // =====================================================
  // FINAL STEP
  // =====================================================

  Future<void> _finalizeVerification() async {
    _addLog("Creating Attendance Session...");

    await _saveAttendance();

    _addLog("Attendance Secured Successfully.");

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      _createRoute(TimeInPage(employee: widget.employee)),
    );
  }

  // =====================================================
  // UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildHeader(),
              const SizedBox(height: 40),
              _buildProgressBar(),
              const SizedBox(height: 20),
              _buildInfoCard(),
              const SizedBox(height: 15),
              _buildLocationStatus(),
              const Spacer(),
              _buildTerminal(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ================= UI COMPONENTS =================

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: currentStep == 2
                ? Colors.green.withAlpha(28)
                : Colors.blue.withAlpha(26),
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Icon(
              currentStep == 2 ? Icons.verified : Icons.security,
              key: ValueKey<int>(currentStep),
              size: 48,
              color: currentStep == 2 ? Colors.green : Colors.blueAccent,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "SECURITY PROTOCOL ACTIVE",
          style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: Color(0xFF2D3142)),
        ),
      ],
    );
  }

  Widget _buildProgressBar() => LinearProgressIndicator(
        value: progressValue,
        minHeight: 8,
        backgroundColor: Colors.grey[300],
        color: const Color(0xFF6C63FF),
      );

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: Colors.blue[50],
              child: const Icon(Icons.person, color: Color(0xFF6C63FF))),
          const SizedBox(width: 15),
          Text(widget.employee.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLocationStatus() {
    if (userPosition == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: inRange ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            inRange ? Icons.check_circle : Icons.cancel,
            color: inRange ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              inRange
                  ? "Within office range (${distanceFromOffice.toStringAsFixed(1)}m)"
                  : "Out of range (${distanceFromOffice.toStringAsFixed(1)}m)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: inRange ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminal() {
    return Container(
      width: double.infinity,
      height: 150,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (_, i) => Text(
          "> ${logs[i]}",
          style: const TextStyle(
              color: Colors.white60,
              fontFamily: 'monospace',
              fontSize: 11),
        ),
      ),
    );
  }

  void _addLog(String message) {
    if (mounted) setState(() => logs.insert(0, message));
  }

  void _updateProgress(double target) {
    progressTimer?.cancel();

    progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || progressValue >= target) {
        timer.cancel();
      } else {
        setState(() => progressValue += 0.01);
      }
    });
  }

  Future<bool> _showActionDialog({
    required String title,
    required String message,
    required String buttonText,
    required IconData icon,
    required Color iconColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 60, color: iconColor),
                const SizedBox(height: 20),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 25),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(buttonText),
                )
              ],
            ),
          ),
        ) ??
        false;
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
            onPressed: () => Navigator.pushReplacement(
                context, _createRoute(const LoginPage())),
            child: const Text("Return to Login"),
          ),
        ],
      ),
    );
  }
}