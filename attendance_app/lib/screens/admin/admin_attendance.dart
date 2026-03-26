import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminAttendancePage extends StatefulWidget {
  const AdminAttendancePage({super.key});

  @override
  State<AdminAttendancePage> createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Workforce Insights',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              DateFormat('MMMM yyyy').format(_selectedDate),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          _buildCalendarButton(),
        ],
      ),
      body: Column(
        children: [
          _buildDateStrip(),
          Expanded(child: _buildDailyList(_selectedDate)),
        ],
      ),
    );
  }

  Widget _buildCalendarButton() {
    return Container(
      margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF4F46E5), size: 20),
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (picked != null) setState(() => _selectedDate = picked);
        },
      ),
    );
  }

  Widget _buildDateStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32), 
            bottomRight: Radius.circular(32)
        ),
        boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _dateNavButton(Icons.arrow_back_ios_new_rounded, () {
            setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
          }),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isToday(_selectedDate) ? 'TODAY' : DateFormat('EEEE').format(_selectedDate).toUpperCase(),
                  style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('MMM dd, yyyy').format(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          _dateNavButton(Icons.arrow_forward_ios_rounded, () {
            setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
          }),
        ],
      ),
    );
  }

  Widget _dateNavButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _buildDailyList(DateTime date) {
    if (date.isAfter(DateTime.now())) {
      return _buildEmptyState('This date is in the future', Icons.auto_awesome_outlined);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('employees').snapshots(),
      builder: (context, empSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('attendance').snapshots(),
          builder: (context, attSnapshot) {
            if (!empSnapshot.hasData || !attSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
            }

            final employees = empSnapshot.data!.docs;
            final attendanceLogs = attSnapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = (data['timestamp'] as Timestamp?)?.toDate();
              return ts != null && ts.year == date.year && ts.month == date.month && ts.day == date.day;
            }).toList();

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: employees.length,
              itemBuilder: (context, index) {
                final empData = employees[index].data() as Map<String, dynamic>;
                final name = empData['name'] ?? 'Unknown';
                
                final logMatch = attendanceLogs.where((log) => 
                  (log.data() as Map<String, dynamic>)['employeeName'] == name).toList();
                
                final logData = logMatch.isNotEmpty ? logMatch.first.data() as Map<String, dynamic> : null;

                return _buildInteractiveCard(name, logData);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInteractiveCard(String name, Map<String, dynamic>? log) {
    final dynamic timeInData = log?['timeIn'];
    final DateTime? timeIn = (timeInData is Timestamp) ? timeInData.toDate() : null;
    final String? photoUrl = log?['verification_photo'];
    
    // ⭐ Key from Firestore: deviceUsed
    final String deviceUsed = log?['deviceUsed'] ?? 'Unknown Device';

    bool isPresent = log != null;
    bool isLate = false;
    
    if (isPresent && timeIn != null) {
      final lateThreshold = DateTime(timeIn.year, timeIn.month, timeIn.day, 8, 1);
      isLate = timeIn.isAfter(lateThreshold);
    }

    bool isAbsent = !isPresent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isAbsent ? const Color(0xFFFCA5A5).withAlpha(100) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Row(
        children: [
          _buildAvatar(name, isAbsent, photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name, 
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_filled_rounded, size: 14, color: isAbsent ? Colors.redAccent : const Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isPresent 
                          ? (timeIn != null ? DateFormat('hh:mm a').format(timeIn) : 'Verified (Waiting In)')
                          : 'Unrecorded',
                        style: TextStyle(color: isAbsent ? Colors.redAccent : const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isPresent) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_android_rounded, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        // ⭐ Flexible prevents the device name from overflowing the card
                        Flexible(
                          child: Text(
                            deviceUsed,
                            style: const TextStyle(
                              color: Color(0xFF475569), 
                              fontSize: 11, 
                              fontWeight: FontWeight.w600
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _indicatorGroup(isPresent && !isLate, isLate, isAbsent),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, bool isAbsent, String? photoUrl) {
    return Container(
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isAbsent ? Colors.red.shade100 : const Color(0xFFEEF2FF),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: (photoUrl != null && photoUrl.isNotEmpty)
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildLetterFallback(name, isAbsent),
              )
            : _buildLetterFallback(name, isAbsent),
      ),
    );
  }

  Widget _buildLetterFallback(String name, bool isAbsent) {
    return Container(
      color: isAbsent ? Colors.red.shade50 : const Color(0xFFEEF2FF),
      child: Center(
        child: Text(
          name[0].toUpperCase(),
          style: TextStyle(
            color: isAbsent ? Colors.red.shade700 : const Color(0xFF4F46E5), 
            fontWeight: FontWeight.w800, 
            fontSize: 18
          ),
        ),
      ),
    );
  }

  Widget _indicatorGroup(bool p, bool l, bool a) {
    return Row(
      children: [
        _indicator('P', p, const Color(0xFF22C55E)), 
        const SizedBox(width: 6),
        _indicator('L', l, const Color(0xFFF59E0B)), 
        const SizedBox(width: 6),
        _indicator('A', a, const Color(0xFFEF4444)), 
      ],
    );
  }

  Widget _indicator(String label, bool active, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? color : const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: active ? Colors.white : const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: const Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 16)),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}