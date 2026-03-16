import 'package:flutter/material.dart';

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

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
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        title: const Text('Announcements',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: const Color(0xFFF2F3F7),
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: sampleAnnouncements.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: sampleAnnouncements.length,
              itemBuilder: (context, index) {
                final item = sampleAnnouncements[index];
                return _buildAnnouncementCard(item);
              },
            ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, String> data) {
    bool isUrgent = data['type'] == 'Urgent';

    return Container(
      // ✅ FIXED: Changed 'EdgeInsets.bottom' to 'EdgeInsets.only(bottom: 15)'
      margin: const EdgeInsets.only(bottom: 15), 
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(4, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data['date']!,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              if (isUrgent)
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data['title']!,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            data['content']!,
            style: TextStyle(color: Colors.grey[700], height: 1.4),
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
          const Icon(Icons.campaign_outlined, size: 100, color: Colors.orange),
          const SizedBox(height: 15),
          const Text('No Announcements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Stay tuned for updates.', 
            textAlign: TextAlign.center, 
            style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}