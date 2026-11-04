# SafeSite AI 🛡️
### Real-Time On-Device Computer Vision & Workplace Safety Intelligence

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![ONNX Runtime](https://img.shields.io/badge/ONNX_Runtime_Mobile-v1.4.1-005CED?logo=onnx&logoColor=white)](https://onnxruntime.ai)
[![YOLO Support](https://img.shields.io/badge/YOLO-v8%20%7C%2011%20%7C%2026-00E5FF)](https://docs.ultralytics.com)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL_3.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-green.svg)]()

SafeSite AI is an industrial-grade, edge-first mobile computer vision application engineered for **construction, manufacturing, warehousing, and industrial safety compliance**. It delivers high-throughput real-time object detection, PPE compliance auditing, multi-person tracking, and live CCTV stream telemetry with **100% on-device neural processing and zero cloud dependency**.

---

## ✨ Key Features & Vision Tasks

SafeSite AI integrates multi-task YOLO architecture directly on mobile hardware:

| Vision Mode | Task Description | Target Use Case |
| :--- | :--- | :--- |
| **DET (Detect)** | High-speed bounding boxes with confidence scores | Workers, Helmets/Hardhats, Safety Vests, Heavy Machinery, Trucks |
| **SEG (Segment)** | Instance segmentation contour polygon masks | Boundary demarcation of workers, hazardous equipment, and safe pathways |
| **SEM (Semantic)** | Full-frame multi-class semantic colormaps | Floor, wall, structural machinery background vs foreground segregation |
| **DEPTH (Depth)** | Real-time continuous thermal/depth heatmaps | Spatial distance estimation, fall-risk proximity, and obstacle depth |
| **CLS (Classify)** | Ultra-fast scene and condition classification | Instant high-FPS environment tagging (`safe`, `violation`, `machinery`) |
| **POSE (Pose)** | 17-keypoint COCO anatomical skeletal tracking | Ergonomics, slip-and-fall detection, unsafe worker posture alerts |
| **OBB (Oriented Box)** | Angled bounding boxes with heading orientation | Tilted industrial containers, angled beams, and vehicle direction |

---

## 🏗️ Safety & Operational Capabilities

- ⛑️ **PPE Compliance Monitoring**: Automatically verifies if personnel are wearing mandatory safety equipment (Hardhats, High-Visibility Vests, Safety Masks) and flags missing gear in real time.
- 👥 **ByteTrack People Counting**: High-accuracy multi-object tracking assigns consistent Track IDs (`ID: #1`, `ID: #2`), eliminating duplicate counts during occlusion or movement.
- 🟢 **Live Safety Status Pill**: Non-intrusive floating HUD displaying live worker counts, compliance percentage, and alert indicators (`🟢 SAFE` / `🔴 VIOLATION`).
- 📹 **CCTV & Video Stream Inspector**: Ingest stored CCTV footage or recorded video clips to run timeline-based automated safety audits with violation timestamps.
- 🔒 **100% On-Device Privacy**: All neural network inference is executed locally using **ONNX Runtime Mobile**. No video feeds, images, or employee data ever leave the device.

---

## 📱 Interactive Dynamic Model Switcher

SafeSite AI includes dynamic on-device model management inspired by Ultralytics:
- **YOLOv8n**: Ultra-fast latency (~13-25ms) optimized for battery efficiency and continuous live monitoring.
- **YOLO11n**: Next-generation state-of-the-art balance between speed and precision for small-object PPE detection.
- **YOLO26n**: High-precision model variant for complex multi-class industrial environments.

Users can switch active models dynamically on-the-fly directly from the fullscreen **About SafeSite AI** view.

---

## 🏛️ Project Architecture

```
safesite_ai/
├── lib/
│   ├── main.dart                      # App entry point with Riverpod ProviderScope
│   ├── models/
│   │   ├── detection_item.dart        # Detection results, bounding boxes, labels
│   │   └── model_variant.dart         # YOLO model variant specifications & metadata
│   ├── providers/
│   │   ├── model_manager_provider.dart# Riverpod state notifier for active model & downloads
│   │   └── safety_provider.dart       # Live compliance metrics & violation aggregators
│   ├── services/
│   │   ├── byte_tracker.dart          # IoU-based multi-object tracker (ByteTrack)
│   │   ├── model_manager_service.dart # On-device model weight loader & storage
│   │   └── on_device_detector.dart    # ONNX runtime inference & coordinate letterbox unpadding
│   └── views/
│       ├── home_screen.dart           # Edge-to-edge camera feed, task filters, HUD
│       ├── cctv_video_player_screen.dart # CCTV clip analyzer & violation logger
│       ├── photo_detection_viewer_screen.dart # Still-image inspection & zoom
│       └── widgets/
│           ├── about_safesite_sheet.dart  # Fullscreen dynamic model & diagnostics screen
│           └── model_download_dialog.dart # Progress dialog for model weights
└── assets/
    ├── models/                        # Pre-bundled on-device ONNX weights
    └── icon/                          # App brand logos and launcher assets
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.24.0`)
- [Dart SDK](https://dart.dev/get-dart) (`>= 3.5.0`)
- Android Studio / VS Code with Flutter extension
- Android device or emulator with Camera permissions (API Level 24+)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/shivamkoffeekodes9084/safesite_ai_app.git
   cd safesite_ai_app
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run code analysis and tests**:
   ```bash
   flutter analyze
   flutter test
   ```

4. **Launch the application**:
   ```bash
   # Run on connected Android / iOS device
   flutter run
   ```

---

## 📜 Licensing

SafeSite AI is open-sourced under the **GNU Affero General Public License v3.0 (AGPL-3.0)**.

### Community & Academic Use (AGPL-3.0)
- You are free to inspect, modify, fork, and distribute this application under the conditions of the AGPL-3.0 license.
- If you run a modified version of this software as a networked or distributed service, the complete corresponding source code must be made publicly available under AGPL-3.0.

### Commercial & Enterprise Licensing
For enterprise deployments, commercial integrations, CCTV server clustering, custom proprietary model integration, or white-label solutions that require exemption from open-source obligations:
- Contact the development team or visit [SafeSite AI Enterprise Inquiries](https://github.com/shivamkoffeekodes9084/safesite_ai_app).

See the [LICENSE](LICENSE) file for the full legal text.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'feat: Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

*Engineered with ❤️ for zero-accident industrial safety powered by Edge AI.*
