import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
import 'image_utils.dart';
import 'yolo_parser.dart';

/// Kết quả nhận diện vật thể từ model YOLO
class Recognition {
  final String label;
  final double confidence;
  final ui.Rect boundingBox; // Tọa độ chuẩn hóa [0.0, 1.0]
  final double opacity;

  Recognition(
    this.label,
    this.confidence,
    this.boundingBox, {
    this.opacity = 1.0,
  });

  @override
  String toString() =>
      'Recognition($label, ${(confidence * 100).toStringAsFixed(1)}%, $boundingBox, opacity: ${opacity.toStringAsFixed(2)})';
}

/// Message khởi tạo Worker Isolate
class _WorkerInitMessage {
  final SendPort sendPort;
  final Uint8List modelBytes;
  final List<String> labels;
  final bool isAndroid;
  final int threadCount;

  _WorkerInitMessage({
    required this.sendPort,
    required this.modelBytes,
    required this.labels,
    required this.isAndroid,
    required this.threadCount,
  });
}

/// Kết quả trả về sau khi khởi tạo Worker Isolate
class _WorkerInitResult {
  final bool success;
  final String backendInfo;
  final List<int> inputShape;
  final List<int> outputShape;
  final bool isNchw;
  final String error;

  _WorkerInitResult({
    required this.success,
    required this.backendInfo,
    this.inputShape = const [],
    this.outputShape = const [],
    this.isNchw = true,
    this.error = '',
  });
}

/// Message gửi frame camera sang Worker Isolate
class _FrameProcessMessage {
  final TransferableTypedData planesData;
  final List<int> planeLengths;
  final List<int> bytesPerRow;
  final List<int?> bytesPerPixel;
  final int width;
  final int height;
  final bool isBgra;
  final int rotationDegrees;
  final bool mirrorHorizontal;

  _FrameProcessMessage({
    required this.planesData,
    required this.planeLengths,
    required this.bytesPerRow,
    required this.bytesPerPixel,
    required this.width,
    required this.height,
    required this.isBgra,
    required this.rotationDegrees,
    required this.mirrorHorizontal,
  });
}

/// Kết quả inference từ Worker Isolate gửi về UI Thread
class _FrameResultMessage {
  final List<Recognition> recognitions;
  final int preprocessMs;
  final int inferenceMs;
  final int postprocessMs;
  final int totalMs;
  final String statusText;
  final String? error;

  _FrameResultMessage({
    required this.recognitions,
    required this.preprocessMs,
    required this.inferenceMs,
    required this.postprocessMs,
    required this.totalMs,
    required this.statusText,
    this.error,
  });
}

/// Service quản lý model YOLOv8n TFLite chạy HOÀN TOÀN TRÊN PERSISTENT BACKGROUND ISOLATE.
/// Giữ cho Main UI Thread đạt chuẩn mượt mà 60 - 120 FPS không giật lag.
class VisionService {
  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  ReceivePort? _mainReceivePort;
  StreamSubscription? _mainReceiveSub;

  Completer<List<Recognition>>? _pendingFrameCompleter;

  bool _isProcessing = false;
  bool _isLoaded = false;
  String lastError = '';

  bool get isModelLoaded => _isLoaded;
  bool get isProcessing => _isProcessing;

  // Cache tensor shapes
  List<int> inputShape = [];
  List<int> outputShape = [];
  bool isNchw = true;

  // Thống kê benchmark độ trễ (Latency metrics)
  int lastPreprocessMs = 0;
  int lastInferenceMs = 0;
  int lastPostprocessMs = 0;
  int lastTotalMs = 0;

