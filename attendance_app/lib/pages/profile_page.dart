import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const Color bgColor = Color(0xFFF2F3F7);
  static const Color primaryColor = Color(0xFF6C63FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20), 
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.black, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    // --- Header ---
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Profile',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28),
                          ),
                          Text(
                            'Manage your information and preferences',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildAvatar(),
                    const SizedBox(height: 15),
                    const Text('Itchan',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text('Software Developer',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 30),

                    // --- SECTION: Personal Information ---
                    _buildSectionLabel('Personal Information'),
                    _buildProfileItem(Icons.badge_outlined, 'Employee ID', 'EMP-2026-001'),
                    _buildProfileItem(Icons.email_outlined, 'Email', 'itchan@companya.com', canEdit: true),
                    _buildProfileItem(Icons.phone_android_outlined, 'Phone', '+63 912 345 6789', canEdit: true),
                    _buildProfileItem(Icons.location_on_outlined, 'Office', 'Main Headquarters'),

                    const Divider(height: 40, thickness: 1),

                    // --- SECTION: Employment Details ---
                    _buildSectionLabel('Employment'),
                    _buildProfileItem(Icons.event_available, 'Employment Status', 'Full-Time Regular'),
                    _buildProfileItem(Icons.schedule, 'Work Schedule', '08:00 AM - 05:00 PM'),
                    _buildProfileItem(Icons.supervisor_account, 'Immediate Supervisor', 'Engr. Santos'),

                    const Divider(height: 40, thickness: 1),

                    // --- SECTION: Settings & Security ---
                    _buildSectionLabel('Settings & Security'),
                    _buildMenuOption(Icons.lock_outline, 'Change Password'),
                    _buildMenuOption(Icons.language_outlined, 'Language', trailing: 'English'),
                    _buildMenuOption(Icons.notifications_none_outlined, 'Notification Preferences'),

                    const Divider(height: 40, thickness: 1),

                    // --- SECTION: Emergency ---
                    _buildSectionLabel('Emergency Contact'),
                    _buildProfileItem(Icons.contact_phone_outlined, 'Contact Person', 'Maria Dela Cruz'),
                    _buildProfileItem(Icons.family_restroom, 'Relationship', 'Spouse'),

                    const Divider(height: 40, thickness: 1),

                    // --- SECTION: Support & About ---
                    _buildSectionLabel('Support'),
                    _buildMenuOption(Icons.help_outline, 'Help Center'),
                    _buildMenuOption(Icons.privacy_tip_outlined, 'Privacy Policy'),
                    _buildMenuOption(Icons.info_outline, 'App Version', trailing: 'v1.0.0'),
                    
                    const SizedBox(height: 10), // Small spacer for the bottom of the card
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)),
          child: const CircleAvatar(
            radius: 55,
            backgroundColor: Color(0xFFE0E0E0),
            child: Icon(Icons.person, size: 65, color: Colors.white),
          ),
        ),
        Positioned(
          bottom: 5,
          right: 5,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value, {bool canEdit = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: Colors.black87),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
          if (canEdit) const Icon(Icons.edit_note, size: 22, color: primaryColor),
        ],
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String title, {String? trailing}) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.black87),
            const SizedBox(width: 15),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            if (trailing != null)
              Text(trailing, style: const TextStyle(fontSize: 13, color: primaryColor, fontWeight: FontWeight.bold)),
            const SizedBox(width: 5),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}