import 'package:flutter/material.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  // UI Constants (Modern Design System)
  static const Color bgColor = Color(0xFFF8F9FC);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF1E293B);

  // ✅ Sample Event Data
  final List<Map<String, dynamic>> sampleEvents = const [
    {
      'title': 'Annual Team Building',
      'month': 'MAR',
      'day': '15',
      'location': 'Grand Ballroom, Hotel A',
      'time': '08:00 AM - 05:00 PM',
      'color': Colors.blue,
    },
    {
      'title': 'Monthly General Assembly',
      'month': 'MAR',
      'day': '28',
      'location': 'Conference Room 2',
      'time': '01:00 PM - 03:00 PM',
      'color': Colors.orange,
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
        title: const Text('Company Events',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: sampleEvents.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: sampleEvents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildEventCard(sampleEvents[index]);
              },
            ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final Color eventColor = event['color'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          // --- Date Badge ---
          Container(
            width: 60,
            height: 70,
            decoration: BoxDecoration(
              color: eventColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event['month'],
                  style: TextStyle(
                      color: eventColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
                Text(
                  event['day'],
                  style: TextStyle(
                      color: eventColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // --- Event Details ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(event['location'],
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(event['time'],
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
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
          Icon(Icons.event_note_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text('No Upcoming Events', style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}