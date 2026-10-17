import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../database/supabase_config.dart';
import '../../data/models/vocabulary_item_model.dart';

/// Service quản lý đồng bộ Sổ tay từ vựng (Vocabulary Notebook) giữa SQLite và Supabase Cloud.
class NotebookService {
  static final SupabaseClient _supabase = SupabaseConfig.client;

  /// Tra cứu UUID hợp lệ từ bảng 'profiles' trên Supabase dựa theo username hoặc local userId
  static Future<String?> resolveUserId({
    String? username,
    int? localUserId,
  }) async {
    // 1. Kiểm tra session Supabase Auth (nếu có)
    final authId = _supabase.auth.currentUser?.id;
    if (authId != null && authId.isNotEmpty) {
      return authId;
    }

    try {
      String? targetUsername = username;

      // Nếu chưa có username, tra cứu trong SQLite từ localUserId
      if ((targetUsername == null || targetUsername.isEmpty) && localUserId != null) {
        final db = await DatabaseHelper.instance.database;
        final res = await db.query(
          'Users',
          columns: ['username'],
          where: 'id = ?',
          whereArgs: [localUserId],
          limit: 1,
        );
        if (res.isNotEmpty) {
          targetUsername = res.first['username'] as String?;
        }
      }

      final lookupName = (targetUsername != null && targetUsername.isNotEmpty)
          ? targetUsername
          : 'learner';

      // 2. Tra cứu UUID từ bảng profiles theo username
      final profile = await _supabase
          .from('profiles')
          .select('id')
          .eq('username', lookupName)
          .maybeSingle();

      if (profile != null && profile['id'] != null) {
        return profile['id'] as String;
      }

      // 3. Nếu chưa có profile trong Supabase, tạo mới để lấy UUID
      final newProfile = await _supabase.from('profiles').insert({
        'username': lookupName,
        'role': 'learner',
      }).select('id').single();

      return newProfile['id'] as String;
    } catch (e) {
      log('⚠️ Không thể resolve UUID cho sổ tay từ vựng: $e');
      // Fallback về tài khoản learner mặc định
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

  /// Đồng bộ một từ vựng mới hoặc đã sửa lên Supabase Cloud (bảng vocabulary_notebook)
  static Future<bool> syncItemToSupabase(
    VocabularyItemModel item, {
    String? username,
  }) async {
    try {
      final userUuid = await resolveUserId(
        username: username,
        localUserId: item.userId,
      );

      if (userUuid == null) {
        log('⚠️ Không tìm thấy user_id (UUID) hợp lệ trên Supabase cho từ "${item.word}".');
        return false;
      }

      // Chuẩn hóa thời gian tạo sang ISO-8601 hợp lệ cho PostgreSQL timestamptz
      DateTime parsedTime;
      try {
        parsedTime = DateTime.parse(item.createdAt);
      } catch (_) {
        parsedTime = DateTime.now();
      }

      final payload = {
        'user_id': userUuid,
        'label': item.label,
        'word': item.word,
        'ipa': item.ipa,
        'translation': item.translation,
        'example': item.example,
        'example_translation': item.exampleTranslation,
        'band_score': item.bandScore,
        'collocations': item.collocations,
        'idioms': item.idioms,
        'created_at': parsedTime.toUtc().toIso8601String(),
      };

      // Kiểm tra xem từ vựng đã tồn tại trên Supabase chưa
      final existing = await _supabase
          .from('vocabulary_notebook')
          .select('id')
          .eq('user_id', userUuid)
          .eq('word', item.word)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('vocabulary_notebook')
            .update(payload)
            .eq('id', existing['id']);
      } else {
        await _supabase.from('vocabulary_notebook').insert(payload);
      }

      log('✅ Đã đồng bộ từ vựng "${item.word}" lên Supabase vocabulary_notebook!');
      return true;
    } catch (e) {
      log('⚠️ Lỗi đồng bộ từ vựng "${item.word}" lên Supabase: $e');
      return false;
    }
  }

  /// Xóa từ vựng trên Supabase khi người dùng xóa ở sổ tay local
  static Future<bool> deleteFromSupabase({
    required String word,
    String? username,
    int? localUserId,
  }) async {
    try {
      final userUuid = await resolveUserId(
        username: username,
        localUserId: localUserId,
      );
      if (userUuid == null) return false;

      await _supabase
          .from('vocabulary_notebook')
          .delete()
          .eq('user_id', userUuid)
          .eq('word', word);

      log('✅ Đã xóa từ "$word" trên Supabase vocabulary_notebook.');
      return true;
    } catch (e) {
      log('⚠️ Lỗi xóa từ vựng trên Supabase: $e');
      return false;
    }
  }

  /// Đồng bộ 2 chiều (2-way sync) giữa SQLite nội bộ và Supabase Cloud
  static Future<void> syncNotebook({
    required int localUserId,
    String? username,
  }) async {
    try {
      final userUuid = await resolveUserId(
        username: username,
        localUserId: localUserId,
      );
      if (userUuid == null) return;

      // 1. Lấy danh sách từ Supabase
      final cloudRecords = await _supabase
          .from('vocabulary_notebook')
          .select()
          .eq('user_id', userUuid);

      final cloudList = List<Map<String, dynamic>>.from(cloudRecords);
      final cloudWords = <String, Map<String, dynamic>>{};
      for (final r in cloudList) {
        final w = (r['word'] as String? ?? '').trim().toLowerCase();
        if (w.isNotEmpty) {
          cloudWords[w] = r;
        }
      }

      // 2. Lấy danh sách từ SQLite
      final localList = await DatabaseHelper.instance.getNotebookItemsByUser(localUserId);
      final localWords = <String, VocabularyItemModel>{};
      for (final item in localList) {
        localWords[item.word.trim().toLowerCase()] = item;
      }

      // 3. Đẩy từ local lên Supabase nếu Supabase chưa có
      for (final item in localList) {
        if (!cloudWords.containsKey(item.word.trim().toLowerCase())) {
          await syncItemToSupabase(item, username: username);
        }
      }

      // 4. Kéo từ Supabase về SQLite nếu local chưa có
      for (final entry in cloudWords.entries) {
        if (!localWords.containsKey(entry.key)) {
          final r = entry.value;
          final newItem = VocabularyItemModel(
            userId: localUserId,
            label: r['label'] as String? ?? r['word'] as String? ?? '',
            word: r['word'] as String? ?? '',
            ipa: r['ipa'] as String? ?? '',
            translation: r['translation'] as String? ?? '',
            example: r['example'] as String?,
            exampleTranslation: r['example_translation'] as String?,
            bandScore: r['band_score'] as String? ?? '7.0',
            collocations: r['collocations'] as String?,
            idioms: r['idioms'] as String?,
            createdAt: r['created_at'] as String? ?? DateTime.now().toIso8601String(),
          );
          await DatabaseHelper.instance.insertNotebookItem(
            newItem,
            skipCloudSync: true,
          );
        }
      }

      log('✅ Hoàn tất đồng bộ 2 chiều Sổ tay từ vựng với Supabase!');
    } catch (e) {
      log('⚠️ Lỗi đồng bộ sổ tay 2 chiều: $e');
    }
  }
}
