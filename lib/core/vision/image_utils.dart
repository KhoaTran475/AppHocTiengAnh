import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

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
  // Buffer tái sử dụng để tránh cấp phát bộ nhớ liên tục trong mỗi frame (khi chạy single isolate)
  static Float32List? _cachedBuffer;

  /// Chuyển đổi CameraImage sang Float32List có kèm Letterbox
  static ProcessedImageResult cameraImageToFloat32Letterbox(
    CameraImage cameraImage,
    int targetWidth,
    int targetHeight, {
    bool nchw = true,
    int rotationDegrees = 90,
    bool mirrorHorizontal = false,
  }) {
    return planesToFloat32Letterbox(
      planeBytes: cameraImage.planes.map((p) => p.bytes).toList(),
      bytesPerRow: cameraImage.planes.map((p) => p.bytesPerRow).toList(),
      bytesPerPixel: cameraImage.planes.map((p) => p.bytesPerPixel).toList(),
      srcWidth: cameraImage.width,
      srcHeight: cameraImage.height,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      isBgra: cameraImage.format.group == ImageFormatGroup.bgra8888,
      nchw: nchw,
      rotationDegrees: rotationDegrees,
      mirrorHorizontal: mirrorHorizontal,
    );
  }

  /// Chuyển đổi plane bytes thô trực tiếp sang Float32List Letterbox (hỗ trợ Worker Background Isolate)
  static ProcessedImageResult planesToFloat32Letterbox({
    required List<Uint8List> planeBytes,
    required List<int> bytesPerRow,
    required List<int?> bytesPerPixel,
    required int srcWidth,
    required int srcHeight,
    required int targetWidth,
    required int targetHeight,
    required bool isBgra,
    bool nchw = true,
    int rotationDegrees = 90,
    bool mirrorHorizontal = false,
    Float32List? outputBuffer,
  }) {
    final int totalPixels = targetWidth * targetHeight;
    final int requiredLength = 3 * totalPixels;

    Float32List result;
    if (outputBuffer != null && outputBuffer.length == requiredLength) {
      result = outputBuffer;
    } else {
      if (_cachedBuffer == null || _cachedBuffer!.length != requiredLength) {
        _cachedBuffer = Float32List(requiredLength);
      }
      result = _cachedBuffer!;
    }

    // Giá trị xám mặc định của YOLO letterbox: 114.0 / 255.0 = 0.4470588
    result.fillRange(0, requiredLength, 0.4470588);

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

    if (isBgra) {
      _convertBgraLetterboxFromPlanes(
        planeBytes: planeBytes[0],
        bytesPerRow: bytesPerRow[0],
        srcWidth: srcWidth,
        srcHeight: srcHeight,
        targetWidth: targetWidth,
        result: result,
        letterbox: letterbox,
        scale: scale,
        nchw: nchw,
        rotationDegrees: rotationDegrees,
        mirrorHorizontal: mirrorHorizontal,
      );
    } else {
      _convertYuv420LetterboxFromPlanes(
        planeBytes: planeBytes,
        bytesPerRow: bytesPerRow,
        bytesPerPixel: bytesPerPixel,
        srcWidth: srcWidth,
        srcHeight: srcHeight,
        targetWidth: targetWidth,
        result: result,
        letterbox: letterbox,
        scale: scale,
        nchw: nchw,
        rotationDegrees: rotationDegrees,
        mirrorHorizontal: mirrorHorizontal,
      );
    }

    return ProcessedImageResult(buffer: result, letterbox: letterbox);
  }

  /// Chuyển đổi YUV420 từ mảng Plane bytes với Letterbox chuẩn xác, tối ưu hóa bằng bảng tọa độ 1D
  static void _convertYuv420LetterboxFromPlanes({
    required List<Uint8List> planeBytes,
    required List<int> bytesPerRow,
    required List<int?> bytesPerPixel,
    required int srcWidth,
    required int srcHeight,
    required int targetWidth,
    required Float32List result,
    required LetterboxInfo letterbox,
    required double scale,
    required bool nchw,
    required int rotationDegrees,
    bool mirrorHorizontal = false,
  }) {
    final Uint8List yBytes = planeBytes[0];
    final Uint8List uBytes = planeBytes[1];
    final Uint8List vBytes = planeBytes[2];

    final int yRowStride = bytesPerRow[0];
    final int uRowStride = bytesPerRow[1];
    final int uPixelStride = bytesPerPixel[1] ?? 1;
    final int vRowStride = bytesPerRow[2];
    final int vPixelStride = bytesPerPixel[2] ?? 1;

    final int totalPixels = letterbox.targetWidth * letterbox.targetHeight;
    final int gOffset = totalPixels;
    final int bOffset = 2 * totalPixels;

    final int startX = letterbox.padX;
    final int endX = letterbox.padX + letterbox.scaledWidth;
    final int startY = letterbox.padY;
    final int endY = letterbox.padY + letterbox.scaledHeight;

    final int scaledW = letterbox.scaledWidth;
    final int scaledH = letterbox.scaledHeight;
    final double invScale = 1.0 / scale;
    const double inv255 = 1.0 / 255.0;

    final xMap = Int32List(scaledW);
    for (int i = 0; i < scaledW; i++) {
      xMap[i] = (i * invScale).round();
    }
    final yMap = Int32List(scaledH);
    for (int i = 0; i < scaledH; i++) {
      yMap[i] = (i * invScale).round();
    }

    if (rotationDegrees == 90 || rotationDegrees == 270) {
      // Camera sau (90°): srcX = yMap, srcY = (srcHeight - 1) - xMap
      // Camera trước (270°): srcX = (srcWidth - 1) - yMap (để đầu hướng lên trên, không bị lộn ngược)
      // Nếu mirrorHorizontal = true (camera trước selfie): đảo trục ngang srcY để khớp 100% với CameraPreview
      final bool invertSrcX = (rotationDegrees == 270);
      final bool invertSrcY = (rotationDegrees == 90)
          ? !mirrorHorizontal
          : mirrorHorizontal;

      final srcYTable = Int32List(scaledW);
      for (int i = 0; i < scaledW; i++) {
        final int mappedY = invertSrcY ? ((srcHeight - 1) - xMap[i]) : xMap[i];
        srcYTable[i] = mappedY.clamp(0, srcHeight - 1);
      }

      for (int outY = startY; outY < endY; outY++) {
        final int rawX = yMap[outY - startY];
        final int srcX = (invertSrcX ? ((srcWidth - 1) - rawX) : rawX)
            .clamp(0, srcWidth - 1);
        final int uvCol = srcX >> 1;
        final int uPixelOffset = uvCol * uPixelStride;
        final int vPixelOffset = uvCol * vPixelStride;
        int pIdx = outY * targetWidth + startX;

        for (int outX = startX; outX < endX; outX++) {
          final int srcY = srcYTable[outX - startX];
          final int yIdx = srcY * yRowStride + srcX;
          final int uvRow = srcY >> 1;
          final int uIdx = uvRow * uRowStride + uPixelOffset;
          final int vIdx = uvRow * vRowStride + vPixelOffset;

          final int yp = (yIdx < yBytes.length) ? yBytes[yIdx] : 0;
          final int up = (uIdx < uBytes.length) ? uBytes[uIdx] : 128;
          final int vp = (vIdx < vBytes.length) ? vBytes[vIdx] : 128;

          final int d = up - 128;
          final int e = vp - 128;

          final int r = (yp + ((1436 * e) >> 10)).clamp(0, 255);
          final int g = (yp - ((352 * d + 731 * e) >> 10)).clamp(0, 255);
          final int b = (yp + ((1815 * d) >> 10)).clamp(0, 255);

          if (nchw) {
            result[pIdx] = r * inv255;
            result[gOffset + pIdx] = g * inv255;
            result[bOffset + pIdx] = b * inv255;
            pIdx++;
          } else {
            final int rgbIdx = pIdx * 3;
            result[rgbIdx] = r * inv255;
            result[rgbIdx + 1] = g * inv255;
            result[rgbIdx + 2] = b * inv255;
            pIdx++;
          }
        }
      }
    } else {
      // 0 độ hoặc 180 độ
      final bool invertX = (rotationDegrees == 180)
          ? !mirrorHorizontal
          : mirrorHorizontal;
      final bool invertY = (rotationDegrees == 180);

      final srcXTable = Int32List(scaledW);
      for (int i = 0; i < scaledW; i++) {
        srcXTable[i] = invertX
            ? ((srcWidth - 1) - xMap[i]).clamp(0, srcWidth - 1)
            : xMap[i].clamp(0, srcWidth - 1);
      }

      for (int outY = startY; outY < endY; outY++) {
        final int srcY = invertY
            ? ((srcHeight - 1) - yMap[outY - startY]).clamp(0, srcHeight - 1)
            : yMap[outY - startY].clamp(0, srcHeight - 1);

        final int yRowBase = srcY * yRowStride;
        final int uvRow = srcY >> 1;
        final int uRowBase = uvRow * uRowStride;
        final int vRowBase = uvRow * vRowStride;
        int pIdx = outY * targetWidth + startX;

        for (int outX = startX; outX < endX; outX++) {
          final int srcX = srcXTable[outX - startX];
          final int uvCol = srcX >> 1;
          final int yIdx = yRowBase + srcX;
          final int uIdx = uRowBase + uvCol * uPixelStride;
          final int vIdx = vRowBase + uvCol * vPixelStride;

          final int yp = (yIdx < yBytes.length) ? yBytes[yIdx] : 0;
          final int up = (uIdx < uBytes.length) ? uBytes[uIdx] : 128;
          final int vp = (vIdx < vBytes.length) ? vBytes[vIdx] : 128;

          final int d = up - 128;
          final int e = vp - 128;

          final int r = (yp + ((1436 * e) >> 10)).clamp(0, 255);
          final int g = (yp - ((352 * d + 731 * e) >> 10)).clamp(0, 255);
          final int b = (yp + ((1815 * d) >> 10)).clamp(0, 255);

          if (nchw) {
            result[pIdx] = r * inv255;
            result[gOffset + pIdx] = g * inv255;
            result[bOffset + pIdx] = b * inv255;
            pIdx++;
          } else {
            final int rgbIdx = pIdx * 3;
            result[rgbIdx] = r * inv255;
            result[rgbIdx + 1] = g * inv255;
            result[rgbIdx + 2] = b * inv255;
            pIdx++;
          }
        }
      }
    }
  }

  /// Chuyển đổi BGRA từ Plane bytes với Letterbox tối ưu
  static void _convertBgraLetterboxFromPlanes({
    required Uint8List planeBytes,
    required int bytesPerRow,
    required int srcWidth,
    required int srcHeight,
    required int targetWidth,
    required Float32List result,
    required LetterboxInfo letterbox,
    required double scale,
    required bool nchw,
    required int rotationDegrees,
    bool mirrorHorizontal = false,
  }) {
    final int totalPixels = letterbox.targetWidth * letterbox.targetHeight;
    final int gOffset = totalPixels;
    final int bOffset = 2 * totalPixels;

    final int startX = letterbox.padX;
    final int endX = letterbox.padX + letterbox.scaledWidth;
    final int startY = letterbox.padY;
    final int endY = letterbox.padY + letterbox.scaledHeight;

    final int scaledW = letterbox.scaledWidth;
    final int scaledH = letterbox.scaledHeight;
    final double invScale = 1.0 / scale;
    const double inv255 = 1.0 / 255.0;

    final xMap = Int32List(scaledW);
    for (int i = 0; i < scaledW; i++) {
      xMap[i] = (i * invScale).round();
    }
    final yMap = Int32List(scaledH);
    for (int i = 0; i < scaledH; i++) {
      yMap[i] = (i * invScale).round();
    }

    if (rotationDegrees == 90 || rotationDegrees == 270) {
      final bool invertSrcX = (rotationDegrees == 270);
      final bool invertSrcY = (rotationDegrees == 90)
          ? !mirrorHorizontal
          : mirrorHorizontal;

      final srcYTable = Int32List(scaledW);
      for (int i = 0; i < scaledW; i++) {
        final int mappedY = invertSrcY ? ((srcHeight - 1) - xMap[i]) : xMap[i];
        srcYTable[i] = mappedY.clamp(0, srcHeight - 1);
      }

      for (int outY = startY; outY < endY; outY++) {
        final int rawX = yMap[outY - startY];
        final int srcX = (invertSrcX ? ((srcWidth - 1) - rawX) : rawX)
            .clamp(0, srcWidth - 1);
        final int srcX4 = srcX * 4;
        int pIdx = outY * targetWidth + startX;

        for (int outX = startX; outX < endX; outX++) {
          final int srcY = srcYTable[outX - startX];
          final int pixelIdx = srcY * bytesPerRow + srcX4;

          if (pixelIdx + 2 < planeBytes.length) {
            final double b = planeBytes[pixelIdx] * inv255;
            final double g = planeBytes[pixelIdx + 1] * inv255;
            final double r = planeBytes[pixelIdx + 2] * inv255;

            if (nchw) {
              result[pIdx] = r;
              result[gOffset + pIdx] = g;
              result[bOffset + pIdx] = b;
              pIdx++;
            } else {
              final int rgbIdx = pIdx * 3;
              result[rgbIdx] = r;
              result[rgbIdx + 1] = g;
              result[rgbIdx + 2] = b;
              pIdx++;
            }
          }
        }
      }
    } else {
      final bool invertX = (rotationDegrees == 180)
          ? !mirrorHorizontal
          : mirrorHorizontal;
      final bool invertY = (rotationDegrees == 180);

      final srcXTable = Int32List(scaledW);
      for (int i = 0; i < scaledW; i++) {
        srcXTable[i] = invertX
            ? ((srcWidth - 1) - xMap[i]).clamp(0, srcWidth - 1)
            : xMap[i].clamp(0, srcWidth - 1);
      }

      for (int outY = startY; outY < endY; outY++) {
        final int srcY = invertY
            ? ((srcHeight - 1) - yMap[outY - startY]).clamp(0, srcHeight - 1)
            : yMap[outY - startY].clamp(0, srcHeight - 1);
        final int yRowBase = srcY * bytesPerRow;
        int pIdx = outY * targetWidth + startX;

        for (int outX = startX; outX < endX; outX++) {
          final int srcX = srcXTable[outX - startX];
          final int pixelIdx = yRowBase + srcX * 4;

          if (pixelIdx + 2 < planeBytes.length) {
            final double b = planeBytes[pixelIdx] * inv255;
            final double g = planeBytes[pixelIdx + 1] * inv255;
            final double r = planeBytes[pixelIdx + 2] * inv255;

            if (nchw) {
              result[pIdx] = r;
              result[gOffset + pIdx] = g;
              result[bOffset + pIdx] = b;
              pIdx++;
            } else {
              final int rgbIdx = pIdx * 3;
              result[rgbIdx] = r;
              result[rgbIdx + 1] = g;
              result[rgbIdx + 2] = b;
              pIdx++;
            }
          }
        }
      }
    }
  }

  /// Chuyển đổi CameraImage (YUV420 trên Android hoặc BGRA trên iOS) thành ui.Image tĩnh
  /// với độ sắc nét gốc để cố định khung hình (Freeze Frame) mà không bị vỡ hạt pixel.
  /// Hỗ trợ đầy đủ cả Camera sau (90°) và Camera trước (270° + lật gương mirrorHorizontal)
  /// để hình ảnh khi bấm dừng không bao giờ bị đảo ngược.
  static Future<ui.Image> convertCameraImageToUiImage(
    CameraImage cameraImage, {
    int rotationDegrees = 90,
    bool mirrorHorizontal = false,
  }) {
    final completer = Completer<ui.Image>();
    final int srcWidth = cameraImage.width;
    final int srcHeight = cameraImage.height;

    final int outWidth = (rotationDegrees == 90 || rotationDegrees == 270)
        ? srcHeight
        : srcWidth;
    final int outHeight = (rotationDegrees == 90 || rotationDegrees == 270)
        ? srcWidth
        : srcHeight;

    final Uint8List rgba = Uint8List(outWidth * outHeight * 4);

    if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      final plane = cameraImage.planes[0];
      final Uint8List bytes = plane.bytes;
      final int bytesPerRow = plane.bytesPerRow;

      if (rotationDegrees == 90 || rotationDegrees == 270) {
        final bool invertSrcX = (rotationDegrees == 270);
        final bool invertSrcY = (rotationDegrees == 90)
            ? !mirrorHorizontal
            : mirrorHorizontal;

        for (int outY = 0; outY < outHeight; outY++) {
          final int srcX = invertSrcX ? ((srcWidth - 1) - outY) : outY;
          for (int outX = 0; outX < outWidth; outX++) {
            final int srcY = invertSrcY ? ((srcHeight - 1) - outX) : outX;
            final int pixelIdx = srcY * bytesPerRow + srcX * 4;
            final int outIdx = (outY * outWidth + outX) << 2;

            if (pixelIdx + 2 < bytes.length) {
              rgba[outIdx] = bytes[pixelIdx + 2]; // R
              rgba[outIdx + 1] = bytes[pixelIdx + 1]; // G
              rgba[outIdx + 2] = bytes[pixelIdx]; // B
              rgba[outIdx + 3] = 255;
            }
          }
        }
      } else {
        final bool invertX = (rotationDegrees == 180)
            ? !mirrorHorizontal
            : mirrorHorizontal;
        final bool invertY = (rotationDegrees == 180);

        for (int outY = 0; outY < outHeight; outY++) {
          final int srcY = invertY ? ((srcHeight - 1) - outY) : outY;
          final int yBase = srcY * bytesPerRow;
          final int outBase = outY * outWidth * 4;
          for (int outX = 0; outX < outWidth; outX++) {
            final int srcX = invertX ? ((srcWidth - 1) - outX) : outX;
            final int pixelIdx = yBase + srcX * 4;
            final int outIdx = outBase + outX * 4;
            if (pixelIdx + 2 < bytes.length) {
              rgba[outIdx] = bytes[pixelIdx + 2];
              rgba[outIdx + 1] = bytes[pixelIdx + 1];
              rgba[outIdx + 2] = bytes[pixelIdx];
              rgba[outIdx + 3] = 255;
            }
          }
        }
      }
    } else {
      // YUV420 (Android chuẩn)
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

      if (rotationDegrees == 90 || rotationDegrees == 270) {
        // Camera sau (90°): invertSrcX = false (srcX = outY), invertSrcY = true (srcY = srcHeight - 1 - outX)
        // Camera trước (270°): invertSrcX = true (srcX = srcWidth - 1 - outY) giúp ảnh đứng thẳng không bị lộn ngược!
        // Với mirrorHorizontal = true cho camera trước: invertSrcY = true giúp ảnh khớp 1:1 với preview selfie.
        final bool invertSrcX = (rotationDegrees == 270);
        final bool invertSrcY = (rotationDegrees == 90)
            ? !mirrorHorizontal
            : mirrorHorizontal;

        for (int outY = 0; outY < outHeight; outY++) {
          final int srcX = invertSrcX ? ((srcWidth - 1) - outY) : outY;
          final int uvCol = srcX >> 1;
          final int uPixelOffset = uvCol * uPixelStride;
          final int vPixelOffset = uvCol * vPixelStride;
          int outIdx = (outY * outWidth) << 2;

          for (int outX = 0; outX < outWidth; outX++) {
            final int srcY = invertSrcY ? ((srcHeight - 1) - outX) : outX;
            final int yIdx = srcY * yRowStride + srcX;
            final int uvRow = srcY >> 1;
            final int uIdx = uvRow * uRowStride + uPixelOffset;
            final int vIdx = uvRow * vRowStride + vPixelOffset;

            final int yp = (yIdx < yBytes.length) ? yBytes[yIdx] : 0;
            final int up = (uIdx < uBytes.length) ? uBytes[uIdx] : 128;
            final int vp = (vIdx < vBytes.length) ? vBytes[vIdx] : 128;

            final int d = up - 128;
            final int e = vp - 128;

            rgba[outIdx] = (yp + ((1436 * e) >> 10)).clamp(0, 255);
            rgba[outIdx + 1] = (yp - ((352 * d + 731 * e) >> 10)).clamp(0, 255);
            rgba[outIdx + 2] = (yp + ((1815 * d) >> 10)).clamp(0, 255);
            rgba[outIdx + 3] = 255;
            outIdx += 4;
          }
        }
      } else {
        final bool invertX = (rotationDegrees == 180)
            ? !mirrorHorizontal
            : mirrorHorizontal;
        final bool invertY = (rotationDegrees == 180);

        for (int outY = 0; outY < outHeight; outY++) {
          final int srcY = invertY ? ((srcHeight - 1) - outY) : outY;
          final int yRowBase = srcY * yRowStride;
          final int uvRow = srcY >> 1;
          final int uRowBase = uvRow * uRowStride;
          final int vRowBase = uvRow * vRowStride;
          int outIdx = (outY * outWidth) << 2;

          for (int outX = 0; outX < outWidth; outX++) {
            final int srcX = invertX ? ((srcWidth - 1) - outX) : outX;
            final int uvCol = srcX >> 1;
            final int yIdx = yRowBase + srcX;
            final int uIdx = uRowBase + uvCol * uPixelStride;
            final int vIdx = vRowBase + uvCol * vPixelStride;

            final int yp = (yIdx < yBytes.length) ? yBytes[yIdx] : 0;
            final int up = (uIdx < uBytes.length) ? uBytes[uIdx] : 128;
            final int vp = (vIdx < vBytes.length) ? vBytes[vIdx] : 128;

            final int d = up - 128;
            final int e = vp - 128;

            rgba[outIdx] = (yp + ((1436 * e) >> 10)).clamp(0, 255);
            rgba[outIdx + 1] = (yp - ((352 * d + 731 * e) >> 10)).clamp(0, 255);
            rgba[outIdx + 2] = (yp + ((1815 * d) >> 10)).clamp(0, 255);
            rgba[outIdx + 3] = 255;
            outIdx += 4;
          }
        }
      }
    }

    ui.decodeImageFromPixels(
      rgba,
      outWidth,
      outHeight,
      ui.PixelFormat.rgba8888,
      (ui.Image img) {
        completer.complete(img);
      },
    );

    return completer.future;
  }

  // ─────────────────────────────────────────────────────────────
  // TIỆN ÍCH CROP VÀ NÉN ẢNH CHO OLLAMA LLAVA-PHI3 DEEP SCAN (CHẠY TRÊN ISOLATE)
  // ─────────────────────────────────────────────────────────────

  /// Cắt vùng ROI ~35%-40% diện tích màn hình quanh điểm chạm (Tap-to-Scan)
  /// và nén ảnh JPEG chất lượng 80%, kích thước tối đa 768px (chạy trên Isolate.run() độc lập)
  static Future<Uint8List> cropAndCompressRoiFromUiImage({
    required ui.Image uiImage,
    required ui.Offset tapPos,
    required ui.Size screenSize,
    double cropAreaRatio = 0.36,
    int maxDimension = 768,
    int quality = 80,
  }) async {
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw Exception('Không thể trích xuất mảng byte từ hình ảnh');
    }

    final Uint8List rawBytes = byteData.buffer.asUint8List();
    final int imgWidth = uiImage.width;
    final int imgHeight = uiImage.height;
    final double tapX = tapPos.dx;
    final double tapY = tapPos.dy;
    final double screenW = screenSize.width;
    final double screenH = screenSize.height;

    // Đẩy toàn bộ quá trình xử lý ảnh CPU-heavy sang Background Isolate
    return await Isolate.run(() {
      final img.Image fullImage = img.Image.fromBytes(
        width: imgWidth,
        height: imgHeight,
        bytes: rawBytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

      // Tính tỷ lệ giữa màn hình preview và kích thước ảnh thực tế
      final double scaleX = imgWidth / screenW;
      final double scaleY = imgHeight / screenH;

      // Chiều dài các cạnh crop (~60% width & 60% height -> 36% diện tích)
      final double dimensionRatio = sqrt(cropAreaRatio);
      final int cropW = (imgWidth * dimensionRatio).round().clamp(64, imgWidth);
      final int cropH = (imgHeight * dimensionRatio).round().clamp(64, imgHeight);

      // Tọa độ tâm điểm chạm quy đổi sang ảnh thực tế
      final int centerX = (tapX * scaleX).round();
      final int centerY = (tapY * scaleY).round();

      // Giới hạn tọa độ trong biên ảnh an toàn [0, width - cropW]
      final int cropX = (centerX - cropW ~/ 2).clamp(0, imgWidth - cropW);
      final int cropY = (centerY - cropH ~/ 2).clamp(0, imgHeight - cropH);

      // Cắt ảnh theo ROI
      img.Image cropped = img.copyCrop(
        fullImage,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      // Resize nếu kích thước vượt ngưỡng 768px (chống nghẽn mạng)
      if (cropped.width > maxDimension || cropped.height > maxDimension) {
        if (cropped.width >= cropped.height) {
          cropped = img.copyResize(cropped, width: maxDimension);
        } else {
          cropped = img.copyResize(cropped, height: maxDimension);
        }
      }

      // Nén JPEG quality 80% (đảm bảo file < 200KB)
      final List<int> jpegBytes = img.encodeJpg(cropped, quality: quality);
      return Uint8List.fromList(jpegBytes);
    });
  }

  /// Cắt vùng ROI từ CameraImage (frame đang stream từ Camera)
  static Future<Uint8List> cropAndCompressRoiFromCameraImage({
    required CameraImage cameraImage,
    required ui.Offset tapPos,
    required ui.Size screenSize,
    double cropAreaRatio = 0.36,
    int maxDimension = 768,
    int quality = 80,
    int rotationDegrees = 90,
    bool mirrorHorizontal = false,
  }) async {
    final ui.Image uiImage = await convertCameraImageToUiImage(
      cameraImage,
      rotationDegrees: rotationDegrees,
      mirrorHorizontal: mirrorHorizontal,
    );
    try {
      return await cropAndCompressRoiFromUiImage(
        uiImage: uiImage,
        tapPos: tapPos,
        screenSize: screenSize,
        cropAreaRatio: cropAreaRatio,
        maxDimension: maxDimension,
        quality: quality,
      );
    } finally {
      uiImage.dispose();
    }
  }

  /// Nén toàn bộ khung hình ảnh tĩnh để quét tổng quan (Deep Scene Scan) trên Background Isolate
  static Future<Uint8List> compressFullImageForDeepScan({
    required ui.Image uiImage,
    int maxDimension = 768,
    int quality = 80,
  }) async {
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw Exception('Không thể trích xuất mảng byte từ hình ảnh');
    }

    final Uint8List rawBytes = byteData.buffer.asUint8List();
    final int imgWidth = uiImage.width;
    final int imgHeight = uiImage.height;

    return await Isolate.run(() {
      img.Image fullImage = img.Image.fromBytes(
        width: imgWidth,
        height: imgHeight,
        bytes: rawBytes.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );

      if (fullImage.width > maxDimension || fullImage.height > maxDimension) {
        if (fullImage.width >= fullImage.height) {
          fullImage = img.copyResize(fullImage, width: maxDimension);
        } else {
          fullImage = img.copyResize(fullImage, height: maxDimension);
        }
      }

      final List<int> jpegBytes = img.encodeJpg(fullImage, quality: quality);
      return Uint8List.fromList(jpegBytes);
    });
  }
}
