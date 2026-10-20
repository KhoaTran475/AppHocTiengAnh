import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'image_utils.dart';

/// Parser chuyên dụng cho YOLOv8n TFLite output.
///
/// YOLOv8n TFLite output shape: [1, 84, 8400] (hoặc [1, 8400, 84])
///   - 84 = 4 tọa độ (xc, yc, w, h) + 80 class scores (COCO)
///   - 8400 = tổng số anchor boxes
class YoloParser {
  static double lastGlobalMaxScore = 0.0;

  /// Parse raw output tensor thành danh sách bounding boxes đã lọc.
  ///
  /// [rawOutput]: Flat Float32List từ TFLite inference
  /// [shape]: Output tensor shape (ví dụ [1, 84, 8400])
  /// [confidenceThreshold]: Ngưỡng lọc ban đầu (0.25)
  /// [inputWidth]/[inputHeight]: Kích thước input YOLO (640)
  static List<Map<String, dynamic>> parse(
    Float32List rawOutput,
    List<int> shape,
    double confidenceThreshold,
    int inputWidth,
    int inputHeight, {
    LetterboxInfo? letterbox,
  }) {
    if (rawOutput.isEmpty) return [];

    const int numClasses = 80;
    const int numFields = 84; // 4 bbox + 80 classes
    int numAnchors = 0;

    // ── Xác định layout của output tensor ──
    bool needTranspose; // true = [1,84,8400], false = [1,8400,84]

    if (shape.length == 3) {
      if (shape[1] == numFields && shape[2] != numFields) {
        // [1, 84, 8400]
        numAnchors = shape[2];
        needTranspose = true;
      } else if (shape[2] == numFields && shape[1] != numFields) {
        // [1, 8400, 84]
        numAnchors = shape[1];
        needTranspose = false;
      } else {
        return [];
      }
    } else {
      return [];
    }

    final List<Map<String, dynamic>> candidates = [];
    double globalMaxScore = 0.0;

    for (int a = 0; a < numAnchors; a++) {
      // ── Tìm class có score cao nhất cho anchor a ──
      double maxClassScore = 0.0;
      int bestClassId = -1;

      for (int c = 0; c < numClasses; c++) {
        final int fieldIndex = c + 4; // field 0..3 = bbox, 4..83 = classes
        final int dataIndex = needTranspose
            ? (fieldIndex * numAnchors + a) // [1, 84, 8400]
            : (a * numFields + fieldIndex); // [1, 8400, 84]

        final double score = rawOutput[dataIndex];
        if (score > maxClassScore) {
          maxClassScore = score;
          bestClassId = c;
        }
      }

      if (maxClassScore > globalMaxScore) {
        globalMaxScore = maxClassScore;
      }

      if (maxClassScore < confidenceThreshold) continue;

      // ── Đọc bounding box (xc, yc, bw, bh) ──
      final double xc, yc, bw, bh;
      if (needTranspose) {
        xc = rawOutput[0 * numAnchors + a];
        yc = rawOutput[1 * numAnchors + a];
        bw = rawOutput[2 * numAnchors + a];
        bh = rawOutput[3 * numAnchors + a];
      } else {
        xc = rawOutput[a * numFields + 0];
        yc = rawOutput[a * numFields + 1];
        bw = rawOutput[a * numFields + 2];
        bh = rawOutput[a * numFields + 3];
      }

      final bool isAlreadyNormalized =
          (bw <= 1.0 && bh <= 1.0 && xc <= 1.0 && yc <= 1.0);
      final double pixelXc = isAlreadyNormalized ? xc * inputWidth : xc;
      final double pixelYc = isAlreadyNormalized ? yc * inputHeight : yc;
      final double pixelBw = isAlreadyNormalized ? bw * inputWidth : bw;
      final double pixelBh = isAlreadyNormalized ? bh * inputHeight : bh;

      final double left;
      final double top;
      final double right;
      final double bottom;

      if (letterbox != null && letterbox.scaledWidth > 0 && letterbox.scaledHeight > 0) {
        // Un-letterbox: Trừ padding và chuẩn hóa theo kích thước camera thực
        left = (pixelXc - pixelBw / 2 - letterbox.padX) / letterbox.scaledWidth;
        top = (pixelYc - pixelBh / 2 - letterbox.padY) / letterbox.scaledHeight;
        right = (pixelXc + pixelBw / 2 - letterbox.padX) / letterbox.scaledWidth;
        bottom = (pixelYc + pixelBh / 2 - letterbox.padY) / letterbox.scaledHeight;
      } else {
        left = (pixelXc - pixelBw / 2) / inputWidth;
        top = (pixelYc - pixelBh / 2) / inputHeight;
        right = (pixelXc + pixelBw / 2) / inputWidth;
        bottom = (pixelYc + pixelBh / 2) / inputHeight;
      }

      final rect = Rect.fromLTRB(
        left.clamp(0.0, 1.0),
        top.clamp(0.0, 1.0),
        right.clamp(0.0, 1.0),
        bottom.clamp(0.0, 1.0),
      );

      // Bỏ qua box quá nhỏ hoặc không hợp lệ
      if (rect.width < 0.02 || rect.height < 0.02) continue;

      candidates.add({
        'classId': bestClassId,
        'score': maxClassScore,
        'rect': rect,
      });
    }

    lastGlobalMaxScore = globalMaxScore;
    return _nonMaximumSuppression(candidates, 0.45);
  }

  /// Non-Maximum Suppression để loại bỏ các box trùng lắp
  /// Hỗ trợ cả intra-class (cùng class) và cross-class suppression (các box khác class nhưng đè lên nhau)
  static List<Map<String, dynamic>> _nonMaximumSuppression(
    List<Map<String, dynamic>> boxes,
    double iouThreshold, {
    double crossClassIouThreshold = 0.50,
  }) {
    if (boxes.isEmpty) return [];

    // Sắp xếp giảm dần theo điểm tin cậy (box có điểm cao nhất được ưu tiên giữ lại)
    boxes.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    final List<Map<String, dynamic>> selected = [];

    for (final box in boxes) {
      bool shouldSelect = true;
      for (final sBox in selected) {
        final double iou = _iou(box['rect'] as Rect, sBox['rect'] as Rect);
        final bool sameClass = (box['classId'] as int) == (sBox['classId'] as int);

        // 1. Cùng class: triệt tiêu nếu IoU > iouThreshold
        if (sameClass && iou > iouThreshold) {
          shouldSelect = false;
          break;
        }

        // 2. Khác class nhưng trùng lấn không gian lớn (IoU > crossClassIouThreshold):
        // Box có điểm thấp hơn sẽ bị triệt tiêu để giải quyết dứt điểm nhầm lẫn cell phone vs keyboard/remote
        if (!sameClass && iou > crossClassIouThreshold) {
          shouldSelect = false;
          break;
        }
      }
      if (shouldSelect) {
        selected.add(box);
      }
    }
    return selected;
  }

  /// Tính IoU giữa 2 hình chữ nhật
  static double _iou(Rect a, Rect b) {
    final double interLeft = max(a.left, b.left);
    final double interTop = max(a.top, b.top);
    final double interRight = min(a.right, b.right);
    final double interBottom = min(a.bottom, b.bottom);

    if (interRight <= interLeft || interBottom <= interTop) return 0.0;

    final double intersectionArea =
        (interRight - interLeft) * (interBottom - interTop);
    final double aArea = a.width * a.height;
    final double bArea = b.width * b.height;
    final double unionArea = aArea + bArea - intersectionArea;

    return unionArea > 0 ? (intersectionArea / unionArea) : 0.0;
  }
}
