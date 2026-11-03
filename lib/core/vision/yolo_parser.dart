import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'image_utils.dart';

/// Kết quả phát hiện thô từ YOLOv8 trước khi ghép với nhãn
class YoloDetection {
  final int classId;
  final double score;
  final Rect rect;

  const YoloDetection({
    required this.classId,
    required this.score,
    required this.rect,
  });

  @override
  String toString() => 'YoloDetection(class: $classId, score: ${(score * 100).toStringAsFixed(1)}%, rect: $rect)';
}

/// Parser chuyên dụng cho YOLOv8n TFLite output.
///
/// Tối ưu hóa hiệu năng cực đại:
/// 1. Xử lý trực tiếp trên mảng Float32List phẳng (Zero Intermediate Allocation)
/// 2. Lọc sớm (Early-Exit) khi maxClassScore < confidenceThreshold
/// 3. Sử dụng strongly-typed YoloDetection struct thay vì Map<String, dynamic>
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
  static List<YoloDetection> parse(
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

    final List<YoloDetection> candidates = [];
    double globalMaxScore = 0.0;

    final bool hasLetterbox = letterbox != null && letterbox.scaledWidth > 0 && letterbox.scaledHeight > 0;
    final double lbPadX = hasLetterbox ? letterbox.padX.toDouble() : 0.0;
    final double lbPadY = hasLetterbox ? letterbox.padY.toDouble() : 0.0;
    final double lbScaledW = hasLetterbox ? letterbox.scaledWidth.toDouble() : inputWidth.toDouble();
    final double lbScaledH = hasLetterbox ? letterbox.scaledHeight.toDouble() : inputHeight.toDouble();

    if (needTranspose) {
      // Shape [1, 84, 8400]: Mỗi class cách nhau đúng numAnchors phần tử
      for (int a = 0; a < numAnchors; a++) {
        double maxClassScore = 0.0;
        int bestClassId = -1;
        int dataIndex = 4 * numAnchors + a;

        for (int c = 0; c < numClasses; c++) {
          final double score = rawOutput[dataIndex];
          if (score > maxClassScore) {
            maxClassScore = score;
            bestClassId = c;
          }
          dataIndex += numAnchors; // Bước nhảy tuyến tính, không nhân phép toán
        }

        if (maxClassScore > globalMaxScore) {
          globalMaxScore = maxClassScore;
        }

        // Lọc sớm (Early Exit)
        if (maxClassScore < confidenceThreshold) continue;

        final double xc = rawOutput[a];
        final double yc = rawOutput[numAnchors + a];
        final double bw = rawOutput[2 * numAnchors + a];
        final double bh = rawOutput[3 * numAnchors + a];

        final bool isAlreadyNormalized = (bw <= 1.0 && bh <= 1.0 && xc <= 1.0 && yc <= 1.0);
        final double pixelXc = isAlreadyNormalized ? xc * inputWidth : xc;
        final double pixelYc = isAlreadyNormalized ? yc * inputHeight : yc;
        final double pixelBw = isAlreadyNormalized ? bw * inputWidth : bw;
        final double pixelBh = isAlreadyNormalized ? bh * inputHeight : bh;

        final double halfW = pixelBw * 0.5;
        final double halfH = pixelBh * 0.5;

        final double left = (pixelXc - halfW - lbPadX) / lbScaledW;
        final double top = (pixelYc - halfH - lbPadY) / lbScaledH;
        final double right = (pixelXc + halfW - lbPadX) / lbScaledW;
        final double bottom = (pixelYc + halfH - lbPadY) / lbScaledH;

        final rect = Rect.fromLTRB(
          left.clamp(0.0, 1.0),
          top.clamp(0.0, 1.0),
          right.clamp(0.0, 1.0),
          bottom.clamp(0.0, 1.0),
        );

        if (rect.width < 0.02 || rect.height < 0.02) continue;

        candidates.add(YoloDetection(
          classId: bestClassId,
          score: maxClassScore,
          rect: rect,
        ));
      }
    } else {
      // Shape [1, 8400, 84]: 80 class scores liên tiếp nhau trong bộ nhớ
      for (int a = 0; a < numAnchors; a++) {
        double maxClassScore = 0.0;
        int bestClassId = -1;
        int dataIndex = a * numFields + 4;

        for (int c = 0; c < numClasses; c++) {
          final double score = rawOutput[dataIndex++];
          if (score > maxClassScore) {
            maxClassScore = score;
            bestClassId = c;
          }
        }

        if (maxClassScore > globalMaxScore) {
          globalMaxScore = maxClassScore;
        }

        // Lọc sớm (Early Exit)
        if (maxClassScore < confidenceThreshold) continue;

        final int base = a * numFields;
        final double xc = rawOutput[base];
        final double yc = rawOutput[base + 1];
        final double bw = rawOutput[base + 2];
        final double bh = rawOutput[base + 3];

        final bool isAlreadyNormalized = (bw <= 1.0 && bh <= 1.0 && xc <= 1.0 && yc <= 1.0);
        final double pixelXc = isAlreadyNormalized ? xc * inputWidth : xc;
        final double pixelYc = isAlreadyNormalized ? yc * inputHeight : yc;
        final double pixelBw = isAlreadyNormalized ? bw * inputWidth : bw;
        final double pixelBh = isAlreadyNormalized ? bh * inputHeight : bh;

        final double halfW = pixelBw * 0.5;
        final double halfH = pixelBh * 0.5;

        final double left = (pixelXc - halfW - lbPadX) / lbScaledW;
        final double top = (pixelYc - halfH - lbPadY) / lbScaledH;
        final double right = (pixelXc + halfW - lbPadX) / lbScaledW;
        final double bottom = (pixelYc + halfH - lbPadY) / lbScaledH;

        final rect = Rect.fromLTRB(
          left.clamp(0.0, 1.0),
          top.clamp(0.0, 1.0),
          right.clamp(0.0, 1.0),
          bottom.clamp(0.0, 1.0),
        );

        if (rect.width < 0.02 || rect.height < 0.02) continue;

        candidates.add(YoloDetection(
          classId: bestClassId,
          score: maxClassScore,
          rect: rect,
        ));
      }
    }

    lastGlobalMaxScore = globalMaxScore;
    return _nonMaximumSuppression(candidates, 0.45);
  }

  /// Non-Maximum Suppression để loại bỏ các box trùng lắp
  /// Hỗ trợ cả intra-class (cùng class) và cross-class suppression (các box khác class nhưng đè lên nhau)
  static List<YoloDetection> _nonMaximumSuppression(
    List<YoloDetection> boxes,
    double iouThreshold, {
    double crossClassIouThreshold = 0.50,
  }) {
    if (boxes.isEmpty) return [];

    // Sắp xếp giảm dần theo điểm tin cậy (box có điểm cao nhất được ưu tiên giữ lại)
    boxes.sort((a, b) => b.score.compareTo(a.score));

    final List<YoloDetection> selected = [];

    for (final box in boxes) {
      bool shouldSelect = true;
      for (final sBox in selected) {
        final double iou = _iou(box.rect, sBox.rect);
        final bool sameClass = box.classId == sBox.classId;

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
