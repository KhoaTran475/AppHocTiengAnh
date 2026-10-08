import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/vision/image_utils.dart';
import '../../../core/vision/vision_service.dart';
import '../widgets/vocabulary_detail_bottom_sheet.dart';

/// Màn hình quét camera nhận diện vật thể bằng YOLOv8n TFLite.
///
/// Yêu cầu đầu ra:
/// - Khoanh vùng vật thể trên camera (bounding box) với hiệu ứng glow
/// - Hiện tên vật thể + độ tin cậy
/// - Chỉ hiển thị detection >= 30% confidence (độ nhạy cao)
/// - Chạm vào vật thể để trượt lên Modal Bottom Sheet từ vựng IELTS Band 7.0 - 8.5
class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  final VisionService _visionService = VisionService();

  List<Recognition> _recognitions = [];
  bool _isCameraReady = false;
  String _debugInfo = 'Đang khởi tạo Camera & Model AI...';

  // Thời gian lần inference gần nhất để điều tiết tốc độ (throttling)
  DateTime _lastInferenceTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Giới hạn tần suất inference AI (~14 FPS) giúp UI isolate luôn duy trì 60 FPS mượt mà
  static const int _inferenceIntervalMs = 70;

  // Kích thước thực tế của camera preview (để căn chỉnh bounding box)
  Size? _previewSize;
  int _sensorOrientation = 90;

  /// Ngưỡng confidence tối thiểu để HIỂN THỊ trên UI (0.50 giúp loại bỏ hoàn toàn các phỏng đoán nhiễu và đoán mò).
  static const double _displayThreshold = 0.50;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initServices();
  }

  Future<void> _initServices() async {
    // Đăng ký callback nhận kết quả từ Background Worker Isolate
    _visionService.onDetections = (results, debugInfo) {
      if (!mounted) return;
      setState(() {
        _recognitions = results
            .where((r) => r.confidence >= _displayThreshold)
            .toList();
        _debugInfo = debugInfo;
      });
    };

    await _visionService.init();
    await _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _debugInfo = 'Không tìm thấy camera trên thiết bị');
        }
        return;
      }

      // Ưu tiên: 1. Camera ngoài (Webcam rời) -> 2. Camera sau -> 3. Camera đầu tiên
      final selectedCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.external,
        orElse: () => cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        ),
      );

      _sensorOrientation = selectedCamera.sensorOrientation;

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium, // 480p: tối ưu tốc độ xử lý frame
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      // Lưu kích thước preview để căn chỉnh bounding box chính xác
      _previewSize = _cameraController!.value.previewSize;

      // Bắt đầu stream xử lý từng frame hình ảnh
      _cameraController!.startImageStream(_onCameraFrame);

      setState(() {
        _isCameraReady = true;
        _debugInfo = _visionService.lastError;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _debugInfo = 'Lỗi khởi tạo camera: $e');
      }
    }
  }

  /// Callback nhận frame camera:
  /// Sao chép siêu nhanh sang DTO (<0.3ms) và đẩy sang Background Worker Isolate
  /// Hàm kết thúc NGAY TỨC THÌ để giải phóng buffer về cho camera driver, xóa bỏ 100% độ trễ (delay)
  void _onCameraFrame(CameraImage image) {
    if (_visionService.isBusy) return;

    final now = DateTime.now();
    if (now.difference(_lastInferenceTime).inMilliseconds <
        _inferenceIntervalMs) {
      return;
    }
    _lastInferenceTime = now;

    try {
      final payload = CameraFramePayload.fromCameraImage(
        image,
        _sensorOrientation,
      );
      _visionService.sendFrame(payload);
    } catch (_) {
      // Bỏ qua lỗi sao chép frame nếu có xung đột buffer tạm thời
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    _visionService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _cameraController?.stopImageStream().catchError((_) {});
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  /// Hiện Modal Bottom Sheet từ vựng IELTS khi tap vào vật thể
  void _showVocabularySheet(Recognition recognition) {
    VocabularyDetailBottomSheet.show(context, recognition);
  }

  @override
  Widget build(BuildContext context) {
    // Đang khởi tạo camera
    if (!_isCameraReady ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _debugInfo,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera Preview (lấp đầy màn hình) ──
          _buildCameraPreview(),

          // ── Bounding Boxes Overlay ──
          _buildBoundingBoxes(),

          // ── Smart Tap Detector (Xử lý chạm thông minh, ưu tiên vật thể cụ thể như điện thoại) ──
          _buildSmartTapDetector(),

          // ── Top Bar (nút quay lại + tiêu đề + trạng thái quét) ──
          _buildTopBar(),

          // ── Debug Overlay ──
          _buildDebugOverlay(),

          // ── Detection Count Badge (hướng dẫn tương tác) ──
          _buildDetectionBadge(),
        ],
      ),
    );
  }

  /// Camera preview widget chiếm toàn bộ màn hình, bọc trong RepaintBoundary để tối ưu GPU compositing
  Widget _buildCameraPreview() {
    return RepaintBoundary(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize!.height,
            height: _cameraController!.value.previewSize!.width,
            child: CameraPreview(_cameraController!),
          ),
        ),
      ),
    );
  }

  /// Vẽ bounding boxes lên camera preview, cô lập vẽ bằng RepaintBoundary
  Widget _buildBoundingBoxes() {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: BoundingBoxPainter(
              recognitions: _recognitions,
              previewSize: _previewSize,
              screenSize: Size(constraints.maxWidth, constraints.maxHeight),
            ),
          );
        },
      ),
    );
  }

  /// Widget bắt sự kiện chạm trên toàn màn hình Preview và giải mã tọa độ thông minh
  Widget _buildSmartTapDetector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) {
            _handleScreenTap(
              details.localPosition,
              Size(constraints.maxWidth, constraints.maxHeight),
            );
          },
          child: const SizedBox.expand(),
        );
      },
    );
  }

  /// Thuật toán Smart Tap Selection:
  /// Xử lý chính xác trường hợp chạm vào vật thể nhỏ (ví dụ điện thoại) nằm trên hoặc gần vật thể lớn (bàn, bàn phím)
  void _handleScreenTap(Offset tapPos, Size screenSize) {
    if (_recognitions.isEmpty) return;

    final candidates = <Map<String, dynamic>>[];

    for (final rec in _recognitions) {
      final rect = _mapBBoxToScreen(
        rec.boundingBox,
        screenSize.width,
        screenSize.height,
      );
      // Mở rộng vùng biên 15px để người dùng bấm trúng viền box vẫn nhận diện được
      final touchArea = rect.inflate(15.0);

      if (touchArea.contains(tapPos)) {
        final double distToCenter = (rect.center - tapPos).distance;
        final double area = rect.width * rect.height;

        candidates.add({
          'rec': rec,
          'rect': rect,
          'distance': distToCenter,
          'area': area,
          'confidence': rec.confidence,
        });
      }
    }

    if (candidates.isEmpty) {
      // Nếu chạm hơi chệch mép box: tìm kiếm box gần nhất trong bán kính 45px
      for (final rec in _recognitions) {
        final rect = _mapBBoxToScreen(
          rec.boundingBox,
          screenSize.width,
          screenSize.height,
        );
        final touchArea = rect.inflate(45.0);
        if (touchArea.contains(tapPos)) {
          final double distToCenter = (rect.center - tapPos).distance;
          candidates.add({
            'rec': rec,
            'rect': rect,
            'distance': distToCenter,
            'area': rect.width * rect.height,
            'confidence': rec.confidence,
          });
        }
      }
    }

    if (candidates.isEmpty) return;

    // Sắp xếp ưu tiên chọn vật thể:
    // 1. Box có diện tích nhỏ hơn được ưu tiên hàng đầu! (Vật thể cụ thể như 'cell phone' nhỏ hơn rất nhiều so với 'keyboard' hay 'diningtable')
    // 2. Nếu diện tích tương đương: Box có tâm gần đầu ngón tay chạm nhất
    // 3. Cuối cùng ưu tiên độ tin cậy (confidence)
    candidates.sort((a, b) {
      final double areaA = a['area'] as double;
      final double areaB = b['area'] as double;

      // Nếu 1 box nhỏ hơn đáng kể (diện tích < 65% box kia), ưu tiên box nhỏ hơn
      if ((areaA / areaB) < 0.65) return -1;
      if ((areaB / areaA) < 0.65) return 1;

      // Nếu diện tích xấp xỉ nhau: chọn box có tâm gần ngón tay nhất
      final double distA = a['distance'] as double;
      final double distB = b['distance'] as double;
      final distCmp = distA.compareTo(distB);
      if (distCmp != 0) return distCmp;

      return (b['confidence'] as double).compareTo(a['confidence'] as double);
    });

    final targetRec = candidates.first['rec'] as Recognition;
    _showVocabularySheet(targetRec);
  }

  /// Top bar với nút back và trạng thái nhận diện
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 16,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Text(
                'AI Scan to Learn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Trạng thái quét
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _recognitions.isNotEmpty
                    ? const Color(0xFF10B981).withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _recognitions.isNotEmpty
                        ? Icons.check_circle_rounded
                        : Icons.radar_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _recognitions.isNotEmpty ? 'Detected' : 'Scanning...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Debug overlay hiển thị log model và confidence
  Widget _buildDebugOverlay() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 70,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _debugInfo,
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 12,
            fontFamily: 'monospace',
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Badge hướng dẫn người dùng chạm vào vật thể
  Widget _buildDetectionBadge() {
    final hasDetections = _recognitions.isNotEmpty;
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: hasDetections
                  ? const Color(0xFF10B981).withValues(alpha: 0.7)
                  : AppColors.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasDetections
                    ? Icons.touch_app_rounded
                    : Icons.camera_alt_rounded,
                color: hasDetections
                    ? const Color(0xFF10B981)
                    : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                hasDetections
                    ? 'Chạm vào vật thể để học từ vựng (${_recognitions.length})'
                    : 'Hướng camera vào vật thể xung quanh...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chuyển đổi tọa độ normalized [0,1] sang pixel trên màn hình khớp với BoxFit.cover
  Rect _mapBBoxToScreen(Rect normalizedBox, double screenW, double screenH) {
    return BoundingBoxPainter.mapBoxToScreen(
      normalizedBox,
      Size(screenW, screenH),
      _previewSize,
    );
  }
}

/// Custom painter vẽ bounding boxes + labels viền emerald trên camera preview.
class BoundingBoxPainter extends CustomPainter {
  final List<Recognition> recognitions;
  final Size? previewSize;
  final Size screenSize;

  BoundingBoxPainter({
    required this.recognitions,
    required this.previewSize,
    required this.screenSize,
  });

  /// Ánh xạ tọa độ chuẩn hóa [0, 1] sang màn hình có tính đến BoxFit.cover của CameraPreview
  static Rect mapBoxToScreen(
    Rect normalizedBox,
    Size screenSize,
    Size? previewSize,
  ) {
    if (previewSize == null) {
      return Rect.fromLTRB(
        normalizedBox.left * screenSize.width,
        normalizedBox.top * screenSize.height,
        normalizedBox.right * screenSize.width,
        normalizedBox.bottom * screenSize.height,
      );
    }

    // Trên Android portrait, previewSize có width là chiều dài (vd 720) và height là chiều rộng (vd 480)
    final double camW = previewSize.height;
    final double camH = previewSize.width;

    final double camAspect = camW / camH;
    final double screenAspect = screenSize.width / screenSize.height;

    double scale;
    double dx = 0.0;
    double dy = 0.0;

    if (screenAspect < camAspect) {
      // Màn hình hẹp hơn camera -> khít chiều cao, crop hai bên chiều rộng
      scale = screenSize.height / camH;
      final double scaledW = camW * scale;
      dx = (scaledW - screenSize.width) / 2.0;
    } else {
      // Màn hình rộng hơn camera -> khít chiều rộng, crop chiều cao
      scale = screenSize.width / camW;
      final double scaledH = camH * scale;
      dy = (scaledH - screenSize.height) / 2.0;
    }

    final double renderW = camW * scale;
    final double renderH = camH * scale;

    return Rect.fromLTRB(
      normalizedBox.left * renderW - dx,
      normalizedBox.top * renderH - dy,
      normalizedBox.right * renderW - dx,
      normalizedBox.bottom * renderH - dy,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final rec in recognitions) {
      // Ánh xạ chuẩn sang tọa độ màn hình
      final rect = mapBoxToScreen(rec.boundingBox, size, previewSize);

      // Màu sắc viền: Xanh lục bảo nổi bật
      const Color accentColor = Color(0xFF10B981);

      // ── 1. Vẽ bounding box ──
      final boxPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      // Viền glow effect
      final glowPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(rRect, glowPaint);
      canvas.drawRRect(rRect, boxPaint);

      // ── 2. Vẽ label background ──
      final labelText =
          '${rec.label.toUpperCase()}  ${(rec.confidence * 100).toStringAsFixed(0)}%';

      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelWidth = textPainter.width + 16;
      final labelHeight = textPainter.height + 8;

      // Label nằm phía trên bounding box (nếu sát mép trên thì đưa vào trong)
      final double labelTop = (rect.top - labelHeight - 2 >= 0)
          ? (rect.top - labelHeight - 2)
          : (rect.top + 2);

      final labelRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(rect.left, labelTop, labelWidth, labelHeight),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
        bottomRight: const Radius.circular(8),
        bottomLeft: const Radius.circular(8),
      );

      final labelBgPaint = Paint()..color = accentColor;
      canvas.drawRRect(labelRect, labelBgPaint);

      // Vẽ text label
      textPainter.paint(canvas, Offset(rect.left + 8, labelTop + 4));

      // ── 3. Corner markers (tạo hiệu ứng viewfinder quét) ──
      _drawCornerMarkers(canvas, rect);
    }
  }

  /// Vẽ 4 góc marker kiểu "viewfinder" cho hiệu ứng scan chuyên nghiệp
  void _drawCornerMarkers(Canvas canvas, Rect rect) {
    final markerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const double len = 20;

    // Top-left
    canvas.drawLine(
      rect.topLeft,
      Offset(rect.left + len, rect.top),
      markerPaint,
    );
    canvas.drawLine(
      rect.topLeft,
      Offset(rect.left, rect.top + len),
      markerPaint,
    );

    // Top-right
    canvas.drawLine(
      rect.topRight,
      Offset(rect.right - len, rect.top),
      markerPaint,
    );
    canvas.drawLine(
      rect.topRight,
      Offset(rect.right, rect.top + len),
      markerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      rect.bottomLeft,
      Offset(rect.left + len, rect.bottom),
      markerPaint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      Offset(rect.left, rect.bottom - len),
      markerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      rect.bottomRight,
      Offset(rect.right - len, rect.bottom),
      markerPaint,
    );
    canvas.drawLine(
      rect.bottomRight,
      Offset(rect.right, rect.bottom - len),
      markerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.recognitions != recognitions;
  }
}
