import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_attendance.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int _selectedIndex = 0;
  final bool _isExpanded = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Page titles for the dynamic AppBar
  final List<String> _titles = ['Dashboard', 'Attendance', 'Employees'];

  Future<void> _handleLogout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 900;

        final List<Widget> pages = [
          const AdminDashboardHome(),
          const AdminAttendancePage(),
          const AdminEmployeeList(),
        ];

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFFF8FAFC),
          // ⭐ Drawer only appears on Mobile
          drawer: isMobile
              ? Drawer(
                  backgroundColor: Colors.white,
                  child: _buildSidebarContent(isMobile: true),
                )
              : null,
          appBar: isMobile
              ? AppBar(
                  title: Text(_titles[_selectedIndex],
                      style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.white,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
                )
              : null,
          body: Row(
            children: [
              // ⭐ Sidebar only visible on Desktop
              if (!isMobile)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isExpanded ? 240 : 80,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: _buildSidebarContent(isMobile: false),
                ),
              // Main Content Area
              Expanded(
                child: pages[_selectedIndex],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebarContent({required bool isMobile}) {
    return Column(
      children: [
        const SizedBox(height: 50),
        const Icon(Icons.admin_panel_settings, size: 40, color: Color(0xFF4F46E5)),
        if (_isExpanded || isMobile) ...[
          const SizedBox(height: 10),
          const Text('ADMIN CENTRAL',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12)),
        ],
        const SizedBox(height: 40),
        _navItem(0, Icons.dashboard_outlined, 'Dashboard', isMobile),
        _navItem(1, Icons.assignment_outlined, 'Attendance', isMobile),
        _navItem(2, Icons.people_outline, 'Employees', isMobile),
        const Spacer(),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: (_isExpanded || isMobile) ? const Text('Logout', style: TextStyle(color: Colors.redAccent)) : null,
          onTap: _handleLogout,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _navItem(int index, IconData icon, String label, bool isMobile) {
    bool active = _selectedIndex == index;
    return ListTile(
      selected: active,
      selectedTileColor: const Color(0xFF4F46E5).withAlpha(20),
      leading: Icon(icon, color: active ? const Color(0xFF4F46E5) : Colors.blueGrey),
      title: (_isExpanded || isMobile)
          ? Text(label,
              style: TextStyle(
                  color: active ? const Color(0xFF4F46E5) : Colors.blueGrey,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal))
          : null,
      onTap: () {
        setState(() => _selectedIndex = index);
        if (isMobile) Navigator.pop(context); // Close drawer
      },
    );
  }
}

// =====================================================
// REFINED EMPLOYEE LIST (Removed inner Scaffold)
// =====================================================
class AdminEmployeeList extends StatelessWidget {
  const AdminEmployeeList({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('employees').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade100),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF4F46E5).withAlpha(30),
                  child: Text(data['name']?[0] ?? '?', style: const TextStyle(color: Color(0xFF4F46E5))),
                ),
                title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data['email'] ?? 'No email'),
                trailing: _StatusBadge(status: data['status'] ?? 'Active'),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    bool isActive = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// =====================================================
// REFINED DASHBOARD HOME
// =====================================================
class AdminDashboardHome extends StatelessWidget {
  const AdminDashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('attendance').snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Text (Visible on Desktop, looks good on Mobile)
              const Text('Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // Grid-like Wrap for Cards
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildStatCard('Total Logs Today', '$count', Icons.history),
                  _buildStatCard('Active Sessions', '12', Icons.bolt), // Placeholder
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      width: 300, // Fixed width helps it "wrap" naturally on mobile
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: const Color(0xFF4F46E5).withAlpha(20), child: Icon(icon, color: const Color(0xFF4F46E5))),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}