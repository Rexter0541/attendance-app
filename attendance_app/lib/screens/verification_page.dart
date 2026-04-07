// ignore_for_file: unused_import
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // This covers foundation and services
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart'; 
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'; 
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart'; 

import '../models/attendance_session.dart';
import '../models/employee.dart';
import '../pages/timein_page.dart';
import '../pages/login_page.dart';
import '../pages/home_page.dart';
import '../services/attendance_service.dart';
import '../services/location_service.dart';
import '../pages/qr_scanner_page.dart';
import '../services/security_service.dart';
// Added these to link the files correctly:
import '../utils/device_utils.dart';
import '../services/face_service.dart';

class VerificationPage extends StatefulWidget {
  final Employee employee;

  const VerificationPage({super.key, required this.employee});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final AttendanceService attendanceService = AttendanceService();
  final LocationService locationService = LocationService();

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOnline = true;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, 
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  int currentStep = 0;
  double progressValue = 0.0;
  final List<String> logs = [];
  Timer? _progressTimer;

  Position? userPosition;
  double distanceFromOffice = 0.0;
  bool inRange = false;
  
  String? _capturedPhotoUrl;

  @override
  void initState() {
    super.initState();
    
    // Monitor Network Awareness
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final bool isConnected = !results.contains(ConnectivityResult.none);
      if (_isOnline != isConnected) {
        setState(() => _isOnline = isConnected);
        _addLog(_isOnline ? 'Network restored. 🌐' : 'Network lost! Check connection. ⚠️');
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkIfTimedIn();
      if (mounted) {
        _startVerification();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _progressTimer?.cancel();
    _faceDetector.close(); 
    super.dispose();
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.05);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: animation.drive(tween), child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
    );
  }

  Future<void> _checkIfTimedIn() async {
    final AttendanceSession? session = await attendanceService.checkTodayAttendance(widget.employee);
    if (session != null) {
      widget.employee.attendanceId = session.id;
      if (!mounted) return;
      Navigator.pushReplacement(context, _createRoute(HomePage(employee: widget.employee)));
    }
  }

  Future<void> _startVerification() async {
    _addLog('Initializing security protocols...');
    
    // Check for Time Manipulation (Anti-Cheat)
    _addLog('Verifying system clock integrity...');
    bool isSynced = await SecurityService.verifyTimeSync();
    
    if (!isSynced) {
      _addLog('SECURITY ALERT: System clock mismatch ⚠️');
      _showErrorDialog(
        'Clock Inaccurate', 
        'Your phone time does not match the server. Please set your time to "Automatic" in settings.',
      );
      return;
    }

    _checkGPS();
  }

  Future<void> _checkGPS() async {
    try {
      _addLog('Requesting location permission...');
      final result = await locationService.verifyLocation();
      if (!mounted) return;

      setState(() {
        userPosition = result.position;
        distanceFromOffice = result.distance;
      });

      _addLog('Distance from office: ${distanceFromOffice.toStringAsFixed(2)} meters');

      if (!result.isAccurate) {
        _addLog('SIGNAL WEAK: Accuracy is ${result.position.accuracy.toStringAsFixed(1)}m');
        _showErrorDialog(
          'Weak GPS Signal',
          'Your location is too imprecise. Please move to an area with a clear view of the sky.',
          onRetry: () => _checkGPS(),
        );
        return;
      }

      // Hardening: Check for Mock Locations (GPS Spoofing)
      if (userPosition?.isMocked ?? false) {
        _addLog('SECURITY ALERT: MOCK LOCATION DETECTED 🛡️');
        _showErrorDialog(
          'Security Violation',
          'Mock location apps are not allowed. Please disable them to continue.',
        );
        return;
      }

      setState(() => inRange = result.inRange);

      if (!inRange) {
        _addLog('STATUS: OUT OF RANGE ❌');
        _showErrorDialog(
          'Out of Range', 
          'You are ${distanceFromOffice.toStringAsFixed(2)}m away.',
          onRetry: () => _checkGPS(),
        );
        return;
      }

      _addLog('STATUS: WITHIN OFFICE RANGE ✅');
      _updateProgress(0.33);
      await Future.delayed(const Duration(milliseconds: 800));
      _initiateQRStep();
    } catch (e) {
      _showErrorDialog('GPS Error', e.toString(), onRetry: () => _checkGPS());
    }
  }

