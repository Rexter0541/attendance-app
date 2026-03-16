import 'package:flutter/material.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

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
      backgroundColor: const Color(0xFFF2F3F7),
      appBar: AppBar(
        title: const Text('Company Events',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: const Color(0xFFF2F3F7),
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: sampleEvents.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: sampleEvents.length,
              itemBuilder: (context, index) {
                return _buildEventCard(sampleEvents[index]);
              },
            ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
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
      child: Row(
        children: [
          // --- Date Badge ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: event['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: event['color'], width: 1),
            ),
            child: Column(
              children: [
                Text(
                  event['month'],
                  style: TextStyle(
                      color: event['color'],
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
                Text(
                  event['day'],
                  style: TextStyle(
                      color: event['color'],
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          // --- Event Details ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['title'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(event['location'],
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(event['time'],
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black26),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_note_outlined, size: 100, color: Colors.blue),
          const SizedBox(height: 15),
          const Text('No Upcoming Events',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('There are no scheduled events\nat this moment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}