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

  // Cumulative map to track all matches across frames (never reset)
  final Map<String, int> _cumulativeMatches = {};

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
      // Track matches in this frame (to avoid double-counting in same frame)
      final thisFrameMatches = <String>{};

      // Debug: Log all detected text
      debugPrint('OCR detected ${recognizedTexts.length} text blocks');

      for (final textBlock in recognizedTexts) {
        // Check each text candidate in the block
        for (final text in textBlock.listText) {
          final trimmedText = text.trim();
          debugPrint('  OCR text: "$trimmedText"');
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

            // Track this match in the current frame
            thisFrameMatches.add(extractedText);
            break; // Only add one match per text block
          }
        }
      }

      // Update cumulative counts for matches found in this frame
      for (final match in thisFrameMatches) {
        _cumulativeMatches[match] = (_cumulativeMatches[match] ?? 0) + 1;
      }

      // Convert cumulative map to sorted list (top 5 by occurrence count)
      final matchedBlocks =
          _cumulativeMatches.entries
              .map(
                (entry) => MatchedTextBlock(
                  text: entry.key,
                  boundingBox: Rect.zero, // Not used for display
                  occurrences: entry.value,
                ),
              )
              .toList()
            ..sort((a, b) => b.occurrences.compareTo(a.occurrences));

      if (mounted) {
        setState(() {
          _matchedBlocks = matchedBlocks.take(5).toList();
        });
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    } finally {
      _isDetecting = false;
    }
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
                      ? 'Scanning for matches...'
                      : '${_matchedBlocks.length} unique ${_matchedBlocks.length == 1 ? 'match' : 'matches'} - tap to select',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_matchedBlocks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ..._matchedBlocks.map(
                    (match) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 16,
                      ),
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.of(context).pop(match.text);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${match.occurrences}×',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    match.text,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
  final int occurrences;

  MatchedTextBlock({
    required this.text,
    required this.boundingBox,
    this.occurrences = 1,
  });
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
