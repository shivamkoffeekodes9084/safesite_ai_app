import 'dart:io';
import 'package:safesite_ai/model/safety_response_model.dart';
import '../services/on_device_detector.dart';

/// Pure On-Device Safety Repository running ONNX models locally
class SafetyRepository {
  SafetyRepository();

  /// Real-time camera frame stream detection (100% On-Device via ONNX Runtime)
  Future<SafetyResponseModel?> detectStreamFrame(
    File frameFile, {
    double conf = 0.25,
    double iouThresh = 0.45,
    bool isCameraFrame = true,
    bool isOnDevice = true,
  }) async {
    return OnDeviceDetector().detectFromFile(
      frameFile,
      conf: conf,
      iouThresh: iouThresh,
      isCameraFrame: isCameraFrame,
    );
  }

  /// Single image detection from file (100% On-Device via ONNX Runtime)
  Future<SafetyResponseModel?> uploadAndDetectImage(
    File imageFile, {
    double conf = 0.25,
    double iouThresh = 0.45,
    bool isOnDevice = true,
  }) async {
    return OnDeviceDetector().detectFromFile(
      imageFile,
      conf: conf,
      iouThresh: iouThresh,
    );
  }
}
