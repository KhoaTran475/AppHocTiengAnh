import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/database/database_helper.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/user_model.dart';
import '../models/object_mapping_model.dart';
import '../models/vocabulary_item_model.dart';
import '../models/vocab_learning_models.dart';
import '../models/skill_models.dart';
import '../models/ai_grading_history_model.dart';
import '../repositories/skill_repository.dart';


/// Service trung tâm giao tiếp trực tiếp với FastAPI Backend
class ApiService {
  static final ApiService instance = ApiService._init();
  final Dio _dio = ApiClient.instance.dio;

  ApiService._init();

  /// Trích xuất thông báo lỗi an toàn từ DioException, chống triệt để lỗi ép kiểu dynamic ['detail']
  String _extractErrorMessage(DioException e, [String defaultMsg = 'Lỗi kết nối máy chủ']) {
    try {
      final data = e.response?.data;
      if (data == null) {
        if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          return 'Hết thời gian chờ phản hồi AI. Vui lòng thử lại sau giây lát.';
        }
        if (e.type == DioExceptionType.connectionError) {
          return 'Không thể kết nối máy chủ backend (${ApiEndpoints.baseUrl}). Vui lòng kiểm tra địa chỉ IP.';
        }
        return e.message ?? defaultMsg;
      }
      if (data is Map) {
        final detail = data['detail'] ?? data['message'] ?? data['error'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first.containsKey('msg')) {
            return first['msg'].toString();
          }
          return detail.join(', ');
        }
        return detail?.toString() ?? e.message ?? defaultMsg;
      }
      if (data is String && data.isNotEmpty) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map) {
            final detail = decoded['detail'] ?? decoded['message'] ?? decoded['error'];
            if (detail != null) return detail.toString();
          }
        } catch (_) {}
        return data.length > 150 ? '${data.substring(0, 150)}...' : data;
      }
      return e.message ?? defaultMsg;
    } catch (_) {
      return e.message ?? defaultMsg;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 1. AUTH & USERS
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.login,
        data: {'username': username, 'password': password},
      );
      final data = res.data as Map<String, dynamic>;
      final user = UserModel.fromMap(data['user'] as Map<String, dynamic>);
      return {
        'token': data['access_token'] as String,
        'user': user,
      };
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e, 'Đăng nhập thất bại: ${e.message}');
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> register(
    String username,
    String password, {
    bool isAdmin = false,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.register,
        data: {
          'username': username,
          'password': password,
          'role': isAdmin ? 'admin' : 'learner',
        },
      );
      final data = res.data as Map<String, dynamic>;
      final user = UserModel.fromMap(data['user'] as Map<String, dynamic>);
      return {
        'token': data['access_token'] as String,
        'user': user,
      };
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e, 'Đăng ký thất bại: ${e.message}');
      throw Exception(msg);
    }
  }

  /// Gửi mã OTP xác thực qua Email
  Future<Map<String, dynamic>> sendOtp({
    required String email,
    String type = 'register',
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.sendOtp,
        data: {
          'email': email.trim().toLowerCase(),
          'type': type,
        },
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e, 'Không thể gửi mã OTP: ${e.message}');
      throw Exception(msg);
    }
  }

  /// Xác thực mã OTP và hoàn tất Đăng ký tài khoản học viên mới
  Future<Map<String, dynamic>> registerVerifyOtp({
    required String email,
    required String otp,
    required String username,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.registerVerifyOtp,
        data: {
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
          'username': username.trim().toLowerCase(),
          'password': password,
        },
      );
      final data = res.data as Map<String, dynamic>;
      final user = UserModel.fromMap(data['user'] as Map<String, dynamic>);
      return {
        'token': data['access_token'] as String,
        'user': user,
      };
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e, 'Xác thực OTP đăng ký thất bại: ${e.message}');
      throw Exception(msg);
    }
  }

  /// Đăng nhập không cần mật khẩu bằng Email và mã OTP
  Future<Map<String, dynamic>> loginWithOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.loginOtp,
        data: {
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
        },
      );
      final data = res.data as Map<String, dynamic>;
      final user = UserModel.fromMap(data['user'] as Map<String, dynamic>);
      return {
        'token': data['access_token'] as String,
        'user': user,
      };
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e, 'Đăng nhập OTP thất bại: ${e.message}');
      throw Exception(msg);
    }
  }

  Future<UserModel?> getMe() async {
    try {
      final res = await _dio.get(ApiEndpoints.me);
      return UserModel.fromMap(res.data as Map<String, dynamic>);
    } catch (e) {
      log('Lỗi lấy thông tin cá nhân: $e');
      return null;
    }
  }

  // --- FaceID Biometric API ---

  /// Lấy mã thử thách ngẫu nhiên 60s để chống tấn công replay
  Future<String> getFaceNonce() async {
    try {
      final res = await _dio.get(ApiEndpoints.faceNonce);
      final data = res.data as Map<String, dynamic>;
      return data['nonce'] as String;
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e, 'Không thể lấy mã bảo mật FaceID: ${e.message}');
      throw Exception(msg);
    }
  }

  /// Đăng nhập bằng FaceID sử dụng ảnh Base64 và Nonce
  Future<Map<String, dynamic>> loginWithFace({
    required String imageBase64,
    required String nonce,
    String? usernameHint,
  }) async {
    try {
      final payload = <String, dynamic>{
        'image_base64': imageBase64,
        'nonce': nonce,
      };
      if (usernameHint != null && usernameHint.trim().isNotEmpty) {
        payload['username_hint'] = usernameHint.trim();
      }

      final res = await _dio.post(
        ApiEndpoints.faceLogin,
        data: payload,
      );
      final data = res.data as Map<String, dynamic>;
      final user = UserModel.fromMap(data['user'] as Map<String, dynamic>);
      return {
        'token': data['access_token'] as String,
        'user': user,
        'similarity': (data['similarity'] as num?)?.toDouble() ?? 0.0,
      };
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = _extractErrorMessage(e, 'Đăng nhập FaceID thất bại');
      if (statusCode == 422) {
        throw Exception('Ánh sáng hoặc góc chụp chưa đạt chuẩn: $detail');
      } else if (statusCode == 401) {
        throw Exception('Không tìm thấy khuôn mặt khớp trong hệ thống: $detail');
      }
      throw Exception(detail);
    }
  }

  /// Đăng ký hoặc cập nhật khuôn mặt FaceID cho tài khoản hiện tại
  Future<Map<String, dynamic>> registerFace({
    required String imageBase64,
    required String nonce,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.faceRegister,
        data: {
          'image_base64': imageBase64,
          'nonce': nonce,
        },
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final detail = _extractErrorMessage(e, 'Đăng ký FaceID thất bại: ${e.message}');
      throw Exception(detail);
    }
  }

  /// Kiểm tra trạng thái FaceID của tài khoản hiện tại
  Future<Map<String, dynamic>> getFaceStatus() async {
    try {
      final res = await _dio.get(ApiEndpoints.faceStatus);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final detail = _extractErrorMessage(e, 'Không thể kiểm tra trạng thái FaceID: ${e.message}');
      throw Exception(detail);
    }
  }

  /// Hủy đăng ký FaceID của tài khoản hiện tại
  Future<bool> deleteFace() async {
    try {
      await _dio.delete(ApiEndpoints.faceDelete);
      return true;
    } on DioException catch (e) {
      final detail = _extractErrorMessage(e, 'Hủy FaceID thất bại: ${e.message}');
      throw Exception(detail);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2. VOCABULARY & OBJECT MAPPINGS
  // ─────────────────────────────────────────────────────────────

  Future<List<ObjectMappingModel>> getMappings({
    String? search,
    String? band,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (band != null && band != 'Tất cả') queryParams['band'] = band;

      final res = await _dio.get(
        ApiEndpoints.mappings,
        queryParameters: queryParams,
      );
      final list = res.data as List<dynamic>;
      return list.map((e) => ObjectMappingModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log('Lỗi lấy danh sách mappings: $e');
      return [];
    }
  }

  Future<ObjectMappingModel?> getMappingByLabel(String label) async {
    try {
      final res = await _dio.get(ApiEndpoints.mappingByLabel(label.trim().toLowerCase()));
      return ObjectMappingModel.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      log('Lỗi tìm mapping theo nhãn "$label": $e');
      return null;
    }
  }

  Future<ObjectMappingModel> createMapping(ObjectMappingModel mapping) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.mappings,
        data: {
          'label': mapping.label,
          'common_word': mapping.commonWord,
          'vietnamese_meaning': mapping.vietnameseMeaning,
          'academic_word': mapping.academicWord,
          'ipa': mapping.ipa,
          'band_score': mapping.bandScore,
          'collocations': mapping.collocations,
          'idioms': mapping.idioms,
          'speaking_part1_example': mapping.speakingPart1Example,
          'speaking_part1_translation': mapping.speakingPart1Translation,
        },
      );
      return ObjectMappingModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi thêm từ vựng'));
    }
  }

  Future<ObjectMappingModel> updateMapping(ObjectMappingModel mapping) async {
    try {
      final res = await _dio.put(
        ApiEndpoints.mappingById(mapping.id!),
        data: {
          'common_word': mapping.commonWord,
          'vietnamese_meaning': mapping.vietnameseMeaning,
          'academic_word': mapping.academicWord,
          'ipa': mapping.ipa,
          'band_score': mapping.bandScore,
          'collocations': mapping.collocations,
          'idioms': mapping.idioms,
          'speaking_part1_example': mapping.speakingPart1Example,
          'speaking_part1_translation': mapping.speakingPart1Translation,
        },
      );
      return ObjectMappingModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi sửa từ vựng'));
    }
  }

  Future<bool> deleteMapping(int id) async {
    try {
      await _dio.delete(ApiEndpoints.mappingById(id));
      return true;
    } catch (e) {
      log('Lỗi xóa mapping: $e');
      return false;
    }
  }

  Future<bool> resetDefaultMappings() async {
    try {
      await _dio.post(ApiEndpoints.resetMappings);
      return true;
    } catch (e) {
      log('Lỗi reset mappings: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> lookupWord(String word) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.lookup,
        queryParameters: {'word': word.trim()},
      );
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 2.5 AI VISION DEEP SCAN (OLLAMA LLAVA-PHI3)
  // ─────────────────────────────────────────────────────────────

  Future<ObjectMappingModel> deepScanObject(Uint8List imageBytes) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          imageBytes,
          filename: 'deep_scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final res = await _dio.post(
        ApiEndpoints.deepScan,
        data: formData,
        options: Options(
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      dynamic rawData = res.data;
      if (rawData is String) {
        try {
          rawData = jsonDecode(rawData);
        } catch (_) {}
      }

      if (rawData is! Map) {
        throw Exception('Phản hồi server không đúng định dạng Map: $rawData');
      }

      dynamic rawVocab = rawData['vocabulary'];
      if (rawVocab is String) {
        try {
          rawVocab = jsonDecode(rawVocab);
        } catch (_) {}
      }

      if (rawVocab is! Map) {
        throw Exception('Dữ liệu từ vựng không hợp lệ trong phản hồi');
      }

      final Map<String, dynamic> vocabMap = Map<String, dynamic>.from(rawVocab);
      final mapping = ObjectMappingModel.fromJson(vocabMap);

      // Tự động đồng bộ vào SQLite cục bộ để dùng offline
      try {
        await DatabaseHelper.instance.insertMapping(mapping);
      } catch (e) {
        log('Lỗi sync SQLite mapping: $e');
      }

      return mapping;
    } on DioException catch (e) {
      final errorMsg = _extractErrorMessage(e, 'Lỗi quét chuyên sâu AI');
      log('Lỗi deepScanObject: $errorMsg');
      throw Exception(errorMsg);
    } catch (e) {
      log('Lỗi deepScanObject không mong muốn: $e');
      throw Exception('Không thể phân tích vật thể: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 3. VOCABULARY NOTEBOOK (SỔ TAY CÁ NHÂN)
  // ─────────────────────────────────────────────────────────────


  Future<List<VocabularyItemModel>> getNotebookItems() async {
    try {
      final res = await _dio.get(ApiEndpoints.notebook);
      final list = res.data as List<dynamic>;
      return list.map((e) => VocabularyItemModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log('Lỗi lấy sổ tay từ vựng: $e');
      rethrow;
    }

  }

  Future<VocabularyItemModel> saveToNotebook(VocabularyItemModel item) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.notebook,
        data: {
          'label': item.label,
          'word': item.word,
          'ipa': item.ipa,
          'translation': item.translation,
          'example': item.example,
          'example_translation': item.exampleTranslation,
          'band_score': item.bandScore,
          'collocations': item.collocations,
          'idioms': item.idioms,
        },
      );
      return VocabularyItemModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi lưu từ vào sổ tay'));
    }
  }

  Future<bool> deleteFromNotebook(int itemId) async {
    try {
      await _dio.delete(ApiEndpoints.notebookItem(itemId));
      return true;
    } catch (e) {
      log('Lỗi xóa từ khỏi sổ tay: $e');
      return false;
    }
  }

  Future<bool> checkWordSaved(String label) async {
    try {
      final res = await _dio.get(ApiEndpoints.checkNotebook(label.trim().toLowerCase()));
      return res.data?['saved'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 4. 4 KỸ NĂNG IELTS
  // ─────────────────────────────────────────────────────────────

  Future<List<ReadingPassageModel>> getReadingLessons() async {
    try {
      final res = await _dio.get(ApiEndpoints.skillLessons('reading'));
      final list = res.data as List<dynamic>;
      return list.map((e) {
        final content = e['content_json'] as Map<String, dynamic>;
        final rawParas = content['paragraphs'] as Map<String, dynamic>? ?? {};
        final Map<String, String> paragraphs = rawParas.map((k, v) => MapEntry(k, v.toString()));

        final rawQuestions = content['questions'] as List<dynamic>? ?? [];
        final questions = rawQuestions.map((q) {
          final options = (q['options'] as List<dynamic>).map((o) => o.toString()).toList();
          return ReadingQuestion(
            id: q['id'] as int,
            questionText: q['questionText'] as String,
            options: options,
            correctAnswer: q['correctAnswer'] as String,
            explanation: q['explanation'] as String? ?? '',
            paragraphRef: q['paragraphRef'] as String? ?? '',
          );
        }).toList();

        return ReadingPassageModel(
          id: e['id'] as String,
          stageNumber: (e['stage_number'] as num?)?.toInt() ?? 1,
          difficultyLabel: e['difficulty_label'] as String? ?? 'Ải ${e['stage_number'] ?? 1}',
          passScoreRequired: (e['pass_score_required'] as num?)?.toInt() ?? 2,
          title: e['title'] as String,
          category: e['category_or_topic'] as String? ?? 'General',
          bandScoreTarget: e['band_score_target'] as String? ?? '7.0',
          paragraphs: paragraphs,
          questions: questions,
        );
      }).toList();
    } catch (e) {
      log('Lỗi tải bài đọc từ API: $e');
      return SkillRepository.sampleReadingPassages;
    }
  }

  Future<List<ListeningLessonModel>> getListeningLessons() async {
    try {
      final res = await _dio.get(ApiEndpoints.skillLessons('listening'));
      final list = res.data as List<dynamic>;
      return list.map((e) {
        final content = e['content_json'] as Map<String, dynamic>;
        final rawQuestions = content['questions'] as List<dynamic>? ?? [];
        final questions = rawQuestions.map((q) {
          final options = (q['options'] as List<dynamic>).map((o) => o.toString()).toList();
          return ListeningQuestion(
            id: q['id'] as int,
            questionText: q['questionText'] as String,
            options: options,
            correctAnswer: q['correctAnswer'] as String,
            explanation: q['explanation'] as String? ?? '',
          );
        }).toList();

        return ListeningLessonModel(
          id: e['id'] as String,
          stageNumber: (e['stage_number'] as num?)?.toInt() ?? 1,
          difficultyLabel: e['difficulty_label'] as String? ?? 'Ải ${e['stage_number'] ?? 1}',
          title: e['title'] as String,
          topic: e['category_or_topic'] as String? ?? 'General',
          bandScoreTarget: e['band_score_target'] as String? ?? '7.0',
          passScoreRequired: (e['pass_score_required'] as num?)?.toInt() ?? 2,
          audioScript: content['audioScript'] as String? ?? '',
          questions: questions,
        );
      }).toList();
    } catch (e) {
      log('Lỗi tải bài nghe từ API: $e');
      return SkillRepository.sampleListeningLessons;
    }
  }

  Future<List<SpeakingLessonModel>> getSpeakingLessons() async {
    try {
      final res = await _dio.get(ApiEndpoints.skillLessons('speaking'));
      final list = res.data as List<dynamic>;
      return list.map((e) {
        final content = e['content_json'] as Map<String, dynamic>;
        final rawPart1 = content['part1Questions'] as List<dynamic>? ?? [];
        final part1Items = rawPart1.map((p) {
          final vocab = (p['keyVocabulary'] as List<dynamic>? ?? []).map((v) => v.toString()).toList();
          return SpeakingPart1Item(
            question: p['question'] as String,
            sampleAnswer: p['sampleAnswer'] as String,
            translation: p['translation'] as String? ?? '',
            keyVocabulary: vocab,
          );
        }).toList();

        final bulletPoints = (content['part2BulletPoints'] as List<dynamic>? ?? []).map((b) => b.toString()).toList();
        final collocations = (content['part2Collocations'] as List<dynamic>? ?? []).map((c) => c.toString()).toList();

        return SpeakingLessonModel(
          id: e['id'] as String,
          stageNumber: (e['stage_number'] as num?)?.toInt() ?? 1,
          difficultyLabel: e['difficulty_label'] as String? ?? 'Ải ${e['stage_number'] ?? 1}',
          passScoreRequired: (e['pass_score_required'] as num?)?.toInt() ?? 6,
          title: e['title'] as String,
          topic: e['category_or_topic'] as String? ?? 'General',
          bandScoreTarget: e['band_score_target'] as String? ?? '7.0',
          part1Questions: part1Items,
          part2CueCardPrompt: content['part2CueCardPrompt'] as String? ?? '',
          part2BulletPoints: bulletPoints,
          part2SampleAnswer: content['part2SampleAnswer'] as String? ?? '',
          part2SampleTranslation: content['part2SampleTranslation'] as String? ?? '',
          part2Collocations: collocations,
        );
      }).toList();
    } catch (e) {
      log('Lỗi tải bài nói từ API: $e');
      return SkillRepository.sampleSpeakingLessons;
    }
  }

  Future<List<WritingLessonModel>> getWritingLessons() async {
    try {
      final res = await _dio.get(ApiEndpoints.skillLessons('writing'));
      final list = res.data as List<dynamic>;
      return list.map((e) {
        final content = e['content_json'] as Map<String, dynamic>;
        final outlines = (content['keyOutline'] as List<dynamic>? ?? []).map((o) => o.toString()).toList();
        final vocabs = (content['academicVocabulary'] as List<dynamic>? ?? []).map((v) => v.toString()).toList();

        ChartDataModel? chartData;
        final rawChart = content['chart_data'] ?? content['chartData'];
        if (rawChart is Map<String, dynamic>) {
          chartData = ChartDataModel.fromMap(rawChart);
        }

        return WritingLessonModel(
          id: e['id'] as String,
          stageNumber: (e['stage_number'] as num?)?.toInt() ?? 1,
          difficultyLabel: e['difficulty_label'] as String? ?? 'Ải ${e['stage_number'] ?? 1}',
          passScoreRequired: (e['pass_score_required'] as num?)?.toInt() ?? 6,
          taskType: content['taskType'] as String? ?? 'Task 1',
          title: e['title'] as String,
          topic: e['category_or_topic'] as String? ?? 'General',
          bandScoreTarget: e['band_score_target'] as String? ?? '7.0',
          prompt: content['prompt'] as String? ?? '',
          minWordCount: content['minWordCount'] as int? ?? 150,
          suggestedTimeMinutes: content['suggestedTimeMinutes'] as int? ?? 20,
          keyOutline: outlines,
          sampleEssay: content['sampleEssay'] as String? ?? '',
          sampleTranslation: content['sampleTranslation'] as String? ?? '',
          academicVocabulary: vocabs,
          chartData: chartData,
        );
      }).toList();
    } catch (e) {
      log('Lỗi tải bài viết từ API: $e');
      return SkillRepository.sampleWritingLessons;
    }
  }


  Future<Map<String, dynamic>> submitTest({
    required String lessonId,
    required String skillType,
    Map<String, dynamic>? answers,
    String? essayText,
    Map<String, int>? ratings,
    String? lessonTitle,
    int? score,
    int? totalQuestions,
    String? bandScore,
    int? taskType,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.submitTest,
        data: {
          'lesson_id': lessonId,
          'skill_type': skillType,
          if (answers != null) 'answers': answers,
          if (essayText != null) 'essay_text': essayText,
          if (ratings != null) 'ratings': ratings,
          if (taskType != null) 'task_type': taskType,
        },
        options: Options(
          // Nâng timeout cho Writing khi chấm điểm bằng mô hình Qwen 2.5 7B Local
          receiveTimeout: skillType == 'writing' ? const Duration(seconds: 70) : const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 45),
        ),
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi nộp bài thi'));
    }
  }

  Future<Map<String, dynamic>> explainAnswer({
    required String lessonId,
    required dynamic questionId,
    required String userChoice,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.explainAnswer,
        data: {
          'lesson_id': lessonId,
          'question_id': questionId.toString(),
          'user_choice': userChoice,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Không thể lấy giải thích AI'));
    }
  }

  Future<List<Map<String, dynamic>>> getPracticeHistory({String? skillType}) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.history,
        queryParameters: skillType != null ? {'skill_type': skillType} : null,
      );
      return List<Map<String, dynamic>>.from(res.data as List<dynamic>);
    } catch (e) {
      log('Lỗi lấy lịch sử thi: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSkillProgress(String skillType) async {
    try {
      final res = await _dio.get(ApiEndpoints.skillProgress(skillType.toLowerCase()));
      return res.data as Map<String, dynamic>;
    } catch (e) {
      log('Lỗi lấy tiến độ $skillType: $e');
      return {'highest_unlocked_stage': 1, 'stages': []};
    }
  }

  Future<Map<String, dynamic>> getListeningProgress() => getSkillProgress('listening');

  /// Lấy lịch sử chấm điểm AI Qwen của học viên (Writing, Vocab sentence, Explain)
  Future<AiGradingHistoryPage> getMyAiGradingHistory({
    String? feature,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (feature != null && feature != 'all') {
        queryParams['feature'] = feature;
      }
      final res = await _dio.get(
        ApiEndpoints.aiGradingMyHistory,
        queryParameters: queryParams,
      );
      return AiGradingHistoryPage.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi lấy lịch sử chấm điểm AI'));
    } catch (e) {
      throw Exception('Không thể tải lịch sử chấm điểm AI: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 5. ADMIN MANAGEMENT & KPIS
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAdminKpis() async {
    try {
      final res = await _dio.get(ApiEndpoints.adminKpis);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi tải KPIs'));
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final res = await _dio.get(ApiEndpoints.users);
      final list = res.data as List<dynamic>;
      return list.map((e) => UserModel.fromMap(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi tải danh sách người dùng'));
    }
  }

  Future<UserModel> createUser({
    required String username,
    required String password,
    required String role,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.users,
        data: {
          'username': username,
          'password': password,
          'role': role,
        },
      );
      return UserModel.fromMap(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi tạo tài khoản'));
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      await _dio.delete('${ApiEndpoints.users}$id');
      return true;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi xóa tài khoản'));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 6. AI VISION (SERVER-SIDE INFERENCE)
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> detectImage(File file, {double confThreshold = 0.35}) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final res = await _dio.post(
        ApiEndpoints.detect,
        queryParameters: {'conf_threshold': confThreshold},
        data: formData,
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi nhận diện AI'));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 7. ADMIN SKILLS & 5 STAGES MANAGEMENT (CRUD + IMPORT FILE)
  // ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAdminSkillLessons(String skillType) async {
    try {
      final res = await _dio.get(ApiEndpoints.skillLessons(skillType.toLowerCase()));
      final list = res.data as List<dynamic>;
      return list.map((e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi tải danh sách bài học'));
    }
  }

  Future<Map<String, dynamic>> createSkillLesson(Map<String, dynamic> lessonData) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.adminSkillLessons,
        data: lessonData,
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi tạo bài học mới'));
    }
  }

  Future<Map<String, dynamic>> updateSkillLesson(String lessonId, Map<String, dynamic> lessonData) async {
    try {
      final res = await _dio.put(
        ApiEndpoints.adminSkillLessonDetail(lessonId),
        data: lessonData,
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi cập nhật bài học'));
    }
  }

  Future<bool> deleteSkillLesson(String lessonId) async {
    try {
      await _dio.delete(ApiEndpoints.adminSkillLessonDetail(lessonId));
      return true;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi xóa bài học'));
    }
  }

  Future<Map<String, dynamic>> importSkillLessonsFile({
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      });
      final res = await _dio.post(
        ApiEndpoints.adminSkillImport,
        data: formData,
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi nạp file đề thi'));
    }
  }

  Future<List<dynamic>> getSkillTemplate([String? skillType]) async {
    try {
      final res = await _dio.get(ApiEndpoints.adminSkillTemplate(skillType));
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi tải file mẫu'));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 8. HỌC TỪ VỰNG 5 CẤP ĐỘ CƠ BẢN -> NÂNG CAO (OLLAMA QWEN 2.5 LOCAL)
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getVocabLearningStatus() async {
    try {
      final res = await _dio.get(ApiEndpoints.vocabLearningStatus);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Không thể kiểm tra trạng thái Ollama Qwen 2.5'));
    }
  }

  Future<VocabRoadmapModel> getVocabRoadmap() async {
    try {
      final res = await _dio.get(ApiEndpoints.vocabLearningLevels);
      return VocabRoadmapModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi tải lộ trình học từ vựng 5 cấp độ'));
    }
  }

  /// Lấy cấu hình hệ thống học từ vựng và AI Qwen được quản trị từ Web Admin Portal
  Future<VocabSystemConfigModel> getVocabSystemConfig() async {
    try {
      final res = await _dio.get(ApiEndpoints.vocabLearningConfig);
      return VocabSystemConfigModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException {
      // Fallback về model mặc định an toàn nếu mất mạng hoặc backend phiên bản cũ
      return VocabSystemConfigModel(
        id: 1,
        activeModel: 'qwen2.5:7b',
        temperature: 0.3,
        defaultGenCount: 5,
        quizQuestionCount: 5,
        passPercentage: 60,
        starThresholds: const {'star1': 60, 'star2': 80, 'star3': 100},
        autoCacheEnabled: true,
        isOllamaOnline: false,
        availableModels: const ['qwen2.5:7b'],
        ollamaBaseUrl: 'http://localhost:11434',
      );
    }
  }

  Future<List<VocabCardModel>> getVocabLearningCards({
    int? level,
    String? topic,
    String? search,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (level != null) params['level'] = level;
      if (topic != null && topic.trim().isNotEmpty && topic != 'Tất cả') {
        params['topic'] = topic.trim();
      }
      if (search != null && search.trim().isNotEmpty) {
        params['search'] = search.trim();
      }
      final res = await _dio.get(
        ApiEndpoints.vocabLearningCards,
        queryParameters: params,
      );
      final list = res.data as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(VocabCardModel.fromJson)
          .toList();
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi tải danh sách thẻ từ vựng'));
    }
  }

  Future<Map<String, dynamic>> generateVocabWithQwen({
    required String topic,
    required int level,
    int count = 5,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.vocabLearningGenerate,
        data: {
          'topic': topic.trim(),
          'level': level,
          'count': count,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 95),
          receiveTimeout: const Duration(seconds: 95),
        ),
      );
      final data = res.data as Map<String, dynamic>;
      final rawCards = data['cards'] as List<dynamic>? ?? [];
      final cards = rawCards
          .whereType<Map<String, dynamic>>()
          .map(VocabCardModel.fromJson)
          .toList();
      return {
        'source': data['source']?.toString() ?? 'qwen2.5',
        'model_used': data['model_used']?.toString() ?? 'qwen2.5:latest',
        'cards': cards,
      };
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi sinh từ vựng với Ollama Qwen 2.5'));
    }
  }

  Future<SentenceEvaluationModel> evaluateSentenceWithQwen({
    required String word,
    required int level,
    required String userSentence,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.vocabLearningEvaluateSentence,
        data: {
          'word': word.trim(),
          'level': level,
          'user_sentence': userSentence.trim(),
        },
        options: Options(
          sendTimeout: const Duration(seconds: 65),
          receiveTimeout: const Duration(seconds: 65),
        ),
      );
      return SentenceEvaluationModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi chấm điểm câu với Ollama Qwen 2.5'));
    }
  }

  Future<Map<String, dynamic>> updateVocabMastery({
    required int cardId,
    required int masteryLevel,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.vocabLearningMastery,
        data: {
          'card_id': cardId,
          'mastery_level': masteryLevel,
        },
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi cập nhật mức độ thuộc từ'));
    }
  }

  Future<VocabQuizModel> generateVocabQuiz({
    required int level,
    String? topic,
    int questionCount = 5,
    bool useAiQwen = true,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.vocabLearningQuiz,
        data: {
          'level': level,
          if (topic != null && topic != 'Tất cả') 'topic': topic,
          'question_count': questionCount,
          'use_ai_qwen': useAiQwen,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 65),
          receiveTimeout: const Duration(seconds: 65),
        ),
      );
      return VocabQuizModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi tạo đề kiểm tra từ vựng'));
    }
  }

  Future<Map<String, dynamic>> submitVocabQuiz({
    required int level,
    required int score,
    required int totalQuestions,
    List<int> masteredCardIds = const [],
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.vocabLearningSubmitQuiz,
        data: {
          'level': level,
          'score': score,
          'total_questions': totalQuestions,
          'mastered_card_ids': masteredCardIds,
        },
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'Lỗi nộp bài kiểm tra từ vựng'));
    }
  }
}
