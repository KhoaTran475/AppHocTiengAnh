import 'dart:io';
import 'package:flutter/foundation.dart';

/// Quản lý toàn bộ URLs & Endpoints kết nối tới FastAPI Backend
class ApiEndpoints {
  /// Địa chỉ IP LAN mặc định của máy tính chạy server (192.168.1.54)
  static const String serverHost = '192.168.1.54';

  /// Base URL thông minh:
  /// - Android Thiết bị thật hoặc Wi-Fi: 192.168.1.50:8000
  /// - Android Emulator: 10.0.2.2:8000
  /// - Windows / Web / iOS: 127.0.0.1:8000
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }
    if (Platform.isAndroid) {
      return 'http://$serverHost:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  static String baseUrl = defaultBaseUrl;

  // --- Auth & Users ---
  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth/register';
  static String get me => '$baseUrl/auth/me';
  static String get users => '$baseUrl/users/';

  // --- FaceID Biometric Auth ---
  static String get faceNonce => '$baseUrl/auth/face/nonce';
  static String get faceLogin => '$baseUrl/auth/face/login';
  static String get faceRegister => '$baseUrl/auth/face/register';
  static String get faceStatus => '$baseUrl/auth/face/status';
  static String get faceDelete => '$baseUrl/auth/face';

  // --- AI Vision ---
  static String get detect => '$baseUrl/vision/detect';

  // --- Vocabulary & Mappings ---
  static String get mappings => '$baseUrl/vocabulary/mappings';
  static String mappingByLabel(String label) => '$baseUrl/vocabulary/mappings/$label';
  static String mappingById(int id) => '$baseUrl/vocabulary/mappings/$id';
  static String get resetMappings => '$baseUrl/vocabulary/mappings/reset';
  static String get lookup => '$baseUrl/vocabulary/lookup';

  // --- Sổ tay từ vựng ---
  static String get notebook => '$baseUrl/notebook/';
  static String notebookItem(int id) => '$baseUrl/notebook/$id';
  static String checkNotebook(String label) => '$baseUrl/notebook/check?label=$label';

  // --- 4 Kỹ năng IELTS ---
  static String skillLessons(String skill) => '$baseUrl/skills/$skill/lessons';
  static String lessonDetail(String id) => '$baseUrl/skills/lessons/$id';
  static String get submitTest => '$baseUrl/skills/submit';
  static String get history => '$baseUrl/skills/history';
  static String skillProgress(String skill) => '$baseUrl/skills/$skill/progress';
  static String get listeningProgress => skillProgress('listening');

  // --- Admin ---
  static String get adminKpis => '$baseUrl/admin/kpis';
  static String get adminSkillLessons => '$baseUrl/admin/skills/lessons';
  static String adminSkillLessonDetail(String id) => '$baseUrl/admin/skills/lessons/$id';
  static String get adminSkillImport => '$baseUrl/admin/skills/import';
  static String adminSkillTemplate([String? skill]) => skill != null
      ? '$baseUrl/admin/skills/template?skill_type=$skill'
      : '$baseUrl/admin/skills/template';
}
