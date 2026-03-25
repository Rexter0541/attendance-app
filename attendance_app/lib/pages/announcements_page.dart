import 'package:flutter/material.dart';

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  // UI Constants (Matching PayrollPage)
  static const Color bgColor = Color(0xFFF8F9FC);
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF1E293B);

  // ✅ Sample Data
  final List<Map<String, String>> sampleAnnouncements = const [
    {
      'title': 'System Maintenance',
      'date': 'Oct 24, 2026',
      'content': 'The workforce system will be down for scheduled maintenance from 10:00 PM to 2:00 AM.',
      'type': 'Urgent'
    },
    {
      'title': 'New Holiday Policy',
      'date': 'Oct 22, 2026',
      'content': 'Please review the updated holiday leave policy in the employee handbook. Effective immediately.',
      'type': 'General'
    },
    {
      'title': 'Team Building Event',
      'date': 'Oct 20, 2026',
      'content': 'Join us for a fun team-building event at the park this Friday. Lunch will be provided.',
      'type': 'General'
    },
    {
      'title': 'Performance Review Deadline',
      'date': 'Oct 18, 2026',
      'content': 'All employees are reminded to complete their self-assessment for the quarterly performance review by October 25th.',
      'type': 'Urgent'
    },
    {
      'title': 'Office Closure',
      'date': 'Oct 15, 2026',
      'content': 'The office will be closed on November 1st for a national holiday.',
      'type': 'General'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Announcements',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: sampleAnnouncements.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: sampleAnnouncements.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = sampleAnnouncements[index];
                return _buildAnnouncementCard(item);
              },
            ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, String> data) {
    bool isUrgent = data['type'] == 'Urgent';
    Color typeColor = isUrgent ? Colors.redAccent : primaryColor;
    IconData typeIcon = isUrgent ? Icons.notification_important_rounded : Icons.campaign_rounded;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(typeIcon, color: typeColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data['type']!.toUpperCase(),
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      data['date']!,
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data['title']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data['content']!,
                  style: TextStyle(color: Colors.grey[600], height: 1.4, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text('No Announcements', style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}