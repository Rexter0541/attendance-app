import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/employee.dart';
import 'attendance_log.dart';
import 'leave_page.dart';
import 'payroll_page.dart';
import 'announcements_page.dart';
import 'events_page.dart';

class NotificationsPage extends StatefulWidget {
  final Employee employee;
  final String currentStatus;
  final Color statusColor;

  const NotificationsPage({super.key, required this.employee, this.currentStatus = 'Check Dashboard', this.statusColor = Colors.grey});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _firestore = FirebaseFirestore.instance;
  final _currentUser = FirebaseAuth.instance.currentUser;

  // Toggle read/unread status
  Future<void> _toggleReadStatus(String notificationId, bool isCurrentlyRead) async {
    if (_currentUser == null) return;
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': !isCurrentlyRead});
    } catch (e) {
      debugPrint('Error toggling notification status: $e');
    }
  }

  // Mark all notifications as read
  Future<void> _markAllAsRead() async {
    if (_currentUser == null) return;
    try {
      final batch = _firestore.batch();
      final snapshots = await _firestore
          .collection('notifications')
          .where('recipientId', isEqualTo: _currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in snapshots.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  // Get the right icon for the notification type
  IconData _getIconForType(String type) {
    switch (type) {
      case 'leave_approved':
        return Icons.check_circle_outline;
      case 'leave_declined':
        return Icons.cancel_outlined;
      case 'payroll':
        return Icons.payments_outlined;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'event':
        return Icons.event_note_outlined;
      case 'attendance_late':
        return Icons.access_time_filled_rounded;
      case 'attendance_present':
        return Icons.person_pin_circle_outlined;
      default:
        return Icons.notifications;
    }
  }

  // Get the right color for the notification type
  Color _getColorForType(String type) {
    switch (type) {
      case 'leave_approved':
        return Colors.green;
      case 'leave_declined':
        return Colors.red;
      case 'payroll':
        return Colors.blue;
      case 'announcement':
        return Colors.orange;
      case 'event':
        return Colors.purple;
      case 'attendance_late':
        return Colors.redAccent;
      case 'attendance_present':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: Stack(
        children: [
          // AMBIENT BACKGROUND LAYER (Blur/Glass Effect Base)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF8F9FC),
                  Color(0xFFE0E7FF),
                ],
              ),
            ),
          ),
          // Top Right Glow
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4F46E5).withAlpha(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withAlpha(28),
                    blurRadius: 100,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          // Bottom Left Glow
          Positioned(
            bottom: 50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF818CF8).withAlpha(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF818CF8).withAlpha(28),
                    blurRadius: 80,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          // MAIN CONTENT
          SafeArea(
            child: _currentUser == null
                ? const Center(child: Text('You must be logged in.'))
                : StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('notifications')
                        .where('recipientId', isEqualTo: _currentUser.uid)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      // Check for errors
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                                'Something went wrong.\n\nError: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red)),
                          ),
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      final notifications = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final doc = notifications[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final notificationId = doc.id;
                          // ... (Data extraction logic remains the same)
                          final String title = data['title'] ?? 'No Title';
                          final String body = data['body'] ?? 'No content.';
                          final String type = data['type'] ?? 'general';
                          final bool isRead = data['isRead'] ?? false;
                          final Timestamp? timestamp = data['timestamp'];
                          String timeAgo = 'Just now';
                          if (timestamp != null) {
                            final diff = DateTime.now().difference(timestamp.toDate());
                            if (diff.inDays > 0) {
                              timeAgo = '${diff.inDays}d ago';
                            } else if (diff.inHours > 0) {
                              timeAgo = '${diff.inHours}h ago';
                            } else if (diff.inMinutes > 0) {
                              timeAgo = '${diff.inMinutes}m ago';
                            }
                          }

                          return _buildNotificationItem(
                            notificationId,
                            title,
                            body,
                            timeAgo,
                            _getIconForType(type),
                            _getColorForType(type),
                            isUnread: !isRead,
                            type: type,
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

  Widget _buildNotificationItem(String id, String title, String message, String time, IconData icon, Color color, {bool isUnread = false, required String type}) {
    return GestureDetector(
      onTap: () {
        if (isUnread) {
          _toggleReadStatus(id, false);
        }
        
        // Navigation Logic based on Notification Type
        Widget? page;
        switch (type) {
          case 'attendance_late':
          case 'attendance_present':
            page = AttendanceLogPage(
              employee: widget.employee,
              currentStatus: widget.currentStatus,
              statusColor: widget.statusColor,
            );
            break;
          case 'leave_approved':
          case 'leave_declined':
            page = LeavePage(
              employee: widget.employee,
              currentStatus: widget.currentStatus,
              statusColor: widget.statusColor,
            );
            break;
          case 'payroll':
            page = PayrollPage(employee: widget.employee, currentStatus: widget.currentStatus, statusColor: widget.statusColor);
            break;
          case 'announcement':
            page = const AnnouncementsPage();
            break;
          case 'event':
            page = const EventsPage();
            break;
        }

        if (page != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isUnread ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            if (isUnread)
              BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 10, offset: const Offset(0, 4))
          ],
          border: isUnread ? Border.all(color: color.withValues(alpha: .3)) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isUnread ? Colors.black : Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(message, style: TextStyle(fontSize: 12, color: isUnread ? Colors.black87 : Colors.black54)),
                ],
              ),
            ),
            Column(
              children: [
                if (isUnread)
                  Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  onSelected: (_) => _toggleReadStatus(id, !isUnread),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(isUnread ? 'Mark as read' : 'Mark as unread'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text('No Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 5),
          Text('You are all caught up!', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}