class SafetyResponseModel {
  final String status;
  final int totalObjectsDetected;
  final int totalFramesProcessed;
  final int uniqueObjectsTracked;
  final int peopleCount;
  final Map<String, int> summaryCounts;
  final ComplianceModel compliance;
  final List<DetectionItem> detections;
  final String? annotatedVideoUrl;
  final double? imageWidth;
  final double? imageHeight;
  final double? inferenceMs;

  SafetyResponseModel({
    required this.status,
    required this.totalObjectsDetected,
    this.totalFramesProcessed = 0,
    this.uniqueObjectsTracked = 0,
    this.peopleCount = 0,
    required this.summaryCounts,
    required this.compliance,
    required this.detections,
    this.annotatedVideoUrl,
    this.imageWidth,
    this.imageHeight,
    this.inferenceMs,
  });

  /// Returns the effective count of people tracked (either from people_count or unique_objects_tracked)
  int get effectivePeopleCount =>
      peopleCount > 0 ? peopleCount : uniqueObjectsTracked;

  /// Resolves relative or absolute URLs against the active backend base URL
  String? getFullAnnotatedVideoUrl(String baseUrl) {
    if (annotatedVideoUrl == null || annotatedVideoUrl!.isEmpty) return null;
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    if (annotatedVideoUrl!.startsWith('http://') ||
        annotatedVideoUrl!.startsWith('https://')) {
      try {
        final videoUri = Uri.parse(annotatedVideoUrl!);
        final baseUri = Uri.parse(cleanBase);
        // Replace scheme, host, and port with active backend base URL so local network devices can stream
        return videoUri
            .replace(
              scheme: baseUri.scheme,
              host: baseUri.host,
              port: baseUri.port,
            )
            .toString();
      } catch (_) {
        return annotatedVideoUrl;
      }
    }

    final cleanPath = annotatedVideoUrl!.startsWith('/')
        ? annotatedVideoUrl!
        : '/$annotatedVideoUrl';
    return '$cleanBase$cleanPath';
  }

  factory SafetyResponseModel.fromJson(Map<String, dynamic> json) {
    final detectionsList = (json['detections'] as List? ?? [])
        .map((x) => DetectionItem.fromJson(x as Map<String, dynamic>))
        .toList();

    // Parse summary_counts safely to Map<String, int>
    final rawSummary = json['summary_counts'] as Map<String, dynamic>? ?? {};
    final summaryCounts = rawSummary.map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    );

    final rawPeople = json['people_count'] ?? json['unique_objects_tracked'] ?? 0;
    final peopleCount = (rawPeople as num?)?.toInt() ?? 0;

    return SafetyResponseModel(
      status: json['status']?.toString() ?? '',
      totalObjectsDetected: (json['total_objects_detected'] as num?)?.toInt() ??
          (json['unique_objects_tracked'] as num?)?.toInt() ??
          detectionsList.length,
      totalFramesProcessed:
          (json['total_frames_processed'] as num?)?.toInt() ?? 0,
      uniqueObjectsTracked:
          (json['unique_objects_tracked'] as num?)?.toInt() ?? peopleCount,
      peopleCount: peopleCount,
      summaryCounts: summaryCounts,
      compliance: ComplianceModel.fromJson(
        json['compliance'] as Map<String, dynamic>? ?? {},
      ),
      detections: detectionsList,
      annotatedVideoUrl: json['annotated_video_url']?.toString(),
      imageWidth: (json['image_width'] as num?)?.toDouble(),
      imageHeight: (json['image_height'] as num?)?.toDouble(),
      inferenceMs: (json['inference_ms'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'total_objects_detected': totalObjectsDetected,
      'total_frames_processed': totalFramesProcessed,
      'unique_objects_tracked': uniqueObjectsTracked,
      'people_count': peopleCount,
      'summary_counts': summaryCounts,
      'compliance': compliance.toJson(),
      'detections': detections.map((x) => x.toJson()).toList(),
      if (annotatedVideoUrl != null) 'annotated_video_url': annotatedVideoUrl,
      if (imageWidth != null) 'image_width': imageWidth,
      if (imageHeight != null) 'image_height': imageHeight,
      if (inferenceMs != null) 'inference_ms': inferenceMs,
    };
  }
}

class ComplianceModel {
  final double complianceScorePercent;
  final int totalSafeItems;
  final int totalViolations;
  final Map<String, dynamic> activeViolations;
  final String safetyStatus;

  ComplianceModel({
    required this.complianceScorePercent,
    required this.totalSafeItems,
    required this.totalViolations,
    required this.activeViolations,
    required this.safetyStatus,
  });

  bool get isCompliant =>
      (safetyStatus.toUpperCase().contains('COMPLIANT') &&
          !safetyStatus.toUpperCase().contains('NON')) ||
      (totalViolations == 0 && complianceScorePercent >= 90.0);

  factory ComplianceModel.fromJson(Map<String, dynamic> json) {
    return ComplianceModel(
      complianceScorePercent:
          (json['compliance_score_percent'] as num?)?.toDouble() ?? 0.0,
      totalSafeItems:
          (json['total_safe_items_detected'] as num?)?.toInt() ?? 0,
      totalViolations:
          (json['total_violations_detected'] as num?)?.toInt() ?? 0,
      activeViolations:
          json['active_violations'] as Map<String, dynamic>? ?? {},
      safetyStatus: json['safety_status']?.toString() ?? 'UNKNOWN',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'compliance_score_percent': complianceScorePercent,
      'total_safe_items_detected': totalSafeItems,
      'total_violations_detected': totalViolations,
      'active_violations': activeViolations,
      'safety_status': safetyStatus,
    };
  }
}

class DetectionItem {
  final int classId;
  final String className;
  final double confidence;
  final List<double> box;
  final int? trackId;

  DetectionItem({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.box,
    this.trackId,
  });

  DetectionItem copyWith({
    int? classId,
    String? className,
    double? confidence,
    List<double>? box,
    int? trackId,
  }) {
    return DetectionItem(
      classId: classId ?? this.classId,
      className: className ?? this.className,
      confidence: confidence ?? this.confidence,
      box: box ?? this.box,
      trackId: trackId ?? this.trackId,
    );
  }

  factory DetectionItem.fromJson(Map<String, dynamic> json) {
    return DetectionItem(
      classId: (json['class_id'] as num?)?.toInt() ?? 0,
      className: json['class_name']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      box: List<double>.from(
        (json['box'] as List? ?? []).map((x) => (x as num).toDouble()),
      ),
      trackId: (json['track_id'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'class_id': classId,
      'class_name': className,
      'confidence': confidence,
      'box': box,
      if (trackId != null) 'track_id': trackId,
    };
  }
}
