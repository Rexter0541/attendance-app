import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee.dart';
import 'notifications_page.dart';

class ProfilePage extends StatefulWidget {
  final Employee employee;
  const ProfilePage({super.key, required this.employee});

  static const Color bgColor = Color(0xFFF2F3F7);
  static const Color primaryColor = Color(0xFF6C63FF);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? imageUrl;
  
  // Dynamic Profile Data (Default values while loading)
  String _name = '';
  String _employeeIdDisplay = 'Loading...';
  String _email = 'Loading...';
  String _phone = 'Loading...';
  String _office = 'Loading...';
  String _emergencyName = 'Loading...';
  String _emergencyRelation = 'Loading...';

  // Firebase and Supabase clients
  final supabase = Supabase.instance.client;
  final _firebaseAuth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _name = widget.employee.name;
    _loadUserProfile();
  }

  /// Fetches the user's profile from Firestore to load the existing image URL.
  Future<void> _loadUserProfile() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      debugPrint('No Firebase user logged in, cannot load profile.');
      return;
    }

    try {
      // Use 'employees' collection to match other pages
      final docSnap = await _firestore.collection('employees').doc(user.uid).get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        if (mounted) {
          setState(() {
            if (data.containsKey('imageUrl')) imageUrl = data['imageUrl'];
            if (data.containsKey('name')) _name = data['name'];
            
            // Load dynamic fields or use defaults if missing
            if (data['employeeId'] != null) {
              _employeeIdDisplay = data['employeeId'];
            } else {
              // Generate ID if missing, then save to Firestore automatically
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
          });
          debugPrint('User profile image loaded from Firestore.');
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile from Firestore: $e');
    }
  }

  Future<void> pickAndUploadImage() async {
    // Ensure the widget is still in the tree.
    if (!mounted) return;

    final user = _firebaseAuth.currentUser;
    if (user == null) {
      debugPrint('Cannot upload: No user is logged in.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to upload an image.')),
        );
      }
      return;
    }

    debugPrint('Sinusubukang pumili at mag-upload ng imahe...');
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      debugPrint('Walang napiling imahe. Kinakansela ang pag-upload.');
      return;
    }

    if (!mounted) return;

    debugPrint('Napiling imahe: ${pickedFile.name}');

    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final fileExt = pickedFile.name.split('.').last;
    final filePath = '$fileName.$fileExt';

    try {
      debugPrint('Nagsisimulang mag-upload sa Supabase storage...');
      final bytes = await pickedFile.readAsBytes();
      await supabase.storage
          .from('employee-images')
          .uploadBinary(filePath, bytes, fileOptions: FileOptions(contentType: pickedFile.mimeType ?? 'image/jpeg'));
      debugPrint('Tagumpay ang pag-upload. File path: $filePath');

      final publicUrl =
          supabase.storage.from('employee-images').getPublicUrl(filePath);
      debugPrint('Nakuha ang public URL: $publicUrl');
      
      // Save the new URL to Firestore and update the local state
      await _updateUserProfileImageUrl(publicUrl);

    } catch (e) {
      debugPrint('Nagkaroon ng error habang nag-a-upload: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  /// Saves the new image URL to the user's document in Firestore.
  Future<void> _updateUserProfileImageUrl(String newUrl) async {
    final user = _firebaseAuth.currentUser;
    
    // 1. Optimistic Update: I-update agad ang UI para makita ng user ang bagong image
    //    kahit naglo-loading pa o offline ang Firestore.
    if (mounted) {
      setState(() => imageUrl = newUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully')),
      );
    }

    if (user == null) return;

    try {
      // 2. I-save sa Firestore (Background sync)
      await _firestore.collection('employees').doc(user.uid).set({
        'imageUrl': newUrl,
      }, SetOptions(merge: true)); // Use merge to avoid overwriting other fields
      debugPrint('Image URL saved to Firestore.');
    } catch (e) {
      debugPrint('Error saving image URL to Firestore: $e');
      // Note: Kahit mag-fail ang save (e.g. offline), nakita na ng user ang image sa session na ito.
      // Sa susunod na restart na lang ulit susubukang i-fetch kung may connection na.
    }
  }

  /// Opens a dialog to edit a specific text field and saves it to Firestore.
  Future<void> _editField(String title, String fieldKey, String currentValue) async {
    final TextEditingController controller = TextEditingController(text: currentValue);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Enter new $title',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newValue = controller.text.trim();
              Navigator.pop(context); // Close dialog

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
    _loadUserProfile(); // Refresh UI
  }

  /// Shows a dialog to change the password with re-authentication.
  Future<void> _showChangePasswordDialog() async {
    final TextEditingController currentPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();

    // Default visibility states (true = hidden)
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

await showDialog(
  context: context,
  builder: (dialogContext) { // Renamed to dialogContext to avoid confusion
    return StatefulBuilder(builder: (context, setState) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'For security, please enter your current password.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: currentPassController,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscureCurrent
                        ? Icons.visibility_off
                        : Icons.visibility),
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
                    icon: Icon(obscureNew
                        ? Icons.visibility_off
                        : Icons.visibility),
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
                    icon: Icon(obscureConfirm
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPassController.text != confirmPassController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New passwords do not match')),
                );
                return;
              }

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && user.email != null) {
                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPassController.text,
                  );

                  // Re-authenticate
                  await user.reauthenticateWithCredential(cred);
                  
                  // Update Password
                  await user.updatePassword(newPassController.text);

                  // ✅ FIX: Check if context is still mounted after async awaits
                  if (!context.mounted) return;

                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password updated successfully!')),
                  );
                }
              } on FirebaseAuthException catch (e) {
                // ✅ FIX: Check if context is still mounted before showing error SnackBar
                if (!context.mounted) return;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message ?? 'Error updating password')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ProfilePage.primaryColor,
              foregroundColor: Colors.white,
            ),
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
      backgroundColor: ProfilePage.bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 50),
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
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 28),
                          ),
                          Text(
                            'Manage your information and preferences',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildAvatar(),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_name,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _editField('Name', 'name', _name),
                          child: const Icon(Icons.edit, size: 20, color: Colors.grey),
                        ),
                      ],
                    ),
                    const Text('Health Officer',
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 30),

                    // --- SECTION: Personal Information ---
                    _buildSectionLabel('Personal Information'),
                    
                    // Employee ID is read-only (System Generated)
                    _buildProfileItem(Icons.badge_outlined, 'Employee ID', _employeeIdDisplay),
                    
                    _buildProfileItem(Icons.email_outlined, 'Email', _email),
                        
                    _buildProfileItem(Icons.phone_android_outlined, 'Phone', _phone,
                        canEdit: true, onTap: () => _editField('Phone', 'phone', _phone)),
                        
                    _buildProfileItem(Icons.location_on_outlined, 'Office', _office,
                        canEdit: true, onTap: () => _editField('Office', 'office', _office)),

                    const Divider(height: 40, thickness: 1),

                    // --- SECTION: Employment Details ---
                    _buildSectionLabel('Employment'),
                    _buildProfileItem(Icons.event_available,
                        'Employment Status', 'Full-Time Regular'),
                    _buildProfileItem(
                        Icons.schedule, 'Work Schedule', '08:00 AM - 05:00 PM'),
                    _buildProfileItem(Icons.supervisor_account,
                        'Immediate Supervisor', 'Engr. Ayro'),

                    const Divider(height: 40, thickness: 1),

                    // --- SECTION: Settings & Security ---
                    _buildSectionLabel('Settings & Security'),
                    _buildMenuOption(Icons.lock_outline, 'Change Password', 
                        onTap: _showChangePasswordDialog),
                    _buildMenuOption(
                      Icons.notifications_none_outlined,
                      'Notifications',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => NotificationsPage(employee: widget.employee))),
                    ),

                    const Divider(height: 40, thickness: 1),

                    // --- SECTION: Emergency ---
                    _buildSectionLabel('Emergency Contact'),
                    _buildProfileItem(Icons.contact_phone_outlined, 'Contact Person', _emergencyName,
                        canEdit: true, onTap: () => _editField('Contact Person', 'emergencyContactName', _emergencyName)),
                        
                    _buildProfileItem(Icons.family_restroom, 'Relationship', _emergencyRelation,
                        canEdit: true, onTap: () => _editField('Relationship', 'emergencyContactRelation', _emergencyRelation)),

                    const Divider(height: 40, thickness: 1),

                    // --- SECTION: Support & About ---
                    _buildSectionLabel('Support'),
                    _buildMenuOption(Icons.help_outline, 'Help Center'),
                    _buildMenuOption(
                        Icons.privacy_tip_outlined, 'Privacy Policy'),
                    _buildMenuOption(Icons.info_outline, 'App Version',
                        trailing: 'v1.0.0'),

                    const SizedBox(height: 10),
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
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ProfilePage.primaryColor,
              letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: pickAndUploadImage,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: CircleAvatar(
              radius: 55,
              backgroundColor: const Color(0xFFE0E0E0),
              backgroundImage:
                  imageUrl != null ? NetworkImage(imageUrl!) : null,
              child: imageUrl == null
                  ? const Icon(Icons.person,
                      size: 65, color: Colors.white)
                  : null,
            ),
          ),
          Positioned(
            bottom: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt,
                  size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, String value,
      {bool canEdit = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: canEdit ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: ProfilePage.bgColor,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: Colors.black87),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                ],
              ),
            ),
            if (canEdit)
              const Icon(Icons.edit_note,
                  size: 22, color: ProfilePage.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String title,
      {String? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.black87),
            const SizedBox(width: 15),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600))),
            if (trailing != null)
              Text(trailing,
                  style: const TextStyle(
                      fontSize: 13,
                      color: ProfilePage.primaryColor,
                      fontWeight: FontWeight.bold)),
            const SizedBox(width: 5),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