  /// Khởi tạo persistent worker isolate và load model TFLite bên trong isolate
  Future<void> init() async {
    try {
      final int threadCount = Platform.numberOfProcessors.clamp(2, 4);

      // 1. Load model bytes & labels từ asset trên UI thread
      final ByteData modelData = await rootBundle.load('assets/models/yolov8n.tflite');
      final Uint8List modelBytes = modelData.buffer.asUint8List();

      final labelData = await rootBundle.loadString('assets/models/labels.txt');
      final List<String> labels = labelData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // 2. Tạo ReceivePort và spawn Persistent Worker Isolate
      _mainReceivePort = ReceivePort();
      final handshakeCompleter = Completer<SendPort>();

      _mainReceiveSub = _mainReceivePort!.listen((message) {
        if (message is SendPort) {
          if (!handshakeCompleter.isCompleted) {
            handshakeCompleter.complete(message);
          }
        } else if (message is _FrameResultMessage) {
          lastPreprocessMs = message.preprocessMs;
          lastInferenceMs = message.inferenceMs;
          lastPostprocessMs = message.postprocessMs;
          lastTotalMs = message.totalMs;
          lastError = message.statusText;

          _isProcessing = false;
          if (_pendingFrameCompleter != null && !_pendingFrameCompleter!.isCompleted) {
            _pendingFrameCompleter!.complete(message.recognitions);
            _pendingFrameCompleter = null;
          }
        }
      });

      _workerIsolate = await Isolate.spawn(
        _visionWorkerEntryPoint,
        _mainReceivePort!.sendPort,
      );

      _workerSendPort = await handshakeCompleter.future;

      // 3. Gửi lệnh khởi tạo TFLite Interpreter vào Worker Isolate
      final initResponsePort = ReceivePort();
      _workerSendPort!.send(_WorkerInitMessage(
        sendPort: initResponsePort.sendPort,
        modelBytes: modelBytes,
        labels: labels,
        isAndroid: Platform.isAndroid,
        threadCount: threadCount,
      ));

      final _WorkerInitResult initResult = await initResponsePort.first;
      initResponsePort.close();

      if (initResult.success) {
        _isLoaded = true;
        inputShape = initResult.inputShape;
        outputShape = initResult.outputShape;
        isNchw = initResult.isNchw;
        lastError = '✅ Model Sẵn Sàng (${initResult.backendInfo}) | In:$inputShape (${isNchw ? "NCHW" : "NHWC"})';
        log(lastError);
      } else {
        lastError = '❌ Load model thất bại: ${initResult.error}';
        log(lastError);
      }
    } catch (e) {
      lastError = '❌ Khởi tạo Worker Isolate thất bại: $e';
      log(lastError);
    }
  }

  /// Chạy inference trên 1 frame camera (Chuyển dữ liệu Zero-Copy sang Worker Isolate).
  /// Nếu Isolate đang bận xử lý frame trước thì tự động skip frame hiện tại (0ms UI blocking).
  Future<List<Recognition>> processImage(
    CameraImage image, {
    int rotationDegrees = 90,
    bool mirrorHorizontal = false,
  }) async {
    if (!_isLoaded || _workerSendPort == null || _isProcessing) {
      return [];
    }

    _isProcessing = true;

    try {
      // Đóng gói mảng byte các plane bằng TransferableTypedData (Zero-Copy)
      final List<Uint8List> planeByteList = [];
      final List<int> planeLengths = [];
      final List<int> bytesPerRow = [];
      final List<int?> bytesPerPixel = [];

      for (final plane in image.planes) {
        planeByteList.add(plane.bytes);
        planeLengths.add(plane.bytes.length);
        bytesPerRow.add(plane.bytesPerRow);
        bytesPerPixel.add(plane.bytesPerPixel);
      }

      final transferableData = TransferableTypedData.fromList(planeByteList);
      final isBgra = image.format.group == ImageFormatGroup.bgra8888;

      _pendingFrameCompleter = Completer<List<Recognition>>();

      _workerSendPort!.send(_FrameProcessMessage(
        planesData: transferableData,
        planeLengths: planeLengths,
        bytesPerRow: bytesPerRow,
        bytesPerPixel: bytesPerPixel,
        width: image.width,
        height: image.height,
        isBgra: isBgra,
        rotationDegrees: rotationDegrees,
        mirrorHorizontal: mirrorHorizontal,
      ));

      // Timeout an toàn sau 350ms nếu worker bị treo
      return await _pendingFrameCompleter!.future.timeout(
        const Duration(milliseconds: 350),
        onTimeout: () {
          _isProcessing = false;
          _pendingFrameCompleter = null;
          return [];
        },
      );
    } catch (e, stack) {
      lastError = '❌ Lỗi gửi frame sang Isolate: $e';
      log('ProcessImage error: $e\n$stack');
      _isProcessing = false;
      _pendingFrameCompleter = null;
      return [];
    }
  }

