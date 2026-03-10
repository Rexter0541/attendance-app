class Employee {
  String name;
  String status;
  DateTime? timeIn;
  DateTime? timeOut;

  Employee({
    required this.name,
    this.status = "Not Timed In",
    this.timeIn,
    this.timeOut,
  });
}