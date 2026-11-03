import 'dart:async';
import 'dart:developer';
import '../../core/database/database_helper.dart';
import '../../core/services/note_sync_service.dart';
import '../models/note_model.dart';
import '../models/vocabulary_item_model.dart';

/// Repository quản lý toàn bộ nghiệp vụ CRUD và đồng bộ Sổ tay ghi chú đa năng.
/// Đóng vai trò Single Source of Truth cho tất cả các màn hình (Reading, Listening, Writing, Speaking, Camera, v.v.)
class NoteRepository {
  static final NoteRepository _instance = NoteRepository._internal();
  factory NoteRepository() => _instance;
  NoteRepository._internal();

  static NoteRepository get instance => _instance;

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  final _changeController = StreamController<void>.broadcast();

  /// Stream thông báo khi có bất kỳ thay đổi nào (thêm/sửa/xóa/sync) đối với ghi chú
  Stream<void> get onNotesChanged => _changeController.stream;

  /// Phát tín hiệu cho các màn hình (đặc biệt Sổ tay) tự động cập nhật UI tức thì
  void notifyNotesChanged() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  /// Lưu một ghi chú mới hoặc cập nhật nếu đã tồn tại
  Future<NoteModel> saveNote(NoteModel note, {String? username}) async {
    try {
      NoteModel resultNote;
      if (note.id != null) {
        await _dbHelper.updateNote(note);
        resultNote = note;
      } else {
        // Kiểm tra xem đã tồn tại ghi chú có cùng uuid chưa
        final existing = await _dbHelper.getNoteByUuid(note.uuid);
        if (existing != null && existing.id != null) {
          final updated = note.copyWith(id: existing.id);
          await _dbHelper.updateNote(updated);
          resultNote = updated;
        } else {
          final newId = await _dbHelper.insertNote(note);
          resultNote = note.copyWith(id: newId);
        }
      }

      // Nếu là từ vựng, đồng thời ghi nhận vào bảng Vocabulary_Notebook cũ để duy trì tương thích ngược
      if (resultNote.type == NoteType.vocab && resultNote.vocabData != null) {
        try {
          await _dbHelper.insertNotebookItem(
            resultNote.vocabData!,
            username: username,
            skipCloudSync: true,
          );
        } catch (_) {}
      }

      // Phát thông báo thay đổi ngay lập tức cho UI
      notifyNotesChanged();

      // Tự động kích hoạt đồng bộ Supabase Cloud ngầm
      NoteSyncService.syncNoteToSupabase(resultNote, username: username)
          .catchError((e) {
        log('Sync note cloud error: $e');
        return false;
      });

      return resultNote;
    } catch (e) {
      log('⚠️ Lỗi khi lưu ghi chú trong NoteRepository: $e');
      rethrow;
    }
  }

  /// Tiện ích lưu nhanh một ghi chú (Quick Note) từ các màn hình luyện tập
  Future<NoteModel> saveQuickNote({
    required int userId,
    required String type,
    required String source,
    required String title,
    required String content,
    String? userNote,
    String? sourceRef,
    List<String> tags = const [],
    int? color,
    VocabularyItemModel? vocabData,
    String? username,
  }) async {
    final note = NoteModel(
      userId: userId,
      type: type,
      source: source,
      sourceRef: sourceRef,
      title: title.trim(),
      content: content.trim(),
      userNote: userNote?.trim().isNotEmpty == true ? userNote!.trim() : null,
      tags: tags,
      color: color,
      vocabData: vocabData,
    );

    return await saveNote(note, username: username);
  }

  /// Sửa lỗi các ghi chú Listening bị gắn nhầm nguồn Reading
  Future<int> fixListeningNotesSource() async {
    return await _dbHelper.fixListeningNotesSource();
  }

