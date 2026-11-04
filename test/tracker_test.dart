import 'package:flutter_test/flutter_test.dart';
import 'package:safesite_ai/model/safety_response_model.dart';
import 'package:safesite_ai/services/byte_tracker.dart';

void main() {
  group('SimpleByteTracker Tests', () {
    test('Calculates IoU between bounding boxes accurately', () {
      final b1 = [10.0, 10.0, 50.0, 50.0];
      final b2 = [10.0, 10.0, 50.0, 50.0];
      expect(SimpleByteTracker.calculateIoU(b1, b2), closeTo(1.0, 0.001));

      final b3 = [60.0, 60.0, 100.0, 100.0];
      expect(SimpleByteTracker.calculateIoU(b1, b3), closeTo(0.0, 0.001));

      final b4 = [30.0, 10.0, 70.0, 50.0];
      // Intersection = 20 * 40 = 800. b1 area = 1600, b4 area = 1600, union = 2400. IoU = 800 / 2400 = 0.333
      expect(SimpleByteTracker.calculateIoU(b1, b4), closeTo(0.333, 0.01));
    });

    test('Assigns new track IDs to initial frame detections', () {
      final tracker = SimpleByteTracker();
      final detections = [
        DetectionItem(
          classId: 5,
          className: 'Person',
          confidence: 0.90,
          box: [100.0, 100.0, 200.0, 300.0],
        ),
        DetectionItem(
          classId: 0,
          className: 'Hardhat',
          confidence: 0.85,
          box: [120.0, 100.0, 180.0, 150.0],
        ),
      ];

      final tracked = tracker.update(detections);
      expect(tracked.length, 2);
      expect(tracked[0].trackId, 1);
      expect(tracked[1].trackId, 2);
      expect(tracked[0].className, 'Person');
      expect(tracked[1].className, 'Hardhat');
    });

    test('Maintains track ID across consecutive frames for moving object', () {
      final tracker = SimpleByteTracker();

      // Frame 1
      final frame1 = [
        DetectionItem(
          classId: 5,
          className: 'Person',
          confidence: 0.92,
          box: [100.0, 100.0, 200.0, 300.0],
        ),
      ];
      final tracked1 = tracker.update(frame1);
      expect(tracked1.first.trackId, 1);

      // Frame 2: Person moves slightly to the right
      final frame2 = [
        DetectionItem(
          classId: 5,
          className: 'Person',
          confidence: 0.93,
          box: [105.0, 100.0, 205.0, 300.0],
        ),
      ];
      final tracked2 = tracker.update(frame2);
      expect(tracked2.first.trackId, 1); // Track ID is preserved!
    });

    test('Resets cleanly when video loops', () {
      final tracker = SimpleByteTracker();
      tracker.update([
        DetectionItem(
          classId: 5,
          className: 'Person',
          confidence: 0.90,
          box: [100.0, 100.0, 200.0, 300.0],
        ),
      ]);

      tracker.reset();

      final trackedAfterReset = tracker.update([
        DetectionItem(
          classId: 5,
          className: 'Person',
          confidence: 0.90,
          box: [100.0, 100.0, 200.0, 300.0],
        ),
      ]);
      expect(trackedAfterReset.first.trackId, 1); // ID starts from 1 again!
    });
  });
}
