import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});
  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _flashOn = false;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid)
      controller?.pauseCamera();
    else if (Platform.isIOS)
      controller?.resumeCamera();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CloseButton(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _flashOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () async {
              await controller?.toggleFlash();
              setState(() => _flashOn = !_flashOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => controller?.flipCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: (ctrl) {
              controller = ctrl;
              ctrl.scannedDataStream.listen((scanData) {
                if (scanData.code == null) return;
                ctrl.pauseCamera();
                Navigator.of(context).pop(scanData.code);
              });
            },
            overlay: QrScannerOverlayShape(
              borderColor: Theme.of(context).colorScheme.primary,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 250,
            ),
            onPermissionSet: (ctrl, p) {
              if (!p) {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Permission Denied'),
                    content: const Text(
                      'Camera permission is required to scan QR codes.',
                    ),
                    actions: [
                      TextButton(
                        child: const Text('OK'),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48.0, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scan Project Config QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () {
                      controller?.pauseCamera();
                      Navigator.pop(context, '');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Enter Manually'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
