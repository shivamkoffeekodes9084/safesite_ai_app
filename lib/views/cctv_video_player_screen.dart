import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../model/safety_response_model.dart';
import '../services/byte_tracker.dart';
import '../services/on_device_detector.dart';

/// Dedicated Fullscreen CCTV Video Player Screen
/// Matches Reference Image (media_1793709267987_5a7e549c.png):
/// - Live On-Device YOLO Inference & ByteTrack Tracking
/// - CCTV Real-Time Vision HUD Overlay in Top-Left Corner
/// - Interactive Video Playback Controls (Play/Pause, Timeline Scrubber, Time Display)
class CctvVideoPlayerScreen extends StatefulWidget {
  final File videoFile;

  const CctvVideoPlayerScreen({
    super.key,
    required this.videoFile,
  });

  @override
  State<CctvVideoPlayerScreen> createState() => _CctvVideoPlayerScreenState();
}

class _CctvVideoPlayerScreenState extends State<CctvVideoPlayerScreen> {
  static const MethodChannel _videoFrameChannel =
      MethodChannel('com.safesite.ai/video_frames');

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = true;

  // Real-time Detection & Tracking State
  final SimpleByteTracker _tracker = SimpleByteTracker();
  final Set<int> _uniqueTrackedSet = <int>{};
  List<DetectionItem> _currentDetections = [];
  int _livePeopleCount = 0;
  int _peakPeopleCount = 0;
  int _uniqueTrackedCount = 0;
  int _activeViolationsCount = 0;

