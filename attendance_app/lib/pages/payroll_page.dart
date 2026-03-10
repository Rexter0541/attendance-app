import 'package:flutter/material.dart';

class PayrollPage extends StatelessWidget {
  const PayrollPage({super.key});

  // Design Colors
  static const Color bgColor = Color(0xFFF2F3F7);
  static const Color presentColor = Color(0xFF4CAF50);

  // ✅ Sample Payroll Data
  final List<Map<String, String>> payrollData = const [
    {"netpay": "₱25,400", "month": "March", "date": "Mar 15, 2026", "status": "Paid"},
    {"netpay": "₱25,400", "month": "Feb", "date": "Feb 28, 2026", "status": "Paid"},
    {"netpay": "₱24,100", "month": "Jan", "date": "Jan 30, 2026", "status": "Paid"},
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
                            Expanded(child: Center(child: _HeaderText("Netpay"))),
                            Expanded(child: Center(child: _HeaderText("Month"))),
                            Expanded(child: Center(child: _HeaderText("Payment Date"))),
                            Expanded(child: Center(child: _HeaderText("Status"))),
                          ],
                        ),
                      ),
                      
                      // ✅ Payroll List Body
                      Expanded(
                        child: payrollData.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                itemCount: payrollData.length,
                                itemBuilder: (context, index) {
                                  return _buildPayrollRow(payrollData[index]);
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

  // ✅ Helper to build payroll rows
  Widget _buildPayrollRow(Map<String, String> data) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(child: Center(child: _DataText(data['netpay']!, fontWeight: FontWeight.bold, color: Colors.blue[800]))),
          Expanded(child: Center(child: _DataText(data['month']!))),
          Expanded(child: Center(child: _DataText(data['date']!))),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const _DataText("Paid", color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
          ),
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
        const Text("No Data", style: TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11));
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