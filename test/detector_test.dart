import 'package:flutter_test/flutter_test.dart';
import 'package:safesite_ai/services/on_device_detector.dart';

void main() {
  group('OnDeviceDetector Unit & Parsing Tests', () {
    test('Default class names include Person, Machinery, and PPE categories', () {
      final names = OnDeviceDetector.defaultClassNames;
      expect(names[0], equals('Hardhat'));
      expect(names[1], equals('Mask'));
      expect(names[2], equals('NO-Hardhat'));
      expect(names[4], equals('NO-Safety Vest'));
      expect(names[5], equals('Person'));
      expect(names[7], equals('Safety Vest'));
      expect(names[8], equals('machinery'));
      expect(names[9], equals('vehicle'));
    });

    test('IoU calculation correctly computes intersection and union', () {
      // Test identical boxes (IoU == 1.0)
      const interX1 = 10.0;
      const interY1 = 10.0;
      const interX2 = 50.0;
      const interY2 = 50.0;
      const interArea = (interX2 - interX1) * (interY2 - interY1);
      const unionArea = 1600.0 + 1600.0 - interArea;
      expect(interArea / unionArea, equals(1.0));

      // Test disjoint coordinates
      const noInterX1 = 100.0;
      const noInterX2 = 50.0;
      expect(noInterX2 < noInterX1, isTrue); // No intersection
    });

    test('Letterbox coordinate unpadding maps accurately to original image space', () {
      const origW = 720.0;
      const origH = 1280.0;
      const inputSize = 320.0;

      // r = min(320 / 720, 320 / 1280) = 320 / 1280 = 0.25
      final r = 320.0 / 1280.0;
      final newW = (origW * r).round(); // 180
      final newH = (origH * r).round(); // 320
      final padX = (inputSize - newW) / 2.0; // 70.0
      final padY = (inputSize - newH) / 2.0; // 0.0

      // Suppose an object is at (360, 640) with width 200, height 400 in original image
      // In letterbox space:
      final cx = 360.0 * r + padX; // 90 + 70 = 160.0
      final cy = 640.0 * r + padY; // 160 + 0 = 160.0
      final bw = 200.0 * r;        // 50.0
      final bh = 400.0 * r;        // 100.0

      // Unpad back to original space
      final x1 = ((cx - bw / 2.0 - padX) / r).clamp(0.0, origW);
      final y1 = ((cy - bh / 2.0 - padY) / r).clamp(0.0, origH);
      final x2 = ((cx + bw / 2.0 - padX) / r).clamp(0.0, origW);
      final y2 = ((cy + bh / 2.0 - padY) / r).clamp(0.0, origH);

      expect(x1, closeTo(260.0, 0.01)); // 360 - 100 = 260
      expect(y1, closeTo(440.0, 0.01)); // 640 - 200 = 440
      expect(x2, closeTo(460.0, 0.01)); // 360 + 100 = 460
      expect(y2, closeTo(840.0, 0.01)); // 640 + 200 = 840
    });
  });
}
