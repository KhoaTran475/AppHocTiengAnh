import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../database/supabase_config.dart';
import '../../data/models/note_model.dart';
import 'notebook_service.dart';

/// Dịch vụ đồng bộ Sổ tay ghi chú đa năng trực tiếp với Supabase Cloud.
/// Hoạt động theo mô hình Offline-First: SQLite lưu trước, sau đó đồng bộ đám mây ngầm.
class NoteSyncService {
  static final SupabaseClient _supabase = SupabaseConfig.client;

  /// Đẩy một ghi chú đơn lẻ lên Supabase Cloud (Upsert theo `uuid`)
  static Future<bool> syncNoteToSupabase(
    NoteModel note, {
    String? username,
  }) async {
    try {
      final userUuid = await NotebookService.resolveUserId(
        username: username,
        localUserId: note.userId,
      );

      if (userUuid == null) {
        log('⚠️ Không tìm thấy userUuid hợp lệ trên Supabase cho note: ${note.title}');
        return false;
      }

      final payload = note.toSupabaseMap(userUuid);

      // Thực hiện upsert trên Supabase dựa theo cột 'uuid'
      await _supabase.from('notes').upsert(
            payload,
            onConflict: 'uuid',
          );

      log('✅ [NoteSyncService] Đã đồng bộ ghi chú "${note.title}" (${note.type}) lên Supabase!');
      return true;
    } catch (e) {
      log('⚠️ [NoteSyncService] Lỗi đồng bộ ghi chú "${note.title}" lên Supabase: $e');
      return false;
    }
  }

  /// Đồng bộ trạng thái xóa ghi chú lên Supabase Cloud
  static Future<bool> deleteNoteFromSupabase(
    String uuid, {
    String? username,
    int? localUserId,
    bool hardDelete = false,
  }) async {
    try {
      final userUuid = await NotebookService.resolveUserId(
        username: username,
        localUserId: localUserId,
      );
      if (userUuid == null) return false;

      if (hardDelete) {
        await _supabase
            .from('notes')
            .delete()
            .eq('user_id', userUuid)
            .eq('uuid', uuid);
      } else {
        await _supabase
            .from('notes')
            .update({
              'deleted_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('user_id', userUuid)
            .eq('uuid', uuid);
      }

      log('✅ [NoteSyncService] Đã cập nhật trạng thái xóa ghi chú $uuid trên Supabase.');
      return true;
    } catch (e) {
      log('⚠️ [NoteSyncService] Lỗi xóa ghi chú trên Supabase: $e');
      return false;
    }
  }

  /// Đồng bộ 2 chiều (2-way sync) toàn bộ sổ tay giữa SQLite và Supabase Cloud
  static Future<void> syncNotes({
    required int localUserId,
    String? username,
  }) async {
    try {
      final userUuid = await NotebookService.resolveUserId(
        username: username,
        localUserId: localUserId,
      );
      if (userUuid == null) {
        log('⚠️ [NoteSyncService] Không thể xác định userUuid để đồng bộ sổ tay.');
        return;
      }

      final dbHelper = DatabaseHelper.instance;

      // 1. Tải danh sách ghi chú từ Supabase
      List<dynamic> cloudRecords = [];
      try {
        cloudRecords = await _supabase
            .from('notes')
            .select()
            .eq('user_id', userUuid);
      } catch (e) {
        log('⚠️ [NoteSyncService] Không thể tải notes từ Supabase (có thể bảng chưa tạo hoặc offline): $e');
        return;
      }

      final Map<String, Map<String, dynamic>> cloudMap = {};
      for (final r in cloudRecords) {
        if (r is Map<String, dynamic> && r['uuid'] != null) {
          cloudMap[r['uuid'].toString()] = r;
        }
      }

      // 2. Tải danh sách ghi chú từ SQLite (bao gồm cả các bản ghi soft deleted để so sánh)
      final localNotes = await dbHelper.getNotesByUser(
        localUserId,
        includeDeleted: true,
      );
      final Map<String, NoteModel> localMap = {
        for (final n in localNotes) n.uuid: n,
      };

      // 3. Đẩy các ghi chú local mới hơn hoặc chưa có trên Supabase
      for (final local in localNotes) {
        final cloud = cloudMap[local.uuid];
        if (cloud == null) {
          // Chưa có trên cloud -> Đẩy lên
          await syncNoteToSupabase(local, username: username);
        } else {
          // So sánh updatedAt giữa local và cloud
          final localUpdated = DateTime.tryParse(local.updatedAt) ?? DateTime(2000);
          final cloudUpdated = DateTime.tryParse(cloud['updated_at']?.toString() ?? '') ?? DateTime(1999);

          if (localUpdated.isAfter(cloudUpdated)) {
            // Local mới hơn -> Cập nhật lên cloud
            await syncNoteToSupabase(local, username: username);
          }
        }
      }

      // 4. Kéo các ghi chú cloud mới hơn hoặc chưa có ở SQLite về local
      for (final entry in cloudMap.entries) {
        final cloudUuid = entry.key;
        final cloudData = entry.value;
        final local = localMap[cloudUuid];

        if (local == null) {
          // Chưa có ở local -> Thêm vào SQLite
          final newNote = NoteModel.fromMap(cloudData).copyWith(userId: localUserId);
          await dbHelper.insertNote(newNote);
        } else {
          // Có ở local, kiểm tra xem cloud có mới hơn không
          final localUpdated = DateTime.tryParse(local.updatedAt) ?? DateTime(2000);
          final cloudUpdated = DateTime.tryParse(cloudData['updated_at']?.toString() ?? '') ?? DateTime(1999);

          if (cloudUpdated.isAfter(localUpdated)) {
            final updatedNote = NoteModel.fromMap(cloudData).copyWith(
              id: local.id,
              userId: localUserId,
            );
            await dbHelper.updateNote(updatedNote);
          }
        }
      }

      log('✅ [NoteSyncService] Đồng bộ 2 chiều Notes thành công (Tổng ${cloudMap.length} cloud, ${localNotes.length} local)!');
    } catch (e) {
      log('⚠️ [NoteSyncService] Ngoại lệ khi chạy 2-way sync: $e');
    }
  }
}

