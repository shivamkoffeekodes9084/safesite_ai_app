import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/model_manager_service.dart';
import '../services/on_device_detector.dart';

class ModelManagerState {
  final List<ModelVariant> models;
  final ModelVariant activeModel;
  final Map<String, bool> isDownloaded;
  final Map<String, double> downloadProgress;
  final String? downloadingModelId;
  final bool isSwitching;
  final String? errorMessage;

  const ModelManagerState({
    required this.models,
    required this.activeModel,
    required this.isDownloaded,
    required this.downloadProgress,
    this.downloadingModelId,
    this.isSwitching = false,
    this.errorMessage,
  });

  bool isModelReady(String id) => isDownloaded[id] ?? false;
  double getProgress(String id) => downloadProgress[id] ?? 0.0;
  bool isModelDownloading(String id) => downloadingModelId == id;

  ModelManagerState copyWith({
    List<ModelVariant>? models,
    ModelVariant? activeModel,
    Map<String, bool>? isDownloaded,
    Map<String, double>? downloadProgress,
    String? downloadingModelId,
    bool clearDownloading = false,
    bool? isSwitching,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ModelManagerState(
      models: models ?? this.models,
      activeModel: activeModel ?? this.activeModel,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadingModelId: clearDownloading
          ? null
          : (downloadingModelId ?? this.downloadingModelId),
      isSwitching: isSwitching ?? this.isSwitching,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ModelManagerNotifier extends StateNotifier<ModelManagerState> {
  final ModelManagerService _service;
  CancelToken? _cancelToken;

  ModelManagerNotifier(this._service)
      : super(
          ModelManagerState(
            models: ModelVariant.models,
            activeModel: ModelVariant.models[0],
            isDownloaded: {
              for (final m in ModelVariant.models) m.id: false,
            },
            downloadProgress: {
              for (final m in ModelVariant.models) m.id: 0.0,
            },
          ),
        ) {
    init();
  }

  /// Cancel any active in-flight model download
  void cancelDownload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel("User cancelled download");
      _cancelToken = null;
    }
    state = state.copyWith(clearDownloading: true);
  }

  /// Initialize model manager and synchronize local storage status
  Future<void> init() async {
    try {
      await _service.ensureDefaultModelReady();

      final statusMap = <String, bool>{};
      for (final m in state.models) {
        statusMap[m.id] = await _service.isModelAvailable(m);
      }

      state = state.copyWith(isDownloaded: statusMap);

      // Initialize OnDeviceDetector with default model if present
      final defaultFile = await _service.getModelFile(state.activeModel);
      if (await defaultFile.exists()) {
        await OnDeviceDetector().switchModel(
          modelId: state.activeModel.displayName,
          filePath: defaultFile.path,
          inputSize: state.activeModel.inputSize,
        );
      }
    } catch (e) {
      debugPrint("[ModelManager] Initialization error: $e");
    }
  }

  /// Selects and switches active model. If not downloaded yet, triggers installation from bundled assets.
  Future<bool> selectModel(ModelVariant variant) async {
    // Prevent starting concurrent downloads
    if (state.downloadingModelId != null &&
        state.downloadingModelId != variant.id) {
      return false;
    }

    // Already active and ready
    if (state.activeModel.id == variant.id && state.isModelReady(variant.id)) {
      return true;
    }

    // 1. If model is already downloaded locally, switch inference session directly
    if (state.isModelReady(variant.id)) {
      state = state.copyWith(isSwitching: true, clearError: true);
      final modelFile = await _service.getModelFile(variant);
      final success = await OnDeviceDetector().switchModel(
        modelId: variant.displayName,
        filePath: modelFile.path,
        inputSize: variant.inputSize,
      );
      state = state.copyWith(
        activeModel: variant,
        isSwitching: false,
      );
      return success;
    }

    // 2. Model not downloaded: Trigger on-device model installation
    final updatedProgress = Map<String, double>.from(state.downloadProgress);
    updatedProgress[variant.id] = 0.0;

    state = state.copyWith(
      downloadingModelId: variant.id,
      downloadProgress: updatedProgress,
      clearError: true,
    );

    _cancelToken = CancelToken();

    final ok = await _service.downloadModel(
      variant,
      cancelToken: _cancelToken,
      onProgress: (progress) {
        final cur = Map<String, double>.from(state.downloadProgress);
        cur[variant.id] = progress;
        state = state.copyWith(downloadProgress: cur);
      },
    );

    if (ok) {
      final downloadedMap = Map<String, bool>.from(state.isDownloaded);
      downloadedMap[variant.id] = true;

      state = state.copyWith(
        isDownloaded: downloadedMap,
        clearDownloading: true,
        isSwitching: true,
      );

      // Once downloaded, switch model session dynamically
      final modelFile = await _service.getModelFile(variant);
      final switchOk = await OnDeviceDetector().switchModel(
        modelId: variant.displayName,
        filePath: modelFile.path,
        inputSize: variant.inputSize,
      );

      state = state.copyWith(
        activeModel: variant,
        isSwitching: false,
      );
      return switchOk;
    } else {
      state = state.copyWith(
        clearDownloading: true,
        errorMessage: "Failed to download ${variant.displayName}. Please verify connection.",
      );
      return false;
    }
  }
}

// Service & State Providers
final modelManagerServiceProvider = Provider((ref) => ModelManagerService());

final modelManagerProvider =
    StateNotifierProvider<ModelManagerNotifier, ModelManagerState>((ref) {
  final service = ref.read(modelManagerServiceProvider);
  return ModelManagerNotifier(service);
});
