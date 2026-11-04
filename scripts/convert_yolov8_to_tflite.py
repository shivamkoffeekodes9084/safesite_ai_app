"""
SafeSite AI - YOLOv8 to TFLite Model Export Script
==================================================
Converts custom trained YOLOv8 model (`best.pt`) to TensorFlow Lite format
for high-performance on-device execution in Flutter mobile apps.

Usage:
    pip install ultralytics tensorflow
    python scripts/convert_yolov8_to_tflite.py --model path/to/best.pt --imgsz 320
"""

import os
import sys
import argparse
from ultralytics import YOLO

def export_model(
    model_path: str = "best.pt",
    imgsz: int = 320,
    half: bool = True,
    int8: bool = False,
):
    if not os.path.exists(model_path):
        print(f"[Error] Model file '{model_path}' not found!")
        sys.exit(1)

    print(f"[SafeSite AI] Loading model '{model_path}'...")
    model = YOLO(model_path)

    print(f"[SafeSite AI] Model classes ({len(model.names)}):")
    for idx, name in model.names.items():
        print(f"  {idx}: {name}")

    # Export classes to labels.txt for Flutter asset bundle
    out_dir = os.path.dirname(os.path.abspath(model_path))
    labels_file = os.path.join(out_dir, "labels.txt")
    with open(labels_file, "w", encoding="utf-8") as f:
        for idx in sorted(model.names.keys()):
            f.write(f"{model.names[idx]}\n")
    print(f"[SafeSite AI] Exported classes to '{labels_file}' successfully!")

    print(f"\n[SafeSite AI] Exporting to TFLite (imgsz={imgsz}, half={half}, int8={int8})...")
    # TFLite Export via Ultralytics
    # half=True generates FP16 quantized model (~1/2 size, 2x faster on mobile GPUs/NPUs)
    # int8=True generates INT8 quantized model (~1/4 size, fastest on mobile CPUs)
    exported_path = model.export(
        format="tflite",
        imgsz=imgsz,
        half=half,
        int8=int8,
    )

    print(f"\n=======================================================")
    print(f" SUCCESS: Model exported to: {exported_path}")
    print(f" Next step: Copy the .tflite file and labels.txt to your")
    print(f" Flutter project 'assets/models/' folder.")
    print(f"=======================================================")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Export YOLOv8 to TFLite for Flutter")
    parser.add_argument("--model", type=str, default="best.pt", help="Path to best.pt")
    parser.add_argument("--imgsz", type=int, default=320, help="Inference resolution (320 or 416)")
    parser.add_argument("--half", action="store_true", default=True, help="FP16 quantization")
    parser.add_argument("--int8", action="store_true", default=False, help="INT8 quantization")
    args = parser.parse_args()

    export_model(model_path=args.model, imgsz=args.imgsz, half=args.half, int8=args.int8)
