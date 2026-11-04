import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Represents an ONNX model variant for PPE detection
class ModelVariant {
  final String id;
  final String displayName;
  final String fileName;
  final String assetPath;
  final String? remoteUrl;
  final int inputSize;
  final String? localFallbackPath;

  const ModelVariant({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.assetPath,
    this.remoteUrl,
    this.inputSize = 640,
    this.localFallbackPath,
  });

  static const List<ModelVariant> models = [
    ModelVariant(
      id: 'yolov8n',
      displayName: 'YOLOv8n',
      fileName: 'yolov8n.onnx',
      assetPath: 'assets/models/yolov8n.onnx',
      remoteUrl:
          'https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.onnx',
      inputSize: 640,
      localFallbackPath:
          r'c:\Users\Hello\Downloads\ppe_models_onnx\yolov8n\weights\best.onnx',
    ),
    ModelVariant(
      id: 'yolo11n',
      displayName: 'YOLO11n',
      fileName: 'yolo11n.onnx',
      assetPath: 'assets/models/yolo11n.onnx',
      remoteUrl:
          'https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.onnx',
      inputSize: 640,
      localFallbackPath:
          r'c:\Users\Hello\Downloads\ppe_models_onnx\yolo11n\weights\best.onnx',
    ),
    ModelVariant(
      id: 'yolo26n',
      displayName: 'YOLO26n',
      fileName: 'yolo26n.onnx',
      assetPath: 'assets/models/yolo26n.onnx',
      remoteUrl:
          'https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.onnx',
      inputSize: 640,
      localFallbackPath:
          r'c:\Users\Hello\Downloads\ppe_models_onnx\yolo26n\weights\best.onnx',
    ),
  ];
}

/// Service managing on-device ONNX model files in internal document storage
class ModelManagerService {
  final Dio _dio;

