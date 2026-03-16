class Employee {
  String id;
  String name;
<<<<<<< HEAD

  Employee({required this.name});
=======
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
>>>>>>> 90cc72584c540e8d03c0d23fd3012d700a73a45b
}