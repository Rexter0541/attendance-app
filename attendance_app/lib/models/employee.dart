class Employee {
  String id;
  String name;
  String status;

  DateTime? timeIn;
  DateTime? timeOut;

  String? attendanceId; // ⭐ Firestore document reference

  Employee({
    required this.id,
    required this.name,
    this.status = "Not Timed In",
    this.timeIn,
    this.timeOut,
    this.attendanceId,
  });
}