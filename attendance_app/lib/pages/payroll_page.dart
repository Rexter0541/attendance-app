import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';

class PayrollPage extends StatefulWidget {
  final Employee employee;
  final String currentStatus;
  final Color statusColor;

  const PayrollPage({
    super.key,
    required this.employee,
    required this.currentStatus,
    required this.statusColor,
  });

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

  // UI Constants
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
    _recalculateAndSavePayroll(_selectedYear, _selectedMonth);
  }

  Future<void> _recalculateAndSavePayroll(int year, int month) async {
    if (mounted) setState(() => _isLoading = true);

    List<Map<String, dynamic>> results = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      // Period 1 (1st to 15th)
      final period1Start = DateTime(year, month, 1);
      final period1End = DateTime(year, month, 15);
      final isFinal1 = today.isAfter(period1End);

      if (now.isAfter(period1Start) || now.isAtSameMomentAs(period1Start)) {
        final period1Result = await _calculatePayForPeriod(period1Start, period1End);
        final netPay1 = period1Result['total'];
        final daily1 = period1Result['daily'];
        await _savePayrollToFirestore(period1Start, period1End, netPay1, isFinal1);
        results.add({
          'netpay': netPay1.toStringAsFixed(2),
          'month': DateFormat('MMMM').format(period1Start),
          'date': DateFormat('MMM dd, yyyy').format(period1End),
          'status': isFinal1 ? 'Calculated' : 'Processing',
          'daily': daily1,
        });
      }

      // Period 2 (16th to End of Month)
      final period2Start = DateTime(year, month, 16);
      final period2End = DateTime(year, month + 1, 0);
      final isFinal2 = today.isAfter(period2End);

      if (now.isAfter(period2Start) || now.isAtSameMomentAs(period2Start)) {
        final period2Result = await _calculatePayForPeriod(period2Start, period2End);
        final netPay2 = period2Result['total'];
        final daily2 = period2Result['daily'];
        await _savePayrollToFirestore(period2Start, period2End, netPay2, isFinal2);
        results.add({
          'netpay': netPay2.toStringAsFixed(2),
          'month': DateFormat('MMMM').format(period2Start),
          'date': DateFormat('MMM dd, yyyy').format(period2End),
          'status': isFinal2 ? 'Calculated' : 'Processing',
          'daily': daily2,
        });
      }

      if (mounted) {
        setState(() {
          _payrollResults = results.reversed.toList();
        });
      }
    } catch (e) {
      debugPrint('Error calculating payroll: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _calculatePayForPeriod(DateTime start, DateTime end) async {
    double totalPay = 0;
    List<Map<String, dynamic>> dailyBreakdown = [];
    final adjustedEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);

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

      final DateTime effectiveEnd = timeOut ?? DateTime.now();
      final int totalMinutesWorked = effectiveEnd.difference(timeIn).inMinutes;

      bool isCapped = false;
      DateTime calculationTimeOut;
      
      if (totalMinutesWorked >= 570) {
        calculationTimeOut = timeIn.add(const Duration(hours: 9, minutes: 30));
        isCapped = true;
      } else {
        calculationTimeOut = effectiveEnd;
      }

      final durationSeconds = calculationTimeOut.difference(timeIn).inSeconds;
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
        const hourlyRate = _dailyWage / _requiredWorkHours;
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
        'isCapped': isCapped,
      });
    }

    return {'total': totalPay, 'daily': dailyBreakdown};
  }

  Future<void> _savePayrollToFirestore(DateTime periodStart, DateTime periodEnd, double netPay, bool isFinal) async {
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

      if (isFinal) {
        await _createPayrollNotificationIfNeeded(docId, periodEnd, netPay);
      }
    } catch (e) {
      debugPrint('Error saving payroll: $e');
    }
  }

  Future<void> _createPayrollNotificationIfNeeded(String payrollDocId, DateTime periodEnd, double netPay) async {
    if (user == null) return;
    final payrollDocRef = FirebaseFirestore.instance.collection('employees').doc(user!.uid).collection('payroll').doc(payrollDocId);
    final payrollDoc = await payrollDocRef.get();
    
    if (payrollDoc.exists && payrollDoc.data()?['notificationSent'] == true) return;

    await FirebaseFirestore.instance.collection('notifications').add({
      'recipientId': user!.uid,
      'title': 'Payroll Processed',
      'body': 'Your payslip for ending ${DateFormat('MMM dd, yyyy').format(periodEnd)} amounting to ₱${netPay.toStringAsFixed(2)} is now available.',
      'type': 'payroll',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await payrollDocRef.update({'notificationSent': true});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payroll History',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -50,
            child: _buildGlow(primaryColor.withValues(alpha: 0.08), 300),
          ),
          Positioned(
            bottom: 50,
            left: -50,
            child: _buildGlow(const Color(0xFF818CF8).withValues(alpha: 0.08), 200),
          ),

          // Main Content
          SafeArea(
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
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: primaryColor))
                        : _payrollResults.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                itemCount: _payrollResults.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) => _buildPayrollCard(_payrollResults[index], index),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlow(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 80, spreadRadius: 30),
          ],
        ),
      );

  Widget _buildPayrollCard(Map<String, dynamic> data, int index) {
    final netPay = data['netpay'] ?? '0.00';
    final month = data['month'] ?? '--';
    final date = data['date'] ?? '--';
    final status = data['status'] ?? 'Pending';
    final daily = data['daily'] ?? [];
    final isCalculated = status == 'Calculated';
    final statusColor = isCalculated ? Colors.green : Colors.orange;
    final isExpanded = expandedRows[index] ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => expandedRows[index] = !isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.payments_outlined, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₱$netPay', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                        const SizedBox(height: 4),
                        Text('$month • $date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
              child: Column(children: daily.map<Widget>((day) => _buildDailyDetail(day)).toList()),
            ),
        ],
      ),
    );
  }

  Widget _buildDailyDetail(Map<String, dynamic> day) {
    final bool isCapped = day['isCapped'] ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(day['date'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (isCapped)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('AUTO-TIMEOUT (9.5h)', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _detailRow('Hours', '${day['hoursWorked']} hrs'),
          _detailRow('Deduction', '₱${day['lateDeduction']}', color: Colors.redAccent),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Earned', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('₱${day['finalPay']}', style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
            ],
          )
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          Text(value, style: TextStyle(color: color ?? Colors.black87, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF818CF8)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(widget.employee.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.employee.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(widget.currentStatus, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
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
        Expanded(child: GestureDetector(onTap: _selectYear, child: _buildFilterDropdown(_selectedYear.toString(), Icons.calendar_today_outlined))),
        const SizedBox(width: 15),
        Expanded(child: GestureDetector(onTap: _selectMonth, child: _buildFilterDropdown(DateFormat('MMMM').format(DateTime(_selectedYear, _selectedMonth)), Icons.keyboard_arrow_down))),
      ],
    );
  }

  Widget _buildFilterDropdown(String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 10),
          Text('No payroll records found', style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
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

// --- Dialogs ---

// --- Dialogs ---

class _YearPickerDialog extends StatelessWidget {
  final int initialYear;
  const _YearPickerDialog({required this.initialYear});

  @override
  Widget build(BuildContext context) {
    final int currentYear = DateTime.now().year;
    final List<int> years = List.generate(6, (index) => currentYear - 5 + index).reversed.toList();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text('Select Year'),
      content: SizedBox(
        width: 100,
        height: 250,
        child: ListView.builder(
          itemCount: years.length,
          itemBuilder: (context, index) => ListTile(
            // Accessing the color via the State class name
            title: Text(
              years[index].toString(), 
              style: TextStyle(
                color: years[index] == initialYear ? _PayrollPageState.primaryColor : null, 
                fontWeight: years[index] == initialYear ? FontWeight.bold : null
              )
            ),
            onTap: () => Navigator.pop(context, years[index]),
          ),
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
      title: const Text('Select Month'),
      content: SizedBox(
        width: 100,
        height: 350,
        child: ListView.builder(
          itemCount: 12,
          itemBuilder: (context, index) => ListTile(
            // Accessing the color via the State class name
            title: Text(
              DateFormat('MMMM').format(DateTime(0, index + 1)), 
              style: TextStyle(
                color: (index + 1) == initialMonth ? _PayrollPageState.primaryColor : null, 
                fontWeight: (index + 1) == initialMonth ? FontWeight.bold : null
              )
            ),
            onTap: () => Navigator.pop(context, index + 1),
          ),
        ),
      ),
    );
  }
}