import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:camera/camera.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/vision/vision_service.dart';
import '../../../core/vision/image_utils.dart';
import '../../../data/datasources/api_service.dart';
import '../widgets/vocabulary_detail_bottom_sheet.dart';

/// Đối tượng vật thể được theo dõi liên tục qua các frame (Temporal Object Tracker)
class _TrackedObject {
  String label;
  double confidence;
  Rect currentRect; // Tọa độ hiển thị hiện tại trên màn hình (được nội suy 60 FPS)
  Rect targetRect; // Tọa độ đích từ lần YOLO inference mới nhất
  int hitStreak; // Số frame liên tiếp xuất hiện
  int missedFrames; // Số frame bị mất dấu tạm thời
  double opacity; // Độ mờ dần (fade in / fade out mượt mà)

  _TrackedObject({
    required this.label,
    required this.confidence,
    required this.currentRect,
    required this.targetRect,
    this.hitStreak = 1,
    this.missedFrames = 0,
    this.opacity = 0.85,
  });
}

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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  final VisionService _visionService = VisionService();

  // ValueNotifier thay thế setState để tránh rebuild toàn bộ widget tree mỗi frame
  final ValueNotifier<List<Recognition>> _recognitionsNotifier =
      ValueNotifier<List<Recognition>>([]);
  final ValueNotifier<String> _debugInfoNotifier =
      ValueNotifier<String>('Đang khởi tạo Camera & Model AI...');

  // Danh sách các vật thể đang được theo dõi (Object Tracking + EMA + Hysteresis)
  final List<_TrackedObject> _trackedObjects = [];
  Ticker? _smoothTicker;

  bool _isDetecting = false;
  bool _isCameraReady = false;
  bool _isDisposed = false;

  // Trạng thái Chế độ Quét Chủ động (Snapshot / Freeze Frame)
  bool _isFrozen = false;
  bool _isTorchOn = false;
  ui.Image? _frozenUiImage;
  CameraImage? _lastCameraFrame;
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;

  // Trạng thái Quét chuyên sâu với Ollama LLaVA-Phi3 (Deep Scan)
  bool _isDeepScanning = false;
  Offset? _tapScanPoint;

  // Điều tiết tốc độ khung hình (Frame Throttling / FPS Limiter)
  DateTime _lastInferenceTime = DateTime.fromMillisecondsSinceEpoch(0);
  /// Khoảng cách tối thiểu giữa 2 lần chạy AI inference trên Isolate (75ms ~ 13 FPS AI).
  /// Vì toàn bộ YUV Letterbox + TFLite chạy trên Worker Isolate nên UI luôn giữ 60 FPS độc lập.
  static const int _inferenceThrottleMs = 75;

  // Kích thước thực tế của camera preview (để căn chỉnh bounding box)
  Size? _previewSize;

  /// Ngưỡng Hysteresis:
  /// - Vật thể mới cần >= 0.40 để bắt đầu hiển thị (chống nhiễu).
  /// - Vật thể đang được theo dõi chỉ cần >= 0.26 để duy trì (chống nhấp nháy).
  static const double _enterThreshold = 0.40;
  static const double _keepThreshold = 0.26;
  static const int _maxMissedFrames = 4;

  /// Lấy góc xoay cảm biến của camera hiện tại (Camera sau: 90°, Camera trước: 270°)
  int get _sensorOrientation =>
      _cameraController?.description.sensorOrientation ?? 90;

  /// Kiểm tra có phải đang dùng Camera trước hay không (CameraPreview mặc định lật gương ngang cho camera trước)
  bool get _isFrontCamera =>
      _cameraController?.description.lensDirection == CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ticker 60 FPS nội suy vị trí Bounding Box mượt mà giữa các chu kỳ AI Inference
    _smoothTicker = createTicker(_onSmoothTick)..start();
    _initServices();
  }

  /// Vòng lặp 60 FPS nội suy tuyến tính có trọng số (Adaptive EMA Interpolation)
  void _onSmoothTick(Duration elapsed) {
    if (_isDisposed || !mounted || _isFrozen || _trackedObjects.isEmpty) return;

    bool hasChanged = false;
    for (final obj in _trackedObjects) {
      final double dx = (obj.targetRect.center.dx - obj.currentRect.center.dx).abs();
      final double dy = (obj.targetRect.center.dy - obj.currentRect.center.dy).abs();
      final double dist = math.sqrt(dx * dx + dy * dy);

      // Adaptive Alpha:
      // Nếu người dùng lia máy nhanh (dist lớn) -> tăng alpha để bám sát ngay lập tức
      // Nếu giữ máy đứng yên (dist nhỏ) -> giảm alpha để triệt tiêu hoàn toàn rung lắc vi mô
      final double alpha = (dist > 0.08)
          ? 0.45
          : (dist > 0.02 ? 0.28 : 0.16);

      if (dist > 0.0008 ||
          (obj.targetRect.width - obj.currentRect.width).abs() > 0.0008 ||
          (obj.targetRect.height - obj.currentRect.height).abs() > 0.0008) {
        obj.currentRect = Rect.lerp(obj.currentRect, obj.targetRect, alpha)!;
        hasChanged = true;
      }

      // Nội suy độ mờ (Opacity fade-in / fade-out)
      final double targetOpacity = obj.missedFrames == 0
          ? 1.0
          : (1.0 - (obj.missedFrames / (_maxMissedFrames + 1))).clamp(0.25, 1.0);
      if ((obj.opacity - targetOpacity).abs() > 0.01) {
        obj.opacity += (targetOpacity - obj.opacity) * 0.25;
        hasChanged = true;
      }
    }

    if (hasChanged) {
      _publishTrackedRecognitions();
    }
  }

  /// Cập nhật danh sách vật thể theo dõi khi có kết quả mới từ Worker Isolate
  void _updateTrackerWithDetections(List<Recognition> rawDetections) {
    final Set<int> matchedTrackIndices = {};

    // Sắp xếp kết quả mới giảm dần theo độ tin cậy
    final sortedDetections = List<Recognition>.from(rawDetections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    for (final det in sortedDetections) {
      int bestIdx = -1;
      double bestScore = 0.0;

      for (int i = 0; i < _trackedObjects.length; i++) {
        if (matchedTrackIndices.contains(i)) continue;
        final tracked = _trackedObjects[i];

        final double iou = _computeIoU(det.boundingBox, tracked.targetRect);
        final double centerDist = (det.boundingBox.center - tracked.targetRect.center).distance;

        if (det.label == tracked.label) {
          // Cùng nhãn: khớp nếu IoU >= 0.20 hoặc tâm gần nhau (< 0.22 màn hình)
          final double matchScore = iou + (centerDist < 0.22 ? (0.22 - centerDist) * 2.0 : 0.0);
          if ((iou >= 0.18 || centerDist < 0.20) && matchScore > bestScore) {
            bestScore = matchScore;
            bestIdx = i;
          }
        } else if (iou >= 0.60 && det.confidence > tracked.confidence + 0.12) {
          // Cùng vị trí vật thể nhưng model cập nhật nhãn chính xác hơn rõ rệt
          if (iou > bestScore) {
            bestScore = iou;
            bestIdx = i;
          }
        }
      }

      if (bestIdx != -1) {
        // Cập nhật vật thể đang theo dõi (áp dụng ngưỡng duy trì _keepThreshold)
        if (det.confidence >= _keepThreshold) {
          matchedTrackIndices.add(bestIdx);
          final tracked = _trackedObjects[bestIdx];
          tracked.label = det.label;
          tracked.confidence = tracked.confidence * 0.35 + det.confidence * 0.65;
          tracked.targetRect = det.boundingBox;
          tracked.hitStreak++;
          tracked.missedFrames = 0;
        }
      } else {
        // Thêm vật thể mới (phải vượt qua ngưỡng vào _enterThreshold)
        if (det.confidence >= _enterThreshold) {
          _trackedObjects.add(
            _TrackedObject(
              label: det.label,
              confidence: det.confidence,
              currentRect: det.boundingBox,
              targetRect: det.boundingBox,
              hitStreak: 1,
              missedFrames: 0,
              opacity: 0.9,
            ),
          );
          matchedTrackIndices.add(_trackedObjects.length - 1);
        }
      }
    }

    // Tăng bộ đếm missedFrames cho các vật thể không xuất hiện trong frame này
    for (int i = _trackedObjects.length - 1; i >= 0; i--) {
      if (!matchedTrackIndices.contains(i)) {
        _trackedObjects[i].missedFrames++;
        if (_trackedObjects[i].missedFrames > _maxMissedFrames) {
          _trackedObjects.removeAt(i);
        }
      }
    }

    _publishTrackedRecognitions();
  }

  /// Xuất danh sách _trackedObjects ra ValueNotifier cho UI vẽ
  void _publishTrackedRecognitions() {
    if (!mounted || _isDisposed) return;
    final List<Recognition> displayList = _trackedObjects
        .map(
          (t) => Recognition(
            t.label,
            t.confidence,
            t.currentRect,
            opacity: t.opacity,
          ),
        )
        .toList();
    _recognitionsNotifier.value = displayList;
  }

  double _computeIoU(Rect a, Rect b) {
    final double interLeft = math.max(a.left, b.left);
    final double interTop = math.max(a.top, b.top);
    final double interRight = math.min(a.right, b.right);
    final double interBottom = math.min(a.bottom, b.bottom);
    if (interRight <= interLeft || interBottom <= interTop) return 0.0;
    final double interArea = (interRight - interLeft) * (interBottom - interTop);
    final double unionArea = a.width * a.height + b.width * b.height - interArea;
    return unionArea > 0 ? interArea / unionArea : 0.0;
  }

  Future<void> _initServices() async {
    await _visionService.init();
    await _initCamera();
  }

  Future<void> _initCamera() async {
    if (_availableCameras.isEmpty) {
      _availableCameras = await availableCameras();
    }
    if (_availableCameras.isEmpty) {
      if (mounted) {
        _debugInfoNotifier.value = 'Không tìm thấy camera trên thiết bị';
      }
      return;
    }

    final cameraDesc = _availableCameras[_currentCameraIndex % _availableCameras.length];

    _cameraController = CameraController(
      cameraDesc,
      ResolutionPreset.high, // 720p HD: hình ảnh preview và freeze sắc nét, không bị vỡ hạt pixel
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted || _isDisposed) return;

      // Lưu kích thước preview để căn chỉnh bounding box chính xác
      _previewSize = _cameraController!.value.previewSize;

      // Bắt đầu stream xử lý từng frame hình ảnh
      _cameraController!.startImageStream(_onCameraFrame);

      setState(() {
        _isCameraReady = true;
        _isFrozen = false;
      });
      _debugInfoNotifier.value = _visionService.lastError;
    } catch (e) {
      if (mounted) {
        _debugInfoNotifier.value = 'Lỗi khởi tạo camera: $e';
      }
    }
  }

  /// Đóng băng / tiếp tục khung hình (Snapshot Freeze Mode)
  /// Sử dụng ảnh chụp trực tiếp từ frame Camera thay vì pausePreview() phần cứng
  /// giúp triệt tiêu 100% hiện tượng vỡ hạt pixel, rác texture và crash camera trên Android.
  Future<void> _toggleFreezeFrame() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    if (!_isFrozen) {
      // 1. Chuyển frame camera gần nhất sang ui.Image HD sắc nét
      // Truyền chuẩn xác sensorOrientation (270° cho camera trước, 90° cho camera sau)
      // và mirrorHorizontal cho camera trước để ảnh không bao giờ bị đảo ngược!
      if (_lastCameraFrame != null) {
        try {
          final frozen = await ImageUtils.convertCameraImageToUiImage(
            _lastCameraFrame!,
            rotationDegrees: _sensorOrientation,
            mirrorHorizontal: _isFrontCamera,
          );
          _frozenUiImage?.dispose();
          _frozenUiImage = frozen;
        } catch (e) {
          debugPrint('Lỗi tạo freeze frame image: $e');
        }
      }

      setState(() {
        _isFrozen = true;
      });
      _debugInfoNotifier.value =
          '📸 Đã cố định khung hình | Nhấn vào vật thể hoặc thẻ từ vựng bên dưới';
    } else {
      // 2. Tiếp tục Live Scan
      _frozenUiImage?.dispose();
      _frozenUiImage = null;
      setState(() {
        _isFrozen = false;
      });
      _debugInfoNotifier.value = '⚡ Đang quét Live...';
    }
  }

  /// Bật/tắt đèn flash
  Future<void> _toggleTorch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final nextState = !_isTorchOn;
      await _cameraController!.setFlashMode(nextState ? FlashMode.torch : FlashMode.off);
      setState(() {
        _isTorchOn = nextState;
      });
    } catch (_) {}
  }

  /// Đổi camera trước / sau
  Future<void> _flipCamera() async {
    if (_availableCameras.length < 2) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _availableCameras.length;
    _isCameraReady = false;
    _frozenUiImage?.dispose();
    _frozenUiImage = null;
    _trackedObjects.clear();
    _recognitionsNotifier.value = const [];

    final controller = _cameraController;
    _cameraController = null;
    controller?.stopImageStream().catchError((_) {});
    await controller?.dispose();

    if (mounted) setState(() {});
    await _initCamera();
  }

  /// Callback xử lý frame camera chạy inference qua YOLOv8n với Throttling & Zero-Rebuild
  Future<void> _onCameraFrame(CameraImage image) async {
    if (_isDisposed || !mounted) return;

    // Lưu frame mới nhất để snapshot tức thì khi nhấn Freeze
    _lastCameraFrame = image;

    // Không inference khi đang ở trạng thái đóng băng ảnh
    if (_isFrozen) return;

    final now = DateTime.now();
    // Bỏ qua frame nếu đang bận inference hoặc chưa đủ thời gian giãn cách throttle
    if (_isDetecting ||
        now.difference(_lastInferenceTime).inMilliseconds < _inferenceThrottleMs) {
      return;
    }

    _isDetecting = true;
    _lastInferenceTime = now;

    try {
      final results = await _visionService.processImage(
        image,
        rotationDegrees: _sensorOrientation,
        mirrorHorizontal: _isFrontCamera,
      );
      if (mounted && !_isFrozen) {
        // Cập nhật qua Object Tracker (Adaptive EMA + Hysteresis)
        _updateTrackerWithDetections(results);
        _debugInfoNotifier.value = _visionService.lastError;
      }
    } catch (e) {
      if (mounted) {
        _debugInfoNotifier.value = 'Lỗi inference: $e';
      }
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _smoothTicker?.stop();
    _smoothTicker?.dispose();
    _smoothTicker = null;
    _frozenUiImage?.dispose();
    _frozenUiImage = null;

    final controller = _cameraController;
    _cameraController = null;
    controller?.stopImageStream().catchError((_) {});
    controller?.dispose();

    _visionService.dispose();
    _recognitionsNotifier.dispose();
    _debugInfoNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    // QUAN TRỌNG: Chỉ dispose camera khi app thực sự rơi vào PAUSED (ẩn xuống nền / Home)
    // Tuyệt đối KHÔNG dispose ở INACTIVE (vì mở BottomSheet, bàn phím hay dialog sẽ gây crash camera disposed!)
    if (state == AppLifecycleState.paused) {
      final controller = _cameraController;
      _cameraController = null;
      controller?.stopImageStream().catchError((_) {});
      controller?.dispose();
      _isCameraReady = false;
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        _initCamera();
      }
    }
  }

  /// Hiện Modal Bottom Sheet từ vựng IELTS khi tap vào vật thể
  void _showVocabularySheet(Recognition recognition) {
    // Nếu đang Live, tự động đóng băng khung hình để người dùng tập trung học từ vựng
    if (!_isFrozen && _lastCameraFrame != null) {
      ImageUtils.convertCameraImageToUiImage(
        _lastCameraFrame!,
        rotationDegrees: _sensorOrientation,
        mirrorHorizontal: _isFrontCamera,
      ).then((frozen) {
        if (mounted && !_isDisposed) {
          _frozenUiImage?.dispose();
          _frozenUiImage = frozen;
          setState(() {
            _isFrozen = true;
          });
        }
      }).catchError((_) {});
    }

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
                child: ValueListenableBuilder<String>(
                  valueListenable: _debugInfoNotifier,
                  builder: (context, debugInfo, _) {
                    return Text(
                      debugInfo,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    );
                  },
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

          // ── Bounding Boxes Overlay (RepaintBoundary tách biệt lớp render) ──
          _buildBoundingBoxes(),

          // ── Smart Tap Detector (Xử lý chạm thông minh, ưu tiên vật thể cụ thể như điện thoại) ──
          _buildSmartTapDetector(),

          // ── Top Bar (nút quay lại + tiêu đề + trạng thái quét) ──
          _buildTopBar(),

          // ── Banner thông báo khi đang đóng băng khung hình (Freeze Banner) ──
          if (_isFrozen) _buildFrozenBanner(),

          // ── Debug Overlay đo lường độ trễ ──
          _buildDebugOverlay(),

          // ── Thanh cuộn danh sách từ vựng IELTS của các vật thể phát hiện được ──
          _buildDetectedChipsCarousel(),

          // ── Hiệu ứng Radar Scanner khi đang quét chuyên sâu bằng Ollama LLaVA-Phi3 ──
          _buildDeepScanningOverlay(),

          // ── Bộ nút điều khiển Camera (Đèn Flash, Deep Scan Phi-3, Snapshot, Đổi Camera) ──
          _buildBottomControls(),
        ],
      ),
    );
  }


  /// Camera preview widget chiếm toàn bộ màn hình
  /// Khi ở chế độ Đóng băng (_isFrozen), hiển thị ảnh chụp tĩnh HD thay vì hardware texture
  /// nhằm tránh hoàn toàn hiện tượng vỡ hạt pixel và rác bộ nhớ của Android SurfaceTexture.
  Widget _buildCameraPreview() {
    if (_isFrozen && _frozenUiImage != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _frozenUiImage!.width.toDouble(),
            height: _frozenUiImage!.height.toDouble(),
            child: RawImage(
              image: _frozenUiImage,
              fit: BoxFit.fill,
            ),
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize!.height,
          height: _cameraController!.value.previewSize!.width,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  /// Vẽ bounding boxes lên camera preview với RepaintBoundary & ValueListenableBuilder
  Widget _buildBoundingBoxes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return RepaintBoundary(
          child: ValueListenableBuilder<List<Recognition>>(
            valueListenable: _recognitionsNotifier,
            builder: (context, recognitions, _) {
              return CustomPaint(
                size: size,
                painter: BoundingBoxPainter(
                  recognitions: recognitions,
                  previewSize: _previewSize,
                  screenSize: size,
                ),
              );
            },
          ),
        );
      },
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
  /// Xử lý chính xác: Nếu chạm trúng box YOLO -> Mở ngay từ vựng YOLO
  /// Nếu chạm vào điểm bất kỳ khác -> Tự động kích hoạt Quét AI Chuyên Sâu Ollama LLaVA-Phi3 (Tap-to-Scan)
  void _handleScreenTap(Offset tapPos, Size screenSize) {
    if (_isDeepScanning) return;
    final currentRecs = _recognitionsNotifier.value;
    if (currentRecs.isEmpty) {
      // Không có nhãn YOLO nào trên màn hình -> Quét chuyên sâu với Ollama Phi-3
      _performDeepScanAtTap(tapPos, screenSize);
      return;
    }

    final candidates = <Map<String, dynamic>>[];

    for (final rec in currentRecs) {
      final rect = _mapBBoxToScreen(rec.boundingBox, screenSize.width, screenSize.height);
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
      for (final rec in currentRecs) {
        final rect = _mapBBoxToScreen(rec.boundingBox, screenSize.width, screenSize.height);
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

    if (candidates.isEmpty) {
      // Không chạm trúng bất kỳ bounding box nào của YOLO (vật thể ngoài 80 nhãn)
      // -> Kích hoạt Quét chuyên sâu mở rộng với Ollama LLaVA-Phi3
      _performDeepScanAtTap(tapPos, screenSize);
      return;
    }

    // Sắp xếp ưu tiên chọn vật thể:
    candidates.sort((a, b) {
      final double areaA = a['area'] as double;
      final double areaB = b['area'] as double;

      if ((areaA / areaB) < 0.65) return -1;
      if ((areaB / areaA) < 0.65) return 1;

      final double distA = a['distance'] as double;
      final double distB = b['distance'] as double;
      final distCmp = distA.compareTo(distB);
      if (distCmp != 0) return distCmp;

      return (b['confidence'] as double).compareTo(a['confidence'] as double);
    });

    final targetRec = candidates.first['rec'] as Recognition;
    _showVocabularySheet(targetRec);
  }

  /// Quét AI chuyên sâu bằng Ollama LLaVA-Phi3 tại điểm chạm (Tap-to-Scan)
  Future<void> _performDeepScanAtTap(Offset tapPos, Size screenSize) async {
    if (_isDeepScanning) return;
    if (_lastCameraFrame == null && _frozenUiImage == null) return;

    // Tự động đóng băng khung hình để người dùng giữ vững vật thể
    if (!_isFrozen && _lastCameraFrame != null) {
      try {
        final frozen = await ImageUtils.convertCameraImageToUiImage(
          _lastCameraFrame!,
          rotationDegrees: _sensorOrientation,
          mirrorHorizontal: _isFrontCamera,
        );
        if (mounted && !_isDisposed) {
          _frozenUiImage?.dispose();
          _frozenUiImage = frozen;
          setState(() {
            _isFrozen = true;
          });
        }
      } catch (_) {}
    }

    setState(() {
      _isDeepScanning = true;
      _tapScanPoint = tapPos;
    });
    _debugInfoNotifier.value = '🧠 Ollama LLaVA-Phi3 đang phân tích vật thể...';

    try {
      Uint8List compressedJpg;
      if (_frozenUiImage != null) {
        compressedJpg = await ImageUtils.cropAndCompressRoiFromUiImage(
          uiImage: _frozenUiImage!,
          tapPos: tapPos,
          screenSize: screenSize,
          cropAreaRatio: 0.36,
          maxDimension: 768,
          quality: 80,
        );
      } else {
        compressedJpg = await ImageUtils.cropAndCompressRoiFromCameraImage(
          cameraImage: _lastCameraFrame!,
          tapPos: tapPos,
          screenSize: screenSize,
          cropAreaRatio: 0.36,
          maxDimension: 768,
          quality: 80,
          rotationDegrees: _sensorOrientation,
          mirrorHorizontal: _isFrontCamera,
        );
      }

      final mapping = await ApiService.instance.deepScanObject(compressedJpg);
      if (!mounted || _isDisposed) return;

      setState(() {
        _isDeepScanning = false;
        _tapScanPoint = null;
      });
      _debugInfoNotifier.value =
          '✅ Hoàn tất nhận diện: ${mapping.commonWord} (${mapping.academicWord})';

      // Mở Bottom Sheet với từ vựng IELTS học thuật chi tiết
      VocabularyDetailBottomSheet.showWithMapping(context, mapping);
    } catch (e) {
      if (!mounted || _isDisposed) return;
      setState(() {
        _isDeepScanning = false;
        _tapScanPoint = null;
      });
      _debugInfoNotifier.value = '⚠️ Lỗi Ollama Deep Scan: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi phân tích chuyên sâu: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Quét AI chuyên sâu toàn khung hình
  Future<void> _performFullDeepScan() async {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    await _performDeepScanAtTap(center, size);
  }


  /// Top bar với nút back và trạng thái nhận diện (Lắng nghe ValueNotifier)
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
            colors: [
              Colors.black.withValues(alpha: 0.75),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Text(
                'AI Scan to Learn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            // Chế độ Quét Live / Snapshot
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _isFrozen
                    ? const Color(0xFFD97706).withValues(alpha: 0.9)
                    : const Color(0xFF10B981).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isFrozen ? Colors.amberAccent : const Color(0xFF10B981),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isFrozen ? Icons.pause_circle_rounded : Icons.fiber_manual_record_rounded,
                    color: _isFrozen ? Colors.white : const Color(0xFF34D399),
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isFrozen ? 'PAUSED' : 'LIVE AI',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Trạng thái quét phản ứng nhanh
            ValueListenableBuilder<List<Recognition>>(
              valueListenable: _recognitionsNotifier,
              builder: (context, recognitions, _) {
                final hasDetections = recognitions.isNotEmpty;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasDetections
                        ? const Color(0xFF10B981).withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasDetections
                            ? Icons.check_circle_rounded
                            : Icons.radar_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasDetections ? 'Detected' : 'Scanning...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Banner thông báo khi đang đóng băng khung hình (Snapshot Freeze Banner)
  Widget _buildFrozenBanner() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 16,
      right: 16,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFD97706).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pause_circle_filled_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Khung hình đã dừng • Chạm vào vật thể để học',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  /// Debug overlay hiển thị log model và latency
  Widget _buildDebugOverlay() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 155,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ValueListenableBuilder<String>(
          valueListenable: _debugInfoNotifier,
          builder: (context, debugInfo, _) {
            return Text(
              debugInfo,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            );
          },
        ),
      ),
    );
  }

  /// Thanh cuộn danh sách từ vựng IELTS của các vật thể nhận diện được
  Widget _buildDetectedChipsCarousel() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 98,
      left: 0,
      right: 0,
      child: ValueListenableBuilder<List<Recognition>>(
        valueListenable: _recognitionsNotifier,
        builder: (context, recognitions, _) {
          if (recognitions.isEmpty) {
            return Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar_rounded, color: Colors.white70, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Hướng camera vào đồ vật để nhận diện từ vựng...',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          }

          return SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recognitions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final rec = recognitions[index];
                final percent = (rec.confidence * 100).toStringAsFixed(0);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showVocabularySheet(rec),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.85),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.school_rounded, color: Color(0xFF10B981), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            rec.label.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$percent%',
                              style: const TextStyle(
                                color: Color(0xFF34D399),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Hiệu ứng Overlay Radar Scanner khi đang quét chuyên sâu bằng Ollama LLaVA-Phi3
  Widget _buildDeepScanningOverlay() {
    if (!_isDeepScanning) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final center = _tapScanPoint ?? Offset(size.width / 2, size.height / 2);

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: Stack(
          children: [
            // Radar Glow ring tại điểm chạm
            Positioned(
              left: center.dx - 60,
              top: center.dy - 60,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 1200),
                builder: (context, val, child) {
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.purpleAccent.withValues(alpha: (1.0 - val).clamp(0.0, 1.0)),
                        width: 2.5 + val * 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purpleAccent.withValues(alpha: (0.6 * (1.0 - val)).clamp(0.0, 1.0)),
                          blurRadius: 20 * val,
                          spreadRadius: 8 * val,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Tâm điểm quét Laser
            Positioned(
              left: center.dx - 12,
              top: center.dy - 12,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purpleAccent,
                ),
                child: const Center(
                  child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                ),
              ),
            ),
            // Banner thông báo ở trên
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 24,
              right: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B4B).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purpleAccent, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purpleAccent.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.purpleAccent,
                        ),
                      ),
                      SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Ollama Phi-3 đang phân tích vật thể & IELTS Band 7.5+...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bộ nút điều khiển Camera (Đèn Flash, Deep Scan Phi-3, Nút Chụp Snapshot, Đổi Camera)
  Widget _buildBottomControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Nút Bật/Tắt Đèn Flash (Torch)
            _buildCircleIconButton(
              icon: _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? Colors.amber : Colors.white,
              tooltip: 'Bật/tắt đèn flash',
              onPressed: _toggleTorch,
            ),

            // Nút Chụp / Cố định khung hình (Snapshot Freeze Action)
            GestureDetector(
              onTap: _toggleFreezeFrame,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isFrozen ? const Color(0xFFD97706) : Colors.white,
                  border: Border.all(
                    color: _isFrozen ? Colors.amberAccent : const Color(0xFF10B981),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isFrozen ? Colors.amber : const Color(0xFF10B981))
                          .withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _isFrozen ? Icons.play_arrow_rounded : Icons.camera_rounded,
                    color: _isFrozen ? Colors.white : const Color(0xFF0F172A),
                    size: 36,
                  ),
                ),
              ),
            ),

            // Nút Quét AI Chuyên Sâu với Ollama LLaVA-Phi3
            _buildCircleIconButton(
              icon: Icons.auto_awesome_rounded,
              color: Colors.purpleAccent,
              tooltip: 'Quét AI chuyên sâu (Ollama Phi-3)',
              onPressed: _performFullDeepScan,
            ),

            // Nút Đổi Camera trước / sau
            _buildCircleIconButton(
              icon: Icons.flip_camera_ios_rounded,
              color: Colors.white,
              tooltip: 'Đổi camera',
              onPressed: _availableCameras.length > 1 ? _flipCamera : null,
            ),
          ],
        ),
      ),
    );
  }


  /// Nút icon hình tròn mờ (Glassmorphism circle button)
  Widget _buildCircleIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 24),
        tooltip: tooltip,
        onPressed: onPressed,
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
/// Tối ưu hóa 60 FPS:
/// - Tái sử dụng (cache) các đối tượng Paint tĩnh và TextPainter theo label
/// - Thay thế MaskFilter.blur (tốn GPU shader) bằng viền Halo Alpha nhẹ mượt mà
class BoundingBoxPainter extends CustomPainter {
  final List<Recognition> recognitions;
  final Size? previewSize;
  final Size screenSize;

