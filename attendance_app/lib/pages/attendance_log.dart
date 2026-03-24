import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';

class AttendanceLogPage extends StatefulWidget {
  final Employee employee;
  final String currentStatus;
  final Color statusColor;

  const AttendanceLogPage({
    super.key,
    required this.employee,
    required this.currentStatus,
    required this.statusColor,
  });

  @override
  State<AttendanceLogPage> createState() => _AttendanceLogPageState();
}

class _AttendanceLogPageState extends State<AttendanceLogPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  late int _selectedYear;
  late int _selectedMonth;
  
  // ✅ 1. Store the stream in a variable to prevent "flickering"
  late Stream<QuerySnapshot> _attendanceStream;

  static const Color bgColor = Color(0xFFF2F3F7);
  static const Color primaryColor = Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    
    // ✅ 2. Initialize the stream once during setup
    _updateStream();
  }

  /// Updates the stream variable. Call this whenever filters change.
  void _updateStream() {
    final firstDay = DateTime(_selectedYear, _selectedMonth, 1);
    final lastDay = (_selectedMonth < 12)
        ? DateTime(_selectedYear, _selectedMonth + 1, 1)
        : DateTime(_selectedYear + 1, 1, 1);

    final startTimestamp = Timestamp.fromDate(firstDay);
    final endTimestamp = Timestamp.fromDate(lastDay);

    setState(() {
      _attendanceStream = FirebaseFirestore.instance
          .collection('attendance')
          .where('employeeId', isEqualTo: widget.employee.id)
          .where('timeIn', isGreaterThanOrEqualTo: startTimestamp)
          .where('timeIn', isLessThan: endTimestamp)
          .orderBy('timeIn', descending: true)
          .snapshots();
    });
  }

  Future<void> _selectYear() async {
    final int? picked = await showDialog(
      context: context,
      builder: (context) => _YearPickerDialog(initialYear: _selectedYear),
    );
    if (picked != null && picked != _selectedYear) {
      _selectedYear = picked;
      _updateStream(); // ✅ 3. Refresh stream on change
    }
  }

  Future<void> _selectMonth() async {
    final int? picked = await showDialog(
      context: context,
      builder: (context) => _MonthPickerDialog(initialMonth: _selectedMonth),
    );
    if (picked != null && picked != _selectedMonth) {
      _selectedMonth = picked;
      _updateStream(); // ✅ 3. Refresh stream on change
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
                      _buildTableHeader(),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _attendanceStream, // ✅ 4. Use the variable
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(child: Text('Error: ${snapshot.error}'));
                            }

                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return _buildEmptyState();
                            }

                            return ListView.builder(
                              itemCount: snapshot.data!.docs.length,
                              itemBuilder: (context, index) {
                                final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                                return _buildDataRow(data);
                              },
                            );
                          },
                        ),
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

  Widget _buildTableHeader() {
    return Container(
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
    );
  }

  Widget _buildDataRow(Map<String, dynamic> data) {
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
            const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
            Text(widget.currentStatus,
                style: TextStyle(color: widget.statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
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
            child: _buildFilterDropdown(_selectedYear.toString(), Icons.calendar_today_outlined),
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

// --- Supporting Widgets (Dialogs & Text Styles) ---

class _YearPickerDialog extends StatelessWidget {
  final int initialYear;
  const _YearPickerDialog({required this.initialYear});

  @override
  Widget build(BuildContext context) {
    final int currentYear = DateTime.now().year;
    final List<int> years = List.generate(6, (index) => currentYear - 5 + index).reversed.toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text('Select Year', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 100,
        height: 250,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: years.length,
          itemBuilder: (context, index) {
            final year = years[index];
            return ListTile(
              title: Text(year.toString(),
                  style: TextStyle(
                    fontWeight: year == initialYear ? FontWeight.bold : FontWeight.normal,
                    color: year == initialYear ? _AttendanceLogPageState.primaryColor : null,
                  )),
              onTap: () => Navigator.of(context).pop(year),
            );
          },
        ),
      ),
    );
  }
}

class _MonthPickerDialog extends StatelessWidget {
  final int initialMonth;
  const _MonthPickerDialog({required this.initialMonth});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text('Select Month', style: TextStyle(fontWeight: FontWeight.bold)),
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

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
}

class _DataText extends StatelessWidget {
  final String text;
  final Color? color;
  final FontWeight? fontWeight;
  const _DataText(this.text, {this.color, this.fontWeight});
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 12, color: color ?? Colors.black87, fontWeight: fontWeight ?? FontWeight.normal));
}