// ignore_for_file: prefer_single_quotes

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/login_page.dart'; 
import '../main.dart'; 

class SessionManager extends StatefulWidget {
  final Widget child;
  final Duration timeout;

  const SessionManager({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 10), // Default to 10 minutes if not provided
  });

  @override
  State<SessionManager> createState() => _SessionManagerState();
}

class _SessionManagerState extends State<SessionManager> with WidgetsBindingObserver {
  Timer? _timer;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // 1. REMOVED: _checkPersistenceOnStart() from here.
    // We don't want to check the OLD timestamp from the previous session 
    // immediately upon startup.
    
    _resetTimer(); // Start a FRESH timer for the current session
  }

  // This now only saves the time; it doesn't trigger the logout logic
  Future<void> _saveTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_action_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When they come back, we reset the timer based on the MOMENT they returned,
      // not based on when they left.
      _resetTimer(); 
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    // We do NOT save the timestamp to SharedPreferences here 
    // because that's for cross-session persistence. 
    // We just want an in-memory timer for active movement.
    _timer = Timer(widget.timeout, () {
      _showInactivityDialog();
    });
  }

  void _resetTimer() {
    if (!_isDialogShowing) {
      _startTimer();
      _saveTimestamp(); // Keep SharedPreferences updated for other checks
    }
  }

  void _showInactivityDialog() async {
    final auth = FirebaseAuth.instance;
    // Only show if user is actually logged in and dialog isn't already up
    if (auth.currentUser == null || _isDialogShowing) return;

    _isDialogShowing = true;
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Session Inactive', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('You have been inactive for a while. You will be logged out for security.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleAutoLogout();
              },
              child: const Text('OK', style: TextStyle(color: Color(0xFF4F46E5))),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAutoLogout() async {
    try {
      final FirebaseAuth auth = FirebaseAuth.instance;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('userId');
      await prefs.remove('userName');
      await prefs.remove('last_action_timestamp');
      await auth.signOut();

      _isDialogShowing = false;

      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Session Manager Error: $e');
      _isDialogShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // This is the "Movement/Interaction" trigger
      onPointerDown: (_) => _resetTimer(),
      behavior: HitTestBehavior.translucent, 
      child: widget.child,
    );
  }
}