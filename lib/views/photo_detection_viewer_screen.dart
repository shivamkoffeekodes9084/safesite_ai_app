import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../model/safety_response_model.dart';
import '../services/on_device_detector.dart';

/// Fullscreen Photo Detection Viewer Screen
/// Displays selected gallery image with on-device YOLO bounding box overlay and stats
class PhotoDetectionViewerScreen extends StatefulWidget {
  final File photoFile;

  const PhotoDetectionViewerScreen({
    super.key,
    required this.photoFile,
  });

  @override
  State<PhotoDetectionViewerScreen> createState() =>
      _PhotoDetectionViewerScreenState();
}

class _PhotoDetectionViewerScreenState
    extends State<PhotoDetectionViewerScreen> {
  bool _isLoading = true;
  SafetyResponseModel? _result;
  double _imgWidth = 1080.0;
  double _imgHeight = 1920.0;

  @override
  void initState() {
    super.initState();
    _processPhoto();
  }

  Future<void> _processPhoto() async {
    setState(() => _isLoading = true);
    try {
      final result = await OnDeviceDetector().detectFromFile(
        widget.photoFile,
        conf: 0.25,
        iouThresh: 0.45,
        isCameraFrame: false,
      );

      if (mounted) {
        setState(() {
          _result = result;
          _imgWidth = result?.imageWidth ?? 1080.0;
          _imgHeight = result?.imageHeight ?? 1920.0;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detections = _result?.detections ?? [];
    final peopleCount = _result?.effectivePeopleCount ?? 0;
    final violations = detections.where((d) {
      final l = d.className.toLowerCase();
      return l.startsWith('no_') || l.contains('violation');
    }).length;
    final isCompliant = violations == 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Photo with Bounding Boxes
          Center(
            child: AspectRatio(
              aspectRatio: _imgWidth / _imgHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    widget.photoFile,
                    fit: BoxFit.contain,
                  ),
                  if (!_isLoading && detections.isNotEmpty)
                    CustomPaint(
                      painter: _PhotoBoundingBoxPainter(
                        detections: detections,
                        imageWidth: _imgWidth,
                        imageHeight: _imgHeight,
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00E5FF),
                strokeWidth: 2.5,
              ),
            ),

          // 2. Top-Left Summary Pill
          if (!_isLoading)
            Positioned(
              top: 40,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCompliant
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFEF4444),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "PEOPLE: $peopleCount | DETECTIONS: ${detections.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCompliant ? "COMPLIANCE: SAFE" : "VIOLATIONS: $violations (UNSAFE)",
                      style: TextStyle(
                        color: isCompliant
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Top-Right Close Button
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoBoundingBoxPainter extends CustomPainter {
  final List<DetectionItem> detections;
  final double imageWidth;
  final double imageHeight;

  _PhotoBoundingBoxPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  Color _getClassColor(String name) {
    final lower = name.toLowerCase().replaceAll("-", "_").replaceAll(" ", "_");
    if (lower.startsWith("no_") || lower.contains("violation")) {
      return const Color(0xFFEF4444);
    }
    if (lower.contains("hardhat") || lower.contains("helmet")) {
      return const Color(0xFFA855F7);
    }
    if (lower.contains("vest")) {
      return const Color(0xFF22C55E);
    }
    if (lower.contains("person") || lower.contains("worker")) {
      return const Color(0xFFEAB308);
    }
    return const Color(0xFF38BDF8);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty || imageWidth <= 0 || imageHeight <= 0) return;

    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    for (final item in detections) {
      if (item.box.length < 4) continue;

      final double x1 = item.box[0] * scaleX;
      final double y1 = item.box[1] * scaleY;
      final double x2 = item.box[2] * scaleX;
      final double y2 = item.box[3] * scaleY;

      if (x2 <= x1 || y2 <= y1) continue;

      final rect = Rect.fromLTRB(x1, y1, x2, y2);
      final color = _getClassColor(item.className);

      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        boxPaint,
      );

      final confPercent = (item.confidence * 100).toInt();
      final textSpan = TextSpan(
        text: "${item.className} $confPercent%",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final chipWidth = textPainter.width + 10;
      final chipHeight = textPainter.height + 4;

      double chipTop = y1 - chipHeight - 2;
      if (chipTop < 0) chipTop = y1 + 2;
      final chipLeft = x1.clamp(0.0, max<double>(0.0, size.width - chipWidth)).toDouble();

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(chipLeft, chipTop, chipWidth, chipHeight),
          const Radius.circular(3),
        ),
        Paint()..color = color,
      );

      textPainter.paint(
        canvas,
        Offset(chipLeft + 5, chipTop + (chipHeight - textPainter.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PhotoBoundingBoxPainter oldDelegate) => true;
}
