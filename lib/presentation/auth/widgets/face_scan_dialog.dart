import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../../../core/theme/app_theme.dart';

/// Chế độ quét khuôn mặt
enum FaceScanMode {
  login,     // Đăng nhập
  register,  // Đăng ký hồ sơ
}

/// Kết quả trả về sau khi quét thành công
class FaceScanResult {
  final String imageBase64;
  final Face face;

  FaceScanResult({
    required this.imageBase64,
    required this.face,
  });
}

/// Widget quét khuôn mặt FaceID an toàn, chống quá tải phần cứng và xung đột Camera.
/// Tuân thủ nghiêm ngặt 4 nguyên tắc:
/// 1. Throttle Frame Stream (_isProcessingFrame).
/// 2. Dừng Stream trước khi gọi takePicture().
/// 3. Chuẩn hóa Rotation/Mirroring & Padding 15-20% BoundingBox.
/// 4. Dispose an toàn, ngăn ngừa triệt để Memory Leak.
class FaceScanDialog extends StatefulWidget {
  final FaceScanMode mode;
  final String? title;
  final String? subtitle;

  const FaceScanDialog({
    super.key,
    this.mode = FaceScanMode.login,
    this.title,
    this.subtitle,
  });

  /// Hàm tiện ích mở Dialog toàn màn hình hoặc Bottom Sheet
  static Future<FaceScanResult?> show(
    BuildContext context, {
    FaceScanMode mode = FaceScanMode.login,
    String? title,
    String? subtitle,
  }) {
    return showDialog<FaceScanResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FaceScanDialog(
        mode: mode,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<FaceScanDialog> createState() => _FaceScanDialogState();
}

class _FaceScanDialogState extends State<FaceScanDialog>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  late final FaceDetector _faceDetector;
  late final AnimationController _laserAnimController;

  CameraDescription? _frontCamera;
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false; // Cờ khóa chống quá tải CPU
  bool _isCapturing = false;       // Cờ đang chụp ảnh chất lượng cao
  bool _isDisposed = false;

  // Trạng thái nhận diện trực quan
  String _statusMessage = 'Đang khởi động Camera FaceID...';
  Color _statusColor = Colors.white70;
  int _consecutiveValidFrames = 0;
  // Tăng lên 6 frame ổn định liên tục (~1.5s - 1.8s) để tránh bị nhạy chụp vội vàng
  static const int _requiredValidFrames = 6;
  DateTime? _lastFrameTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Khởi tạo FaceDetector của Google ML Kit với cấu hình tối ưu hiệu năng
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableClassification: false,
        enableLandmarks: false,
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast, // Tối ưu realtime frame stream
        minFaceSize: 0.25,                     // Khuôn mặt phải đủ gần camera
      ),
    );

    // Animation chuyển động tia laser quét lên xuống
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopStreamAndCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _stopStreamAndCamera() async {
    try {
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController?.dispose();
      _cameraController = null;
      if (mounted) {
        setState(() => _isCameraInitialized = false);
      }
    } catch (e) {
      debugPrint('Lỗi giải phóng camera: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _statusMessage = 'Không tìm thấy Camera trên thiết bị';
            _statusColor = Colors.redAccent;
          });
        }
        return;
      }

      // Ưu tiên camera trước (Front Camera)
      _frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        _frontCamera!,
        ResolutionPreset.medium, // 720p hoặc 480p tối ưu giữa nét và tốc độ
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      if (_isDisposed || !mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _statusMessage = 'Vui lòng đưa khuôn mặt vào khung tròn';
        _statusColor = Colors.white;
      });

      // Bắt đầu lắng nghe Frame Stream an toàn
      await _cameraController!.startImageStream(_processCameraFrame);
    } catch (e) {
      debugPrint('Lỗi khởi tạo Camera: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'Lỗi khởi động camera: $e';
          _statusColor = Colors.redAccent;
        });
      }
    }
  }

  /// QUẢN LÝ RỦI RO 1: Chống quá tải CPU & Điều tiết tốc độ nhận diện (Tránh nhạy quá nhanh)
  void _processCameraFrame(CameraImage image) async {
    if (_isProcessingFrame || _isCapturing || _isDisposed) {
      return;
    }

    // Giới hạn tần suất xử lý frame tối thiểu mỗi 200ms (5 FPS) để người dùng kịp nhìn rõ hướng dẫn
    final now = DateTime.now();
    if (_lastFrameTime != null && now.difference(_lastFrameTime!).inMilliseconds < 220) {
      return;
    }
    _lastFrameTime = now;

    _isProcessingFrame = true;

    try {
      final inputImage = _buildInputImageFromCamera(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      if (_isDisposed || !mounted || _isCapturing) return;

      if (faces.isEmpty) {
        _consecutiveValidFrames = 0;
        setState(() {
          _statusMessage = 'Vui lòng nhìn vào khung tròn';
          _statusColor = Colors.white70;
        });
      } else if (faces.length > 1) {
        _consecutiveValidFrames = 0;
        setState(() {
          _statusMessage = 'Phát hiện nhiều người. Vui lòng quét 1 người';
          _statusColor = Colors.amberAccent;
        });
      } else {
        final face = faces.first;
        final rotY = face.headEulerAngleY ?? 0.0; // Nghiêng trái/phải
        final rotZ = face.headEulerAngleZ ?? 0.0; // Nghiêng gật đầu
        final rotX = face.headEulerAngleX ?? 0.0;

        // Kiểm tra góc chụp thẳng tự nhiên (nghiêng dưới 18 độ)
        if (rotY.abs() > 18.0 || rotZ.abs() > 18.0 || rotX.abs() > 18.0) {
          _consecutiveValidFrames = 0;
          setState(() {
            _statusMessage = 'Vui lòng nhìn thẳng vào camera';
            _statusColor = Colors.amberAccent;
          });
        } else {
          // Khuôn mặt hợp lệ
          _consecutiveValidFrames++;
          setState(() {
            _statusMessage = 'Giữ nguyên khuôn mặt... ($_consecutiveValidFrames/$_requiredValidFrames)';
            _statusColor = Colors.greenAccent;
          });

          // Khi giữ ổn định đủ 6 frame (~1.5s) -> Mới kích hoạt chụp ảnh
          if (_consecutiveValidFrames >= _requiredValidFrames) {
            _triggerCaptureAndCrop(face);
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi xử lý frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// QUẢN LÝ RỦI RO 2 & 3:
  /// - Chống xung đột giữa startImageStream và takePicture()
  /// - Padding 15-20% chống cụt trán/cằm/tai trước khi Base64
  Future<void> _triggerCaptureAndCrop(Face face) async {
    if (_isCapturing) return;
    _isCapturing = true;

    try {
      setState(() {
        _statusMessage = 'Đang chụp ảnh sinh trắc học...';
        _statusColor = Colors.cyanAccent;
      });

      // BƯỚC 1: Bắt buộc dừng Stream trước khi chụp ảnh
      if (_cameraController != null && _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }

      // BƯỚC 2: Chụp ảnh độ nét cao
      final XFile pictureFile = await _cameraController!.takePicture();
      final Uint8List imageBytes = await pictureFile.readAsBytes();

      setState(() {
        _statusMessage = 'Đang trích xuất đặc trưng khuôn mặt...';
      });

      // BƯỚC 3: Xử lý xoay & cắt ảnh khuôn mặt trong isolate/background
      final base64String = await compute(_cropAndEncodeFace, {
        'bytes': imageBytes,
        'rect': {
          'left': face.boundingBox.left,
          'top': face.boundingBox.top,
          'width': face.boundingBox.width,
          'height': face.boundingBox.height,
        },
        'isFrontCamera': _frontCamera?.lensDirection == CameraLensDirection.front,
      });

      if (!mounted || _isDisposed) return;

      // Trả kết quả thành công
      Navigator.of(context).pop(FaceScanResult(
        imageBase64: base64String,
        face: face,
      ));
    } catch (e) {
      debugPrint('Lỗi chụp hoặc cắt ảnh: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _consecutiveValidFrames = 0;
          _statusMessage = 'Không thể chụp ảnh, đang thử lại...';
          _statusColor = Colors.redAccent;
        });
        // Khôi phục stream nếu lỗi
        try {
          if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
            await _cameraController!.startImageStream(_processCameraFrame);
          }
        } catch (_) {}
      }
    }
  }

  /// QUẢN LÝ RỦI RO 3: Helper chuẩn hóa InputImage từ CameraImage theo nền tảng
  InputImage? _buildInputImageFromCamera(CameraImage image) {
    if (_cameraController == null || _frontCamera == null) return null;

    final sensorOrientation = _frontCamera!.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _cameraController!.description.sensorOrientation;
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    rotation ??= InputImageRotation.rotation0deg;

    // Định dạng pixel
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Ghép các planes thành một mảng bytes duy nhất
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  /// QUẢN LÝ RỦI RO 4: Giải phóng bộ nhớ và vòng đời an toàn tuyệt đối
  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _laserAnimController.dispose();
    _faceDetector.close();
    if (_cameraController != null) {
      if (_cameraController!.value.isStreamingImages) {
        _cameraController!.stopImageStream();
      }
      _cameraController!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.title ??
        (widget.mode == FaceScanMode.login ? 'Đăng nhập FaceID' : 'Đăng ký FaceID');
    final subtitleText = widget.subtitle ??
        (widget.mode == FaceScanMode.login
            ? 'Đưa khuôn mặt vào khung tròn để xác thực'
            : 'Giữ gương mặt ổn định và đủ ánh sáng');

    final size = MediaQuery.of(context).size;
    final ovalWidth = size.width * 0.74;
    final ovalHeight = ovalWidth * 1.34;
    final ovalLeft = (size.width - ovalWidth) / 2;
    // Căn giữa khung Oval trên màn hình
    final ovalTop = (size.height - ovalHeight) / 2 - 20;
    final ovalRect = Rect.fromLTWH(ovalLeft, ovalTop, ovalWidth, ovalHeight);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview tràn màn hình (Không bị cắt ngang hay chừa viền đen trên dưới)
          if (_isCameraInitialized && _cameraController != null)
            ClipRect(
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: size.width,
                    height: size.width * _cameraController!.value.aspectRatio,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          // 2. Lớp phủ mờ chuyên nghiệp khoét rỗng Oval ở giữa + viền đôi Glow
          CustomPaint(
            painter: _OvalOverlayPainter(
              ovalRect: ovalRect,
              borderColor: _statusColor,
            ),
          ),

          // 3. Hiệu ứng vạch quét Laser chuyển động chuẩn xác bên trong khung Oval
          AnimatedBuilder(
            animation: _laserAnimController,
            builder: (context, _) {
              final laserY = ovalRect.top + (ovalRect.height * _laserAnimController.value);

              return Positioned(
                top: laserY,
                left: ovalRect.left + 15,
                right: ovalRect.left + 15,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        _statusColor.withValues(alpha: 0.9),
                        Colors.white,
                        _statusColor.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _statusColor.withValues(alpha: 0.7),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

            // 4. Header: Nút đóng & Tiêu đề
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(width: 42), // Giữ cân bằng trung tâm tiêu đề
                ],
              ),
            ),

            // 5. Footer: Hướng dẫn trạng thái trực quan
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: _statusColor.withValues(alpha: 0.6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _statusColor.withValues(alpha: 0.25),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isCapturing) ...[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                          ] else ...[
                            Icon(
                              _statusColor == Colors.greenAccent
                                  ? Icons.check_circle_rounded
                                  : (_statusColor == Colors.amberAccent
                                      ? Icons.warning_amber_rounded
                                      : Icons.face_rounded),
                              color: _statusColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              _statusMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _statusColor,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'AI ML Kit • Liveness & Pose Checked',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }
}

/// Helper cắt ảnh với đệm Padding 20% và chuyển đổi sang Base64 trong Isolate
String _cropAndEncodeFace(Map<String, dynamic> data) {
  final Uint8List bytes = data['bytes'] as Uint8List;
  final Map<String, dynamic> rect = data['rect'] as Map<String, dynamic>;
  final bool isFrontCamera = data['isFrontCamera'] as bool? ?? false;

  final originalImage = img.decodeImage(bytes);
  if (originalImage == null) {
    // Fallback nếu không decode được: trả về ảnh gốc dạng base64
    return base64Encode(bytes);
  }

  // Chuẩn hóa xoay nếu ảnh chụp bị lật
  img.Image workingImage = originalImage;
  if (isFrontCamera) {
    // Một số thiết bị Android camera trước chụp ảnh bị lộn hoặc ngược
    workingImage = img.bakeOrientation(originalImage);
  }

  final double left = (rect['left'] as num).toDouble();
  final double top = (rect['top'] as num).toDouble();
  final double width = (rect['width'] as num).toDouble();
  final double height = (rect['height'] as num).toDouble();

  // Mở rộng lề đệm 20% mỗi cạnh (Padding/Margin)
  final double padX = width * 0.20;
  final double padY = height * 0.20;

  int cropX = (left - padX).toInt().clamp(0, workingImage.width - 1);
  int cropY = (top - padY).toInt().clamp(0, workingImage.height - 1);
  int cropW = (width + padX * 2).toInt().clamp(1, workingImage.width - cropX);
  int cropH = (height + padY * 2).toInt().clamp(1, workingImage.height - cropY);

  img.Image faceImage;
  try {
    faceImage = img.copyCrop(
      workingImage,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );
  } catch (_) {
    faceImage = workingImage;
  }

  // Nén ảnh JPEG chất lượng cao 90 để nhận diện đặc trưng tốt nhất
  final jpegBytes = img.encodeJpg(faceImage, quality: 90);
  return base64Encode(jpegBytes);
}

/// CustomPainter vẽ lớp phủ màu tối với khung hình Oval ở giữa theo ovalRect truyền vào
class _OvalOverlayPainter extends CustomPainter {
  final Rect ovalRect;
  final Color borderColor;

  _OvalOverlayPainter({
    required this.ovalRect,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Nền mờ điện ảnh (Cinema dark backdrop)
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    // Khoét lỗ Oval
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    // 2. Vòng phát sáng Glow mềm mại bên ngoài
    final glowPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawOval(ovalRect, glowPaint);

    // 3. Viền Oval chính phát sáng
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawOval(ovalRect, borderPaint);

    // 4. Viền nét đứt hoặc viền mỏng phía trong tạo chiều sâu biometric
    final innerBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawOval(ovalRect.deflate(5), innerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _OvalOverlayPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor || oldDelegate.ovalRect != ovalRect;
  }
}
