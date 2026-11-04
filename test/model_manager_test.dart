import 'package:flutter_test/flutter_test.dart';
import 'package:safesite_ai/services/model_manager_service.dart';
import 'package:safesite_ai/providers/model_manager_provider.dart';

void main() {
  group('Model Variant & Manager Tests', () {
    test('ModelVariant list defines YOLOv8n, YOLO11n, and YOLO26n', () {
      final models = ModelVariant.models;
      expect(models.length, equals(3));

      expect(models[0].id, equals('yolov8n'));
      expect(models[0].displayName, equals('YOLOv8n'));
      expect(models[0].fileName, equals('yolov8n.onnx'));
      expect(models[0].assetPath, equals('assets/models/yolov8n.onnx'));
      expect(models[0].inputSize, equals(640));

      expect(models[1].id, equals('yolo11n'));
      expect(models[1].displayName, equals('YOLO11n'));
      expect(models[1].fileName, equals('yolo11n.onnx'));
      expect(models[1].assetPath, equals('assets/models/yolo11n.onnx'));
      expect(models[1].inputSize, equals(640));

      expect(models[2].id, equals('yolo26n'));
      expect(models[2].displayName, equals('YOLO26n'));
      expect(models[2].fileName, equals('yolo26n.onnx'));
      expect(models[2].assetPath, equals('assets/models/yolo26n.onnx'));
      expect(models[2].inputSize, equals(640));
    });

    test('ModelManagerState correctly reports readiness and progress', () {
      final state = ModelManagerState(
        models: ModelVariant.models,
        activeModel: ModelVariant.models[0],
        isDownloaded: {
          'yolov8n': true,
          'yolo11n': false,
          'yolo26n': false,
        },
        downloadProgress: {
          'yolo11n': 0.45,
        },
        downloadingModelId: 'yolo11n',
      );

      expect(state.isModelReady('yolov8n'), isTrue);
      expect(state.isModelReady('yolo11n'), isFalse);
      expect(state.isModelDownloading('yolo11n'), isTrue);
      expect(state.getProgress('yolo11n'), equals(0.45));
    });
  });
}
