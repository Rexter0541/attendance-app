// ignore_for_file: prefer_single_quotes

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';

class LeavePage extends StatefulWidget {
  final Employee employee;
  final String currentStatus;
  final Color statusColor;

  const LeavePage({
    super.key,
    required this.employee,
    required this.currentStatus,
    required this.statusColor,
  });

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  Map<int, bool> expandedRows = {};
  late int _selectedYear;
  late int _selectedMonth;

  static const Color bgColor = Color(0xFFF8F9FC);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color textColor = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  void _showApplyLeaveForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const _ApplyLeaveForm(),
    );
  }

  Future<void> _selectYear() async {
    final int? picked = await showDialog(
      context: context,
      builder: (context) => _YearPickerDialog(initialYear: _selectedYear),
    );
    if (picked != null && picked != _selectedYear) setState(() => _selectedYear = picked);
  }

  Future<void> _selectMonth() async {
    final int? picked = await showDialog(
      context: context,
      builder: (context) => _MonthPickerDialog(initialMonth: _selectedMonth),
    );
    if (picked != null && picked != _selectedMonth) setState(() => _selectedMonth = picked);
  }

  @override
  Widget build(BuildContext context) {
    DateTime startOfMonth = DateTime(_selectedYear, _selectedMonth, 1);
    DateTime endOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Leave Requests', 
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Helvetica')),
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
                  stream: FirebaseFirestore.instance
                      .collection('employees')
                      .doc(user?.uid)
                      .collection('leaves')
                      .where('startDate', isGreaterThanOrEqualTo: startOfMonth)
                      .where('startDate', isLessThanOrEqualTo: endOfMonth)
                      .orderBy('startDate', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text('Query Error: Check Firestore Indexes'));
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: primaryColor));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();
                    
                    final docs = snapshot.data!.docs;
                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                         final data = docs[index].data() as Map<String, dynamic>;
                         return _buildLeaveCard(data, index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showApplyLeaveForm,
        backgroundColor: primaryColor,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Apply for Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmployeeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primaryColor, Color(0xFF818CF8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primaryColor.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundColor: Colors.white.withValues(alpha: 0.2), child: Text(widget.employee.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.employee.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(widget.currentStatus, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12)),
            ]),
          ])),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Row(children: [
      Expanded(child: GestureDetector(onTap: _selectYear, child: _buildFilterDropdown(_selectedYear.toString(), Icons.calendar_today_outlined))),
      const SizedBox(width: 15),
      Expanded(child: GestureDetector(onTap: _selectMonth, child: _buildFilterDropdown(DateFormat('MMMM').format(DateTime(0, _selectedMonth)), Icons.keyboard_arrow_down))),
    ]);
  }

  Widget _buildFilterDropdown(String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
        Icon(icon, size: 18, color: Colors.grey),
      ]),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> data, int index) {
    if (data['startDate'] == null) return const SizedBox.shrink();

    Color itemStatusColor;
    IconData statusIcon;
    switch (data['status']) {
      case 'Approved': itemStatusColor = Colors.green; statusIcon = Icons.check_circle_outline; break;
      case 'Declined': itemStatusColor = Colors.redAccent; statusIcon = Icons.highlight_off; break;
      default: itemStatusColor = Colors.orange; statusIcon = Icons.hourglass_empty;
    }
    final isExpanded = expandedRows[index] ?? false;
    final String fromDate = DateFormat('MMM dd, yyyy').format((data['startDate'] as Timestamp).toDate());

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(children: [
        ListTile(
          onTap: () => setState(() => expandedRows[index] = !isExpanded),
          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_today_rounded, color: primaryColor, size: 20)),
          title: Text(data['type'] ?? 'Leave', style: const TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          subtitle: Text('Filed: $fromDate', style: const TextStyle(fontSize: 12)),
          trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: itemStatusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(statusIcon, size: 12, color: itemStatusColor), const SizedBox(width: 4), Text(data['status'] ?? 'Pending', style: TextStyle(color: itemStatusColor, fontWeight: FontWeight.bold, fontSize: 11))])),
        ),
        if (isExpanded) Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0)),
          const SizedBox(height: 8),
          _buildDetailItem(Icons.date_range, 'Duration', "${DateFormat('MMM dd').format((data['startDate'] as Timestamp).toDate())} - ${DateFormat('MMM dd').format((data['endDate'] as Timestamp).toDate())}"),
          const SizedBox(height: 8),
          _buildDetailItem(Icons.notes, 'Reason', data['reason'] ?? 'No reason provided.'),
        ])),
      ]),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 14, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text('$label: $value', style: const TextStyle(fontSize: 12, color: textColor)))]);
  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.event_busy_rounded, size: 60, color: Colors.grey.shade300), const SizedBox(height: 16), const Text('No leave requests for this month', style: TextStyle(color: Colors.grey))]));
}

// --- APPLY LEAVE FORM ---

class _ApplyLeaveForm extends StatefulWidget {
  const _ApplyLeaveForm();
  @override
  State<_ApplyLeaveForm> createState() => _ApplyLeaveFormState();
}

class _ApplyLeaveFormState extends State<_ApplyLeaveForm> {
  final _formKey = GlobalKey<FormState>();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('employees').doc(user!.uid).collection('leaves').add({
        'type': _selectedLeaveType,
        'startDate': _startDate,
        'endDate': _endDate,
        'reason': _reasonController.text,
        'status': 'Pending',
        'filedDate': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Submit Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(25, 12, 25, 25),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const Text('File a Leave', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isDense: true,
                  decoration: _inputDecoration('Leave Type'),
                  items: ['Vacation', 'Sick Leave', 'Emergency', 'Maternity/Paternity'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _selectedLeaveType = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: _startDateController, readOnly: true, onTap: () => _selectDate(true), decoration: _inputDecoration('Start'), validator: (v) => v!.isEmpty ? 'Required' : null)),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _endDateController, readOnly: true, onTap: () => _selectDate(false), decoration: _inputDecoration('End'), validator: (v) => v!.isEmpty ? 'Required' : null)),
                ]),
                const SizedBox(height: 12),
                TextFormField(controller: _reasonController, maxLines: 2, decoration: _inputDecoration('Reason (Optional)')),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitLeaveRequest,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(labelText: label, isDense: true, filled: true, fillColor: Colors.grey[100], contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context, 
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          _startDateController.text = DateFormat('MMM dd, yyyy').format(picked);
        } else {
          _endDate = picked;
          _endDateController.text = DateFormat('MMM dd, yyyy').format(picked);
        }
      });
    }
  }
}

// --- PICKER DIALOGS ---

class _YearPickerDialog extends StatelessWidget {
  final int initialYear;
  const _YearPickerDialog({required this.initialYear});
  @override
  Widget build(BuildContext context) {
    final years = List.generate(6, (i) => DateTime.now().year - 5 + i).reversed.toList();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text('Select Year'),
      content: SizedBox(width: 100, height: 250, child: ListView.builder(itemCount: years.length, itemBuilder: (c, i) => ListTile(title: Text(years[i].toString()), onTap: () => Navigator.pop(c, years[i])))),
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
      content: SizedBox(width: 100, height: 350, child: ListView.builder(itemCount: 12, itemBuilder: (c, i) => ListTile(title: Text(DateFormat('MMMM').format(DateTime(0, i + 1))), onTap: () => Navigator.pop(c, i + 1)))),
    );
  }
}