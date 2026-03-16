import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';
import '../pages/timein_page.dart';

class VerificationPage extends StatefulWidget {
  final Employee employee;
  const VerificationPage({super.key, required this.employee});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  int currentStep = 0;
  double progressValue = 0.0;
  final List<String> logs = [];
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initiateQRStep());
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _initiateQRStep() async {
    bool start = await _showActionDialog(
      title: 'QR Scanner Request',
      message: 'The system requires access to scan your Employee QR Code.',
      buttonText: 'START SCANNING',
      icon: Icons.qr_code_scanner,
      iconColor: const Color(0xFF6C63FF),
    );

    if (!start) return;

    _addLog('Initializing Camera...');
    _updateProgress(0.35);
    await Future.delayed(const Duration(seconds: 2));

    _addLog('QR Code Verified: EMP-8821');

    if (!mounted) return;

    setState(() => currentStep = 1);
    await Future.delayed(const Duration(milliseconds: 500));

    _initiatePhotoStep();
  }

  void _initiatePhotoStep() async {
    bool start = await _showActionDialog(
      title: 'Photo Capture Request',
      message: 'QR Verified. We now need to capture a photo for facial verification.',
      buttonText: 'START CAPTURE',
      icon: Icons.face_retouching_natural,
      iconColor: Colors.orange,
    );

    if (!start) return;

    _addLog('Analyzing Facial Features...');
    _updateProgress(0.75);

    await Future.delayed(const Duration(seconds: 2));

    _addLog('Photo Captured Successfully.');

    if (!mounted) return;

    setState(() => currentStep = 2);
    await Future.delayed(const Duration(milliseconds: 500));

    _finalizeVerification();
  }

  Future<void> _finalizeVerification() async {
    _addLog('Syncing with Server...');
    _updateProgress(1.0);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _addLog('Error: User authentication failed.');
        return;
      }

      final now = DateTime.now();
      final docId = DateFormat('yyyy-MM-dd').format(now);

      final docRef = FirebaseFirestore.instance
          .collection('employees')
          .doc(user.uid)
          .collection('attendance')
          .doc(docId);

      final docSnapshot = await docRef.get();

      /// 🚫 Prevent double time-in
      if (docSnapshot.exists && docSnapshot.data()?['timeIn'] != null) {
        _addLog('Already timed in today.');

        await Future.delayed(const Duration(seconds: 1));

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => TimeInPage(employee: widget.employee),
          ),
          (route) => false,
        );
        return;
      }

      /// ✅ Save attendance
      await docRef.set({
        'timeIn': FieldValue.serverTimestamp(),
        'timeOut': null,
        'date': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      _addLog('Attendance Logged Successfully.');

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      /// ✅ Go to TimeInPage
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => TimeInPage(employee: widget.employee),
        ),
        (route) => false,
      );
    } catch (e) {
      _addLog('Error: Failed to save attendance data.');
      debugPrint('Firestore Error: $e');
    }
  }

  Future<bool> _showActionDialog({
    required String title,
    required String message,
    required String buttonText,
    required IconData icon,
    required Color iconColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 50, color: iconColor),
            const SizedBox(height: 15),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        logs.insert(0, message);
      });
    }
  }

  void _updateProgress(double target) {
    _progressTimer?.cancel();

    _progressTimer =
        Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        progressValue = (progressValue + 0.01).clamp(0.0, target);

        if (progressValue >= target) {
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F7),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(4, 4))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentStep == 2 ?
                    'IDENTITY SECURED' :
                    'PENDING AUTHORIZATION',
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 11,
                    color: Colors.grey),
              ),
              const SizedBox(height: 20),
              _buildStepVisual(),
              const SizedBox(height: 25),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 10,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                ),
              ),
              const SizedBox(height: 25),
              _buildLogsContainer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogsContainer() {
    return Container(
      height: 90,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) => Text(
          '> ${logs[index]}',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: index == 0 ? Colors.black : Colors.grey,
            fontWeight:
                index == 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStepVisual() {
    IconData icon;
    String label;
    Color color;

    if (currentStep == 0) {
      icon = Icons.qr_code_scanner_rounded;
      label = 'STEP 1: QR SCAN';
      color = const Color(0xFF6C63FF);
    } else if (currentStep == 1) {
      icon = Icons.camera_front_rounded;
      label = 'STEP 2: PHOTO CAPTURE';
      color = Colors.orange;
    } else {
      icon = Icons.verified_user_rounded;
      label = 'VERIFIED';
      color = Colors.green;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Column(
        key: ValueKey(currentStep),
        children: [
          Icon(icon, size: 64, color: color),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}