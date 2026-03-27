import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee.dart';
import 'meeting_page.dart';
import 'notifications_page.dart';

class ProfilePage extends StatefulWidget {
  final Employee employee;
  const ProfilePage({super.key, required this.employee});

  static const Color bgColor = Color(0xFFF8F9FC);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF1E293B);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? imageUrl;
  
  // Dynamic Profile Data
  String _name = '';
  String _employeeIdDisplay = 'Loading...';
  String _email = 'Loading...';
  String _phone = 'Loading...';
  String _office = 'Loading...';
  String _emergencyName = 'Loading...';
  String _emergencyRelation = 'Loading...';

  // Admin-Managed Employment Data (Fetches from DB, Read-Only in UI)
  String _employmentStatus = 'Loading...';
  String _workSchedule = 'Loading...';
  String _supervisor = 'Loading...';

  final supabase = Supabase.instance.client;
  final _firebaseAuth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _name = widget.employee.name;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    try {
      final docSnap = await _firestore.collection('employees').doc(user.uid).get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        if (mounted) {
          setState(() {
            if (data.containsKey('imageUrl')) imageUrl = data['imageUrl'];
            if (data.containsKey('name')) _name = data['name'];
            
            // Employee ID handling
            if (data['employeeId'] != null) {
              _employeeIdDisplay = data['employeeId'];
            } else {
              _employeeIdDisplay = 'EMP-${user.uid.substring(0, 5).toUpperCase()}';
              _firestore.collection('employees').doc(user.uid).set({
                'employeeId': _employeeIdDisplay
              }, SetOptions(merge: true));
            }

            _email = data['email'] ?? user.email ?? 'No email';
            _phone = data['phone'] ?? 'No phone';
            _office = data['office'] ?? 'Main Headquarters';
            _emergencyName = data['emergencyContactName'] ?? 'None';
            _emergencyRelation = data['emergencyContactRelation'] ?? 'None';
            
            // Fetching fields intended for Admin Update
            _employmentStatus = data['employmentStatus'] ?? 'Pending...';
            _workSchedule = data['workSchedule'] ?? 'TBD';
            _supervisor = data['supervisor'] ?? 'None Assigned';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<void> pickAndUploadImage() async {
    if (!mounted) return;
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final fileExt = pickedFile.name.split('.').last;
    final filePath = '$fileName.$fileExt';

    try {
      final bytes = await pickedFile.readAsBytes();
      await supabase.storage
          .from('employee-profile')
          .uploadBinary(filePath, bytes, fileOptions: FileOptions(contentType: pickedFile.mimeType ?? 'image/jpeg'));

      final publicUrl = supabase.storage.from('employee-profile').getPublicUrl(filePath);
      await _updateUserProfileImageUrl(publicUrl);
    } catch (e) {
      debugPrint('Upload failed: $e');
    }
  }

  Future<void> _updateUserProfileImageUrl(String newUrl) async {
    final user = _firebaseAuth.currentUser;
    if (mounted) {
      setState(() => imageUrl = newUrl);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile image updated successfully')));
    }
    if (user == null) return;
    await _firestore.collection('employees').doc(user.uid).set({'imageUrl': newUrl}, SetOptions(merge: true));
  }

  Future<void> _editField(String title, String fieldKey, String currentValue) async {
    final TextEditingController controller = TextEditingController(text: currentValue);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: 'Enter new $title', border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newValue = controller.text.trim();
              Navigator.pop(context);
              if (newValue.isNotEmpty && newValue != currentValue) {
                await _saveProfileField(fieldKey, newValue);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: ProfilePage.primaryColor, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfileField(String fieldKey, String newValue) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    await _firestore.collection('employees').doc(user.uid).set({fieldKey: newValue}, SetOptions(merge: true));
    _loadUserProfile(); 
  }

  Future<void> _showChangePasswordDialog() async {
    final TextEditingController currentPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text('Change Password'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter your current password to proceed.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: currentPassController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: newPassController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: confirmPassController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (newPassController.text != confirmPassController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                    return;
                  }
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null && user.email != null) {
                      final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassController.text);
                      await user.reauthenticateWithCredential(cred);
                      await user.updatePassword(newPassController.text);
                      if (!context.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated!')));
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: ProfilePage.primaryColor, foregroundColor: Colors.white),
                child: const Text('Update'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text('My Profile', style: TextStyle(color: ProfilePage.textColor, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF8F9FC), Color(0xFFE0E7FF)],
              ),
            ),
          ),
          // Ambience Blobs
          Positioned(top: -100, right: -100, child: _buildBlurCircle(300, const Color(0xFF4F46E5))),
          Positioned(bottom: 50, left: -50, child: _buildBlurCircle(200, const Color(0xFF818CF8))),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 25),
                  
                  _buildSectionContainer('Personal Information', [
                    _buildProfileItem(Icons.badge_outlined, 'Employee ID', _employeeIdDisplay),
                    _buildDivider(),
                    _buildProfileItem(Icons.email_outlined, 'Email', _email),
                    _buildDivider(),
                    _buildProfileItem(Icons.phone_android_outlined, 'Phone', _phone,
                        canEdit: true, onTap: () => _editField('Phone', 'phone', _phone)),
                    _buildDivider(),
                    _buildProfileItem(Icons.location_on_outlined, 'Office', _office,
                        canEdit: true, onTap: () => _editField('Office', 'office', _office)),
                  ]),
                  
                  const SizedBox(height: 20),
                  
                  // Employment Section - DATA FETCHED FROM DB but NOT EDITABLE by user
                  _buildSectionContainer('Employment', [
                    _buildProfileItem(Icons.work_outline, 'Employment Status', _employmentStatus, canEdit: false),
                    _buildDivider(),
                    _buildProfileItem(Icons.schedule, 'Work Schedule', _workSchedule, canEdit: false),
                    _buildDivider(),
                    _buildProfileItem(Icons.supervisor_account_outlined, 'Immediate Supervisor', _supervisor, canEdit: false),
                  ]),
                  
                  const SizedBox(height: 20),
                  
                  _buildSectionContainer('Emergency Contact', [
                    _buildProfileItem(Icons.contact_phone_outlined, 'Contact Person', _emergencyName,
                        canEdit: true, onTap: () => _editField('Contact Person', 'emergencyContactName', _emergencyName)),
                    _buildDivider(),
                    _buildProfileItem(Icons.family_restroom, 'Relationship', _emergencyRelation,
                        canEdit: true, onTap: () => _editField('Relationship', 'emergencyContactRelation', _emergencyRelation)),
                  ]),
                  
                  const SizedBox(height: 20),
                  
                  _buildSectionContainer('Settings & Security', [
                    _buildMenuOption(Icons.lock_outline, 'Change Password', onTap: _showChangePasswordDialog),
                    _buildDivider(),
                    _buildMenuOption(Icons.notifications_none_outlined, 'Notifications', 
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(employee: widget.employee)))),
                    _buildDivider(),
                    _buildMenuOption(Icons.video_call_outlined, 'Online Meeting', 
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MeetingPage(employee: widget.employee)))),
                  ]),
                  
                  const SizedBox(height: 20),
                  
                  _buildSectionContainer('Support', [
                    _buildMenuOption(Icons.help_outline, 'Help Center'),
                    _buildDivider(),
                    _buildMenuOption(Icons.privacy_tip_outlined, 'Privacy Policy'),
                    _buildDivider(),
                    _buildMenuOption(Icons.info_outline, 'App Version', trailing: 'v1.0.0'),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(28),
        boxShadow: [BoxShadow(color: color.withAlpha(28), blurRadius: 100, spreadRadius: 50)],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF818CF8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withAlpha(16), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          _buildAvatar(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _editField('Name', 'name', _name),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(51), shape: BoxShape.circle),
                  child: const Icon(Icons.edit, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Health Officer', style: TextStyle(fontSize: 14, color: Colors.white.withAlpha(230))),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: pickAndUploadImage,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withAlpha(128), width: 2)),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white.withAlpha(51),
              backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
              child: imageUrl == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
            ),
          ),
          Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, size: 16, color: ProfilePage.primaryColor))),
        ],
      ),
    );
  }

  Widget _buildSectionContainer(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0))),
        Container(decoration: BoxDecoration(color: ProfilePage.cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withAlpha(28), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(children: children)),
      ],
    );
  }

  Widget _buildDivider() => Divider(height: 1, thickness: 1, color: Colors.grey.shade100, indent: 16, endIndent: 16);

  Widget _buildProfileItem(IconData icon, String label, String value, {bool canEdit = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: canEdit ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ProfilePage.primaryColor.withAlpha(26), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 20, color: ProfilePage.primaryColor)),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ProfilePage.textColor))])),
            if (canEdit) const Icon(Icons.edit_note, size: 24, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String title, {String? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: ProfilePage.textColor),
            const SizedBox(width: 15),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: ProfilePage.textColor))),
            if (trailing != null) Text(trailing, style: const TextStyle(fontSize: 13, color: ProfilePage.primaryColor, fontWeight: FontWeight.bold)),
            const SizedBox(width: 5),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}