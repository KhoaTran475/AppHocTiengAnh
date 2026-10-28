import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
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

/// Lệnh khởi tạo gửi tới Background Isolate
class _IsolateInitRequest {
  final SendPort replyPort;
  final TransferableTypedData modelBytes;

  _IsolateInitRequest({
    required this.replyPort,
    required this.modelBytes,
  });
}

/// Lệnh xử lý 1 frame camera gửi tới Background Isolate (Zero-copy TransferableTypedData)
class _IsolateFrameRequest {
  final SendPort replyPort;
  final int width;
  final int height;
  final bool isBgra;
  final TransferableTypedData yData;
  final int yRowStride;
  final TransferableTypedData? uData;
  final int uRowStride;
  final int uPixelStride;
  final TransferableTypedData? vData;
  final int vRowStride;
  final int vPixelStride;
  final int rotationDegrees;

  _IsolateFrameRequest({
    required this.replyPort,
    required this.width,
    required this.height,
    required this.isBgra,
    required this.yData,
    required this.yRowStride,
    this.uData,
    this.uRowStride = 0,
    this.uPixelStride = 1,
    this.vData,
    this.vRowStride = 0,
    this.vPixelStride = 1,
    this.rotationDegrees = 90,
  });
}

/// Service quản lý model YOLOv8n TFLite chạy hoàn toàn trên Background Worker Isolate.
///
/// Tối ưu hóa triệt để chống giật lag Camera:
/// 1. 100% quá trình chuyển đổi YUV420 -> Float32, chạy TFLite Inference và YoloParser NMS
///    được thực thi trên Background Isolate riêng biệt (không bao giờ khóa Main UI Thread).
/// 2. Kích hoạt đa luồng C++ (`InterpreterOptions()..threads = 4`).
/// 3. Truy cập trực tiếp vùng nhớ Tensor (`inputTensor.data` & `outputTensor.data`)
///    loại bỏ hoàn toàn việc cấp phát mảng 3 chiều 705,600 phần tử mỗi frame.
class VisionService {
  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  List<String>? _labels;
  bool _isProcessing = false;
  bool _isDisposed = false;
  String lastError = '';

  List<int> _inputShape = [];
  bool _isNchw = true;

  bool get isModelLoaded => _workerSendPort != null && _labels != null;

  /// Khởi tạo model và Background Isolate. Gọi 1 lần khi mở camera.
  Future<void> init() async {
    try {
      _isDisposed = false;

      // 1. Đọc labels & model bytes từ assets
      final labelData = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final rawModelAsset = await rootBundle.load('assets/models/yolov8n.tflite');
      final Uint8List modelBytes = rawModelAsset.buffer.asUint8List(
        rawModelAsset.offsetInBytes,
        rawModelAsset.lengthInBytes,
      );

      // 2. Khởi chạy Background Worker Isolate
      final handshakePort = ReceivePort();
      _workerIsolate = await Isolate.spawn(
        _visionWorkerEntry,
        handshakePort.sendPort,
        debugName: 'YoloVisionWorkerIsolate',
      );

      final SendPort workerPort = await handshakePort.first as SendPort;
      handshakePort.close();

      if (_isDisposed) {
        _workerIsolate?.kill(priority: Isolate.immediate);
        return;
      }

      // 3. Khởi tạo TFLite Interpreter bên trong Worker Isolate
      final initReplyPort = ReceivePort();
      workerPort.send(
        _IsolateInitRequest(
          replyPort: initReplyPort.sendPort,
          modelBytes: TransferableTypedData.fromList([modelBytes]),
        ),
      );

      final Map<dynamic, dynamic> initResult =
          await initReplyPort.first as Map<dynamic, dynamic>;
      initReplyPort.close();

      if (initResult['ok'] == true) {
        _workerSendPort = workerPort;
        _inputShape = (initResult['inputShape'] as List).cast<int>();
        _isNchw = initResult['isNchw'] as bool;
        lastError =
            '✅ AI Isolate Sẵn Sàng | In:$_inputShape (${_isNchw ? "NCHW" : "NHWC"}) | ${_labels!.length} classes';
        log(lastError);
      } else {
        lastError = '❌ Load model thất bại: ${initResult['error']}';
        log(lastError);
      }
    } catch (e) {
      lastError = '❌ Load model thất bại: $e';
      log(lastError);
    }
  }

