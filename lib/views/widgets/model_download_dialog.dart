import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/model_manager_provider.dart';

/// Centered download progress modal overlay matching Image 1
class ModelDownloadDialog extends ConsumerWidget {
  const ModelDownloadDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(modelManagerProvider);
    final downloadingId = modelState.downloadingModelId;

    if (downloadingId == null) {
      return const SizedBox.shrink();
    }

    final variant = modelState.models.firstWhere(
      (m) => m.id == downloadingId,
      orElse: () => modelState.activeModel,
    );

    final progress = modelState.getProgress(downloadingId);
    final percent = (progress * 100).clamp(0, 100).toInt();

    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.82,
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Purple Rounded Linear Progress Bar on Top
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 5,
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFA855F7), // Purple / Lavender
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Title: "Downloading YOLO11n Detect"
              Text(
                "Downloading ${variant.displayName} Detect",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),

              // 3. Large Download Percentage
              Text(
                "$percent%",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),

              // 4. Subtitle: "Downloading model weights"
              const Text(
                "Downloading model weights",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),

              // 5. Lavender "Cancel" Button
              GestureDetector(
                onTap: () {
                  ref.read(modelManagerProvider.notifier).cancelDownload();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Color(0xFFC084FC), // Lavender accent
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