  void _initiateQRStep() async {
    bool start = await _showActionDialog(
      title: 'Step 2: QR Scan',
      message: 'Please scan the official terminal QR code.',
      buttonText: 'OPEN SCANNER',
      icon: Icons.qr_code_scanner,
      iconColor: const Color(0xFF6C63FF),
    );

    if (!mounted || !start) return;

    final String? scannedValue = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerPage()),
    );

    if (scannedValue == null) {
      _addLog('Scanning cancelled.');
      return;
    }

    _addLog('Decrypting QR Signature...');
    bool isValid = await SecurityService.verifyQRWithFirebase(scannedValue); 
    
    if (isValid) {
      _updateProgress(0.66);
      setState(() => currentStep = 1);
      _addLog('Identity Token Validated ✅');
      _initiatePhotoStep();
    } else {
      _addLog('Invalid QR Code ❌');
      _showErrorDialog(
        'Verification Failed', 
        'Incorrect or expired QR code.',
        onRetry: () => _initiateQRStep(),
      );
    }
  }

  void _initiatePhotoStep() async {
    bool start = await _showActionDialog(
      title: 'Step 3: Biometric Liveness',
      message: 'Position your face in the oval and follow the prompts.',
      buttonText: 'START VERIFICATION',
      icon: Icons.face_unlock_outlined,
      iconColor: Colors.orange,
    );

    if (!mounted || !start) return;

    final File? photoFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (context) => LivenessCameraPage(faceDetector: _faceDetector),
      ),
    );

    if (photoFile == null) {
      _addLog('Capture cancelled.');
      return;
    }

    _addLog('Uploading biometric proof...');
    _updateProgress(0.90);

    try {
      final fileName = '${widget.employee.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final supabase = Supabase.instance.client;

      await supabase.storage.from('attendance_photos').upload(
            fileName,
            photoFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      _capturedPhotoUrl = supabase.storage.from('attendance_photos').getPublicUrl(fileName);

      setState(() => currentStep = 2);
      _updateProgress(1.0);
      _addLog('Facial Proof Secured ✅');
      _finalizeVerification();
    } catch (e) {
      _addLog('Upload Error: $e');
      _showErrorDialog(
        'Upload Failed', 
        'Could not save photo to Supabase.',
        onRetry: () => _initiatePhotoStep(),
      );
    }
  }

  Future<void> _finalizeVerification() async {
    _addLog('Securing technical identity...');

    // Detect technical hardware/browser signature
    String deviceSignature = await DeviceUtils.getTechnicalDeviceName();
    
    _addLog('IDENTIFIED: $deviceSignature');
    _addLog('Creating Attendance Session...');

    final attendanceId = await attendanceService.createAttendance(
      employee: widget.employee,
      lat: userPosition!.latitude,
      lng: userPosition!.longitude,
      distance: distanceFromOffice,
      photoUrl: _capturedPhotoUrl, 
      deviceUsed: deviceSignature, // Passed to service
    );

    widget.employee.attendanceId = attendanceId;
    _addLog('Attendance Secured Successfully.');
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    Navigator.pushReplacement(context, _createRoute(TimeInPage(employee: widget.employee)));
  }

  void _showErrorDialog(String title, String message, {VoidCallback? onRetry}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushReplacement(context, _createRoute(const LoginPage())),
            child: const Text('Return to Login'),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildHeader(),
              const SizedBox(height: 40),
              _buildProgressBar(),
              const SizedBox(height: 20),
              _buildInfoCard(),
              const SizedBox(height: 15),
              _buildLocationStatus(),
              const Spacer(),
              _buildTerminal(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: currentStep == 2 ? Colors.green.withAlpha(30) : Colors.blue.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Icon(
            currentStep == 2 ? Icons.verified : Icons.security,
            size: 48,
            color: currentStep == 2 ? Colors.green : Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 16),
        const Text('SECURITY PROTOCOL ACTIVE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      ],
    );
  }

  Widget _buildProgressBar() => LinearProgressIndicator(
        value: progressValue,
        minHeight: 8,
        borderRadius: BorderRadius.circular(10),
        backgroundColor: Colors.grey[300],
        color: const Color(0xFF6C63FF),
      );

  Widget _buildInfoCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: Colors.blue[50], child: const Icon(Icons.person, color: Color(0xFF6C63FF))),
            const SizedBox(width: 15),
            Text(widget.employee.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _buildLocationStatus() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: inRange ? Colors.green[50] : Colors.red[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(inRange ? Icons.check_circle : Icons.cancel, color: inRange ? Colors.green : Colors.red),
            const SizedBox(width: 10),
            Text(
              inRange ? 'Within office range (${distanceFromOffice.toStringAsFixed(1)}m)' : 'Out of range',
              style: TextStyle(fontWeight: FontWeight.bold, color: inRange ? Colors.green : Colors.red),
            ),
          ],
        ),
      );

  Widget _buildTerminal() => Container(
        width: double.infinity,
        height: 150,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(15)),
        child: ListView.builder(
          itemCount: logs.length,
          itemBuilder: (_, i) => Text('> ${logs[i]}', style: const TextStyle(color: Colors.white60, fontFamily: 'monospace', fontSize: 11)),
        ),
      );

  void _addLog(String message) {
    if (mounted) setState(() => logs.insert(0, message));
  }

  void _updateProgress(double target) {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || progressValue >= target) {
        timer.cancel();
      } else {
        setState(() => progressValue += 0.01);
      }
    });
  }

  Future<bool> _showActionDialog({required String title, required String message, required String buttonText, required IconData icon, required Color iconColor}) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 60, color: iconColor),
                const SizedBox(height: 20),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 25),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(buttonText))
              ],
            ),
          ),
        ) ?? false;
  }
}

