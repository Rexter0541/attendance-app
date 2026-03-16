import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';

class PayrollPage extends StatefulWidget {
  final Employee employee;
  final String currentStatus;
  final Color statusColor;

  const PayrollPage(
      {super.key,
      required this.employee,
      required this.currentStatus,
      required this.statusColor});

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  List<Map<String, dynamic>> _payrollResults = [];
  late int _selectedYear;
  late int _selectedMonth;
  Map<int, bool> expandedRows = {};

  // Payroll Config
  static const double _dailyWage = 650.0;
  static const double _lateDeductionPerMinute = 0.01;
  static const int _requiredWorkHours = 8;
  static const int _defaultTimeOutHour = 17; // 5 PM default

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _recalculateAndSavePayroll(_selectedYear, _selectedMonth);
  }

  /// MAIN FUNCTION: Recalculates based on filtered attendance
  Future<void> _recalculateAndSavePayroll(int year, int month) async {
    if (mounted) setState(() => _isLoading = true);

    List<Map<String, dynamic>> results = [];
    final now = DateTime.now();

    // --- Period 1: 1st to 15th ---
    final period1Start = DateTime(year, month, 1);
    final period1End = DateTime(year, month, 15);
    if (now.isAfter(period1Start) || now.isAtSameMomentAs(period1Start)) {
      final period1Result = await _calculatePayForPeriod(period1Start, period1End);
      final netPay1 = period1Result['total'];
      final daily1 = period1Result['daily'];
      await _savePayrollToFirestore(period1Start, period1End, netPay1);
      results.add({
        'netpay': netPay1.toStringAsFixed(2),
        'month': DateFormat('MMMM').format(period1Start),
        'date': DateFormat('MMM dd, yyyy').format(period1End),
        'status': now.isAfter(period1End) ? 'Calculated' : 'Processing',
        'daily': daily1,
      });
    }

    // --- Period 2: 16th to end of month ---
    final period2Start = DateTime(year, month, 16);
    final period2End = DateTime(year, month + 1, 0);
    if (now.isAfter(period2Start) || now.isAtSameMomentAs(period2Start)) {
      final period2Result = await _calculatePayForPeriod(period2Start, period2End);
      final netPay2 = period2Result['total'];
      final daily2 = period2Result['daily'];
      await _savePayrollToFirestore(period2Start, period2End, netPay2);
      results.add({
        'netpay': netPay2.toStringAsFixed(2),
        'month': DateFormat('MMMM').format(period2Start),
        'date': DateFormat('MMM dd, yyyy').format(period2End),
        'status': now.isAfter(period2End) ? 'Calculated' : 'Processing',
        'daily': daily2,
      });
    }

    if (mounted) {
      setState(() {
        _payrollResults = results.reversed.toList();
        _isLoading = false;
      });
    }
  }

  /// CALCULATE PAY: Points to the root 'attendance' collection
  Future<Map<String, dynamic>> _calculatePayForPeriod(DateTime start, DateTime end) async {
    double totalPay = 0;
    List<Map<String, dynamic>> dailyBreakdown = [];

    final adjustedEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);

    // FIX: Look in root 'attendance' where employeeId matches
    final attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance') 
        .where('employeeId', isEqualTo: widget.employee.id) 
        .where('timeIn', isGreaterThanOrEqualTo: start)
        .where('timeIn', isLessThanOrEqualTo: adjustedEnd)
        .get();

    for (var doc in attendanceSnapshot.docs) {
      final data = doc.data();
      final timeIn = (data['timeIn'] as Timestamp?)?.toDate();
      DateTime? timeOut = (data['timeOut'] as Timestamp?)?.toDate();

      if (timeIn == null) continue;

      timeOut ??= DateTime(timeIn.year, timeIn.month, timeIn.day, _defaultTimeOutHour);

      final durationSeconds = timeOut.difference(timeIn).inSeconds;
      final hoursWorked = durationSeconds / 3600.0;

      final officialStart = DateTime(timeIn.year, timeIn.month, timeIn.day, 8, 0);
      double lateDeduction = 0;

      if (timeIn.isAfter(officialStart)) {
        final minutesLate = timeIn.difference(officialStart).inMinutes;
        lateDeduction = minutesLate * _lateDeductionPerMinute;
      }

      double dailyEarning = 0;
      if (hoursWorked >= _requiredWorkHours) {
        dailyEarning = _dailyWage;
      } else if (hoursWorked > 0) {
        final hourlyRate = _dailyWage / _requiredWorkHours;
        dailyEarning = hoursWorked * hourlyRate;
      }

      final finalDailyPay = dailyEarning - lateDeduction;
      totalPay += finalDailyPay > 0 ? finalDailyPay : 0;

      dailyBreakdown.add({
        'date': DateFormat('MMM dd').format(timeIn),
        'hoursWorked': hoursWorked.toStringAsFixed(2),
        'lateDeduction': lateDeduction.toStringAsFixed(2),
        'dailyEarning': dailyEarning.toStringAsFixed(2),
        'finalPay': finalDailyPay > 0 ? finalDailyPay.toStringAsFixed(2) : '0.00',
      });
    }

    return {'total': totalPay, 'daily': dailyBreakdown};
  }

  /// SAVE PAYROLL: Saves to employees/{id}/payroll sub-collection
  Future<void> _savePayrollToFirestore(
      DateTime periodStart, DateTime periodEnd, double netPay) async {
    
    final docId = '${periodStart.year}-${periodStart.month.toString().padLeft(2, '0')}-${periodStart.day == 1 ? '1' : '2'}';

    final payrollDocRef = FirebaseFirestore.instance
        .collection('employees')
        .doc(widget.employee.id) 
        .collection('payroll')
        .doc(docId);

    try {
      await payrollDocRef.set({
        'netpay': netPay,
        'periodStart': periodStart,
        'periodEnd': periodEnd,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving payroll: $e');
    }
  }

  // --- UI Logic (Headers, Rows, Filters - No logic changes below) ---

  static const Color bgColor = Color(0xFFF2F3F7);

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
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(child: Center(child: _HeaderText('Netpay'))),
                            Expanded(child: Center(child: _HeaderText('Month'))),
                            Expanded(child: Center(child: _HeaderText('Payment Date'))),
                            Expanded(child: Center(child: _HeaderText('Status'))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _payrollResults.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                    itemCount: _payrollResults.length,
                                    itemBuilder: (context, index) {
                                      return _buildPayrollRow(_payrollResults[index], index);
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPayrollRow(Map<String, dynamic> data, int index) {
    final netPay = data['netpay'] ?? '0.00';
    final month = data['month'] ?? '--';
    final date = data['date'] ?? '--';
    final status = data['status'] ?? 'Pending';
    final daily = data['daily'] ?? [];
    final statusColor = status == 'Paid' ? Colors.green : Colors.orange;
    final isExpanded = expandedRows[index] ?? false;

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => expandedRows[index] = !isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
            child: Row(
              children: [
                Expanded(child: Center(child: _DataText('₱$netPay', fontWeight: FontWeight.bold, color: Colors.blue[800]))),
                Expanded(child: Center(child: _DataText(month))),
                Expanded(child: Center(child: _DataText(date))),
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withAlpha(28), borderRadius: BorderRadius.circular(6)),
                      child: _DataText(status, color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          ...daily.map<Widget>((day) => _buildDailyDetail(day)).toList(),
      ],
    );
  }

  Widget _buildDailyDetail(Map<String, dynamic> day) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(day['date'], style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _detailRow('Hours Worked:', '${day['hoursWorked']} hrs'),
          _detailRow('Late Deduction:', '₱${day['lateDeduction']}', color: Colors.red),
          const SizedBox(height: 8),
          _detailRow('Daily Pay:', '₱${day['finalPay']}', isBold: true, color: Colors.blue),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54)),
        Text(value, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      ],
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
            Text(widget.currentStatus, style: TextStyle(color: widget.statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        )
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(child: InkWell(onTap: _selectYear, child: _buildFilterDropdown(_selectedYear.toString(), Icons.calendar_today_outlined))),
        const SizedBox(width: 15),
        Expanded(child: InkWell(onTap: _selectMonth, child: _buildFilterDropdown(DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth)), Icons.keyboard_arrow_down))),
      ],
    );
  }

  Widget _buildFilterDropdown(String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black87)),
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
        const Text('No Data', style: TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }

  Future<void> _selectYear() async {
    final int? picked = await showDialog(context: context, builder: (context) => _YearPickerDialog(initialYear: _selectedYear));
    if (picked != null) {
      setState(() => _selectedYear = picked);
      _recalculateAndSavePayroll(_selectedYear, _selectedMonth);
    }
  }

  Future<void> _selectMonth() async {
    final int? picked = await showDialog(context: context, builder: (context) => _MonthPickerDialog(initialMonth: _selectedMonth));
    if (picked != null) {
      setState(() => _selectedMonth = picked);
      _recalculateAndSavePayroll(_selectedYear, _selectedMonth);
    }
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);
  @override Widget build(BuildContext context) => Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
}

class _DataText extends StatelessWidget {
  final String text;
  final Color? color;
  final FontWeight? fontWeight;
  const _DataText(this.text, {this.color, this.fontWeight});
  @override Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 12, color: color ?? Colors.black87, fontWeight: fontWeight ?? FontWeight.normal));
}

class _YearPickerDialog extends StatelessWidget {
  final int initialYear;
  const _YearPickerDialog({required this.initialYear});
  @override Widget build(BuildContext context) {
    final List<int> years = List.generate(5, (index) => DateTime.now().year - index);
    return AlertDialog(
      title: const Text('Select Year'),
      content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: years.length, itemBuilder: (context, index) {
        return ListTile(title: Text(years[index].toString()), onTap: () => Navigator.pop(context, years[index]));
      })),
    );
  }
}

class _MonthPickerDialog extends StatelessWidget {
  final int initialMonth;
  const _MonthPickerDialog({required this.initialMonth});
  @override Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Month'),
      content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: 12, itemBuilder: (context, index) {
        return ListTile(title: Text(DateFormat('MMMM').format(DateTime(0, index + 1))), onTap: () => Navigator.pop(context, index + 1));
      })),
    );
  }
}