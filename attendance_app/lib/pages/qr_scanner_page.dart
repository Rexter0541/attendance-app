import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isScanned = false; // ✅ Guard to prevent double-popping

  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal, 
    facing: CameraFacing.back,
    formats: [BarcodeFormat.qrCode],
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    controller.dispose();
    super.dispose();
  }

 @override
Widget build(BuildContext context) {
  // ✅ Define the scan area size
  const double scanArea = 260.0;

  // ✅ Create the Scan Window (The ONLY area where the camera will look for QR codes)
  final Rect scanWindow = Rect.fromCenter(
    center: Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    ),
    width: scanArea,
    height: scanArea,
  );

  return Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        // 1. The Camera View
        MobileScanner(
          controller: controller,
          scanWindow: scanWindow, // ✅ CRITICAL: Ignores everything outside the white box
          onDetect: (capture) async {
            if (_isScanned) return; 

            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final String? code = barcodes.first.rawValue;
              if (code != null) {
                setState(() => _isScanned = true);
                await controller.stop(); 
                await Future.delayed(const Duration(milliseconds: 600));
                if (!context.mounted) return;

                Navigator.pop(context, code);
              }
            }
          },
        ),
          // 2. Cinematic Overlay (Dimming edges)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(150),
              backgroundBlendMode: BlendMode.dstOut,
            ),
          ),

          // 3. The Scanning Frame & Laser
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      width: scanArea,
                      height: scanArea,
                      decoration: BoxDecoration(
                        // Border turns Green on success
                        border: Border.all(
                          color: _isScanned ? Colors.greenAccent : Colors.white24, 
                          width: 2
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    // Only show laser if not yet scanned
                    if (!_isScanned)
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Positioned(
                            top: _animationController.value * (scanArea - 10),
                            left: 10,
                            right: 10,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withAlpha(200),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                                color: Colors.blueAccent,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  _isScanned ? 'SECURED' : 'ALIGN QR CODE WITHIN FRAME',
                  style: TextStyle(
                    color: _isScanned ? Colors.greenAccent : Colors.white70,
                    letterSpacing: 2,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 4. Back Button
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // 5. Flash Toggle
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.flashlight_on,
                    color: Colors.white70,
                    size: 28,
                  ),
                  onPressed: () => controller.toggleTorch(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}