import 'dart:math';
import '../model/safety_response_model.dart';

class _TrackedTarget {
  final int id;
  final int classId;
  final String className;
  List<double> box; // [x1, y1, x2, y2]
  double confidence;
  int lostFrames;

  _TrackedTarget({
    required this.id,
    required this.classId,
    required this.className,
    required this.box,
    required this.confidence,
  }) : lostFrames = 0;
}

/// SimpleByteTracker: Lightweight IoU-based multi-object tracker for on-device video inference.
/// Keeps track IDs consistent across consecutive video frames and smooths bounding box jitter.
class SimpleByteTracker {
  int _nextTrackId = 1;
  final List<_TrackedTarget> _tracks = [];
  final int maxLostFrames;
  final double matchIoUThreshold;

  SimpleByteTracker({
    this.maxLostFrames = 10,
    this.matchIoUThreshold = 0.30,
  });

  /// Reset all active tracks (e.g., when video restarts or user switches video)
  void reset() {
    _nextTrackId = 1;
    _tracks.clear();
  }

  /// Calculates Intersection-over-Union (IoU) between two bounding boxes [x1, y1, x2, y2]
  static double calculateIoU(List<double> b1, List<double> b2) {
    if (b1.length < 4 || b2.length < 4) return 0.0;
    final double xA = max(b1[0], b2[0]);
    final double yA = max(b1[1], b2[1]);
    final double xB = min(b1[2], b2[2]);
    final double yB = min(b1[3], b2[3]);

    final double interArea = max(0.0, xB - xA) * max(0.0, yB - yA);
    final double b1Area = max(0.0, b1[2] - b1[0]) * max(0.0, b1[3] - b1[1]);
    final double b2Area = max(0.0, b2[2] - b2[0]) * max(0.0, b2[3] - b2[1]);

    final double unionArea = b1Area + b2Area - interArea;
    if (unionArea <= 0.0) return 0.0;
    return interArea / unionArea;
  }

  /// Update active tracks with new frame detections and assign consistent track IDs
  List<DetectionItem> update(List<DetectionItem> detections) {
    if (detections.isEmpty) {
      for (final track in _tracks) {
        track.lostFrames++;
      }
      _tracks.removeWhere((t) => t.lostFrames > maxLostFrames);
      return [];
    }

    final matchedTrackIndices = <int>{};
    final matchedDetectionIndices = <int>{};
    final result = <DetectionItem>[];

    // Greedy IoU matching
    final pairs = <MapEntry<double, Point<int>>>[];
    for (int d = 0; d < detections.length; d++) {
      for (int t = 0; t < _tracks.length; t++) {
        if (detections[d].classId == _tracks[t].classId) {
          final iou = calculateIoU(detections[d].box, _tracks[t].box);
          if (iou >= matchIoUThreshold) {
            pairs.add(MapEntry(iou, Point(d, t)));
          }
        }
      }
    }

    // Sort by IoU descending
    pairs.sort((a, b) => b.key.compareTo(a.key));

    for (final pair in pairs) {
      final d = pair.value.x;
      final t = pair.value.y;
      if (!matchedDetectionIndices.contains(d) &&
          !matchedTrackIndices.contains(t)) {
        matchedDetectionIndices.add(d);
        matchedTrackIndices.add(t);

        // Exponential Moving Average (EMA) to smooth out box jitter across video frames
        final prevBox = _tracks[t].box;
        final newBox = detections[d].box;
        final smoothedBox = [
          0.70 * newBox[0] + 0.30 * prevBox[0],
          0.70 * newBox[1] + 0.30 * prevBox[1],
          0.70 * newBox[2] + 0.30 * prevBox[2],
          0.70 * newBox[3] + 0.30 * prevBox[3],
        ];

        _tracks[t].box = smoothedBox;
        _tracks[t].confidence = detections[d].confidence;
        _tracks[t].lostFrames = 0;

        result.add(
          detections[d].copyWith(
            box: smoothedBox,
            trackId: _tracks[t].id,
          ),
        );
      }
    }

    // New detections that didn't match existing tracks receive a new track ID
    for (int d = 0; d < detections.length; d++) {
      if (!matchedDetectionIndices.contains(d)) {
        final newId = _nextTrackId++;
        final item = detections[d];
        _tracks.add(
          _TrackedTarget(
            id: newId,
            classId: item.classId,
            className: item.className,
            box: List.from(item.box),
            confidence: item.confidence,
          ),
        );
        result.add(
          item.copyWith(
            trackId: newId,
          ),
        );
      }
    }

    // Increment lost frames for unmatched tracks and drop dead tracks
    for (int t = 0; t < _tracks.length; t++) {
      if (!matchedTrackIndices.contains(t)) {
        _tracks[t].lostFrames++;
      }
    }
    _tracks.removeWhere((t) => t.lostFrames > maxLostFrames);

    return result;
  }
}
