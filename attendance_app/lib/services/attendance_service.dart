import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee.dart';
import '../models/attendance_session.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================
  // CHECK IF EMPLOYEE ALREADY HAS ATTENDANCE TODAY
  // ============================================
  Future<AttendanceSession?> checkTodayAttendance(Employee employee) async {

    final now = DateTime.now();

    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final snapshot = await _firestore
        .collection('attendance')
        .where('employeeId', isEqualTo: employee.id)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final doc = snapshot.docs.first;
    final data = doc.data();

    final coords = data['coords'] ?? {};

    return AttendanceSession(
      id: doc.id,
      lat: (coords['lat'] ?? 0).toDouble(),
      lng: (coords['lng'] ?? 0).toDouble(),
      distance: (coords['distance'] ?? 0).toDouble(),
    );
  }

  // ============================================
  // CREATE NEW ATTENDANCE RECORD
  // ============================================
  Future<String> createAttendance({
    required Employee employee,
    required double lat,
    required double lng,
    required double distance,
  }) async {

    final docRef = await _firestore.collection("attendance").add({
      "employeeId": employee.id,
      "employeeName": employee.name,
      "status": "verified",
      "timeIn": null,
      "timeOut": null,

      "coords": {
        "lat": lat,
        "lng": lng,
        "distance": distance,
      },

      "timestamp": Timestamp.now(),
    });

    return docRef.id;
  }
}