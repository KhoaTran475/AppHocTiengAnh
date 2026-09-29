import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';

/// Chứa thông số Letterbox để un-pad và un-scale bounding box chính xác 100%
class LetterboxInfo {
  final int padX;
  final int padY;
  final int scaledWidth;
  final int scaledHeight;
  final int targetWidth;
  final int targetHeight;

  const LetterboxInfo({
    required this.padX,
    required this.padY,
    required this.scaledWidth,
    required this.scaledHeight,
    required this.targetWidth,
    required this.targetHeight,
  });
}

/// Kết quả sau khi tiền xử lý ảnh camera với Letterbox bảo toàn Aspect Ratio
class ProcessedImageResult {
  final Float32List buffer;
  final LetterboxInfo letterbox;

  ProcessedImageResult({
    required this.buffer,
    required this.letterbox,
  });
}

/// Tiện ích chuyển đổi CameraImage sang Float32List chuẩn hóa [0.0, 1.0] cho YOLOv8n TFLite.
///
/// Tích hợp LETTERBOXING CHUẨN CỦA YOLOV8:
/// Bảo toàn 100% tỷ lệ hình học (Aspect Ratio), không bóp méo hay kéo giãn hình ảnh.
/// Khắc phục triệt để lỗi méo hình khiến con chuột (mouse) bị nhận diện nhầm thành ván lướt sóng (surfboard)
/// hoặc điều khiển từ xa (remote) bị méo thành điện thoại (cell phone).
class ImageUtils {
  // Buffer tái sử dụng để tránh cấp phát bộ nhớ liên tục trong mỗi frame
  static Float32List? _cachedBuffer;

  /// Chuyển đổi CameraImage sang Float32List có kèm Letterbox
  static ProcessedImageResult cameraImageToFloat32Letterbox(
    CameraImage cameraImage,
    int targetWidth,
    int targetHeight, {
    bool nchw = true,
    int rotationDegrees = 90,
  }) {
    final int totalPixels = targetWidth * targetHeight;
    final int requiredLength = 3 * totalPixels;

    if (_cachedBuffer == null || _cachedBuffer!.length != requiredLength) {
      _cachedBuffer = Float32List(requiredLength);
    }

    final Float32List result = _cachedBuffer!;

    // Giá trị xám mặc định của YOLO letterbox: 114.0 / 255.0 = 0.4470588
    result.fillRange(0, requiredLength, 0.4470588);

    final int srcWidth = cameraImage.width;
    final int srcHeight = cameraImage.height;

    // Kích thước sau khi xoay portrait
    final int rotW = (rotationDegrees == 90 || rotationDegrees == 270)
        ? srcHeight
        : srcWidth;
    final int rotH = (rotationDegrees == 90 || rotationDegrees == 270)
        ? srcWidth
        : srcHeight;

    // Tính tỷ lệ scale giữ nguyên Aspect Ratio
    final double scale = min(
      targetWidth / rotW,
      targetHeight / rotH,
    );

    final int scaledW = (rotW * scale).round();
    final int scaledH = (rotH * scale).round();

    final int padX = (targetWidth - scaledW) ~/ 2;
    final int padY = (targetHeight - scaledH) ~/ 2;

    final letterbox = LetterboxInfo(
      padX: padX,
      padY: padY,
      scaledWidth: scaledW,
      scaledHeight: scaledH,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );

    if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      _convertBgraLetterbox(
        cameraImage,
        targetWidth,
        result,
        letterbox,
        scale,
        nchw: nchw,
        rotationDegrees: rotationDegrees,
      );
    } else {
      _convertYuv420Letterbox(
        cameraImage,
        targetWidth,
        result,
        letterbox,
        scale,
        nchw: nchw,
        rotationDegrees: rotationDegrees,
      );
    }

