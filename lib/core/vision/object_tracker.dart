import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'vision_service.dart';

/// Đại diện cho một vật thể đang được theo dõi (Tracked Object) qua các khung hình
class TrackedBox {
  final int id;
  final String label;

  /// Vị trí nội suy hiện tại trên màn hình (được cập nhật mỗi nhịp 60 FPS)
  Rect currentRect;

  /// Vị trí mục tiêu nhận được từ AI Worker Isolate (đã làm mượt bằng EMA)
  Rect targetRect;

  /// Độ tin cậy nội suy hiện tại
  double currentConfidence;

  /// Độ tin cậy mục tiêu từ AI Worker Isolate (đã làm mượt bằng EMA)
  double targetConfidence;

  /// Độ mờ đục (Opacity) để hiển thị hiệu ứng fade-in / fade-out mượt mà [0.0 - 1.0]
  double opacity;

  /// Số chu kỳ AI liên tiếp không phát hiện thấy vật thể (Grace Period)
  int missingFrames;

  /// Trạng thái đã vượt qua ngưỡng hiển thị (Entry Threshold) hay chưa (Hysteresis)
  bool isVisible;

  TrackedBox({
    required this.id,
    required this.label,
    required this.currentRect,
    required this.targetRect,
    required this.currentConfidence,
    required this.targetConfidence,
    this.opacity = 1.0,
    this.missingFrames = 0,
    this.isVisible = false,
  });

  Recognition toRecognition() {
    return Recognition(
      label,
      currentConfidence,
      currentRect,
      opacity: opacity.clamp(0.0, 1.0),
    );
  }
}

/// Bộ theo dõi vật thể (Object Tracker) với:
/// 1. Ghép cặp vật thể (IoU & Center Distance Matching)
/// 2. Làm mượt hàm mũ (Exponential Moving Average - EMA)
/// 3. Cơ chế trễ chống chớp tắt (Hysteresis: Entry 0.42 ↔ Retain 0.28)
/// 4. Đệm chu kỳ duy trì (Grace Frames: 2-3 chu kỳ AI khi vật thể bị che khuất thoáng qua)
/// 5. Nội suy 60 FPS (Linear Interpolation - Lerp)
class ObjectTracker {
  /// Ngưỡng tin cậy để bắt đầu hiển thị vật thể mới (Entry Threshold)
  final double entryThreshold;

  /// Ngưỡng tin cậy để duy trì hiển thị vật thể đã bắt được (Retain Threshold)
  final double retainThreshold;

  /// Số chu kỳ AI tối đa giữ lại vật thể trước khi hủy (Grace Frames)
  final int maxGraceFrames;

  /// Trọng số EMA cho tọa độ và confidence (Box_smooth = alpha * Box_new + (1 - alpha) * Box_prev)
  final double emaAlpha;

  int _nextId = 0;
  final List<TrackedBox> _trackedBoxes = [];

  ObjectTracker({
    this.entryThreshold = 0.42,
    this.retainThreshold = 0.28,
    this.maxGraceFrames = 3,
    this.emaAlpha = 0.65,
  });

  List<TrackedBox> get trackedBoxes => List.unmodifiable(_trackedBoxes);

