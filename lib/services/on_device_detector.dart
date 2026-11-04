import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import '../model/safety_response_model.dart';

class OnDeviceDetector {
  static final OnDeviceDetector _instance = OnDeviceDetector._internal();
  factory OnDeviceDetector() => _instance;
  OnDeviceDetector._internal();

  OrtSession? _session;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isSwitchingModel = false;
  String _currentModelId = 'YOLOv8n';

  bool get isInitialized => _isInitialized;
  bool get isSwitchingModel => _isSwitchingModel;
  String get currentModelId => _currentModelId;

  int inputSize = 640;

  static const Map<int, String> defaultClassNames = {
    0: 'Hardhat',
    1: 'Mask',
    2: 'NO-Hardhat',
    3: 'NO-Mask',
    4: 'NO-Safety Vest',
    5: 'Person',
    6: 'Safety Cone',
    7: 'Safety Vest',
    8: 'machinery',
    9: 'vehicle',
  };

  Map<int, String> _classNames = Map.from(defaultClassNames);
  Map<int, String> get classNames => _classNames;

  /// Initialize ONNX Runtime environment and load model and dynamic class labels
  Future<bool> initialize({
    String? modelPath,
    int? inputSize,
    String? modelId,
  }) async {
    if (_isInitialized) return true;
    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _isInitialized;
    }

    _isInitializing = true;
    try {
      // 1. Try to load dynamic labels.json exported alongside the model
      try {
        final labelsString =
            await rootBundle.loadString('assets/models/labels.json');
        final Map<String, dynamic> jsonMap = json.decode(labelsString);
        _classNames = jsonMap.map(
          (k, v) => MapEntry(int.parse(k), v.toString()),
        );
      } catch (_) {
        _classNames = Map.from(defaultClassNames);
      }

      // 2. Initialize ONNX runtime and load session
      OrtEnv.instance.init();
      final sessionOptions = OrtSessionOptions()
        ..setInterOpNumThreads(2)
        ..setIntraOpNumThreads(2);

      if (modelPath != null && File(modelPath).existsSync()) {
        _session = OrtSession.fromFile(File(modelPath), sessionOptions);
        this.inputSize = inputSize ?? 640;
      } else {
        ByteData byteData;
        try {
          byteData = await rootBundle.load('assets/models/yolov8n.onnx');
        } catch (_) {
          byteData = await rootBundle.load('assets/models/best.onnx');
        }
        final modelBytes = byteData.buffer.asUint8List();
        _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
        this.inputSize = inputSize ?? 640;
      }

      _currentModelId = modelId ?? 'YOLOv8n';
      _isInitialized = true;
      return true;
    } catch (e) {
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Dynamically switch active ONNX model session to new file or asset
  Future<bool> switchModel({
    required String modelId,
    String? filePath,
    int inputSize = 640,
  }) async {
    _isSwitchingModel = true;
    try {
      _session?.release();
      _session = null;

      final sessionOptions = OrtSessionOptions()
        ..setInterOpNumThreads(2)
        ..setIntraOpNumThreads(2);

      if (filePath != null && File(filePath).existsSync()) {
        _session = OrtSession.fromFile(File(filePath), sessionOptions);
      } else {
        final byteData = await rootBundle.load('assets/models/best.onnx');
        _session = OrtSession.fromBuffer(
          byteData.buffer.asUint8List(),
          sessionOptions,
        );
      }

      this.inputSize = inputSize;
      _currentModelId = modelId;
      _isInitialized = true;
      return true;
    } catch (e) {
      return false;
    } finally {
      _isSwitchingModel = false;
    }
  }

  /// Runs on-device detection from a local image file
  Future<SafetyResponseModel?> detectFromFile(
    File file, {
    double conf = 0.25,
    double iouThresh = 0.45,
    bool isCameraFrame = false,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      return detectFromBytes(
        bytes,
        conf: conf,
        iouThresh: iouThresh,
        isCameraFrame: isCameraFrame,
      );
    } catch (_) {
      return null;
    }
  }

  /// Runs on-device detection from image bytes
  Future<SafetyResponseModel?> detectFromBytes(
    Uint8List bytes, {
    double conf = 0.25,
    double iouThresh = 0.45,
    bool isCameraFrame = false,
  }) async {
    if (_isSwitchingModel) return null;

    if (!_isInitialized || _session == null) {
      final ok = await initialize();
      if (!ok || _session == null) return null;
    }

    final stopwatch = Stopwatch()..start();

    // 1. Decode original image
    var originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    // Apply EXIF orientation if embedded
    originalImage = img.bakeOrientation(originalImage);

    // If mobile camera sensor captured landscape (width > height) in portrait mode,
    // rotate 90 degrees clockwise to align with upright portrait camera preview
    if (isCameraFrame && originalImage.width > originalImage.height) {
      originalImage = img.copyRotate(originalImage, angle: 90);
    }

    final origW = originalImage.width.toDouble();
    final origH = originalImage.height.toDouble();

    // 2. Preprocess with Letterboxing:
    // Scale preserving aspect ratio with gray (114, 114, 114) border padding.
    // This avoids feature stretching that degrades bounding box and class accuracy.
    final double r = min(inputSize / origW, inputSize / origH);
    final int newW = (origW * r).round();
    final int newH = (origH * r).round();
    final double padX = (inputSize - newW) / 2.0;
    final double padY = (inputSize - newH) / 2.0;

    final resized = img.copyResize(
      originalImage,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.linear,
    );

    final letterboxed = img.Image(width: inputSize, height: inputSize);
    img.fill(letterboxed, color: img.ColorRgb8(114, 114, 114));
    img.compositeImage(
      letterboxed,
      resized,
      dstX: padX.round(),
      dstY: padY.round(),
    );

    // Float32 input tensor in BCHW shape: [1, 3, inputSize, inputSize]
    final floatList = Float32List(1 * 3 * inputSize * inputSize);
    final planeSize = inputSize * inputSize;

    int pixelIndex = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = letterboxed.getPixel(x, y);
        // Normalize 0-255 to 0.0-1.0
        floatList[pixelIndex] = pixel.r / 255.0; // Channel 0 (R)
        floatList[planeSize + pixelIndex] = pixel.g / 255.0; // Channel 1 (G)
        floatList[planeSize * 2 + pixelIndex] = pixel.b / 255.0; // Channel 2 (B)
        pixelIndex++;
      }
    }

