import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'image_utils.dart';
import 'yolo_parser.dart';

/// Kết quả nhận diện vật thể từ model YOLO
class Recognition {
  final String label;
  final double confidence;
  final Rect boundingBox; // Tọa độ chuẩn hóa [0.0, 1.0]

  Recognition(this.label, this.confidence, this.boundingBox);

  @override
  String toString() =>
      'Recognition($label, ${(confidence * 100).toStringAsFixed(1)}%, $boundingBox)';
}

/// Service quản lý model YOLOv8n TFLite để nhận diện vật thể.
class VisionService {
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isProcessing = false;
  String lastError = '';
  bool get isModelLoaded => _interpreter != null && _labels != null;

  // Cache tensor shapes & buffers
  List<int> _inputShape = [];
  List<int> _outputShape = [];
  bool _isNchw = true;

  // Buffer tái sử dụng để tránh cấp phát bộ nhớ liên tục trong mỗi frame
  List<List<List<double>>>? _outputBuffer;
  Float32List? _flatOutputBuffer;

  /// Khởi tạo model và labels. Gọi 1 lần khi mở camera.
  Future<void> init() async {
    try {
      _interpreter =
          await Interpreter.fromAsset('assets/models/yolov8n.tflite');

      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;

      // Nhận diện chuẩn tensor: [1, 3, 640, 640] là NCHW
      _isNchw = _inputShape.length == 4 && _inputShape[1] == 3;

      // Khởi tạo buffer đệm cho output
      _outputBuffer = List.generate(
        _outputShape[0],
        (_) => List.generate(
          _outputShape[1],
          (_) => List.filled(_outputShape[2], 0.0),
        ),
      );

      final int totalElements = _outputShape.reduce((a, b) => a * b);
      _flatOutputBuffer = Float32List(totalElements);

      final labelData =
          await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      lastError =
          '✅ Model Sẵn Sàng | In:$_inputShape (${_isNchw ? "NCHW" : "NHWC"}) | ${_labels!.length} classes';
      log(lastError);
    } catch (e) {
      lastError = '❌ Load model thất bại: $e';
      log(lastError);
    }
  }

  /// Chạy inference trên 1 frame camera.
  Future<List<Recognition>> processImage(CameraImage image) async {
    if (_interpreter == null ||
        _labels == null ||
        _outputBuffer == null ||
        _flatOutputBuffer == null ||
        _isProcessing) {
      return [];
    }

    _isProcessing = true;

    try {
      const int targetSize = 640;

      // ── 1. Chuyển frame camera sang Float32List với Letterbox chuẩn YOLOv8 (bảo toàn 100% Aspect Ratio) ──
      final processed = ImageUtils.cameraImageToFloat32Letterbox(
        image,
        targetSize,
        targetSize,
        nchw: _isNchw,
        rotationDegrees: 90,
      );

      // ── 2. Chạy inference TFLite ──
      _interpreter!.run(processed.buffer.buffer, _outputBuffer!);

      // ── 3. Flatten output từ nested List sang Float32List ──
      int idx = 0;
      final int rows = _outputShape[1];
      final int cols = _outputShape[2];
      final firstBatch = _outputBuffer![0];

      for (int i = 0; i < rows; i++) {
        final row = firstBatch[i];
        for (int j = 0; j < cols; j++) {
          _flatOutputBuffer![idx++] = row[j];
        }
      }

      // ── 4. Parse bounding boxes + Cross-Class NMS (ngưỡng lọc sơ bộ 0.25) ──
      final parsedBoxes = YoloParser.parse(
        _flatOutputBuffer!,
        _outputShape,
        0.25,
        targetSize,
        targetSize,
        letterbox: processed.letterbox,
      );

      // ── 5. Map sang Recognition objects ──
      final List<Recognition> results = [];
      for (final box in parsedBoxes) {
        final int classId = box['classId'] as int;
        final double score = box['score'] as double;
        final Rect rect = box['rect'] as Rect;

        if (classId >= 0 && classId < _labels!.length) {
          results.add(Recognition(_labels![classId], score, rect));
        }
      }

      // Cập nhật trạng thái debug
      if (results.isEmpty) {
        lastError =
            'Đang quét... Max score: ${(YoloParser.lastGlobalMaxScore * 100).toStringAsFixed(1)}%';
      } else {
        final top = results.first;
        lastError =
            'Tìm thấy ${results.length} vật thể | ${top.label} ${(top.confidence * 100).toStringAsFixed(0)}%';
      }

      return results;
    } catch (e, stack) {
      lastError = '❌ Lỗi xử lý: $e';
      log('Inference error: $e\n$stack');
      return [];
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    _interpreter?.close();
    _outputBuffer = null;
    _flatOutputBuffer = null;
  }
}
