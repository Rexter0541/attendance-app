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
  late Stream<QuerySnapshot> _attendanceStream;

  static const Color bgColor = Color(0xFFF8FAFC);
  static const Color primaryColor = Color(0xFF6366F1); // Matching Directory Accent

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _updateStream();
  }

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
      _updateStream();
    }
  }

  Future<void> _selectMonth() async {
    final int? picked = await showDialog(
      context: context,
      builder: (context) => _MonthPickerDialog(initialMonth: _selectedMonth),
    );
    if (picked != null && picked != _selectedMonth) {
      _selectedMonth = picked;
      _updateStream();
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
              _buildBackButton(),
              _buildHeader(),
              const SizedBox(height: 25),
              _buildFilters(),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(28),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTableHeader(),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _attendanceStream,
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
                              physics: const BouncingScrollPhysics(),
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

  Widget _buildBackButton() {
    if (!Navigator.canPop(context)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Row(
          children: [
            Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: primaryColor),
            const SizedBox(width: 6),
            Text('Back', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
          ],
        ),
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
            Text(widget.employee.name,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF0F172A))),
            const Text('Workforce Accountability Log',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.statusColor.withAlpha(26),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(widget.currentStatus,
              style: TextStyle(color: widget.statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
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
            child: _buildFilterDropdown(_selectedYear.toString(), Icons.calendar_month_rounded),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: _selectMonth,
            child: _buildFilterDropdown(
                DateFormat('MMMM').format(DateTime(0, _selectedMonth)),
                Icons.filter_list_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
      ),
      child: const Row(
        children: [
          Expanded(child: Center(child: _HeaderText('DATE'))),
          Expanded(child: Center(child: _HeaderText('IN'))),
          Expanded(child: Center(child: _HeaderText('OUT'))),
          Expanded(child: Center(child: _HeaderText('STATUS'))),
        ],
      ),
    );
  }

  Widget _buildDataRow(Map<String, dynamic> data) {
    // Variable 'name' removed to fix unused_local_variable warning
    final String date = data['timeIn'] != null 
        ? DateFormat('MMM dd').format((data['timeIn'] as Timestamp).toDate()) 
        : '--';
    final String timeIn = data['timeIn'] != null
        ? DateFormat('h:mm a').format((data['timeIn'] as Timestamp).toDate())
        : '--';
    final String timeOut = data['timeOut'] != null
        ? DateFormat('h:mm a').format((data['timeOut'] as Timestamp).toDate())
        : '--';

    String statusLabel = '--';
    Color statusColor = Colors.grey;

    if (data['timeIn'] != null) {
      final DateTime dt = (data['timeIn'] as Timestamp).toDate();
      final DateTime officialStart = DateTime(dt.year, dt.month, dt.day, 8, 0);

      if (dt.isAfter(officialStart)) {
        statusLabel = 'Late';
        statusColor = Colors.redAccent;
      } else {
        statusLabel = 'On Time';
        statusColor = const Color(0xFF10B981);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
      ),
      child: Row(
        children: [
          Expanded(child: Center(child: _DataText(date, fontWeight: FontWeight.bold))),
          Expanded(child: Center(child: _DataText(timeIn, color: const Color(0xFF475569)))),
          Expanded(child: Center(child: _DataText(timeOut, color: const Color(0xFF475569)))),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          const Text('No attendance logs found for this period',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// --- Supporting Dialogs ---

class _YearPickerDialog extends StatelessWidget {
  final int initialYear;
  const _YearPickerDialog({required this.initialYear});

  @override
  Widget build(BuildContext context) {
    final int currentYear = DateTime.now().year;
    final List<int> years = List.generate(10, (index) => currentYear - 5 + index).reversed.toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Select Year', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: years.length,
          itemBuilder: (context, index) {
            final year = years[index];
            return ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              selected: year == initialYear,
              selectedTileColor: _AttendanceLogPageState.primaryColor.withAlpha(26),
              title: Text(year.toString(),
                  style: TextStyle(
                    fontWeight: year == initialYear ? FontWeight.bold : FontWeight.normal,
                    color: year == initialYear ? _AttendanceLogPageState.primaryColor : const Color(0xFF1E293B),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Select Month', style: TextStyle(fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: 12,
          itemBuilder: (context, index) {
            final month = index + 1;
            final monthName = DateFormat('MMMM').format(DateTime(0, month));
            return ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              selected: month == initialMonth,
              selectedTileColor: _AttendanceLogPageState.primaryColor.withAlpha(26),
              title: Text(monthName,
                  style: TextStyle(
                      fontWeight: month == initialMonth ? FontWeight.bold : FontWeight.normal,
                      color: month == initialMonth ? _AttendanceLogPageState.primaryColor : const Color(0xFF1E293B))),
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
  Widget build(BuildContext context) => Text(text, 
    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1, color: Color(0xFF94A3B8)));
}

class _DataText extends StatelessWidget {
  final String text;
  final Color? color;
  final FontWeight? fontWeight;
  const _DataText(this.text, {this.color, this.fontWeight});
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 12, color: color ?? const Color(0xFF1E293B), fontWeight: fontWeight ?? FontWeight.w500));
}