import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:apple_vision_recognize_text/apple_vision_recognize_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/text_pattern_matcher.dart';

/// OCR Scanner page with live camera preview and text detection overlay
/// Only highlights text that matches the specified pattern (API key or URL)
class OcrScannerPage extends StatefulWidget {
  final ScanType scanType;

  const OcrScannerPage({required this.scanType, super.key});

  @override
  State<OcrScannerPage> createState() => _OcrScannerPageState();
}

class _OcrScannerPageState extends State<OcrScannerPage> {
  CameraController? _cameraController;
  final AppleVisionRecognizeTextController _textRecognizer =
      AppleVisionRecognizeTextController();
  bool _isDetecting = false;
  List<MatchedTextBlock> _matchedBlocks = [];
  bool _isInitialized = false;
  String? _errorMessage;
  bool _hasFoundMatch = false; // Stop processing once we find matches

  // Throttle image processing to improve performance
  DateTime? _lastProcessedTime;
  static const _processingInterval = Duration(
    milliseconds: 500,
  ); // Process every 2 seconds

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      debugPrint('Initializing camera...');

      // Get available cameras first
      final cameras = await availableCameras();
      debugPrint('Available cameras: ${cameras.length}');

      if (cameras.isEmpty) {
        setState(() {
          _errorMessage =
              'No camera found on this device.\n\n${defaultTargetPlatform == TargetPlatform.iOS ? 'Note: iOS Simulator does not support camera. Please test on a physical device.' : 'Please ensure your device has a working camera.'}';
        });
        return;
      }

