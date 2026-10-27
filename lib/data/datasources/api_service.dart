import 'dart:developer';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/user_model.dart';
import '../models/object_mapping_model.dart';
import '../models/vocabulary_item_model.dart';
import '../models/skill_models.dart';
import '../repositories/skill_repository.dart';

/// Service trung tâm giao tiếp trực tiếp với FastAPI Backend
class ApiService {
  static final ApiService instance = ApiService._init();
  final Dio _dio = ApiClient.instance.dio;

  ApiService._init();

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
      final msg = e.response?.data?['detail'] ?? 'Đăng nhập thất bại: ${e.message}';
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
      final msg = e.response?.data?['detail'] ?? 'Đăng ký thất bại: ${e.message}';
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
      final msg = e.response?.data?['detail'] ?? 'Không thể lấy mã bảo mật FaceID: ${e.message}';
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
      final detail = e.response?.data?['detail'] ?? 'Đăng nhập FaceID thất bại';
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
      final detail = e.response?.data?['detail'] ?? 'Đăng ký FaceID thất bại: ${e.message}';
      throw Exception(detail);
    }
  }

  /// Kiểm tra trạng thái FaceID của tài khoản hiện tại
  Future<Map<String, dynamic>> getFaceStatus() async {
    try {
      final res = await _dio.get(ApiEndpoints.faceStatus);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? 'Không thể kiểm tra trạng thái FaceID: ${e.message}';
      throw Exception(detail);
    }
  }

  /// Hủy đăng ký FaceID của tài khoản hiện tại
  Future<bool> deleteFace() async {
    try {
      await _dio.delete(ApiEndpoints.faceDelete);
      return true;
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? 'Hủy FaceID thất bại: ${e.message}';
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
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi thêm từ vựng');
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
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi sửa từ vựng');
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
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi lưu từ vào sổ tay');
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
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi nộp bài thi');
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

  // ─────────────────────────────────────────────────────────────
  // 5. ADMIN MANAGEMENT & KPIS
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAdminKpis() async {
    try {
      final res = await _dio.get(ApiEndpoints.adminKpis);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi tải KPIs');
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final res = await _dio.get(ApiEndpoints.users);
      final list = res.data as List<dynamic>;
      return list.map((e) => UserModel.fromMap(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi tải danh sách người dùng');
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
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi tạo tài khoản');
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      await _dio.delete('${ApiEndpoints.users}$id');
      return true;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi xóa tài khoản');
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
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi nhận diện AI');
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
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi tải danh sách bài học');
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
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi tạo bài học mới');
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
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi cập nhật bài học');
    }
  }

  Future<bool> deleteSkillLesson(String lessonId) async {
    try {
      await _dio.delete(ApiEndpoints.adminSkillLessonDetail(lessonId));
      return true;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi xóa bài học');
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
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi nạp file đề thi');
    }
  }

  Future<List<dynamic>> getSkillTemplate([String? skillType]) async {
    try {
      final res = await _dio.get(ApiEndpoints.adminSkillTemplate(skillType));
      return res.data as List<dynamic>;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Lỗi tải file mẫu');
    }
  }
}
