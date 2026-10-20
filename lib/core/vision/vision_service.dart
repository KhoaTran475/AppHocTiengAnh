import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
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

/// DTO truyền dữ liệu nhận diện dạng nguyên thủy giữa các Isolate
class RecognitionRaw {
  final String label;
  final double confidence;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const RecognitionRaw({
    required this.label,
    required this.confidence,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
}

class _WorkerInitParams {
  final Uint8List modelBytes;
  final List<String> labels;
  final SendPort sendPort;

  const _WorkerInitParams({
    required this.modelBytes,
    required this.labels,
    required this.sendPort,
  });
}

class _WorkerOutput {
  final List<RecognitionRaw> recognitions;
  final double maxScore;
  final String? error;

  const _WorkerOutput({
    required this.recognitions,
    required this.maxScore,
    this.error,
  });
}

/// Entry point cho Background Worker Isolate
void _visionWorkerEntryPoint(_WorkerInitParams params) async {
  final commandPort = ReceivePort();
  params.sendPort.send(commandPort.sendPort);

  try {
    final options = InterpreterOptions()..threads = 4;
    final interpreter = Interpreter.fromBuffer(
      params.modelBytes,
      options: options,
    );
    interpreter.allocateTensors();

    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;
    final bool isNchw = inputShape.length == 4 && inputShape[1] == 3;
    final labels = params.labels;
    const int targetSize = 640;

    await for (final message in commandPort) {
      if (message is CameraFramePayload) {
        try {
          final processed = ImageUtils.payloadToFloat32Letterbox(
            message,
            targetSize,
            targetSize,
            nchw: isNchw,
          );

          interpreter.getInputTensor(0).setTo(processed.buffer.buffer);
          interpreter.invoke();

          final Float32List flatOutput =
              interpreter.getOutputTensor(0).data.buffer.asFloat32List();

          final parsedBoxes = YoloParser.parse(
            flatOutput,
            outputShape,
            0.25,
            targetSize,
            targetSize,
            letterbox: processed.letterbox,
          );

          final List<RecognitionRaw> recognitions = [];
          for (final box in parsedBoxes) {
            final int classId = box['classId'] as int;
            final double score = box['score'] as double;
            final Rect rect = box['rect'] as Rect;

            if (classId >= 0 && classId < labels.length) {
              recognitions.add(RecognitionRaw(
                label: labels[classId],
                confidence: score,
                left: rect.left,
                top: rect.top,
                right: rect.right,
                bottom: rect.bottom,
              ));
            }
          }

          params.sendPort.send(_WorkerOutput(
            recognitions: recognitions,
            maxScore: YoloParser.lastGlobalMaxScore,
          ));
        } catch (e) {
          params.sendPort.send(_WorkerOutput(
            recognitions: [],
            maxScore: 0.0,
            error: e.toString(),
          ));
        }
      } else if (message == 'DISPOSE') {
        interpreter.close();
        commandPort.close();
        break;
      }
    }
  } catch (e) {
    params.sendPort.send(_WorkerOutput(
      recognitions: [],
      maxScore: 0.0,
      error: 'Worker init error: $e',
    ));
  }
}

/// Service quản lý model YOLOv8n TFLite chạy hoàn toàn trong Background Worker Isolate
class VisionService {
  Isolate? _workerIsolate;
  SendPort? _workerSendPort;
  ReceivePort? _workerReceivePort;

  bool _isProcessing = false;
  bool _isReady = false;
  String lastError = 'Đang khởi tạo AI Vision Worker...';

  bool get isBusy => _isProcessing || !_isReady;

  /// Callback nhận kết quả nhận diện từ Worker Isolate về Main Thread
  void Function(List<Recognition> results, String debugInfo)? onDetections;

  /// Khởi tạo Background Worker Isolate độc lập
  Future<void> init() async {
    try {
      final modelByteData = await rootBundle.load('assets/models/yolov8n.tflite');
      final modelBytes = modelByteData.buffer.asUint8List();

      final labelData = await rootBundle.loadString('assets/models/labels.txt');
      final labels = labelData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      _workerReceivePort = ReceivePort();
      final initCompleter = Completer<SendPort>();

      _workerReceivePort!.listen((message) {
        if (message is SendPort) {
          if (!initCompleter.isCompleted) {
            initCompleter.complete(message);
          }
        } else if (message is _WorkerOutput) {
          _handleWorkerOutput(message);
        }
      });

      _workerIsolate = await Isolate.spawn(
        _visionWorkerEntryPoint,
        _WorkerInitParams(
          modelBytes: modelBytes,
          labels: labels,
          sendPort: _workerReceivePort!.sendPort,
        ),
      );

      _workerSendPort = await initCompleter.future;
      _isReady = true;
      lastError = '✅ AI Vision Worker (Isolate) Sẵn Sàng | 4 threads | ${labels.length} classes';
      log(lastError);
    } catch (e) {
      lastError = '❌ Load model thất bại: $e';
      log(lastError);
    }
  }

  /// Gửi frame sang Background Isolate trong <0.1ms, không chặn UI Main Thread
  void sendFrame(CameraFramePayload payload) {
    if (!_isReady || _isProcessing || _workerSendPort == null) return;
    _isProcessing = true;
    _workerSendPort!.send(payload);
  }

  /// Xử lý kết quả trả về từ Worker Isolate trên Main Thread
  void _handleWorkerOutput(_WorkerOutput output) {
    _isProcessing = false;

    if (output.error != null) {
      lastError = '❌ Lỗi xử lý: ${output.error}';
      onDetections?.call([], lastError);
      return;
    }

    final results = output.recognitions.map((r) {
      return Recognition(
        r.label,
        r.confidence,
        Rect.fromLTRB(r.left, r.top, r.right, r.bottom),
      );
    }).toList();

    if (results.isEmpty) {
      lastError =
          'Đang quét... Max score: ${(output.maxScore * 100).toStringAsFixed(1)}%';
    } else {
      final top = results.first;
      lastError =
          'Tìm thấy ${results.length} vật thể | ${top.label} ${(top.confidence * 100).toStringAsFixed(0)}%';
    }

    onDetections?.call(results, lastError);
  }

  void dispose() {
    _workerSendPort?.send('DISPOSE');
    _workerReceivePort?.close();
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _workerSendPort = null;
    _workerReceivePort = null;
    _isReady = false;
  }
}
