import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ⭐ Added for session clearing
import 'admin_attendance.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int _selectedIndex = 0;
  bool _isExpanded = true;

  // Navigation Logic
  final List<Widget> _pages = [
    const AdminDashboardHome(),
    const AdminAttendancePage(),
    const AdminEmployeeList(), // ⭐ Replaced "Coming Soon" with actual widget
  ];

  // ⭐ Proper Logout Function
  Future<void> _handleLogout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all saved session data
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // SIDEBAR
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isExpanded ? 240 : 80,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.admin_panel_settings, size: 40, color: Color(0xFF4F46E5)),
                if (_isExpanded) ...[
                  const SizedBox(height: 10),
                  const Text('ADMIN CENTRAL', 
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
                ],
                const SizedBox(height: 40),
                _navItem(0, Icons.dashboard_outlined, 'Dashboard'),
                _navItem(1, Icons.assignment_outlined, 'Attendance'),
                _navItem(2, Icons.people_outline, 'Employees'),
                const Spacer(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: _isExpanded ? const Text('Logout', style: TextStyle(color: Colors.redAccent)) : null,
                  onTap: _handleLogout,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // MAIN CONTENT
          Expanded(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.menu, color: Colors.black),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  ),
                  title: const Text('Management Console', 
                    style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
                ),
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool active = _selectedIndex == index;
    return ListTile(
      selected: active,
      selectedTileColor: const Color(0xFF4F46E5).withAlpha(20),
      leading: Icon(icon, color: active ? const Color(0xFF4F46E5) : Colors.blueGrey),
      title: _isExpanded ? Text(label, style: TextStyle(
          color: active ? const Color(0xFF4F46E5) : Colors.blueGrey,
          fontWeight: active ? FontWeight.bold : FontWeight.normal)) : null,
      onTap: () => setState(() => _selectedIndex = index),
    );
  }
}

// =====================================================
// NEW: EMPLOYEE LIST COMPONENT
// =====================================================
class AdminEmployeeList extends StatelessWidget {
  const AdminEmployeeList({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Employee Management', 
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('employees').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF4F46E5).withAlpha(30),
                          child: Text(data['name']?[0] ?? '?', 
                              style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                        ),
                        title: Text(data['name'] ?? 'Unknown', 
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(data['email'] ?? 'No email set'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: data['status'] == 'Active' ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            data['status'] ?? 'Active',
                            style: TextStyle(
                              color: data['status'] == 'Active' ? Colors.green : Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Internal Dashboard Home Widget
class AdminDashboardHome extends StatelessWidget {
  const AdminDashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('attendance').snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Container(
                width: 300,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Logs Today', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    Text('$count', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}