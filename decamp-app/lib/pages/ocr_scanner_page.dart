import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isDetecting = false;
  List<MatchedTextBlock> _matchedBlocks = [];
  bool _isInitialized = false;
  String? _errorMessage;

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

      // Initialize camera controller
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

    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Filter text blocks that match the pattern
      final matchedBlocks = <MatchedTextBlock>[];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          final matches = widget.scanType == ScanType.apiKey
              ? TextPatternMatcher.isApiKey(text)
              : TextPatternMatcher.isUrl(text);

          if (matches) {
            final extractedText =
                TextPatternMatcher.extractMatch(text, widget.scanType) ?? text;
            matchedBlocks.add(
              MatchedTextBlock(
                text: extractedText,
                boundingBox: line.boundingBox,
              ),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _matchedBlocks = matchedBlocks;
        });
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Theme.of(context).platform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      // Android
      rotation = InputImageRotation.rotation0deg;
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;
    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: plane.bytes, metadata: inputImageData);
  }

  void _selectText(String text) {
    Navigator.of(context).pop(text);
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scanTypeName = widget.scanType == ScanType.apiKey ? 'API Key' : 'URL';

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
          : _buildCameraView(theme, scanTypeName),
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

  Widget _buildCameraView(ThemeData theme, String scanTypeName) {
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

        // Tap detector for selecting text
        ..._matchedBlocks.map((block) => _buildTextTapArea(block, theme)),

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
                Icon(
                  widget.scanType == ScanType.apiKey ? Icons.key : Icons.link,
                  color: Colors.white,
                  size: 32,
                ),
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
                      : 'Tap highlighted text to select',
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

  Widget _buildTextTapArea(MatchedTextBlock block, ThemeData theme) {
    return Positioned.fromRect(
      rect: block.boundingBox,
      child: GestureDetector(
        onTap: () => _selectText(block.text),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
        ),
      ),
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
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    for (final block in matchedBlocks) {
      final rect = _scaleRect(block.boundingBox, imageSize, size);

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
    final scaleX = screenSize.width / imageSize.width;
    final scaleY = screenSize.height / imageSize.height;

    return Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );
  }

  @override
  bool shouldRepaint(TextOverlayPainter oldDelegate) {
    return matchedBlocks != oldDelegate.matchedBlocks;
  }
}
