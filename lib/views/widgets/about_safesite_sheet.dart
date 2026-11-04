import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/model_manager_provider.dart';

/// Full-height "About SafeSite AI" Bottom Sheet matching Image 2
class AboutSafeSiteSheet extends ConsumerWidget {
  const AboutSafeSiteSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111116),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const AboutSafeSiteSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(modelManagerProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111116), // Dark background matching Image 2
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Top Drag Handle & Close Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 22,
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

              // Scrollable Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  children: [
                    // Brand Hero Tile (Matching Image 2 top tile)
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
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
                      "Run real-time PPE object detection (Hardhat, Mask, Safety Vest, Machinery, Persons) "
                      "directly on your mobile device with zero cloud dependency and complete privacy.",
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 2: YOLO Models
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
                    Text(
                      "Active Model: ${modelState.activeModel.displayName} (640x640 resolution).\n"
                      "Compare nano models bundled with the app and switch dynamically on-device.",
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Section 3: Continue Learning
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

                    // Link 1: Docs
                    _buildLearnTile(
                      icon: Icons.menu_book_rounded,
                      title: "SafeSite AI Docs",
                      description:
                          "Training, prediction, export, and deployment guides.",
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("SafeSite AI Docs & Guidelines"),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),

                    // Link 2: YOLO Models
                    _buildLearnTile(
                      icon: Icons.view_in_ar_rounded,
                      title: "YOLO Models",
                      description:
                          "Explore YOLOv8, YOLO11, and YOLO26 tasks, sizes, and performance.",
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Models: YOLOv8n (Fast), YOLO11n (Accurate), YOLO26n (Ultra-Efficient).",
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),

                    // Link 3: GitHub
                    _buildLearnTile(
                      icon: Icons.code_rounded,
                      title: "GitHub",
                      description:
                          "Source code, releases, and open-source tools.",
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("SafeSite AI Open Source Repository"),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),

                    // Link 4: Licensing
                    _buildLearnTile(
                      icon: Icons.description_rounded,
                      title: "Licensing",
                      description:
                          "100% on-device private processing. AGPL-3.0 and Enterprise License options.",
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "SafeSite AI: 100% On-Device edge intelligence. No camera streams uploaded.",
                            ),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: const Color(0xFF38BDF8), // Blue icon matching Image 2
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
                      color: Color(0xFF38BDF8), // Blue title matching Image 2
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
