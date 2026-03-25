import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/login_page.dart'; 

class SessionManager extends StatefulWidget {
  final Widget child;
  final Duration timeout;

  const SessionManager({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 30),
  });

  @override
  State<SessionManager> createState() => _SessionManagerState();
}

// 1. Add WidgetsBindingObserver to listen for app background/foreground events
class _SessionManagerState extends State<SessionManager> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _lastActivity = DateTime.now();

  @override
  void initState() {
    super.initState();
    // 2. Register the observer
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    // 3. Unregister the observer
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // 4. Handle App Lifecycle (Background to Foreground)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInactivityOnResume();
    }
  }

  void _checkInactivityOnResume() {
    final diff = DateTime.now().difference(_lastActivity);
    if (diff >= widget.timeout) {
      // User was away longer than the timeout
      _handleAutoLogout();
    } else {
      // User returned within the time limit, restart timer with remaining time
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _lastActivity = DateTime.now(); // Update the timestamp
    _timer = Timer(widget.timeout, _handleAutoLogout);
  }

  void _resetTimer() {
    // Only reset if we are logged in (avoids timer running on Login/Splash)
    if (FirebaseAuth.instance.currentUser != null) {
      _startTimer();
    }
  }

  Future<void> _handleAutoLogout() async {
    try {
      final FirebaseAuth auth = FirebaseAuth.instance;
      if (auth.currentUser == null) return;

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('userId');
      await prefs.remove('userName');

      await auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out due to 30 minutes of inactivity'),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Session Manager Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetTimer(),
      behavior: HitTestBehavior.translucent, 
      child: widget.child,
    );
  }
}