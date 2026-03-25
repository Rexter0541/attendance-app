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

  // UI Constants (Modern Design System)
  static const Color bgColor = Color(0xFFF8F9FC);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    
    // ✅ 2. Initialize the stream once during setup
    // DO NOT call setState in initState. Just set the variable directly or via a method that allows bypassing setState.
    _updateStream(initialize: true);
  }

  /// Updates the stream variable. Call this whenever filters change.
  void _updateStream({bool initialize = false}) {
    final firstDay = DateTime(_selectedYear, _selectedMonth, 1);
    final lastDay = (_selectedMonth < 12)
        ? DateTime(_selectedYear, _selectedMonth + 1, 1)
        : DateTime(_selectedYear + 1, 1, 1);

    final startTimestamp = Timestamp.fromDate(firstDay);
    final endTimestamp = Timestamp.fromDate(lastDay);

    final stream = FirebaseFirestore.instance
        .collection('attendance')
        .where('employeeId', isEqualTo: widget.employee.id)
        .where('timeIn', isGreaterThanOrEqualTo: startTimestamp)
        .where('timeIn', isLessThan: endTimestamp)
        .orderBy('timeIn', descending: true)
        .snapshots();

    if (initialize) {
      _attendanceStream = stream;
    } else {
      setState(() {
        _attendanceStream = stream;
      });
    }
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Attendance Log',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildEmployeeCard(),
              const SizedBox(height: 20),
              _buildFilters(),
              const SizedBox(height: 20),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _attendanceStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: primaryColor));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        return _buildAttendanceCard(data);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> data) {
    final String date = data['timeIn'] != null
        ? DateFormat('MMM dd').format((data['timeIn'] as Timestamp).toDate())
        : '--';
    final String fullDate = data['timeIn'] != null
        ? DateFormat('EEEE, MMMM d').format((data['timeIn'] as Timestamp).toDate())
        : '--';
    final String timeIn = data['timeIn'] != null
        ? DateFormat('h:mm a').format((data['timeIn'] as Timestamp).toDate())
        : '--';
    final String timeOut = data['timeOut'] != null
        ? DateFormat('h:mm a').format((data['timeOut'] as Timestamp).toDate())
        : '--';

    // Logic para sa Status (Late vs On Time)
    String status = '--';
    Color itemStatusColor = Colors.grey;

    if (data['timeIn'] != null) {
      final DateTime dt = (data['timeIn'] as Timestamp).toDate();
      // Set 8:00 AM as the official start time
      final DateTime officialStart = DateTime(dt.year, dt.month, dt.day, 8, 0);

      if (dt.isAfter(officialStart)) {
        status = 'LATE';
        itemStatusColor = Colors.orange;
      } else {
        status = 'ON TIME';
        itemStatusColor = Colors.green;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  date.split(' ')[1], // Day
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor),
                ),
                Text(
                  date.split(' ')[0], // Month
                  style: const TextStyle(fontSize: 12, color: primaryColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(color: itemStatusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                          color: itemStatusColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                )
              ],
            ),
          ),
          // Times
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(timeIn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
              const SizedBox(height: 4),
              Text(timeOut, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEmployeeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              widget.employee.name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employee.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: widget.statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.currentStatus,
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _selectYear,
            child: _buildFilterDropdown(_selectedYear.toString(), Icons.calendar_today_outlined),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: GestureDetector(
            onTap: _selectMonth,
            child: _buildFilterDropdown(
                DateFormat('MMMM').format(DateTime(0, _selectedMonth)),
                Icons.keyboard_arrow_down),
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
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
          Icon(icon, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        const Text('No Logs Found',
            style: TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }
}

/// Year Picker Dialog
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

/// Month Picker Dialog
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
                      fontWeight:
                          month == initialMonth ? FontWeight.bold : FontWeight.normal,
                      color: month == initialMonth
                          ? _AttendanceLogPageState.primaryColor
                          : null)),
              onTap: () => Navigator.of(context).pop(month),
            );
          },
        ),
      ),
    );
  }
}