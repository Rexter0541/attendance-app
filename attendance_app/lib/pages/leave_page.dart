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

class _LeavePageState extends State<LeavePage> with AutomaticKeepAliveClientMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  final Set<String> expandedDocIds = {}; 
  
  late int _selectedYear;
  late int _selectedMonth;
  
  // CRITICAL: We start with loading = true to force the skeleton
  bool _isInitializing = true; 

  static const Color bgColor = Color(0xFFF8F9FC);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color textColor = Color(0xFF1E293B);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;

    // FIX: Delay the stream attachment. This prevents the "Davey!" 1s hang 
    // by letting the route transition finish before Firestore starts heavy work.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    });
  }

  void _showApplyLeaveForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black.withAlpha(28),
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
    super.build(context);
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
        body: Stack(
          children: [
            // Background Glows
            Positioned(top: -100, right: -50, child: _buildGlow(primaryColor)),
            Positioned(bottom: 50, left: -50, child: _buildGlow(const Color(0xFF818CF8))),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildEmployeeCard(),
                    const SizedBox(height: 20),
                    _buildFilters(),
                    const SizedBox(height: 20),
                    Expanded(
                      // If initializing, show skeleton. Otherwise, show the Stream.
                      child: _isInitializing 
                        ? _buildSkeletonList() 
                        : StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('employees')
                                .doc(user?.uid)
                                .collection('leaves')
                                .orderBy('filedDate', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return _buildSkeletonList();
                              }
                              
                              final filteredDocs = (snapshot.data?.docs ?? []).where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                try {
                                  final startDate = (data['startDate'] as Timestamp).toDate();
                                  return startDate.year == _selectedYear && startDate.month == _selectedMonth;
                                } catch (e) { return false; }
                              }).toList();

                              if (filteredDocs.isEmpty) return _buildEmptyState();

                              return ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 100),
                                itemCount: filteredDocs.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                   final doc = filteredDocs[index];
                                   return _buildLeaveCard(doc.id, doc.data() as Map<String, dynamic>);
                                },
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showApplyLeaveForm,
          backgroundColor: primaryColor,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Apply for Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  // --- SKELETON UI ---
  Widget _buildSkeletonList() {
    return ListView.builder(
      itemCount: 5,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 80,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 100, height: 12, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(width: 150, height: 8, decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(4))),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- SUB-WIDGETS ---

  Widget _buildGlow(Color color) => Container(
    width: 250, height: 250,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(20), boxShadow: [BoxShadow(color: color.withAlpha(20), blurRadius: 100, spreadRadius: 40)]),
  );

  Widget _buildEmployeeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primaryColor, Color(0xFF818CF8)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24, backgroundColor: Colors.white.withAlpha(30),
            child: Text(widget.employee.name.isNotEmpty ? widget.employee.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.employee.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(widget.currentStatus, style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 12)),
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

  Widget _buildLeaveCard(String docId, Map<String, dynamic> data) {
    final isExpanded = expandedDocIds.contains(docId);
    String fromDate = "N/A";
    String rangeStr = "N/A";
    try {
      final start = (data['startDate'] as Timestamp).toDate();
      fromDate = DateFormat('MMM dd, yyyy').format(start);
      final end = (data['endDate'] as Timestamp).toDate();
      rangeStr = "${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd').format(end)}";
    } catch (e) { debugPrint(e.toString()); }

    Color itemColor = data['status'] == 'Approved' ? Colors.green : (data['status'] == 'Declined' ? Colors.redAccent : Colors.orange);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)]),
      child: Column(children: [
        ListTile(
          onTap: () => setState(() => isExpanded ? expandedDocIds.remove(docId) : expandedDocIds.add(docId)),
          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: primaryColor.withAlpha(20), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_today_rounded, color: primaryColor, size: 20)),
          title: Text(data['type'] ?? 'Leave', style: const TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          subtitle: Text('Filed: $fromDate', style: const TextStyle(fontSize: 12)),
          trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: itemColor.withAlpha(20), borderRadius: BorderRadius.circular(20)), child: Text(data['status'] ?? 'Pending', style: TextStyle(color: itemColor, fontWeight: FontWeight.bold, fontSize: 11))),
        ),
        if (isExpanded) Container(width: double.infinity, padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildDetailItem(Icons.date_range, 'Duration', rangeStr),
          const SizedBox(height: 8),
          _buildDetailItem(Icons.notes, 'Reason', data['reason'] ?? 'None'),
        ])),
      ]),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) => Row(children: [Icon(icon, size: 14, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text('$label: $value', style: const TextStyle(fontSize: 12, color: textColor)))]);
  Widget _buildEmptyState() => const Center(child: Text('No leave requests', style: TextStyle(color: Colors.grey)));
}

// --- APPLY FORM ---

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
  String? _selectedType;
  DateTime? _start;
  DateTime? _end;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(25, 20, 25, 25),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('File a Leave', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: _inputDecoration('Leave Type'),
                items: ['Vacation', 'Sick Leave', 'Emergency'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => _selectedType = v,
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _startDateController, readOnly: true, onTap: () => _pick(true), decoration: _inputDecoration('Start'))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _endDateController, readOnly: true, onTap: () => _pick(false), decoration: _inputDecoration('End'))),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: _reasonController, decoration: _inputDecoration('Reason')),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), padding: const EdgeInsets.all(16)),
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit', style: TextStyle(color: Colors.white)),
              )),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(labelText: label, filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));

  Future<void> _pick(bool start) async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (d != null) {
      setState(() {
        if (start) { _start = d; _startDateController.text = DateFormat('MMM dd, yyyy').format(d); }
        else { _end = d; _endDateController.text = DateFormat('MMM dd, yyyy').format(d); }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('employees').doc(user!.uid).collection('leaves').add({
      'type': _selectedType, 'startDate': _start, 'endDate': _end, 'reason': _reasonController.text, 'status': 'Pending', 'filedDate': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.pop(context);
  }
}

class _YearPickerDialog extends StatelessWidget {
  final int initialYear;
  const _YearPickerDialog({required this.initialYear});
  @override
  Widget build(BuildContext context) {
    final years = List.generate(5, (i) => DateTime.now().year - 2 + i);
    return AlertDialog(content: SizedBox(height: 200, width: 100, child: ListView(children: years.map((y) => ListTile(title: Text(y.toString()), onTap: () => Navigator.pop(context, y))).toList())));
  }
}

class _MonthPickerDialog extends StatelessWidget {
  final int initialMonth;
  const _MonthPickerDialog({required this.initialMonth});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(content: SizedBox(height: 300, width: 100, child: ListView(children: List.generate(12, (i) => ListTile(title: Text(DateFormat('MMMM').format(DateTime(0, i + 1))), onTap: () => Navigator.pop(context, i + 1))))));
  }
}