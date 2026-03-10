import 'package:flutter/material.dart';

class AttendanceLogPage extends StatelessWidget {
  const AttendanceLogPage({super.key});

  static const Color bgColor = Color(0xFFF2F3F7);
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color presentColor = Color(0xFF4CAF50);

  // ✅ Sample Data
  final List<Map<String, String>> attendanceData = const [
    {"name": "Itchan", "in": "08:00 AM", "out": "05:00 PM", "date": "Mar 01"},
    {"name": "Itchan", "in": "07:55 AM", "out": "05:10 PM", "date": "Mar 02"},
    {"name": "Itchan", "in": "08:05 AM", "out": "04:55 PM", "date": "Mar 03"},
    {"name": "Itchan", "in": "07:45 AM", "out": "05:00 PM", "date": "Mar 04"},
  ];

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
              
              // --- Main Data Table Container ---
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
                            Expanded(child: Center(child: _HeaderText("Name"))),
                            Expanded(child: Center(child: _HeaderText("Time-in"))),
                            Expanded(child: Center(child: _HeaderText("Time-out"))),
                            Expanded(child: Center(child: _HeaderText("Date"))),
                          ],
                        ),
                      ),
                      
                      // ✅ Attendance List Body
                      Expanded(
                        child: attendanceData.isEmpty 
                          ? _buildEmptyState() 
                          : ListView.builder(
                              itemCount: attendanceData.length,
                              itemBuilder: (context, index) {
                                final log = attendanceData[index];
                                return _buildDataRow(log);
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

  // ✅ Helper to build individual data rows
  Widget _buildDataRow(Map<String, String> log) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(child: Center(child: _DataText(log["name"]!))),
          Expanded(child: Center(child: _DataText(log["in"]!, color: Colors.blue))),
          Expanded(child: Center(child: _DataText(log["out"]!, color: Colors.orange))),
          Expanded(child: Center(child: _DataText(log["date"]!, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Employee: Itchan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text("Location: Company A", style: TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ),
        Row(
          children: [
            const Text("Status: ", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
            Text("Present", style: TextStyle(color: presentColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        )
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(child: _buildFilterDropdown("2026", Icons.calendar_today_outlined)),
        const SizedBox(width: 15),
        Expanded(child: _buildFilterDropdown("March", Icons.keyboard_arrow_down)),
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
        const Text("No Logs Found", style: TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }
}

/// Header Text Style
class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12));
  }
}

/// Data Text Style
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
        fontSize: 12,
        color: color ?? Colors.black87,
        fontWeight: fontWeight ?? FontWeight.normal,
      ),
    );
  }
}