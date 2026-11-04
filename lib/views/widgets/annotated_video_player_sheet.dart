import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:safesite_ai/model/safety_response_model.dart';

class AnnotatedVideoPlayerSheet extends StatefulWidget {
  final SafetyResponseModel result;
  final String backendBaseUrl;

  const AnnotatedVideoPlayerSheet({
    super.key,
    required this.result,
    required this.backendBaseUrl,
  });

  /// Helper to show this bottom sheet cleanly anywhere in the app
  static Future<void> show(
    BuildContext context, {
    required SafetyResponseModel result,
    required String backendBaseUrl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1120),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AnnotatedVideoPlayerSheet(
        result: result,
        backendBaseUrl: backendBaseUrl,
      ),
    );
  }

  @override
  State<AnnotatedVideoPlayerSheet> createState() =>
      _AnnotatedVideoPlayerSheetState();
}

class _AnnotatedVideoPlayerSheetState extends State<AnnotatedVideoPlayerSheet> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    final videoUrl =
        widget.result.getFullAnnotatedVideoUrl(widget.backendBaseUrl);

    if (videoUrl == null || videoUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = "No annotated video stream returned by backend.";
      });
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      controller.addListener(() {
        if (mounted) {
          setState(() {
            _isPlaying = controller.value.isPlaying;
          });
        }
      });

      if (mounted) {
        setState(() {
          _controller = controller;
          _isLoading = false;
          _isPlaying = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load video stream: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatViolationName(String raw) {
    final clean = raw.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (clean.toLowerCase().startsWith('no ')) {
      return "Missing ${clean.substring(3).trim()}";
    }
    return clean;
  }

  String _getViolationDescription(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('vest')) {
      return "Personnel observed working without high-visibility safety vest.";
    } else if (lower.contains('hardhat') || lower.contains('helmet')) {
      return "Worker exposed to head hazard without approved hardhat.";
    } else if (lower.contains('mask')) {
      return "Missing respiratory protective face mask or covering.";
    } else if (lower.contains('glove')) {
      return "Hand protection not detected during hazardous task.";
    } else if (lower.contains('boot')) {
      return "Foot protection / steel-toe boots not verified.";
    }
    return "Mandatory PPE gear not detected in active workspace.";
  }

  @override
  Widget build(BuildContext context) {
    final compliance = widget.result.compliance;

    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.50,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B1120),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            children: [
              // 1. Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Sheet Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          Icons.videocam_rounded,
                          color: Color(0xFF00E5FF),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AI VIDEO AUDIT REPORT",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            "YOLOv8 + ByteTrack Personnel Tracking",
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Annotated Video Player Container
              _buildVideoPlayerSection(),
              const SizedBox(height: 18),

              // 4. Hero Safety Status Banner
              _buildHeroComplianceBanner(compliance),
              const SizedBox(height: 16),

              // 5. 2x2 Key Metrics Summary Grid (Completely overflow-safe)
              _buildMetricsGrid(compliance),
              const SizedBox(height: 22),

              // 6. Active Violations Alert Cards (if any)
              if (compliance.activeViolations.isNotEmpty) ...[
                _buildActiveViolationsSection(compliance),
                const SizedBox(height: 22),
              ],

              // 7. Summary Counts Breakdown
              _buildObjectsBreakdownSection(),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Video Player Container with Glassmorphic Controls
  // ---------------------------------------------------------------------------
  Widget _buildVideoPlayerSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: _controller?.value.aspectRatio ?? (16 / 9),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              VideoPlayer(_controller!)
            else if (_isLoading)
              const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFEA580C),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Streaming annotated video from AI backend...",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage ?? "Unable to stream video.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFEF4444)),
                ),
              ),

            // Controls Overlay
            if (_controller != null && _controller!.value.isInitialized)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_controller!.value.isPlaying) {
                        _controller!.pause();
                      } else {
                        _controller!.play();
                      }
                    });
                  },
                  child: Container(
                    color: Colors.transparent,
                    child: Stack(
                      children: [
                        // Play Center Button when paused
                        if (!_isPlaying)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                          ),

                        // Bottom Player Bar
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_isPlaying) {
                                        _controller!.pause();
                                      } else {
                                        _controller!.play();
                                      }
                                    });
                                  },
                                  child: Icon(
                                    _isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: VideoProgressIndicator(
                                    _controller!,
                                    allowScrubbing: true,
                                    colors: const VideoProgressColors(
                                      playedColor: Color(0xFFEA580C),
                                      bufferedColor: Colors.white24,
                                      backgroundColor: Colors.white10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "${_formatDuration(_controller!.value.position)} / ${_formatDuration(_controller!.value.duration)}",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero Compliance Status Banner with Circular Radial Gauge
  // ---------------------------------------------------------------------------
  Widget _buildHeroComplianceBanner(ComplianceModel compliance) {
    final bool isCompliant = compliance.isCompliant;
    final int violationCount = compliance.totalViolations;

    final Color statusColor;
    final String statusTitle;
    final String statusSubtitle;
    final String statusBadge;
    final List<Color> gradientColors;

    if (isCompliant) {
      statusColor = const Color(0xFF10B981);
      statusTitle = "PPE SAFETY COMPLIANT";
      statusSubtitle = "All personnel verified wearing required safety gear.";
      statusBadge = "SITE SECURE";
      gradientColors = const [Color(0xFF0A2617), Color(0xFF091811)];
    } else if (violationCount <= 2) {
      statusColor = const Color(0xFFF59E0B);
      statusTitle = "SAFETY WARNING";
      statusSubtitle = "$violationCount minor safety violation(s) flagged on site.";
      statusBadge = "WARNING";
      gradientColors = const [Color(0xFF28190B), Color(0xFF191209)];
    } else {
      statusColor = const Color(0xFFEF4444);
      statusTitle = "SAFETY VIOLATIONS DETECTED";
      statusSubtitle = "$violationCount safety infractions identified across video.";
      statusBadge = "VIOLATION";
      gradientColors = const [Color(0xFF2C1014), Color(0xFF190C0E)];
    }

    final double score = compliance.complianceScorePercent.clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Icon with soft glowing circle
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompliant
                  ? Icons.verified_user_rounded
                  : Icons.warning_amber_rounded,
              color: statusColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),

          // Center Status Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusBadge,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  statusTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Right Radial Progress Gauge (e.g. 58%)
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 4.5,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                CircularProgressIndicator(
                  value: score / 100.0,
                  strokeWidth: 4.5,
                  color: statusColor,
                  strokeCap: StrokeCap.round,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${score.toStringAsFixed(0)}%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const Text(
                      "SCORE",
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2x2 Key Metrics Summary Grid (Fully Responsive, Zero Overflow)
  // ---------------------------------------------------------------------------
  Widget _buildMetricsGrid(ComplianceModel compliance) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.people_alt_rounded,
                label: "PEOPLE TRACKED",
                value: "${widget.result.effectivePeopleCount}",
                accentColor: const Color(0xFF00E5FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.layers_rounded,
                label: "FRAMES AUDITED",
                value: "${widget.result.totalFramesProcessed}",
                accentColor: const Color(0xFFA855F7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.shield_rounded,
                label: "SAFE ITEMS",
                value: "${compliance.totalSafeItems}",
                accentColor: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.gpp_bad_rounded,
                label: "VIOLATIONS",
                value: "${compliance.totalViolations}",
                accentColor: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Active Violations Alert Section
  // ---------------------------------------------------------------------------
  Widget _buildActiveViolationsSection(ComplianceModel compliance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.gpp_maybe_rounded,
              color: Color(0xFFEF4444),
              size: 16,
            ),
            const SizedBox(width: 6),
            const Text(
              "CRITICAL VIOLATIONS ALERT",
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                "${compliance.activeViolations.length} TYPES",
                style: const TextStyle(
                  color: Color(0xFFFCA5A5),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...compliance.activeViolations.entries.map((violation) {
          final count = violation.value;
          final title = _formatViolationName(violation.key);
          final desc = _getViolationDescription(violation.key);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF171116),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.30),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xFFEF4444), width: 3.5),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFEF4444),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            desc,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10.5,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        "$count FLAGGED",
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Objects Inventory & Breakdown Section
  // ---------------------------------------------------------------------------
  Widget _buildObjectsBreakdownSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.category_rounded,
              color: Color(0xFF94A3B8),
              size: 15,
            ),
            const SizedBox(width: 6),
            const Text(
              "DETECTED OBJECTS BREAKDOWN",
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            const Spacer(),
            Text(
              "${widget.result.summaryCounts.length} classes detected",
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (widget.result.summaryCounts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                "No target objects detected in video stream.",
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.result.summaryCounts.entries.map((entry) {
              final lower = entry.key.toLowerCase();
              final isViolation =
                  lower.contains('no-') || lower.contains('no_') || lower.contains('violation');
              final isPerson = lower == 'person';

              final Color chipColor;
              final IconData chipIcon;

              if (isViolation) {
                chipColor = const Color(0xFFEF4444);
                chipIcon = Icons.cancel_outlined;
              } else if (isPerson) {
                chipColor = const Color(0xFF00E5FF);
                chipIcon = Icons.person_rounded;
              } else {
                chipColor = const Color(0xFF10B981);
                chipIcon = Icons.check_circle_outline_rounded;
              }

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: chipColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chipIcon, size: 14, color: chipColor),
                    const SizedBox(width: 5),
                    Text(
                      entry.key,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        "${entry.value}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
