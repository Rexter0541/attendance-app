import 'dart:async';
import 'package:flutter/material.dart';
import '../models/employee.dart';
import 'home_page.dart';

class TimeInPage extends StatefulWidget {
  final Employee employee;

  const TimeInPage({super.key, required this.employee});

  @override
  State<TimeInPage> createState() => _TimeInPageState();
}

class _TimeInPageState extends State<TimeInPage> {
  late Timer timer;
  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();

    /// ✅ Live Clock
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => now = DateTime.now());
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  /// ✅ TIME FORMAT
  String formatTime(DateTime time) {
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  /// ✅ TIME IN
  void timeIn() {
    setState(() {
      widget.employee.status = "Timed In";
      widget.employee.timeIn = DateTime.now();
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(employee: widget.employee),
        ),
      );
    });
  }

  /// ✅ TIME OUT
  void timeOut() {
    setState(() {
      widget.employee.status = "Timed Out";
      widget.employee.timeOut = DateTime.now();
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(employee: widget.employee),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF3F4F6),

      body: Stack(
        children: [

          /// ✅ GO TO DASHBOARD BUTTON
          Positioned(
            top: 50,
            left: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        HomePage(employee: widget.employee),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(20),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dashboard, color: Colors.black87),
                    SizedBox(width: 8),
                    Text(
                      "Go to Dashboard",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// ✅ PAGE CONTENT
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 15,
                      color: Colors.black.withAlpha(20),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    const Text(
                      "Check-In Portal",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      "Current Time",
                      style: TextStyle(color: Colors.grey),
                    ),

                    const SizedBox(height: 10),

                    /// ✅ LIVE CLOCK
                    Text(
                      formatTime(now),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff6366F1),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      "Welcome, ${widget.employee.name}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 25),

                    /// ✅ TIME CARD
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xffF3F4F6),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Time In",
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                widget.employee.timeIn == null
                                    ? "-- : --"
                                    : formatTime(
                                        widget.employee.timeIn!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const Divider(height: 25),

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Time Out",
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                widget.employee.timeOut == null
                                    ? "-- : --"
                                    : formatTime(
                                        widget.employee.timeOut!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    /// ✅ BUTTONS
                    Row(
                      children: [

                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text("Time In"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: widget.employee.timeIn != null
                                ? null
                                : timeIn,
                          ),
                        ),

                        const SizedBox(width: 15),

                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.logout),
                            label: const Text("Time Out"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xffE9E5F3),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: widget.employee.timeIn == null
                                ? null
                                : timeOut,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}