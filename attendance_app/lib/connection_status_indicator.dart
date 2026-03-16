import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ConnectionStatusIndicator extends StatefulWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  State<ConnectionStatusIndicator> createState() =>
      _ConnectionStatusIndicatorState();
}

class _ConnectionStatusIndicatorState extends State<ConnectionStatusIndicator> {
  // Assume connected at first, and let the check confirm if otherwise.
  bool _isConnected = true;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Check immediately and then periodically every 5 seconds.
    _checkConnection();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnection();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    bool currentlyConnected;
    try {
      // We perform a lightweight server-only operation to check connectivity.
      // Getting a non-existent document is a reliable and low-cost way to
      // confirm the client can communicate with the Firestore backend.
      await FirebaseFirestore.instance
          .doc('_internal_health_check/status')
          .get(const GetOptions(source: Source.server));
      currentlyConnected = true;
    } on FirebaseException catch (e) {
      debugPrint('Connection check failed with FirebaseException: [${e.code}] ${e.message}');
      // Any Firebase exception during this check implies a problem with the connection or setup.
      currentlyConnected = false;
    } catch (e) {
      debugPrint('Connection check failed with generic error: $e');
      // For any other exception, assume disconnection.
      currentlyConnected = false;
    }

    // Update state only if it has changed to avoid unnecessary rebuilds.
    if (mounted && _isConnected != currentlyConnected) {
      setState(() => _isConnected = currentlyConnected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _isConnected ? Colors.green.shade400 : Colors.red.shade400;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.7),
            blurRadius: 4.0,
          ),
        ],
      ),
    );
  }
}