  void dispose() {
    _isProcessing = false;
    _isLoaded = false;
    try {
      _workerSendPort?.send('dispose');
    } catch (_) {}
    _mainReceiveSub?.cancel();
    _mainReceiveSub = null;
    _mainReceivePort?.close();
    _mainReceivePort = null;
    _workerIsolate?.kill(priority: Isolate.beforeNextEvent);
    _workerIsolate = null;
    _workerSendPort = null;
  }
}

/// Entry point của Persistent Background Worker Isolate
void _visionWorkerEntryPoint(SendPort mainSendPort) {
  final workerReceivePort = ReceivePort();
  mainSendPort.send(workerReceivePort.sendPort);

  Interpreter? interpreter;
  List<String>? labels;
  List<int> inputShape = [];
  List<int> outputShape = [];
  bool isNchw = true;

  Float32List? flatOutputBuffer;
  Float32List? letterboxBuffer;
  int totalOutputElements = 0;

  workerReceivePort.listen((message) {
    if (message is _WorkerInitMessage) {
      try {
        String backendInfo = 'CPU (${message.threadCount} threads)';

        // 1. Khởi tạo GPU Delegate (Android GpuDelegateV2)
        if (message.isAndroid) {
          try {
            final gpuOptions = InterpreterOptions()..addDelegate(GpuDelegateV2());
            interpreter = Interpreter.fromBuffer(
              message.modelBytes,
              options: gpuOptions,
            );
            backendInfo = '🚀 GPU V2 Acceleration';
          } catch (_) {
            interpreter = null;
          }
        }

        // 2. Fallback sang XNNPack CPU ARM
        if (interpreter == null) {
          try {
            final xnnOptions = InterpreterOptions()
              ..threads = message.threadCount
              ..addDelegate(XNNPackDelegate());
            interpreter = Interpreter.fromBuffer(
              message.modelBytes,
              options: xnnOptions,
            );
            backendInfo = '⚡ XNNPack ARM (${message.threadCount} threads)';
          } catch (_) {
            interpreter = null;
          }
        }

        // 3. Fallback sang Standard Multithreaded CPU
        if (interpreter == null) {
          try {
            final cpuOptions = InterpreterOptions()..threads = message.threadCount;
            interpreter = Interpreter.fromBuffer(
              message.modelBytes,
              options: cpuOptions,
            );
            backendInfo = 'CPU (${message.threadCount} threads)';
          } catch (_) {
            interpreter = Interpreter.fromBuffer(message.modelBytes);
            backendInfo = 'Standard CPU';
          }
        }

        labels = message.labels;
        inputShape = interpreter!.getInputTensor(0).shape;
        outputShape = interpreter!.getOutputTensor(0).shape;
        isNchw = inputShape.length == 4 && inputShape[1] == 3;

        totalOutputElements = outputShape.reduce((a, b) => a * b);
        flatOutputBuffer = Float32List(totalOutputElements);
        letterboxBuffer = Float32List(3 * 640 * 640)
          ..fillRange(0, 3 * 640 * 640, 0.4470588);

        message.sendPort.send(_WorkerInitResult(
          success: true,
          backendInfo: backendInfo,
          inputShape: inputShape,
          outputShape: outputShape,
          isNchw: isNchw,
        ));
      } catch (e) {
        message.sendPort.send(_WorkerInitResult(
          success: false,
          backendInfo: 'None',
          error: e.toString(),
        ));
      }
    } else if (message is _FrameProcessMessage) {
      if (interpreter == null || labels == null || flatOutputBuffer == null) {
        mainSendPort.send(_FrameResultMessage(
          recognitions: [],
          preprocessMs: 0,
          inferenceMs: 0,
          postprocessMs: 0,
          totalMs: 0,
          statusText: 'Model chưa sẵn sàng',
        ));
        return;
      }

      final sw = Stopwatch()..start();
      try {
        final byteBuffer = message.planesData.materialize();
        final List<Uint8List> planeByteLists = [];
        int offset = 0;
        for (final len in message.planeLengths) {
          planeByteLists.add(Uint8List.view(byteBuffer, offset, len));
          offset += len;
        }

        const int targetSize = 640;

        // ── 1. Chuyển plane bytes sang Float32List Letterbox (Zero-Copy) ──
        final int tStartPrep = sw.elapsedMilliseconds;
        final processed = ImageUtils.planesToFloat32Letterbox(
          planeBytes: planeByteLists,
          bytesPerRow: message.bytesPerRow,
          bytesPerPixel: message.bytesPerPixel,
          srcWidth: message.width,
          srcHeight: message.height,
          targetWidth: targetSize,
          targetHeight: targetSize,
          isBgra: message.isBgra,
          nchw: isNchw,
          rotationDegrees: message.rotationDegrees,
          mirrorHorizontal: message.mirrorHorizontal,
          outputBuffer: letterboxBuffer,
        );
        final int prepMs = sw.elapsedMilliseconds - tStartPrep;

        // ── 2. Chạy inference TFLite trực tiếp vào flat output ByteBuffer (0 Allocation) ──
        final int tStartInf = sw.elapsedMilliseconds;
        interpreter!.run(processed.buffer.buffer, flatOutputBuffer!.buffer);
        final int infMs = sw.elapsedMilliseconds - tStartInf;

        // ── 3. Parse bounding boxes tối ưu (Early-Exit & Typed Detection) ──
        final int tStartPost = sw.elapsedMilliseconds;
        final detections = YoloParser.parse(
          flatOutputBuffer!,
          outputShape,
          0.25,
          targetSize,
          targetSize,
          letterbox: processed.letterbox,
        );

        // ── 4. Ánh xạ sang Recognition structs ──
        final List<Recognition> results = [];
        for (final det in detections) {
          if (det.classId >= 0 && det.classId < labels!.length) {
            results.add(Recognition(labels![det.classId], det.score, det.rect));
          }
        }
        final int postMs = sw.elapsedMilliseconds - tStartPost;
        final int totalMs = sw.elapsedMilliseconds;

        String status;
        if (results.isEmpty) {
          status = '⚡ Đang quét... | Inf: ${infMs}ms | Prep: ${prepMs}ms | Post: ${postMs}ms | Tot: ${totalMs}ms';
        } else {
          final top = results.first;
          status = '⚡ ${results.length} vật thể (${top.label} ${(top.confidence * 100).toStringAsFixed(0)}%) | Inf: ${infMs}ms | Prep: ${prepMs}ms | Post: ${postMs}ms';
        }

        mainSendPort.send(_FrameResultMessage(
          recognitions: results,
          preprocessMs: prepMs,
          inferenceMs: infMs,
          postprocessMs: postMs,
          totalMs: totalMs,
          statusText: status,
        ));
      } catch (e) {
        mainSendPort.send(_FrameResultMessage(
          recognitions: [],
          preprocessMs: 0,
          inferenceMs: 0,
          postprocessMs: 0,
          totalMs: 0,
          statusText: '❌ Lỗi xử lý: $e',
          error: e.toString(),
        ));
      }
    } else if (message == 'dispose') {
      try {
        interpreter?.close();
      } catch (_) {}
      workerReceivePort.close();
    }
  });
}