      // Initialize camera controller with medium resolution (faster)
      // On iOS, this will automatically trigger the permission dialog if needed
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      try {
        await _cameraController!.initialize();
        debugPrint('Camera initialized successfully');

        // Enable continuous auto-focus for better OCR scanning
        // This is crucial for scanning text at close range
        await _cameraController!.setFocusMode(FocusMode.auto);

        // Optional: Set exposure mode to auto for better text recognition
        await _cameraController!.setExposureMode(ExposureMode.auto);

        debugPrint('Auto-focus and exposure mode configured');
      } on CameraException catch (e) {
        debugPrint('Camera exception: ${e.code} - ${e.description}');

        // Check if it's a permission error
        if (e.code == 'CameraAccessDenied' ||
            e.description?.contains('denied') == true ||
            e.description?.contains('authorized') == true) {
          setState(() {
            _errorMessage =
                'Camera access was denied.\n\nTo use this feature, please:\n1. Go to Settings\n2. Find this app\n3. Enable Camera access';
          });
          return;
        }

        // Other camera errors
        setState(() {
          _errorMessage = 'Failed to access camera: ${e.description ?? e.code}';
        });
        return;
      }

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });

      // Start image stream for continuous text detection
      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Unexpected error: $e');
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;

    // Stop processing if we already found matches (to save battery/CPU)
    if (_hasFoundMatch && _matchedBlocks.isNotEmpty) return;

    // Throttle processing to avoid overwhelming the device
    final now = DateTime.now();
    if (_lastProcessedTime != null &&
        now.difference(_lastProcessedTime!) < _processingInterval) {
      return;
    }
    _lastProcessedTime = now;

    _isDetecting = true;

    try {
      // Convert CameraImage to bytes
      final bytes = _convertCameraImageToBytes(image);
      if (bytes == null) {
        _isDetecting = false;
        return;
      }

      final imageSize = Size(image.width.toDouble(), image.height.toDouble());

      // Process image with Apple Vision - use FAST recognition for better performance
      final recognizedTexts = await _textRecognizer.processImage(
        RecognizeTextData(
          image: bytes,
          imageSize: imageSize,
          recognitionLevel: RecognitionLevel.accurate,
          automaticallyDetectsLanguage: false, // Disabled for speed
        ),
      );

      if (recognizedTexts == null) {
        _isDetecting = false;
        return;
      }

      // Filter text blocks that match the pattern
      final matchedBlocks = <MatchedTextBlock>[];
      for (final textBlock in recognizedTexts) {
        // Check each text candidate in the block
        for (final text in textBlock.listText) {
          final trimmedText = text.trim();
          bool matches = false;

          switch (widget.scanType) {
            case ScanType.apiKey:
              matches = TextPatternMatcher.isApiKey(trimmedText);
              break;
            case ScanType.url:
              matches = TextPatternMatcher.isUrl(trimmedText);
              break;
            case ScanType.sshKey:
              matches = TextPatternMatcher.isSshKey(trimmedText);
              break;
            case ScanType.hostname:
              matches = TextPatternMatcher.isHostname(trimmedText);
              break;
          }

          if (matches) {
            final extractedText =
                TextPatternMatcher.extractMatch(trimmedText, widget.scanType) ??
                trimmedText;
            debugPrint(
              'Found match: "$extractedText" at ${textBlock.boundingBox}',
            );
            matchedBlocks.add(
              MatchedTextBlock(
                text: extractedText,
                boundingBox: textBlock.boundingBox,
              ),
            );
            break; // Only add one match per text block
          }
        }
      }

      if (mounted) {
        setState(() {
          _matchedBlocks = matchedBlocks;
          if (matchedBlocks.isNotEmpty) {
            _hasFoundMatch = true; // Stop continuous processing

            // Auto-return the detected result
            // If multiple matches, prefer the one closest to screen center
            final selectedMatch = _selectCenterMostMatch(matchedBlocks);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pop(selectedMatch.text);
              }
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    } finally {
      _isDetecting = false;
    }
  }

  /// Selects the match closest to the center of the screen
  MatchedTextBlock _selectCenterMostMatch(List<MatchedTextBlock> matches) {
    if (matches.length == 1) {
      return matches.first;
    }

    // Get camera preview center point (in camera coordinate space)
    final previewSize = _cameraController!.value.previewSize!;
    final centerX = previewSize.width / 2;
    final centerY = previewSize.height / 2;

    // Find the match with minimum distance to center
    MatchedTextBlock closestMatch = matches.first;
    double minDistance = double.infinity;

    for (final match in matches) {
      // Calculate the center of the bounding box
      final boxCenterX = match.boundingBox.left + match.boundingBox.width / 2;
      final boxCenterY = match.boundingBox.top + match.boundingBox.height / 2;

      // Calculate Euclidean distance to screen center
      final dx = boxCenterX - centerX;
      final dy = boxCenterY - centerY;
      final distance = dx * dx + dy * dy; // No need for sqrt, just comparing

      if (distance < minDistance) {
        minDistance = distance;
        closestMatch = match;
      }
    }

    debugPrint(
      'Selected center-most match: "${closestMatch.text}" '
      'from ${matches.length} candidates',
    );

    return closestMatch;
  }

  Uint8List? _convertCameraImageToBytes(CameraImage image) {
    try {
      // For iOS, CameraImage provides YUV420 format
      // We need to convert it to a format Apple Vision can process
      final plane = image.planes[0];
      return plane.bytes;
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    // Apple Vision controller doesn't need explicit disposal
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String scanTypeName;
    IconData scanIcon;

    switch (widget.scanType) {
      case ScanType.apiKey:
        scanTypeName = 'API Key';
        scanIcon = Icons.key;
        break;
      case ScanType.url:
        scanTypeName = 'URL';
        scanIcon = Icons.link;
        break;
      case ScanType.sshKey:
        scanTypeName = 'SSH Private Key';
        scanIcon = Icons.vpn_key;
        break;
      case ScanType.hostname:
        scanTypeName = 'Hostname/IP';
        scanIcon = Icons.dns;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Scan $scanTypeName'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _errorMessage != null
          ? _buildErrorView(theme)
          : !_isInitialized
          ? _buildLoadingView()
          : _buildCameraView(theme, scanTypeName, scanIcon),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    final isPermissionError = _errorMessage?.contains('permission') ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermissionError ? Icons.lock_outline : Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isPermissionError) ...[
              FilledButton.icon(
                onPressed: () async {
                  await openAppSettings();
                },
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildCameraView(
    ThemeData theme,
    String scanTypeName,
    IconData scanIcon,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        CameraPreview(_cameraController!),

        // Overlay with detected text boxes
        CustomPaint(
          painter: TextOverlayPainter(
            matchedBlocks: _matchedBlocks,
            imageSize: _cameraController!.value.previewSize!,
            color: theme.colorScheme.primary,
          ),
        ),

        // Instructions at the bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(scanIcon, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Point camera at $scanTypeName',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _matchedBlocks.isEmpty
                      ? 'Matching text will be highlighted'
                      : 'Match detected - returning...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Represents a text block that matches the search pattern
class MatchedTextBlock {
  final String text;
  final Rect boundingBox;

  MatchedTextBlock({required this.text, required this.boundingBox});
}

/// Custom painter to draw overlay boxes on detected text
class TextOverlayPainter extends CustomPainter {
  final List<MatchedTextBlock> matchedBlocks;
  final Size imageSize;
  final Color color;

  TextOverlayPainter({
    required this.matchedBlocks,
    required this.imageSize,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    debugPrint(
      'TextOverlayPainter: painting ${matchedBlocks.length} blocks, '
      'imageSize=$imageSize, screenSize=$size',
    );

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    for (final block in matchedBlocks) {
      final rect = _scaleRect(block.boundingBox, imageSize, size);
      debugPrint('  Block boundingBox=${block.boundingBox}, scaled=$rect');

      // Draw filled background
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        fillPaint,
      );

      // Draw border
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        paint,
      );
    }
  }

  Rect _scaleRect(Rect rect, Size imageSize, Size screenSize) {
    // WORKAROUND: Apple Vision package appears to return incorrect width/height
    // Use a fixed size box around the center point for now
    final scaleX = screenSize.width / imageSize.width;
    final scaleY = screenSize.height / imageSize.height;

    // Get center of the (malformed) rect
    final centerX = (rect.left + rect.right) / 2;
    final centerY = (rect.top + rect.bottom) / 2;

    // Vision uses bottom-left origin, Flutter uses top-left
    final flippedY = imageSize.height - centerY;

    // Create a reasonable-sized box (100x40 pixels in image space)
    const boxWidth = 100.0;
    const boxHeight = 40.0;

    return Rect.fromCenter(
      center: Offset(centerX * scaleX, flippedY * scaleY),
      width: boxWidth * scaleX,
      height: boxHeight * scaleY,
    );
  }

  @override
  bool shouldRepaint(TextOverlayPainter oldDelegate) {
    return matchedBlocks != oldDelegate.matchedBlocks;
  }
}