    return ProcessedImageResult(buffer: result, letterbox: letterbox);
  }

  /// Chuyển đổi YUV420 với Letterbox chuẩn xác
  static void _convertYuv420Letterbox(
    CameraImage cameraImage,
    int targetWidth,
    Float32List result,
    LetterboxInfo letterbox,
    double scale, {
    required bool nchw,
    required int rotationDegrees,
  }) {
    final int srcWidth = cameraImage.width;
    final int srcHeight = cameraImage.height;

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final Uint8List yBytes = yPlane.bytes;
    final Uint8List uBytes = uPlane.bytes;
    final Uint8List vBytes = vPlane.bytes;

    final int yRowStride = yPlane.bytesPerRow;
    final int uRowStride = uPlane.bytesPerRow;
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vRowStride = vPlane.bytesPerRow;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    final int totalPixels = letterbox.targetWidth * letterbox.targetHeight;
    final int gOffset = totalPixels;
    final int bOffset = 2 * totalPixels;

    final int startX = letterbox.padX;
    final int endX = letterbox.padX + letterbox.scaledWidth;
    final int startY = letterbox.padY;
    final int endY = letterbox.padY + letterbox.scaledHeight;

    for (int outY = startY; outY < endY; outY++) {
      final double rotY = (outY - letterbox.padY) / scale;

      for (int outX = startX; outX < endX; outX++) {
        final double rotX = (outX - letterbox.padX) / scale;

        int srcX;
        int srcY;

        // Ánh xạ tọa độ sau xoay ngược về cảm biến camera gốc
        if (rotationDegrees == 90) {
          srcX = rotY.round().clamp(0, srcWidth - 1);
          srcY = ((srcHeight - 1) - rotX).round().clamp(0, srcHeight - 1);
        } else if (rotationDegrees == 270) {
          srcX = ((srcWidth - 1) - rotY).round().clamp(0, srcWidth - 1);
          srcY = rotX.round().clamp(0, srcHeight - 1);
        } else {
          srcX = rotX.round().clamp(0, srcWidth - 1);
          srcY = rotY.round().clamp(0, srcHeight - 1);
        }

        final int yIdx = srcY * yRowStride + srcX;
        final int uvRow = srcY >> 1;
        final int uvCol = srcX >> 1;
        final int uIdx = uvRow * uRowStride + uvCol * uPixelStride;
        final int vIdx = uvRow * vRowStride + uvCol * vPixelStride;

        final int yp = (yIdx < yBytes.length) ? yBytes[yIdx] : 0;
        final int up = (uIdx < uBytes.length) ? uBytes[uIdx] : 128;
        final int vp = (vIdx < vBytes.length) ? vBytes[vIdx] : 128;

        // Chuẩn chuyển đổi ITU-R BT.601 YUV -> RGB
        final int c = yp;
        final int d = up - 128;
        final int e = vp - 128;

        final double r = ((c + 1.402 * e).round().clamp(0, 255)) / 255.0;
        final double g =
            ((c - 0.344136 * d - 0.714136 * e).round().clamp(0, 255)) / 255.0;
        final double b = ((c + 1.772 * d).round().clamp(0, 255)) / 255.0;

        if (nchw) {
          final int pIdx = outY * targetWidth + outX;
          result[pIdx] = r;
          result[gOffset + pIdx] = g;
          result[bOffset + pIdx] = b;
        } else {
          final int pIdx = (outY * targetWidth + outX) * 3;
          result[pIdx] = r;
          result[pIdx + 1] = g;
          result[pIdx + 2] = b;
        }
      }
    }
  }

  /// Chuyển đổi BGRA với Letterbox
  static void _convertBgraLetterbox(
    CameraImage cameraImage,
    int targetWidth,
    Float32List result,
    LetterboxInfo letterbox,
    double scale, {
    required bool nchw,
    required int rotationDegrees,
  }) {
    final int srcWidth = cameraImage.width;
    final int srcHeight = cameraImage.height;
    final plane = cameraImage.planes[0];
    final Uint8List bytes = plane.bytes;
    final int bytesPerRow = plane.bytesPerRow;

    final int totalPixels = letterbox.targetWidth * letterbox.targetHeight;
    final int gOffset = totalPixels;
    final int bOffset = 2 * totalPixels;

    final int startX = letterbox.padX;
    final int endX = letterbox.padX + letterbox.scaledWidth;
    final int startY = letterbox.padY;
    final int endY = letterbox.padY + letterbox.scaledHeight;

    for (int outY = startY; outY < endY; outY++) {
      final double rotY = (outY - letterbox.padY) / scale;

      for (int outX = startX; outX < endX; outX++) {
        final double rotX = (outX - letterbox.padX) / scale;

        int srcX;
        int srcY;

        if (rotationDegrees == 90) {
          srcX = rotY.round().clamp(0, srcWidth - 1);
          srcY = ((srcHeight - 1) - rotX).round().clamp(0, srcHeight - 1);
        } else {
          srcX = rotX.round().clamp(0, srcWidth - 1);
          srcY = rotY.round().clamp(0, srcHeight - 1);
        }

        final int pixelIdx = srcY * bytesPerRow + srcX * 4;
        if (pixelIdx + 2 < bytes.length) {
          final double b = bytes[pixelIdx] / 255.0;
          final double g = bytes[pixelIdx + 1] / 255.0;
          final double r = bytes[pixelIdx + 2] / 255.0;

          if (nchw) {
            final int pIdx = outY * targetWidth + outX;
            result[pIdx] = r;
            result[gOffset + pIdx] = g;
            result[bOffset + pIdx] = b;
          } else {
            final int pIdx = (outY * targetWidth + outX) * 3;
            result[pIdx] = r;
            result[pIdx + 1] = g;
            result[pIdx + 2] = b;
          }
        }
      }
    }
  }
}