    final inputOrtValue = OrtValueTensor.createTensorWithDataList(
      floatList,
      [1, 3, inputSize, inputSize],
    );

    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;

    try {
      outputs = _session!.run(runOptions, {'images': inputOrtValue});
    } finally {
      inputOrtValue.release();
      runOptions.release();
    }

    if (outputs.isEmpty || outputs[0] == null) return null;

    final outputTensor = outputs[0] as OrtValueTensor;
    // Output shape: [1, 4 + numClasses, numPredictions]
    final dynamic rawValue = outputTensor.value;
    outputTensor.release();

    if (rawValue is! List || rawValue.isEmpty) return null;

    final List<dynamic> batch0 = rawValue[0] as List<dynamic>;
    if (batch0.length < 5) return null;

    final int numClasses = batch0.length - 4;
    final List<dynamic> cxList = batch0[0] as List<dynamic>;
    final List<dynamic> cyList = batch0[1] as List<dynamic>;
    final List<dynamic> wList = batch0[2] as List<dynamic>;
    final List<dynamic> hList = batch0[3] as List<dynamic>;
    final int numPredictions = cxList.length;

    // 3. Parse Candidate Detections
    // Each prediction anchor corresponds to ONE spatial object. We perform single-class argmax
    // across the class scores so that a person does not trigger spurious machinery/PPE duplicates.
    final List<_CandidateDetection> candidates = [];

    for (int j = 0; j < numPredictions; j++) {
      int bestClassId = -1;
      double maxScore = -1.0;

      for (int c = 0; c < numClasses; c++) {
        final score = (batch0[4 + c][j] as num).toDouble();
        if (score > maxScore) {
          maxScore = score;
          bestClassId = c;
        }
      }

      if (maxScore >= conf && bestClassId >= 0) {
        final cx = (cxList[j] as num).toDouble();
        final cy = (cyList[j] as num).toDouble();
        final bw = (wList[j] as num).toDouble();
        final bh = (hList[j] as num).toDouble();

        // Map box from letterboxed coordinates back to original image space
        final x1 = ((cx - bw / 2.0 - padX) / r).clamp(0.0, origW);
        final y1 = ((cy - bh / 2.0 - padY) / r).clamp(0.0, origH);
        final x2 = ((cx + bw / 2.0 - padX) / r).clamp(0.0, origW);
        final y2 = ((cy + bh / 2.0 - padY) / r).clamp(0.0, origH);

        // Discard degenerate or inverted boxes
        if (x2 <= x1 || y2 <= y1) continue;

        final className = _classNames[bestClassId] ?? 'Class $bestClassId';

        candidates.add(_CandidateDetection(
          classId: bestClassId,
          className: className,
          confidence: maxScore,
          box: [x1, y1, x2, y2],
        ));
      }
    }

