import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeListPage extends StatefulWidget {
  const EmployeeListPage({super.key});

  @override
  State<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  final Color primaryDark = const Color(0xFF0F172A);
  final Color accentBlue = const Color(0xFF6366F1);
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          _buildSearchBox(),
          _buildEmployeeList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Add your Navigation to Add Staff page here
        }, 
        backgroundColor: accentBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: primaryDark,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: const Text(
          'Staff Directory',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 20),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              colors: [primaryDark, const Color(0xFF1E293B)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search by name, role, or office...',
            prefixIcon: Icon(Icons.search_rounded, color: accentBlue),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('employees').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SliverFillRemaining(child: Center(child: Text('Error loading data')));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] as String? ?? '').toLowerCase();
          final role = (data['role'] as String? ?? '').toLowerCase();
          final office = (data['office'] as String? ?? '').toLowerCase();
          return name.contains(_searchQuery) || 
                 role.contains(_searchQuery) || 
                 office.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return const SliverFillRemaining(child: Center(child: Text('No staff found.')));
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return _buildEmployeeCard(data, index);
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> data, int index) {
    final String name = data['name'] ?? 'Unknown';
    final String email = data['email'] ?? 'No email';
    // Trim used to avoid issues with hidden spaces in Firestore strings
    final String? imageUrl = (data['imageUrl'] as String?)?.trim(); 
    final String status = data['status'] ?? 'Active';
    bool isActive = status.toLowerCase() == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildProfileImage(name, imageUrl),
        title: Text(
          name,
          style: TextStyle(fontWeight: FontWeight.w700, color: primaryDark),
        ),
        subtitle: Text(
          email,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        trailing: _buildStatusIndicator(status, isActive),
        onTap: () => _showEmployeeDetails(data),
      ),
    );
  }

  Widget _buildProfileImage(String name, String? imageUrl) {
    return Container(
      height: 52,
      width: 52,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9), // Subtle grey background
        shape: BoxShape.circle,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: (imageUrl != null && imageUrl.isNotEmpty)
            ? Image.network(
                imageUrl,
                key: ValueKey(imageUrl),
                fit: BoxFit.cover,
                // Handles CORS issues or broken links
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Image fail for $name: $error');
                  return _buildLetterAvatar(name);
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              )
            : _buildLetterAvatar(name),
      ),
    );
  }

  Widget _buildLetterAvatar(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: accentBlue,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF22C55E).withAlpha(26) : const Color(0xFFEF4444).withAlpha(26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toLowerCase(),
        style: TextStyle(
          color: isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showEmployeeDetails(Map<String, dynamic> data) {
    final String name = data['name'] ?? 'Unknown';
    final String? imageUrl = (data['imageUrl'] as String?)?.trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            _buildLargeProfileImage(name, imageUrl),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            Text(data['email'] ?? 'No email provided', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(Icons.edit_note_rounded, 'Edit'),
                _actionButton(Icons.call_rounded, 'Call'),
                _actionButton(Icons.delete_outline_rounded, 'Remove', isDelete: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeProfileImage(String name, String? imageUrl) {
    return Container(
      height: 96,
      width: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: accentBlue.withAlpha(51), blurRadius: 20)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(48),
        child: (imageUrl != null && imageUrl.isNotEmpty)
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  color: const Color(0xFFEEF2FF),
                  child: Center(child: Text(name[0], style: TextStyle(fontSize: 32, color: accentBlue, fontWeight: FontWeight.bold))),
                ),
              )
            : Container(
                color: const Color(0xFFEEF2FF),
                child: Center(child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(fontSize: 32, color: accentBlue, fontWeight: FontWeight.bold))),
              ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, {bool isDelete = false}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDelete ? Colors.red.withAlpha(26) : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isDelete ? Colors.red : primaryDark, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDelete ? Colors.red : primaryDark)),
      ],
    );
  }
}