  /// Cập nhật kết quả nhận diện mới từ AI Worker Isolate (chạy mỗi ~180ms)
  void updateDetections(List<Recognition> newDetections) {
    final List<bool> matchedDetections = List.filled(newDetections.length, false);
    final List<TrackedBox> nextTrackedList = [];

    // ── 1. Ghép cặp vật thể hiện tại với detection mới ──
    for (final tracked in _trackedBoxes) {
      int bestIndex = -1;
      double bestScore = -1.0;

      for (int i = 0; i < newDetections.length; i++) {
        if (matchedDetections[i]) continue;
        final det = newDetections[i];
        if (det.label != tracked.label) continue;

        final double iou = _calculateIoU(tracked.targetRect, det.boundingBox);
        final double centerDist =
            (tracked.targetRect.center - det.boundingBox.center).distance;

        // Cho phép ghép cặp nếu IoU > 0.20 hoặc khoảng cách tâm < 0.25 (hệ tọa độ [0, 1])
        if (iou > 0.20 || centerDist < 0.25) {
          final double score = iou > 0 ? (iou + 0.5) : (1.0 - centerDist);
          if (score > bestScore) {
            bestScore = score;
            bestIndex = i;
          }
        }
      }

      if (bestIndex != -1) {
        matchedDetections[bestIndex] = true;
        final det = newDetections[bestIndex];

        // Áp dụng EMA Smoothing cho vị trí mục tiêu
        final Rect smoothedTarget = Rect.fromLTRB(
          emaAlpha * det.boundingBox.left + (1.0 - emaAlpha) * tracked.targetRect.left,
          emaAlpha * det.boundingBox.top + (1.0 - emaAlpha) * tracked.targetRect.top,
          emaAlpha * det.boundingBox.right + (1.0 - emaAlpha) * tracked.targetRect.right,
          emaAlpha * det.boundingBox.bottom + (1.0 - emaAlpha) * tracked.targetRect.bottom,
        );
        tracked.targetRect = smoothedTarget;

        // Áp dụng EMA Smoothing cho điểm tin cậy
        tracked.targetConfidence =
            emaAlpha * det.confidence + (1.0 - emaAlpha) * tracked.targetConfidence;

        // Cơ chế Hysteresis:
        if (!tracked.isVisible) {
          if (tracked.targetConfidence >= entryThreshold) {
            tracked.isVisible = true;
          }
        } else {
          if (tracked.targetConfidence < retainThreshold) {
            // Rơi xuống dưới ngưỡng giữ -> bắt đầu mờ dần
            tracked.isVisible = false;
          }
        }

        tracked.missingFrames = 0;
        nextTrackedList.add(tracked);
      } else {
        // Không ghép được trong chu kỳ này -> tăng số frame vắng mặt (Grace Frames)
        tracked.missingFrames++;
        if (tracked.missingFrames <= maxGraceFrames && tracked.isVisible) {
          nextTrackedList.add(tracked);
        }
      }
    }

    // ── 2. Thêm các detection mới vượt qua Entry Threshold ──
    for (int i = 0; i < newDetections.length; i++) {
      if (!matchedDetections[i]) {
        final det = newDetections[i];
        if (det.confidence >= entryThreshold) {
          nextTrackedList.add(TrackedBox(
            id: _nextId++,
            label: det.label,
            currentRect: det.boundingBox,
            targetRect: det.boundingBox,
            currentConfidence: det.confidence,
            targetConfidence: det.confidence,
            opacity: 0.2, // Fade in nhanh từ 0.2
            missingFrames: 0,
            isVisible: true,
          ));
        }
      }
    }

    _trackedBoxes.clear();
    _trackedBoxes.addAll(nextTrackedList);
  }

  /// Gọi trên mỗi nhịp vẽ màn hình (60 FPS / 16.6ms) để nội suy vị trí mượt mà
  List<Recognition> tick({double lerpFactor = 0.25}) {
    // Loại bỏ vật thể đã vắng mặt quá số frame ân hạn và đã mờ hoàn toàn
    _trackedBoxes.removeWhere((box) =>
        box.missingFrames > maxGraceFrames && box.opacity <= 0.05);

    final List<Recognition> results = [];

    for (final box in _trackedBoxes) {
      // Nội suy tuyến tính (Rect.lerp) vị trí 60 FPS
      box.currentRect =
          Rect.lerp(box.currentRect, box.targetRect, lerpFactor) ?? box.targetRect;

      // Nội suy độ tin cậy
      box.currentConfidence = ui.lerpDouble(
            box.currentConfidence,
            box.targetConfidence,
            lerpFactor,
          ) ??
          box.targetConfidence;

      // Cập nhật hiệu ứng độ mờ đục (Opacity)
      if (box.missingFrames > 0) {
        // Đang trong grace period: mờ dần theo số frame vắng mặt
        final double targetOpacity =
            (1.0 - (box.missingFrames / (maxGraceFrames + 1))).clamp(0.0, 1.0);
        box.opacity = ui.lerpDouble(box.opacity, targetOpacity, lerpFactor * 1.5) ??
            targetOpacity;
      } else if (box.isVisible) {
        // Đang hoạt động bình thường: fade in lên 1.0
        box.opacity =
            ui.lerpDouble(box.opacity, 1.0, lerpFactor * 2.0) ?? 1.0;
      } else {
        // Dưới retain threshold: mờ dần về 0.0
        box.opacity =
            ui.lerpDouble(box.opacity, 0.0, lerpFactor * 1.5) ?? 0.0;
      }

      if (box.isVisible && box.opacity > 0.05) {
        results.add(box.toRecognition());
      }
    }

    return results;
  }

  /// Xóa toàn bộ trạng thái tracking (ví dụ khi Pause, Flip camera, v.v.)
  void reset() {
    _trackedBoxes.clear();
  }

  /// Tính Intersection over Union (IoU) giữa 2 hình chữ nhật
  static double _calculateIoU(Rect a, Rect b) {
    final double interLeft = max(a.left, b.left);
    final double interTop = max(a.top, b.top);
    final double interRight = min(a.right, b.right);
    final double interBottom = min(a.bottom, b.bottom);

    if (interRight <= interLeft || interBottom <= interTop) return 0.0;

    final double interArea = (interRight - interLeft) * (interBottom - interTop);
    final double unionArea = (a.width * a.height) + (b.width * b.height) - interArea;
    return unionArea > 0 ? (interArea / unionArea) : 0.0;
  }
}