  /// Lấy danh sách ghi chú của học viên với bộ lọc linh hoạt
  Future<List<NoteModel>> getNotes(
    int userId, {
    String? type,
    String? source,
    bool includeDeleted = false,
    String? searchQuery,
  }) async {
    try {
      return await _dbHelper.getNotesByUser(
        userId,
        type: type,
        source: source,
        includeDeleted: includeDeleted,
        searchQuery: searchQuery,
      );
    } catch (e) {
      log('⚠️ Lỗi khi lấy danh sách ghi chú: $e');
      return [];
    }
  }

  /// Lấy chi tiết một ghi chú theo ID
  Future<NoteModel?> getNoteById(int id) async {
    return await _dbHelper.getNoteById(id);
  }

  /// Lấy ghi chú theo UUID
  Future<NoteModel?> getNoteByUuid(String uuid) async {
    return await _dbHelper.getNoteByUuid(uuid);
  }

  /// Cập nhật nội dung ghi chú cá nhân của người học
  Future<bool> updateUserNote(int noteId, String? userNote, {String? username}) async {
    try {
      final existing = await _dbHelper.getNoteById(noteId);
      if (existing == null) return false;

      final updated = existing.copyWith(
        userNote: userNote,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _dbHelper.updateNote(updated);

      NoteSyncService.syncNoteToSupabase(updated, username: username)
          .catchError((_) => false);

      notifyNotesChanged();
      return true;
    } catch (e) {
      log('⚠️ Lỗi cập nhật userNote: $e');
      return false;
    }
  }

  /// Bật / tắt ghim ghi chú lên đầu
  Future<bool> togglePin(int noteId, bool isPinned, {String? username}) async {
    try {
      final existing = await _dbHelper.getNoteById(noteId);
      if (existing == null) return false;

      final updated = existing.copyWith(
        isPinned: isPinned,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _dbHelper.updateNote(updated);

      NoteSyncService.syncNoteToSupabase(updated, username: username)
          .catchError((_) => false);

      notifyNotesChanged();
      return true;
    } catch (e) {
      log('⚠️ Lỗi togglePin ghi chú: $e');
      return false;
    }
  }

  /// Xóa ghi chú (Mặc định soft delete)
  Future<bool> deleteNote(int id, {bool softDelete = true, String? username}) async {
    try {
      final existing = await _dbHelper.getNoteById(id);
      await _dbHelper.deleteNote(id, softDelete: softDelete);

      if (existing != null) {
        NoteSyncService.deleteNoteFromSupabase(
          existing.uuid,
          username: username,
          localUserId: existing.userId,
          hardDelete: !softDelete,
        ).catchError((_) => false);
      }

      notifyNotesChanged();
      return true;
    } catch (e) {
      log('⚠️ Lỗi xóa ghi chú: $e');
      return false;
    }
  }

  /// Khôi phục ghi chú đã xóa
  Future<bool> restoreNote(int id, {String? username}) async {
    try {
      await _dbHelper.restoreNote(id);
      final restored = await _dbHelper.getNoteById(id);
      if (restored != null) {
        NoteSyncService.syncNoteToSupabase(restored, username: username)
            .catchError((_) => false);
      }
      notifyNotesChanged();
      return true;
    } catch (e) {
      log('⚠️ Lỗi khôi phục ghi chú: $e');
      return false;
    }
  }

  /// Thực hiện đồng bộ 2 chiều với Supabase Cloud
  Future<void> syncWithCloud(int userId, {String? username}) async {
    await NoteSyncService.syncNotes(localUserId: userId, username: username);
    notifyNotesChanged();
  }

  /// Kiểm tra xem nội dung đã được lưu vào sổ tay chưa
  Future<bool> isSaved(int userId, String title, {String? type}) async {
    try {
      return await _dbHelper.isNoteSaved(userId, title, type: type);
    } catch (e) {
      log('⚠️ Lỗi kiểm tra trạng thái lưu: $e');
      return false;
    }
  }

  /// Đếm tổng số ghi chú
  Future<int> getNotesCount(int userId, {String? type}) async {
    try {
      return await _dbHelper.getNotesCount(userId, type: type);
    } catch (e) {
      return 0;
    }
  }
}

