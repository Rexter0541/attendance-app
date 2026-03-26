import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceAuditLog extends StatefulWidget {
  const AttendanceAuditLog({super.key});

  @override
  State<AttendanceAuditLog> createState() => _AttendanceAuditLogState();
}

class _AttendanceAuditLogState extends State<AttendanceAuditLog> {
  // Cinematic Color Palette
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate900 = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Allow AdminPanel color to show
      appBar: AppBar(
        title: const Text(
          'Attendance Audit Log',
          style: TextStyle(
            color: slate900, 
            fontWeight: FontWeight.bold,
            fontFamily: 'Helvetica',
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: slate900),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: primaryIndigo),
            onPressed: () {
              // Future: Add date range filtering
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryIndigo));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs = snapshot.data!.docs;

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFEEF2FF)),
                      columnSpacing: 32,
                      horizontalMargin: 20,
                      headingRowHeight: 56,
                      dataRowMaxHeight: 64,
                      columns: [
                        _buildHeader('Employee'),
                        _buildHeader('Device Info'),
                        _buildHeader('Date'),
                        _buildHeader('Time In'),
                        _buildHeader('Time Out'),
                        _buildHeader('Status'),
                      ],
                      rows: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final timeIn = data['timeIn'] as Timestamp?;
                        final timeOut = data['timeOut'] as Timestamp?;
                        final String deviceName = data['deviceUsed'] ?? data['device'] ?? 'Unknown';

                        return DataRow(cells: [
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: primaryIndigo.withAlpha(28),
                                child: Text(
                                  (data['employeeName'] as String? ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 11, color: primaryIndigo, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                data['employeeName'] ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: slate900),
                              ),
                            ],
                          )),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getDeviceIcon(deviceName), size: 14, color: slate700),
                                const SizedBox(width: 6),
                                Text(
                                  deviceName,
                                  style: const TextStyle(fontSize: 11, color: slate700, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          )),
                          DataCell(Text(
                            timeIn != null ? DateFormat('MMM dd, yyyy').format(timeIn.toDate()) : '--',
                            style: const TextStyle(color: slate700),
                          )),
                          DataCell(Text(
                            timeIn != null ? DateFormat('h:mm a').format(timeIn.toDate()) : '--',
                            style: const TextStyle(fontWeight: FontWeight.w500, color: slate900),
                          )),
                          DataCell(Text(
                            timeOut != null ? DateFormat('h:mm a').format(timeOut.toDate()) : '--',
                            style: const TextStyle(color: Colors.grey),
                          )),
                          DataCell(_buildStatusBadge(data['status'] ?? 'Absent')),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  DataColumn _buildHeader(String label) {
    return DataColumn(
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, color: primaryIndigo, fontSize: 13),
      ),
    );
  }

  IconData _getDeviceIcon(String? device) {
    if (device == null) return Icons.device_unknown_rounded;
    final d = device.toLowerCase();
    if (d.contains('android') || d.contains('poco')) return Icons.smartphone_rounded;
    if (d.contains('ios') || d.contains('iphone')) return Icons.phone_iphone_rounded;
    if (d.contains('windows') || d.contains('mac') || d.contains('desktop')) return Icons.laptop_mac_rounded;
    return Icons.devices_other_rounded;
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String cleanStatus = status.toLowerCase();

    if (cleanStatus.contains('late')) {
      color = Colors.orange;
    } else if (cleanStatus.contains('on time') || cleanStatus.contains('present')) {
      color = Colors.green;
    } else {
      color = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color, 
          fontSize: 10, 
          fontWeight: FontWeight.bold, 
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No attendance records found.',
            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}