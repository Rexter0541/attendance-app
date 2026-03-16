import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  String? _timeIn;
  String? _timeOut;
  bool _isLoading = true;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();

    _getTodaysAttendance();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                ),
              ),
            ),
          ),

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
            ),
          ),
        ],
      ),
    );
  }

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
      ],
    );
  }
}