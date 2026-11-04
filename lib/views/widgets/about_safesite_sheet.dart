import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/model_manager_provider.dart';

/// Fullscreen "About SafeSite AI" Screen matching the official Ultralytics YOLO About Screen
class AboutSafeSiteScreen extends ConsumerWidget {
  const AboutSafeSiteScreen({super.key});

  /// Pushes this screen as a clean fullscreen view
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AboutSafeSiteScreen(),
      ),
    );
  }

  Future<void> _launchExternalUrl(BuildContext context, String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Opened: $urlString"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Opening: $urlString"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(modelManagerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF111116), // Exact dark OLED background
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Fullscreen App Bar with Close [X] Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "About SafeSite AI",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // 2. Scrollable Content (100% Fullscreen, Edge-to-Edge)
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                children: [
                  // Hero Brand Header Tile
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.center_focus_strong_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SafeSite AI Vision",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Real-time AI vision on-device",
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  // Section 1: The App
                  const Text(
                    "The App",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Try detection, segmentation, classification, pose estimation, "
                    "and oriented bounding box models directly on-device with zero cloud latency.",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section 2: YOLO Models (Dynamic List)
                  const Text(
                    "YOLO Models",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Compare nano models bundled with the app and larger official models downloaded when selected.",
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Dynamic Model Selector Cards (Interactive Switcher)
                  ...modelState.models.map((variant) {
                    final isActive = modelState.activeModel.id == variant.id;
                    final isReady = modelState.isModelReady(variant.id);
                    final isDownloading =
                        modelState.isModelDownloading(variant.id);
                    final progress = modelState.getProgress(variant.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF00E5FF).withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.1),
                          width: isActive ? 1.2 : 0.8,
                        ),
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          ref
                              .read(modelManagerProvider.notifier)
                              .selectModel(variant);
                        },
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: isActive
                                  ? const Color(0xFF00E5FF)
                                  : Colors.white38,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        variant.displayName,
                                        style: TextStyle(
                                          color: isActive
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isActive) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981)
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFF10B981),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: const Text(
                                            "ACTIVE",
                                            style: TextStyle(
                                              color: Color(0xFF10B981),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${variant.fileName} · ${variant.inputSize}x${variant.inputSize} ONNX",
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (isDownloading) ...[
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: progress > 0 ? progress : null,
                                        backgroundColor: Colors.white12,
                                        color: const Color(0xFF00E5FF),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!isActive && !isReady && !isDownloading)
                              const Icon(
                                Icons.file_download_outlined,
                                color: Colors.white54,
                                size: 20,
                              )
                            else if (!isActive && isReady)
                              const Text(
                                "SWITCH",
                                style: TextStyle(
                                  color: Color(0xFF00B0FF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // Real-time On-Device Engine Diagnostics Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.memory_rounded,
                              color: Color(0xFF00E5FF),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "ON-DEVICE ACCELERATION",
                              style: TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildEngineMetricRow(
                          "Runtime Engine",
                          "ONNX Runtime Mobile (v1.4.1)",
                        ),
                        const SizedBox(height: 6),
                        _buildEngineMetricRow(
                          "Execution Mode",
                          "Local CPU / NPU (100% Private)",
                        ),
                        const SizedBox(height: 6),
                        _buildEngineMetricRow(
                          "Active Resolution",
                          "${modelState.activeModel.inputSize} x ${modelState.activeModel.inputSize} RGB",
                        ),
                        const SizedBox(height: 6),
                        _buildEngineMetricRow(
                          "Model Weights",
                          modelState.activeModel.fileName,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Section 3: Continue Learning (Live External Links)
                  const Text(
                    "Continue Learning",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Link 1: Ultralytics / SafeSite Docs
                  _buildLearnTile(
                    icon: Icons.menu_book_rounded,
                    title: "Ultralytics Docs",
                    description:
                        "Training, prediction, export, and deployment guides.",
                    onTap: () => _launchExternalUrl(
                      context,
                      "https://docs.ultralytics.com",
                    ),
                  ),

                  // Link 2: YOLO Models
                  _buildLearnTile(
                    icon: Icons.view_in_ar_rounded,
                    title: "YOLO Models",
                    description:
                        "Explore YOLOv8, YOLO11, and YOLO26 tasks, sizes, and performance.",
                    onTap: () => _launchExternalUrl(
                      context,
                      "https://docs.ultralytics.com/models/",
                    ),
                  ),

                  // Link 3: GitHub
                  _buildLearnTile(
                    icon: Icons.code_rounded,
                    title: "GitHub",
                    description:
                        "Source code, releases, and open-source tools.",
                    onTap: () => _launchExternalUrl(
                      context,
                      "https://github.com/shivamkoffeekodes9084/safesite_ai_app",
                    ),
                  ),

                  // Link 4: Licensing
                  _buildLearnTile(
                    icon: Icons.description_rounded,
                    title: "Licensing",
                    description:
                        "AGPL-3.0 and Enterprise License options for on-device AI.",
                    onTap: () => _launchExternalUrl(
                      context,
                      "https://github.com/shivamkoffeekodes9084/safesite_ai_app/blob/main/README.md",
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLearnTile({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: const Color(0xFF38BDF8), // Blue icon matching Ultralytics
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8), // Blue title matching Ultralytics
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new_rounded,
              color: Colors.white38,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

/// Backwards compatibility typedef so existing calls continue to work seamlessly
typedef AboutSafeSiteSheet = AboutSafeSiteScreen;
