import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class SecurityService {
  /// Verifies the scanned QR value against the secret stored in Firestore.
  static Future<bool> verifyQRWithFirebase(String scannedValue) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('attendance_config')
          .get();

      if (doc.exists) {
        String serverSecret = (doc.data()?['qr_secret'] ?? '').toString().trim();
        return scannedValue.trim() == serverSecret;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Checks if the provided position is using a mock provider (spoofing).
  static bool isLocationMocked(Position? position) => 
      position?.isMocked ?? false;

  /// Compares local device time with server time to prevent "Time Travel" cheating.
  /// Returns true if the clock is synced within a 2-minute margin.
  static Future<bool> verifyTimeSync() async {
    try {
      // We use the 'serverTimestamp' behavior of Firestore to check drift
      // By fetching a document that contains a server-side timestamp
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('time_sync')
          .get();
      
      // If the setting doesn't exist, we fallback to true but log it
      if (!doc.exists) return true;

      DateTime serverTime = (doc.data()?['current_time'] as Timestamp).toDate();
      DateTime localTime = DateTime.now();
      
      // Allow for a 2-minute (120 seconds) discrepancy
      return localTime.difference(serverTime).inSeconds.abs() < 120;
    } catch (e) {
      // In case of network error during time check, we allow to proceed 
      // but the backend should use server-side timestamps for the final record.
      return true; 
    }
  }
}