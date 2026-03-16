import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/employee.dart';

class LeavePage extends StatefulWidget {
  final Employee employee;
  final String currentStatus;
  final Color statusColor;
  const LeavePage(
      {super.key,
      required this.employee,
      required this.currentStatus,
      required this.statusColor});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  Map<int, bool> expandedRows = {};

  static const Color bgColor = Color(0xFFF2F3F7);

  void _showApplyLeaveForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ApplyLeaveForm(),
    );
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

              // --- Main Data Container ---
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
                            Expanded(child: Center(child: _HeaderText('Type'))),
                            Expanded(child: Center(child: _HeaderText('From'))),
                            Expanded(child: Center(child: _HeaderText('To'))),
                            Expanded(child: Center(child: _HeaderText('Status'))),
                          ],
                        ),
                      ),
                      
                      // ✅ Leave Requests List Body
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('employees')
                              .doc(user?.uid)
                              .collection('leaves')
                              .orderBy('filedDate', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return _buildEmptyState();
                            }
                            return ListView.builder(
                              itemCount: snapshot.data!.docs.length,
                              itemBuilder: (context, index) {
                                return _buildLeaveRow(snapshot.data!.docs[index].data() as Map<String, dynamic>, index);
                              },
                            );
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showApplyLeaveForm,
        backgroundColor: Colors.black,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Apply for Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ✅ Helper to build leave data rows
  Widget _buildLeaveRow(Map<String, dynamic> data, int index) {
    // Determine color based on status
    Color statusColor;
    switch (data['status']) {
      case 'Approved': statusColor = Colors.green; break;
      case 'Declined': statusColor = Colors.red; break;
      default: statusColor = Colors.orange; // Pending
    }

    // Format data from Firestore
    final String type = data['type'] ?? 'N/A';
    final String status = data['status'] ?? 'N/A';
    final String fromDate = data['startDate'] != null
        ? DateFormat('MMM dd').format((data['startDate'] as Timestamp).toDate())
        : '--';
    final String toDate = data['endDate'] != null
        ? DateFormat('MMM dd').format((data['endDate'] as Timestamp).toDate())
        : '--';
    final String reason = data['reason'] != null && (data['reason'] as String).isNotEmpty
        ? data['reason']
        : 'No reason provided.';
    final isExpanded = expandedRows[index] ?? false;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              expandedRows[index] = !isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Expanded(child: Center(child: _DataText(type, fontWeight: FontWeight.w600))),
                Expanded(child: Center(child: _DataText(fromDate))),
                Expanded(child: Center(child: _DataText(toDate))),
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _DataText(status, color: statusColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reason for Leave:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 5),
                Text(
                  reason,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
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
        Expanded(child: _buildFilterDropdown('2026', Icons.calendar_today_outlined)),
        const SizedBox(width: 15),
        Expanded(child: _buildFilterDropdown('All Types', Icons.keyboard_arrow_down)),
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
        Icon(Icons.event_busy_outlined, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        const Text('No Leave Requests', style: TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }
}

/// Form widget shown in a modal bottom sheet to apply for leave.
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

  final List<String> _leaveTypes = ['Vacation', 'Sick Leave', 'Emergency', 'Maternity/Paternity'];

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _startDateController.text = DateFormat('MMMM dd, yyyy').format(picked);
        } else {
          _endDate = picked;
          _endDateController.text = DateFormat('MMMM dd, yyyy').format(picked);
        }
      });
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      await FirebaseFirestore.instance
          .collection('employees')
          .doc(user.uid)
          .collection('leaves')
          .add({
        'type': _selectedLeaveType,
        'startDate': _startDate,
        'endDate': _endDate,
        'reason': _reasonController.text,
        'status': 'Pending',
        'filedDate': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close the bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit request: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Accommodate for the keyboard
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('File a Leave', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Leave Type', border: OutlineInputBorder()),
                initialValue: _selectedLeaveType,
                items: _leaveTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) => setState(() => _selectedLeaveType = value),
                validator: (value) => value == null ? 'Please select a leave type' : null,
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startDateController,
                      decoration: const InputDecoration(labelText: 'Start Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                      readOnly: true,
                      onTap: () => _selectDate(context, true),
                      validator: (value) => value == null || value.isEmpty ? 'Select a start date' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _endDateController,
                      decoration: const InputDecoration(labelText: 'End Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                      readOnly: true,
                      onTap: () => _selectDate(context, false),
                      validator: (value) => value == null || value.isEmpty ? 'Select an end date' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Reason (Optional)', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitLeaveRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text('Submit Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
  }
}

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
        fontSize: 11,
        color: color ?? Colors.black87,
        fontWeight: fontWeight ?? FontWeight.normal,
      ),
    );
  }
}