  double _frameWidth = 1920.0;
  double _frameHeight = 1080.0;
  bool _isProcessingFrame = false;
  bool _isLoopActive = true;

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
  }

  Future<void> _initVideoPlayer() async {
    try {
      final controller = VideoPlayerController.file(widget.videoFile);
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (!mounted) return;

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _isPlaying = true;
        _frameWidth = controller.value.size.width > 0
            ? controller.value.size.width
            : 1920.0;
        _frameHeight = controller.value.size.height > 0
            ? controller.value.size.height
            : 1080.0;
      });

      controller.addListener(() {
        if (mounted && _controller != null) {
          if (_isPlaying != _controller!.value.isPlaying) {
            setState(() {
              _isPlaying = _controller!.value.isPlaying;
            });
          }
        }
      });

      _startVideoInferenceLoop();
    } catch (e) {
      debugPrint("[CctvVideoPlayer] Error initializing video: $e");
    }
  }

  Future<Uint8List?> _getVideoFrame(String videoPath, int timeMs) async {
    try {
      final result = await _videoFrameChannel.invokeMethod<Uint8List>(
        'getFrameAtTime',
        {
          'videoPath': videoPath,
          'timeMs': timeMs,
          'maxDimension': 640,
        },
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  void _startVideoInferenceLoop() async {
    int lastProcessedMs = -1;
    int lastLoopMs = 0;

    while (mounted && _isLoopActive) {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 35));
        continue;
      }

      final currentMs = controller.value.position.inMilliseconds;

      // Video looped back: reset tracker
      if (currentMs < lastLoopMs - 1000) {
        _tracker.reset();
      }
      lastLoopMs = currentMs;

      if (!_isProcessingFrame && (currentMs - lastProcessedMs).abs() >= 40) {
        _isProcessingFrame = true;
        lastProcessedMs = currentMs;

        try {
          final bytes = await _getVideoFrame(widget.videoFile.path, currentMs);
          if (bytes != null && bytes.isNotEmpty && mounted && _isLoopActive) {
            final result = await OnDeviceDetector().detectFromBytes(
              bytes,
              conf: 0.25,
              iouThresh: 0.45,
              isCameraFrame: false,
            );

            if (mounted && result != null && _isLoopActive) {
              final tracked = _tracker.update(result.detections);

              // Update CCTV Analytics
              _livePeopleCount = result.effectivePeopleCount;
              if (_livePeopleCount > _peakPeopleCount) {
                _peakPeopleCount = _livePeopleCount;
              }
              for (final d in tracked) {
                if (d.trackId != null) {
                  _uniqueTrackedSet.add(d.trackId!);
                }
              }
              _uniqueTrackedCount =
                  max(_uniqueTrackedCount, _uniqueTrackedSet.length);

              int violations = 0;
              for (final d in tracked) {
                final lower = d.className
                    .toLowerCase()
                    .replaceAll("-", "_")
                    .replaceAll(" ", "_");
                if (lower.startsWith("no_") ||
                    lower.contains("no_") ||
                    lower.contains("violation")) {
                  violations++;
                }
              }
              _activeViolationsCount = violations;

              setState(() {
                _currentDetections = tracked;
                _frameWidth = result.imageWidth ?? controller.value.size.width;
                _frameHeight =
                    result.imageHeight ?? controller.value.size.height;
              });
            }
          }
        } catch (e) {
          debugPrint("[CctvVideoPlayer] Frame error: $e");
        } finally {
          _isProcessingFrame = false;
        }
      }

      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _isLoopActive = false;
    _controller?.dispose();
    try {
      _videoFrameChannel.invokeMethod('releaseRetriever');
    } catch (_) {}
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Top-Left CCTV HUD Overlay Card (Matches Reference Image)
  // ---------------------------------------------------------------------------
  Widget _buildCctvHudCard() {
    final bool isCompliant = _activeViolationsCount == 0;
    final Color statusColor =
        isCompliant ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: statusColor,
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.25),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "SAFESITE CCTV | REAL-TIME VISION",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "LIVE PEOPLE: $_livePeopleCount",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "PEAK: $_peakPeopleCount | UNIQUE TRACKED: $_uniqueTrackedCount",
                style: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "COMPLIANCE: ",
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    isCompliant ? "SAFE" : "UNSAFE",
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom Video Player Controls Bar (Matches Reference Image)
  // ---------------------------------------------------------------------------
  Widget _buildBottomVideoControls() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final position = controller.value.position;
    final duration = controller.value.duration;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Play / Pause Button
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: _togglePlayPause,
            ),
            const SizedBox(width: 8),

            // Time Display: "0:00 / 0:10"
            Text(
              "${_formatDuration(position)} / ${_formatDuration(duration)}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 14),

            // Video Timeline Scrubber
            Expanded(
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                colors: const VideoProgressColors(
                  playedColor: Color(0xFF00E5FF),
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Model Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                OnDeviceDetector().currentModelId,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Surface (Center / AspectRatio)
          if (_isInitialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00E5FF),
                strokeWidth: 2.5,
              ),
            ),

          // 2. Real-Time Bounding Box & Label Overlay
          if (_isInitialized && _controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: CustomPaint(
                  painter: _CctvBoundingBoxPainter(
                    detections: _currentDetections,
                    imageWidth: _frameWidth,
                    imageHeight: _frameHeight,
                  ),
                ),
              ),
            ),

          // 3. Top-Left CCTV HUD Box (Matches Reference Image)
          Positioned(
            top: 40,
            left: 16,
            child: _buildCctvHudCard(),
          ),

          // 4. Top-Right Close Button
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

          // 5. Bottom Interactive Video Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomVideoControls(),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// CCTV Bounding Box & Solid Label Tag Painter (Matches media_1793709267987_5a7e549c.png)
// ==============================================================================
class _CctvBoundingBoxPainter extends CustomPainter {
  final List<DetectionItem> detections;
  final double imageWidth;
  final double imageHeight;

  _CctvBoundingBoxPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  Color _getClassColor(String name) {
    final lower = name.toLowerCase().replaceAll("-", "_").replaceAll(" ", "_");

    // Violations
    if (lower.contains("no_hardhat") || lower.contains("violation")) {
      return const Color(0xFFEF4444); // Alert Red (Matches #14 in screenshot)
    }
    if (lower.contains("no_vest") || lower.contains("no_safety_vest")) {
      return const Color(0xFFF97316); // Alert Orange (Matches #10 in screenshot)
    }
    if (lower.contains("no_mask")) {
      return const Color(0xFFEA580C); // Safety Orange (Matches #25 in screenshot)
    }
    if (lower.startsWith("no_") || lower.contains("no_")) {
      return const Color(0xFFEF4444);
    }

    // Compliant PPE & Equipment
    if (lower.contains("hardhat") || lower.contains("helmet")) {
      return const Color(0xFFA855F7); // Purple (Matches #27 Hardhat in screenshot)
    }
    if (lower.contains("vest")) {
      return const Color(0xFF22C55E); // Green (Matches #7 Safety Vest in screenshot)
    }
    if (lower.contains("mask")) {
      return const Color(0xFF06B6D4);
    }
    if (lower.contains("cone")) {
      return const Color(0xFFF59E0B);
    }

    // Personnel
    if (lower.contains("person") || lower.contains("worker")) {
      return const Color(0xFFEAB308); // Yellow (Matches #5 Person in screenshot)
    }

    // Machinery & Vehicles
    if (lower.contains("machinery") ||
        lower.contains("crane") ||
        lower.contains("truck") ||
        lower.contains("vehicle")) {
      return const Color(0xFF38BDF8);
    }

    return const Color(0xFF818CF8);
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

      final lowerName = item.className.toLowerCase().replaceAll("-", "_");
      final isViolation = lowerName.startsWith("no_") ||
          lowerName.contains("no_") ||
          lowerName.contains("violation");

      // 1. Draw Bounding Rectangle
      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isViolation ? 2.6 : 1.8;

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rrect, boxPaint);

      // Subtle fill highlight for violations
      if (isViolation) {
        final alertFill = Paint()
          ..color = color.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(rrect, alertFill);
      }

      // 2. Draw Solid Label Chip with Track ID: e.g. "#10 NO-Safety Vest 75%"
      final confPercent = (item.confidence * 100).toInt();
      final labelPrefix = isViolation ? "⚠️ " : "";
      final trackPrefix = item.trackId != null ? "#${item.trackId} " : "";
      final labelText =
          "$labelPrefix$trackPrefix${item.className} $confPercent%";

      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
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
      final double chipLeft = x1.clamp(0.0, max(0.0, size.width - chipWidth));

      final chipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(chipLeft, chipTop, chipWidth, chipHeight),
        const Radius.circular(3),
      );
      final chipPaint = Paint()..color = color;

      canvas.drawRRect(chipRect, chipPaint);
      textPainter.paint(
        canvas,
        Offset(chipLeft + 5, chipTop + (chipHeight - textPainter.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CctvBoundingBoxPainter oldDelegate) => true;
}