  static const Color _accentColor = Color(0xFF10B981);

  static final Paint _boxPaint = Paint()
    ..color = _accentColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.8
    ..strokeCap = StrokeCap.round;

  static final Paint _haloPaint = Paint()
    ..color = const Color(0x4010B981)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7.5
    ..strokeCap = StrokeCap.round;

  static final Paint _labelBgPaint = Paint()..color = _accentColor;

  static final Paint _markerPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round;

  static final Map<String, TextPainter> _textPainterCache = {};

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
    if (_textPainterCache.length > 120) {
      _textPainterCache.clear();
    }

    for (final rec in recognitions) {
      // Ánh xạ chuẩn sang tọa độ màn hình
      final rect = mapBoxToScreen(rec.boundingBox, size, previewSize);
      final double alpha = rec.opacity.clamp(0.0, 1.0);

      _boxPaint.color = _accentColor.withValues(alpha: alpha);
      _haloPaint.color = _accentColor.withValues(alpha: 0.24 * alpha);
      _labelBgPaint.color = _accentColor.withValues(alpha: alpha);
      _markerPaint.color = Colors.white.withValues(alpha: alpha);

      final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
      canvas.drawRRect(rRect, _haloPaint);
      canvas.drawRRect(rRect, _boxPaint);

      // ── 2. Vẽ label background (Cache TextPainter) ──
      final int pct = (rec.confidence * 100).round();
      final String labelText = '${rec.label.toUpperCase()}  $pct%';

      TextPainter? textPainter = _textPainterCache[labelText];
      if (textPainter == null) {
        textPainter = TextPainter(
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
        _textPainterCache[labelText] = textPainter;
      }

      final double labelWidth = textPainter.width + 16;
      final double labelHeight = textPainter.height + 8;

      // Label nằm phía trên bounding box (nếu sát mép trên thì đưa vào trong)
      final double labelTop = (rect.top - labelHeight - 2 >= 0)
          ? (rect.top - labelHeight - 2)
          : (rect.top + 2);

      final labelRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left,
          labelTop,
          labelWidth,
          labelHeight,
        ),
        const Radius.circular(8),
      );

