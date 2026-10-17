import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/supabase_config.dart';

/// Service quản lý lưu trữ điểm số & lịch sử làm bài tập 4 kỹ năng lên Supabase Cloud.
class PracticeService {
  static final SupabaseClient _supabase = SupabaseConfig.client;

  /// Tra cứu UUID hợp lệ từ bảng 'profiles' trên Supabase dựa vào Auth User ID hoặc username
  static Future<String?> _resolveUserId(String? username) async {
    // 1. Nếu người dùng đăng nhập qua Supabase Auth
    final authId = _supabase.auth.currentUser?.id;
    if (authId != null && authId.isNotEmpty) {
      return authId;
    }

    final targetUsername = (username != null && username.isNotEmpty) ? username : 'learner';

    try {
      // 2. Tra cứu id (UUID) từ bảng profiles dựa theo username
      final profile = await _supabase
          .from('profiles')
          .select('id')
          .eq('username', targetUsername)
          .maybeSingle();

      if (profile != null && profile['id'] != null) {
        return profile['id'] as String;
      }

      // 3. Nếu chưa có profile trong Supabase, tự động tạo mới để lấy UUID
      final newProfile = await _supabase.from('profiles').insert({
        'username': targetUsername,
        'role': 'learner',
      }).select('id').single();

      return newProfile['id'] as String;
    } catch (e) {
      log('⚠️ Không thể resolve UUID cho người dùng "$targetUsername": $e');
      // Thử fallback về tài khoản 'learner' mặc định nếu có sẵn
      try {
        final fallback = await _supabase
            .from('profiles')
            .select('id')
            .eq('username', 'learner')
            .maybeSingle();
        if (fallback != null && fallback['id'] != null) {
          return fallback['id'] as String;
        }
      } catch (_) {}
      return null;
    }
  }

  /// Lưu kết quả bài làm (Reading / Listening) lên Supabase
  static Future<bool> savePracticeResult({
    required String skillType, // 'reading', 'listening'
    required String lessonId,
    required String lessonTitle,
    required int score,
    required int totalQuestions,
    required String bandScore,
    String? username,
  }) async {
    try {
      final userId = await _resolveUserId(username);
      if (userId == null) {
        log('⚠️ Không tìm thấy user_id (UUID) hợp lệ trên Supabase.');
        return false;
      }

      await _supabase.from('practice_history').insert({
        'user_id': userId,
        'skill_type': skillType,
        'lesson_id': lessonId,
        'lesson_title': lessonTitle,
        'score': score,
        'total_questions': totalQuestions,
        'band_score': bandScore,
        'created_at': DateTime.now().toIso8601String(),
      });

      log('✅ Đã lưu thành công kết quả ($skillType - $lessonTitle - Band $bandScore) lên Supabase!');
      return true;
    } catch (e) {
      log('⚠️ Lỗi lưu kết quả làm bài lên Supabase: $e');
      return false;
    }
  }

  /// Lấy lịch sử làm bài từ Supabase
  static Future<List<Map<String, dynamic>>> getPracticeHistory(String skillType, {String? username}) async {
    try {
      final userId = await _resolveUserId(username);
      if (userId == null) return [];

      final data = await _supabase
          .from('practice_history')
          .select()
          .eq('user_id', userId)
          .eq('skill_type', skillType)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      log('⚠️ Lỗi lấy lịch sử làm bài từ Supabase: $e');
      return [];
    }
  }
}