  /// Chạy inference trên 1 frame camera thông qua Background Isolate (không chặn UI).
  Future<List<Recognition>> processImage(
    CameraImage image, {
    int rotationDegrees = 90,
  }) async {
    if (_workerSendPort == null ||
        _labels == null ||
        _isProcessing ||
        _isDisposed) {
      return [];
    }

    _isProcessing = true;

    try {
      final bool isBgra = image.format.group == ImageFormatGroup.bgra8888;
      final yPlane = image.planes[0];

      TransferableTypedData? uTransfer;
      TransferableTypedData? vTransfer;
      int uRowStride = 0;
      int uPixelStride = 1;
      int vRowStride = 0;
      int vPixelStride = 1;

      if (!isBgra && image.planes.length >= 3) {
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];
        uTransfer = TransferableTypedData.fromList([uPlane.bytes]);
        vTransfer = TransferableTypedData.fromList([vPlane.bytes]);
        uRowStride = uPlane.bytesPerRow;
        uPixelStride = uPlane.bytesPerPixel ?? 1;
        vRowStride = vPlane.bytesPerRow;
        vPixelStride = vPlane.bytesPerPixel ?? 1;
      }

      final replyPort = ReceivePort();
      _workerSendPort!.send(
        _IsolateFrameRequest(
          replyPort: replyPort.sendPort,
          width: image.width,
          height: image.height,
          isBgra: isBgra,
          yData: TransferableTypedData.fromList([yPlane.bytes]),
          yRowStride: yPlane.bytesPerRow,
          uData: uTransfer,
          uRowStride: uRowStride,
          uPixelStride: uPixelStride,
          vData: vTransfer,
          vRowStride: vRowStride,
          vPixelStride: vPixelStride,
          rotationDegrees: rotationDegrees,
        ),
      );

      final Map<dynamic, dynamic> response =
          await replyPort.first as Map<dynamic, dynamic>;
      replyPort.close();

      if (_isDisposed) return [];

      if (response['ok'] != true) {
        lastError = '❌ Lỗi xử lý: ${response['error']}';
        return [];
      }

      final List<dynamic> rawBoxes = response['boxes'] as List<dynamic>;
      final double maxScore = (response['maxScore'] as num).toDouble();
      final int inferenceMs = (response['ms'] as int?) ?? 0;

      final List<Recognition> results = [];
      for (final item in rawBoxes) {
        final List<dynamic> boxData = item as List<dynamic>;
        final int classId = boxData[0] as int;
        final double score = (boxData[1] as num).toDouble();
        final Rect rect = Rect.fromLTRB(
          (boxData[2] as num).toDouble(),
          (boxData[3] as num).toDouble(),
          (boxData[4] as num).toDouble(),
          (boxData[5] as num).toDouble(),
        );

        if (classId >= 0 && classId < _labels!.length) {
          results.add(Recognition(_labels![classId], score, rect));
        }
      }

      if (results.isEmpty) {
        lastError =
            'Đang quét (${inferenceMs}ms)... Max score: ${(maxScore * 100).toStringAsFixed(1)}%';
      } else {
        final top = results.first;
        lastError =
            'Tìm thấy ${results.length} vật thể (${inferenceMs}ms) | ${top.label} ${(top.confidence * 100).toStringAsFixed(0)}%';
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

  /// Entry point của Background Worker Isolate
  static void _visionWorkerEntry(SendPort mainSendPort) {
    final workerCommandPort = ReceivePort();
    mainSendPort.send(workerCommandPort.sendPort);

    Interpreter? interpreter;
    InterpreterOptions? options;
    Tensor? inputTensor;
    Tensor? outputTensor;
    List<int> inputShape = [];
    List<int> outputShape = [];
    int totalOutputElements = 0;
    bool isNchw = true;

    workerCommandPort.listen((dynamic message) {
      if (message is _IsolateInitRequest) {
        try {
          final Uint8List modelBytes =
              message.modelBytes.materialize().asUint8List();

          options = InterpreterOptions()..threads = 4;
          interpreter = Interpreter.fromBuffer(modelBytes, options: options);
          inputTensor = interpreter!.getInputTensor(0);
          outputTensor = interpreter!.getOutputTensor(0);

          inputShape = inputTensor!.shape;
          outputShape = outputTensor!.shape;
          totalOutputElements = outputShape.reduce((a, b) => a * b);
          isNchw = inputShape.length == 4 && inputShape[1] == 3;

          message.replyPort.send({
            'ok': true,
            'inputShape': inputShape,
            'outputShape': outputShape,
            'isNchw': isNchw,
          });
        } catch (e) {
          message.replyPort.send({
            'ok': false,
            'error': e.toString(),
          });
        }
      } else if (message is _IsolateFrameRequest) {
        if (interpreter == null || inputTensor == null || outputTensor == null) {
          message.replyPort.send({
            'ok': false,
            'error': 'Interpreter chưa sẵn sàng',
          });
          return;
        }

        try {
          final sw = Stopwatch()..start();
          const int targetSize = 640;

          final rawFrame = RawCameraFrame(
            width: message.width,
            height: message.height,
            isBgra: message.isBgra,
            yBytes: message.yData.materialize().asUint8List(),
            yRowStride: message.yRowStride,
            uBytes: message.uData?.materialize().asUint8List(),
            uRowStride: message.uRowStride,
            uPixelStride: message.uPixelStride,
            vBytes: message.vData?.materialize().asUint8List(),
            vRowStride: message.vRowStride,
            vPixelStride: message.vPixelStride,
          );

          // 1. Tiền xử lý ảnh YUV420 -> Float32List với Letterbox bằng Integer LUT
          final processed = ImageUtils.rawFrameToFloat32Letterbox(
            rawFrame,
            targetSize,
            targetSize,
            nchw: isNchw,
            rotationDegrees: message.rotationDegrees,
          );

          // 2. Copy trực tiếp byte buffer vào vùng nhớ C++ của Input Tensor
          inputTensor!.data = processed.buffer.buffer.asUint8List(
            processed.buffer.offsetInBytes,
            processed.buffer.lengthInBytes,
          );

          // 3. Thực thi Inference C++ đa luồng
          interpreter!.invoke();

          // 4. Đọc trực tiếp vùng nhớ Output Tensor dưới dạng Float32List (Zero-Copy, không dùng mảng 3D)
          final Uint8List outBytes = outputTensor!.data;
          final Float32List flatOutput = outBytes.buffer.asFloat32List(
            outBytes.offsetInBytes,
            totalOutputElements,
          );

          // 5. Giải mã YOLOv8 Bounding Boxes + Cross-Class NMS ngay trong Worker Isolate
          final parsedBoxes = YoloParser.parse(
            flatOutput,
            outputShape,
            0.25,
            targetSize,
            targetSize,
            letterbox: processed.letterbox,
          );

          // Đóng gói gọn nhẹ gửi về Main UI Isolate
          final List<List<num>> compactBoxes = parsedBoxes.map((box) {
            final Rect r = box['rect'] as Rect;
            return <num>[
              box['classId'] as int,
              box['score'] as double,
              r.left,
              r.top,
              r.right,
              r.bottom,
            ];
          }).toList(growable: false);

          sw.stop();
          message.replyPort.send({
            'ok': true,
            'boxes': compactBoxes,
            'maxScore': YoloParser.lastGlobalMaxScore,
            'ms': sw.elapsedMilliseconds,
          });
        } catch (e) {
          message.replyPort.send({
            'ok': false,
            'error': e.toString(),
          });
        }
      } else if (message == 'dispose') {
        interpreter?.close();
        options?.delete();
        workerCommandPort.close();
      }
    });
  }

  void dispose() {
    _isDisposed = true;
    _workerSendPort?.send('dispose');
    _workerSendPort = null;
    Future.delayed(const Duration(milliseconds: 50), () {
      _workerIsolate?.kill(priority: Isolate.immediate);
      _workerIsolate = null;
    });
  }
}