      canvas.drawRRect(labelRect, _labelBgPaint);

      // Vẽ text label
      textPainter.paint(
        canvas,
        Offset(rect.left + 8, labelTop + 4),
      );

      // ── 3. Corner markers (tạo hiệu ứng viewfinder quét) ──
      _drawCornerMarkers(canvas, rect);
    }
  }

  /// Vẽ 4 góc marker kiểu "viewfinder" cho hiệu ứng scan chuyên nghiệp
  void _drawCornerMarkers(Canvas canvas, Rect rect) {
    const double len = 20;

    // Top-left
    canvas.drawLine(rect.topLeft, Offset(rect.left + len, rect.top), _markerPaint);
    canvas.drawLine(rect.topLeft, Offset(rect.left, rect.top + len), _markerPaint);

    // Top-right
    canvas.drawLine(rect.topRight, Offset(rect.right - len, rect.top), _markerPaint);
    canvas.drawLine(rect.topRight, Offset(rect.right, rect.top + len), _markerPaint);

    // Bottom-left
    canvas.drawLine(rect.bottomLeft, Offset(rect.left + len, rect.bottom), _markerPaint);
    canvas.drawLine(rect.bottomLeft, Offset(rect.left, rect.bottom - len), _markerPaint);

    // Bottom-right
    canvas.drawLine(rect.bottomRight, Offset(rect.right - len, rect.bottom), _markerPaint);
    canvas.drawLine(rect.bottomRight, Offset(rect.right, rect.bottom - len), _markerPaint);
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.recognitions != recognitions;
  }
}
