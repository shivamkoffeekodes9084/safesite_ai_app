import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/model_manager_provider.dart';

/// Clean, glassmorphic horizontal model selector bar matching UI specs
class ModelSwitcherBar extends ConsumerWidget {
  const ModelSwitcherBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(modelManagerProvider);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.20),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: modelState.models.map((variant) {
                    final isSelected = modelState.activeModel.id == variant.id;
                    final isDownloaded = modelState.isModelReady(variant.id);
                    final isDownloading =
                        modelState.isModelDownloading(variant.id);
                    final progress = modelState.getProgress(variant.id);

                    return GestureDetector(
                      onTap: () async {
                        if (isDownloading) return;

                        final success = await ref
                            .read(modelManagerProvider.notifier)
                            .selectModel(variant);

                        if (!context.mounted) return;

                        final error =
                            ref.read(modelManagerProvider).errorMessage;
                        if (!success && error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: const Color(0xFFDC2626),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.28)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              variant.displayName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.bold,
                                shadows: const [
                                  Shadow(color: Colors.black54, blurRadius: 4),
                                ],
                              ),
                            ),
                            if (isDownloading) ...[
                              const SizedBox(width: 5),
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  value: progress > 0 ? progress : null,
                                  color: const Color(0xFF00E5FF),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${(progress * 100).toInt()}%",
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else if (!isDownloaded) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_downward_rounded,
                                color: Colors.white70,
                                size: 11,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (modelState.downloadingModelId != null) ...[
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: modelState
                                .getProgress(modelState.downloadingModelId!) >
                            0
                        ? modelState.getProgress(modelState.downloadingModelId!)
                        : null,
                    minHeight: 2,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00E5FF),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
