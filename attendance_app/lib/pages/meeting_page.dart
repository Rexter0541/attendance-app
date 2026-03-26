import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/employee.dart';

class MeetingPage extends StatefulWidget {
  final Employee employee;
  const MeetingPage({super.key, required this.employee});

  @override
  State<MeetingPage> createState() => _MeetingPageState();
}

class _MeetingPageState extends State<MeetingPage> {
  final TextEditingController _roomController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Color primaryColor = const Color(0xFF4F46E5);

  final _jitsiMeetPlugin = JitsiMeet();
  
  // Tracking variables
  String? _currentLogId;
  DateTime? _joinTime;
  static const int minMinutesForPresence = 5; // X minutes rule
  bool _isGeneratingCode = false;

  // Function to generate random GMeet-like code (xxx-yyyy-zzz)
  String _generateMeetingCode() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    String part1 = List.generate(3, (index) => chars[random.nextInt(chars.length)]).join();
    String part2 = List.generate(4, (index) => chars[random.nextInt(chars.length)]).join();
    String part3 = List.generate(3, (index) => chars[random.nextInt(chars.length)]).join();
    return '$part1-$part2-$part3';
  }

  void _handleMeetingAction({required bool isCreating}) async {
    try {
      String roomCode = _roomController.text.trim().toLowerCase();
      
      if (isCreating) {
        setState(() => _isGeneratingCode = true);
        roomCode = _generateMeetingCode();
        _roomController.text = roomCode;
        
        // Save to Firestore as an active meeting
        await _firestore.collection('active_meetings').doc(roomCode).set({
          'hostId': widget.employee.id,
          'hostName': widget.employee.name,
          'createdAt': FieldValue.serverTimestamp(),
        });
        setState(() => _isGeneratingCode = false);
      } else {
        if (roomCode.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a meeting code to join.'), backgroundColor: Colors.orange),
          );
          return;
        }
      }

      String finalRoomName = "LGU_Meet_$roomCode";

      // Check if platform is supported
      if (kIsWeb) {
        debugPrint('Log: Running on Web. Launching browser tab...');
        
        final String encodedName = Uri.encodeComponent(widget.employee.name);
        final String webUrl = 'https://meet.jit.si/$finalRoomName#userInfo.displayName="$encodedName"&config.prejoinPageEnabled=false&config.disableDeepLinking=true';
        
        final Uri url = Uri.parse(webUrl);
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          throw Exception('Could not launch $url');
        }
        return;
      }

      debugPrint('Log: Attempting to join: "$finalRoomName"');

      var options = JitsiMeetConferenceOptions(
        serverURL: "https://meet.jit.si", // Default Jitsi server
        room: finalRoomName,
        configOverrides: {
          'startWithAudioMuted': true,
          'startWithVideoMuted': true,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: widget.employee.name, // Feature 3: Auth Tie-in
          email: widget.employee.id, // Gamitin ang ID para sa internal tracking
        ),
      );

    // 2. Join/Leave Tracking Logic (Feature 1)
    await _jitsiMeetPlugin.join(
      options,
      JitsiMeetEventListener(
        conferenceJoined: (url) async{
        _joinTime = DateTime.now();
        debugPrint('Log: User joined meeting. Logging to Firestore...');

        final docRef = await _firestore.collection('meeting_logs').add({
          'employeeId': widget.employee.id,
          'employeeName': widget.employee.name,
          'roomName': finalRoomName,
          'joinTime': FieldValue.serverTimestamp(),
          'leaveTime': null,
          'durationMinutes': 0,
          'status': 'In-Progress',
        });
        _currentLogId = docRef.id;
      },
        conferenceTerminated: (url, error) async{
        if (_currentLogId != null && _joinTime != null) {
          final leaveTime = DateTime.now();
          final duration = leaveTime.difference(_joinTime!).inMinutes;

          debugPrint('Log: Meeting terminated. Duration: $duration mins');

          await _firestore.collection('meeting_logs').doc(_currentLogId).update({
            'leaveTime':
            FieldValue.serverTimestamp(),
            'durationMinutes': duration,
            'status': duration >=
                minMinutesForPresence
                ? 'Present'
                : 'Short Stay',
          });
        }
      },
      ),
    );

    } catch (e) {
      debugPrint('Jitsi Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _copyRoomName() {
    if (_roomController.text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _roomController.text.trim()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room name copied to clipboard!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room name first')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Meeting', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1E293B),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8F9FC), Color(0xFFE0E7FF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_camera_front_rounded, size: 80, color: primaryColor),
                const SizedBox(height: 24),
                const Text(
                  'LGU Video Conference',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                Text(
                  _isGeneratingCode ? 'Generating unique code...' : 'Enter a meeting code to join or create a new one.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _roomController,
                  decoration: InputDecoration(
                    hintText: 'Meeting Code (e.g. abc-defg-hij)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.video_camera_back_outlined, color: primaryColor),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: _copyRoomName,
                      tooltip: 'Copy Room Name',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () => _handleMeetingAction(isCreating: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          child: const Text('Create', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: () => _handleMeetingAction(isCreating: false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('Join', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}