  ModelManagerService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 60),
              ),
            );

  /// Gets the internal storage directory for PPE models
  Future<Directory> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/ppe_models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// Gets the local File destination for a model variant
  Future<File> getModelFile(ModelVariant variant) async {
    final dir = await getModelsDirectory();
    return File('${dir.path}/${variant.fileName}');
  }

  /// Checks if the model variant ONNX file is present in internal document storage
  Future<bool> isModelAvailable(ModelVariant variant) async {
    final file = await getModelFile(variant);
    if (!await file.exists()) return false;

    // For YOLOv8n, ensure it matches latest 640x640 asset size if bundled
    if (variant.id == 'yolov8n') {
      try {
        final byteData = await rootBundle.load(variant.assetPath);
        if (await file.length() != byteData.lengthInBytes) {
          return false;
        }
      } catch (_) {}
    }

    return await file.length() > 500 * 1024;
  }

  /// Ensures default YOLOv8n model is seeded into app's documents directory
  Future<void> ensureDefaultModelReady() async {
    final defaultVariant = ModelVariant.models[0]; // YOLOv8n
    final file = await getModelFile(defaultVariant);

    try {
      ByteData byteData;
      try {
        byteData = await rootBundle.load(defaultVariant.assetPath);
      } catch (_) {
        byteData = await rootBundle.load('assets/models/best.onnx');
      }
      final assetBytes = byteData.buffer.asUint8List();
      final expectedLength = assetBytes.length;

      // Overwrite if missing OR if file size does not match the latest 640x640 model (12,782,067 bytes)
      if (!await file.exists() || await file.length() != expectedLength) {
        debugPrint(
          "[ModelManager] Seeding/Updating ${defaultVariant.displayName} ($expectedLength bytes)...",
        );
        await file.writeAsBytes(assetBytes, flush: true);
        debugPrint(
            "[ModelManager] Default ${defaultVariant.displayName} model ready.");
      }
    } catch (e) {
      debugPrint("[ModelManager] Error copying initial bundled asset: $e");
      if (defaultVariant.localFallbackPath != null &&
          File(defaultVariant.localFallbackPath!).existsSync()) {
        try {
          await File(defaultVariant.localFallbackPath!).copy(file.path);
        } catch (_) {}
      }
    }
  }

  /// Downloads model via remote URL (Dio) with progress, falling back gracefully to bundled assets
  Future<bool> downloadModel(
    ModelVariant variant, {
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final targetFile = await getModelFile(variant);
    final tempFile = File('${targetFile.path}.tmp');

    // Clean previous partial download
    if (await tempFile.exists()) {
      try {
        await tempFile.delete();
      } catch (_) {}
    }

    bool downloaded = false;

    // 1. Remote HTTP/HTTPS Download via Dio
    if (variant.remoteUrl != null &&
        (cancelToken == null || !cancelToken.isCancelled)) {
      try {
        debugPrint(
            "[ModelManager] Attempting remote download from: ${variant.remoteUrl}");
        final response = await _dio.download(
          variant.remoteUrl!,
          tempFile.path,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              final ratio = (received / total).clamp(0.0, 1.0);
              onProgress(ratio);
            }
          },
        );

        if (response.statusCode == 200 &&
            await tempFile.exists() &&
            await tempFile.length() > 500 * 1024) {
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          await tempFile.rename(targetFile.path);
          downloaded = true;
          onProgress(1.0);
          debugPrint(
              "[ModelManager] Remote download succeeded for ${variant.displayName}");
          return true;
        }
      } catch (e) {
        debugPrint(
            "[ModelManager] Remote download attempt failed or offline: $e");
        if (cancelToken?.isCancelled == true) {
          if (await tempFile.exists()) await tempFile.delete();
          return false;
        }
      }
    }

    // 2. Bundled Asset Installation Fallback (Guarantees zero-network reliability)
    if (!downloaded && (cancelToken == null || !cancelToken.isCancelled)) {
      try {
        debugPrint(
            "[ModelManager] Extracting bundled asset: ${variant.displayName} (${variant.assetPath})");
        ByteData byteData;
        try {
          byteData = await rootBundle.load(variant.assetPath);
        } catch (_) {
          byteData = await rootBundle.load('assets/models/best.onnx');
        }
        final bytes = byteData.buffer.asUint8List();
        final totalBytes = bytes.length;

        final sink = tempFile.openWrite();
        const chunkSize = 256 * 1024; // 256 KB per chunk
        int written = 0;

        for (int i = 0; i < totalBytes; i += chunkSize) {
          if (cancelToken?.isCancelled == true) {
            await sink.close();
            if (await tempFile.exists()) await tempFile.delete();
            return false;
          }
          final end = (i + chunkSize < totalBytes) ? i + chunkSize : totalBytes;
          sink.add(bytes.sublist(i, end));
          written = end;

          onProgress((written / totalBytes).clamp(0.0, 1.0));
          await Future.delayed(const Duration(milliseconds: 20));
        }

        await sink.flush();
        await sink.close();

        if (await tempFile.exists() && await tempFile.length() > 500 * 1024) {
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          await tempFile.rename(targetFile.path);
          downloaded = true;
          onProgress(1.0);
          debugPrint(
              "[ModelManager] Asset installation complete for ${variant.displayName}");
          return true;
        }
      } catch (e) {
        debugPrint("[ModelManager] Asset installation error: $e");
      }
    }

    // 3. Host filesystem fallback (for desktop test suite or local dev)
    if (!downloaded &&
        (cancelToken == null || !cancelToken.isCancelled) &&
        variant.localFallbackPath != null &&
        File(variant.localFallbackPath!).existsSync()) {
      try {
        debugPrint(
            "[ModelManager] Copying from host path: ${variant.localFallbackPath}");
        for (int i = 1; i <= 5; i++) {
          if (cancelToken?.isCancelled == true) return false;
          await Future.delayed(const Duration(milliseconds: 30));
          onProgress(i * 0.2);
        }
        await File(variant.localFallbackPath!).copy(targetFile.path);
        downloaded = true;
        onProgress(1.0);
        return true;
      } catch (_) {}
    }

    return downloaded;
  }
}