// =====================================================
// LIVENESS CAMERA PAGE (UNCHANGED)
// =====================================================

enum LivenessStep { lookFront, lookLeft, lookRight, smile }

class LivenessCameraPage extends StatefulWidget {
  final FaceDetector faceDetector;
  const LivenessCameraPage({super.key, required this.faceDetector});

  @override
  State<LivenessCameraPage> createState() => _LivenessCameraPageState();
}

class _LivenessCameraPageState extends State<LivenessCameraPage> {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _livenessSuccess = false;
  double _scanProgress = 0.0; 
  LivenessStep _currentStep = LivenessStep.lookFront;
  String _statusMessage = 'POSITION YOUR FACE: FRONT';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    
    _controller = CameraController(
      front, 
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});

    _controller!.startImageStream((image) => _detectLiveness(image));
  }

  void _detectLiveness(CameraImage image) async {
    if (_isProcessing || _livenessSuccess || !mounted) return;
    _isProcessing = true;

    try {
      final inputImage = FaceService.convertCameraImage(image, _controller!.description);
      if (inputImage == null) return;

      final faces = await widget.faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage = 'SEARCHING FOR FACE...';
            if (_scanProgress > 0) _scanProgress -= 0.01; 
          });
        }
      } else {
        final face = faces.first;
        final double? headY = FaceService.getHeadRotation(face); 
        
        if (mounted) {
          setState(() {
            switch (_currentStep) {
              case LivenessStep.lookFront:
                _statusMessage = 'LOOK STRAIGHT AHEAD';
                if (headY != null && headY.abs() < 10) {
                  _scanProgress += 0.02;
                  if (_scanProgress >= 0.33) _currentStep = LivenessStep.lookLeft;
                }
                break;
              case LivenessStep.lookLeft:
                _statusMessage = 'TURN HEAD LEFT ←';
                if (headY != null && headY > 20) {
                  _scanProgress += 0.02;
                  if (_scanProgress >= 0.66) _currentStep = LivenessStep.lookRight;
                }
                break;
              case LivenessStep.lookRight:
                _statusMessage = 'TURN HEAD RIGHT →';
                if (headY != null && headY < -20) {
                  _scanProgress += 0.02;
                  if (_scanProgress >= 0.95) _currentStep = LivenessStep.smile;
                }
                break;
              case LivenessStep.smile:
                _statusMessage = 'SMILE TO CONFIRM';
                _scanProgress = 1.0;
                break;
            }
          });
        }

        if (_currentStep == LivenessStep.smile) {
          bool isSmiling = FaceService.isSmiling(face);

          if (isSmiling) {
            _livenessSuccess = true;
            if (mounted) setState(() => _statusMessage = 'VERIFIED! CAPTURING...');
            
            await _controller?.stopImageStream();
            await Future.delayed(const Duration(milliseconds: 300));
            final file = await _controller!.takePicture();
            if (mounted) Navigator.pop(context, File(file.path));
          }
        }
      }
    } catch (e) {
      debugPrint('Liveness Error: $e');
    } finally {
      await Future.delayed(const Duration(milliseconds: 40));
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: Colors.white, 
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Text(
              'Face Verification',
              style: TextStyle(fontSize: 22, color: Colors.black, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              _getSubtitleText(),
              style: const TextStyle(fontSize: 14, color: Colors.black45, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 25, spreadRadius: 2)
                      ],
                    ),
                    child: ClipOval(
                      child: Transform.scale(
                        scale: scale,
                        child: Center(child: CameraPreview(_controller!)),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 270,
                    height: 270,
                    child: CustomPaint(
                      painter: ScannerProgressPainter(
                        progress: _scanProgress,
                        color: const Color(0xFFFF5722), 
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            Text(
              '${(_scanProgress * 100).toInt()}%',
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Color(0xFF2D3436)),
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage.toUpperCase(),
              style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.1),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  String _getSubtitleText() {
    switch (_currentStep) {
      case LivenessStep.lookFront: return 'Align your face within the frame';
      case LivenessStep.lookLeft: return 'Slowly turn your head left';
      case LivenessStep.lookRight: return 'Now slowly turn your head right';
      case LivenessStep.smile: return 'Smile clearly into the camera';
    }
  }
}

class ScannerProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  ScannerProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final trackPaint = Paint()
      ..color = Colors.grey[100]!
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(size.center(Offset.zero), size.width / 2, trackPaint);

    canvas.drawArc(
      Offset.zero & size,
      -1.5708, 
      6.2831 * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(ScannerProgressPainter oldDelegate) => true;
}