    // 4. Apply Non-Maximum Suppression (NMS)
    final suppressed = _applyNms(candidates, iouThresh);

    stopwatch.stop();
    final inferenceMs = stopwatch.elapsedMilliseconds.toDouble();

    // 5. Build Structured Result Matching Backend API format
    final Map<String, int> summaryCounts = {};
    int peopleCount = 0;

    final List<DetectionItem> detections = [];
    for (final item in suppressed) {
      final cname = item.className;
      summaryCounts[cname] = (summaryCounts[cname] ?? 0) + 1;
      if (item.classId == 5 || cname.toLowerCase() == 'person') {
        peopleCount++;
      }
      detections.add(DetectionItem(
        classId: item.classId,
        className: cname,
        confidence: double.parse(item.confidence.toStringAsFixed(2)),
        box: item.box.map((v) => double.parse(v.toStringAsFixed(1))).toList(),
      ));
    }

    final compliance = _analyzeCompliance(summaryCounts, peopleCount);

    return SafetyResponseModel(
      status: 'success',
      totalObjectsDetected: detections.length,
      peopleCount: peopleCount,
      uniqueObjectsTracked: peopleCount,
      summaryCounts: summaryCounts,
      compliance: compliance,
      detections: detections,
      imageWidth: origW,
      imageHeight: origH,
      inferenceMs: inferenceMs,
    );
  }

  /// NMS Filter: Class-specific suppression + Cross-class heavy overlap suppression
  List<_CandidateDetection> _applyNms(
    List<_CandidateDetection> boxes,
    double iouThresh,
  ) {
    if (boxes.isEmpty) return [];
    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));
    final List<_CandidateDetection> result = [];

    for (int i = 0; i < boxes.length; i++) {
      final current = boxes[i];
      bool keep = true;

      for (int j = 0; j < result.length; j++) {
        final existing = result[j];
        if (current.classId == existing.classId) {
          final iou = _calculateIoU(current.box, existing.box);
          if (iou > iouThresh) {
            keep = false;
            break;
          }
        } else {
          // Cross-class heavy overlap check (prevents phantom duplicate boxes)
          final iou = _calculateIoU(current.box, existing.box);
          if (iou > 0.82) {
            keep = false;
            break;
          }
        }
      }
      if (keep) {
        result.add(current);
      }
    }
    return result;
  }

  double _calculateIoU(List<double> box1, List<double> box2) {
    final x1 = max(box1[0], box2[0]);
    final y1 = max(box1[1], box2[1]);
    final x2 = min(box1[2], box2[2]);
    final y2 = min(box1[3], box2[3]);

    final interArea = max(0.0, x2 - x1) * max(0.0, y2 - y1);
    final box1Area = (box1[2] - box1[0]) * (box1[3] - box1[1]);
    final box2Area = (box2[2] - box2[0]) * (box2[3] - box2[1]);
    final unionArea = box1Area + box2Area - interArea;

    if (unionArea <= 0) return 0.0;
    return interArea / unionArea;
  }

  /// Compliance Analyzer identical to backend
  ComplianceModel _analyzeCompliance(
    Map<String, int> summary,
    int peopleCount,
  ) {
    int safeCount = 0;
    int violationCount = 0;
    final Map<String, dynamic> violations = {};

    summary.forEach((name, count) {
      final clean = name.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
      if (clean.startsWith('no_') || clean.contains('violation')) {
        violationCount += count;
        violations[name] = count;
      } else if (clean.contains('hardhat') ||
          clean.contains('vest') ||
          clean.contains('mask') ||
          clean.contains('cone')) {
        safeCount += count;
      }
    });

    final total = safeCount + violationCount;
    double score = 100.0;
    String status = 'SAFE';

    if (total > 0) {
      score = double.parse(((safeCount / total) * 100).toStringAsFixed(1));
      if (violationCount == 0) {
        status = 'SAFE';
      } else if (violationCount <= 2) {
        status = 'WARNING';
      } else {
        status = 'VIOLATION';
      }
    } else {
      score = peopleCount > 0 ? 80.0 : 100.0;
      status = 'SAFE';
    }

    return ComplianceModel(
      complianceScorePercent: score,
      totalSafeItems: safeCount,
      totalViolations: violationCount,
      activeViolations: violations,
      safetyStatus: status,
    );
  }

  void dispose() {
    _session?.release();
    _session = null;
    _isInitialized = false;
  }
}

class _CandidateDetection {
  final int classId;
  final String className;
  final double confidence;
  final List<double> box;

  _CandidateDetection({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.box,
  });
}
