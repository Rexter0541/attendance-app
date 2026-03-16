import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';

class AttendanceLogPage extends StatefulWidget {
  final Employee employee;
  final String currentStatus;
  final Color statusColor;
  const AttendanceLogPage(
      {super.key,
      required this.employee,
      required this.currentStatus,
      required this.statusColor});

  @override
  State<AttendanceLogPage> createState() => _AttendanceLogPageState();
}

class _AttendanceLogPageState extends State<AttendanceLogPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  late int _selectedYear;
  late int _selectedMonth;

  static const Color bgColor = Color(0xFFF2F3F7);
  static const Color primaryColor = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  /// Creates a Firestore stream based on the selected filters.
  Stream<QuerySnapshot> _getAttendanceStream() {
    if (user == null) return const Stream.empty();

    final firstDay = DateTime(_selectedYear, _selectedMonth, 1);
    // Go to the first moment of the next month for the 'isLessThan' query.
    final lastDay = DateTime(_selectedYear, _selectedMonth + 1, 1);

    return FirebaseFirestore.instance
        .collection('attendance')
        .where('employeeId', isEqualTo: widget.employee.id)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .where('timestamp', isLessThan: Timestamp.fromDate(lastDay))
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Shows a dialog to select the year.
  Future<void> _selectYear() async {
    final int? picked = await showDialog(
      context: context,
      builder: (context) => _YearPickerDialog(initialYear: _selectedYear),
    );
    if (picked != null && picked != _selectedYear) {
      setState(() => _selectedYear = picked);
    }
  }

  /// Shows a dialog to select the month.
  Future<void> _selectMonth() async {
    final int? picked = await showDialog(
      context: context,
      builder: (context) => _MonthPickerDialog(initialMonth: _selectedMonth),
    );
    if (picked != null && picked != _selectedMonth) {
      setState(() => _selectedMonth = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 25),
              _buildFilters(),
              const SizedBox(height: 20),
              
              // --- Main Data Table Container ---
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(26),
                        blurRadius: 10,
                        offset: const Offset(4, 4),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(child: Center(child: _HeaderText('Name'))),
                            Expanded(child: Center(child: _HeaderText('Time-in'))),
                            Expanded(child: Center(child: _HeaderText('Time-out'))),
                            Expanded(child: Center(child: _HeaderText('Date'))),
                          ],
                        ),
                      ),
                      
                      // ✅ Attendance List Body
                      StreamBuilder<QuerySnapshot>(
                        stream: _getAttendanceStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Expanded(child: Center(child: CircularProgressIndicator()));
                          }
                          if (snapshot.hasError) {
                            debugPrint("ATTENDANCE LOG ERROR: ${snapshot.error}");
                            return const Expanded(child: Center(child: Text("Missing Index. Check Debug Console.")));
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Expanded(child: _buildEmptyState());
                          }

                          return Expanded(child: _buildList(snapshot.data!.docs));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<DocumentSnapshot> docs) {
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        return _buildDataRow(docs[index].data() as Map<String, dynamic>);
      },
    );
  }

  // ✅ Helper to build individual data rows
  Widget _buildDataRow(Map<String, dynamic> data) {
    // Format Data
    final String name = widget.employee.name;
    final String date = data['timeIn'] != null 
        ? DateFormat('MMM dd').format((data['timeIn'] as Timestamp).toDate()) 
        : '--';
    final String timeIn = data['timeIn'] != null 
        ? DateFormat('h:mm a').format((data['timeIn'] as Timestamp).toDate()) 
        : '--';
    final String timeOut = data['timeOut'] != null 
        ? DateFormat('h:mm a').format((data['timeOut'] as Timestamp).toDate()) 
        : '--';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(child: Center(child: _DataText(name))),
          Expanded(child: Center(child: _DataText(timeIn, color: Colors.blue))),
          Expanded(child: Center(child: _DataText(timeOut, color: Colors.orange))),
          Expanded(child: Center(child: _DataText(date, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee: ${widget.employee.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Text('Location: Company A', style: TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
        Row(
          children: [
            const Text('Status: ',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
            Text(widget.currentStatus,
                style: TextStyle(
                    color: widget.statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ],
        )
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _selectYear,
            child: _buildFilterDropdown(
                _selectedYear.toString(), Icons.calendar_today_outlined),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: InkWell(
            onTap: _selectMonth,
            child: _buildFilterDropdown(
                DateFormat('MMMM').format(DateTime(0, _selectedMonth)), Icons.keyboard_arrow_down),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black87),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Icon(icon, size: 18),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        const Text('No Logs Found', style: TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }
}

/// A simple dialog to pick a year.
class _YearPickerDialog extends StatelessWidget {
  final int initialYear;
  const _YearPickerDialog({required this.initialYear});

  @override
  Widget build(BuildContext context) {
    final int currentYear = DateTime.now().year;
    final List<int> years =
        List.generate(6, (index) => currentYear - 5 + index).reversed.toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text('Select Year',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 100,
        height: 250,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: years.length,
          itemBuilder: (context, index) {
            final year = years[index];
            return ListTile(
              title: Text(
                year.toString(),
                style: TextStyle(
                  fontWeight:
                      year == initialYear ? FontWeight.bold : FontWeight.normal,
                  color: year == initialYear
                      ? _AttendanceLogPageState.primaryColor
                      : null,
                ),
              ),
              onTap: () => Navigator.of(context).pop(year),
            );
          },
        ),
      ),
    );
  }
}

/// A simple dialog to pick a month.
class _MonthPickerDialog extends StatelessWidget {
  final int initialMonth;
  const _MonthPickerDialog({required this.initialMonth});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text('Select Month',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 100,
        height: 350,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: 12,
          itemBuilder: (context, index) {
            final month = index + 1;
            final monthName = DateFormat('MMMM').format(DateTime(0, month));
            return ListTile(
              title: Text(monthName,
                  style: TextStyle(
                      fontWeight: month == initialMonth ? FontWeight.bold : FontWeight.normal,
                      color: month == initialMonth ? _AttendanceLogPageState.primaryColor : null)),
              onTap: () => Navigator.of(context).pop(month),
            );
          },
        ),
      ),
    );
  }
}

/// Header Text Style
class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
  }
}

/// Data Text Style
class _DataText extends StatelessWidget {
  final String text;
  final Color? color;
  final FontWeight? fontWeight;
  const _DataText(this.text, {this.color, this.fontWeight});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: color ?? Colors.black87,
        fontWeight: fontWeight ?? FontWeight.normal,
      ),
    );
  }
}