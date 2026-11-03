import 'dart:convert';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../data/models/object_mapping_model.dart';
import '../../data/models/vocabulary_item_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/note_model.dart';
import 'supabase_config.dart';
import '../services/notebook_service.dart';

/// Lớp Helper quản lý toàn bộ cơ sở dữ liệu SQLite nội bộ (Local Database).
/// Tuân thủ nguyên tắc Singleton, xử lý Migration, CRUD và Auto-seeding dữ liệu IELTS.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('ielts_vision_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );

    // Khởi tạo và tự động migration bảng Notes (Sổ tay ghi chú đa ngữ cảnh)
    try {
      await _ensureNotesTable(db);
      await _migrateVocabNotebookToNotes(db);
      await _fixListeningNotesSource(db);
    } catch (e) {
      log('Lỗi auto-sync/migration Notes table: $e');
    }

    // Tự động kiểm tra và nâng cấp cột email cho Users
    try {
      await db.execute('ALTER TABLE Users ADD COLUMN email TEXT;');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE Users ADD COLUMN is_email_verified INTEGER DEFAULT 0;');
    } catch (_) {}

    // Tự động đồng bộ hóa toàn bộ kho từ điển nếu phiên âm chưa được chuyển sang từ thông dụng
    try {
      final sample = await db.query(
        'Object_Mappings',
        where: "label = 'person' AND ipa != '/ˈpɜː.sən/'",
        limit: 1,
      );
      if (sample.isNotEmpty) {
        await db.delete('Object_Mappings');
        await _seedObjectMappings(db);
        log('✅ Đã tự động đồng bộ hóa phiên âm từ thông dụng cho toàn bộ 82 từ vựng!');
      }
    } catch (e) {
      log('Lỗi auto-sync Object_Mappings: $e');
    }

    return db;
  }

  /// Khởi tạo cấu trúc các bảng trong SQLite
  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const textNullable = 'TEXT';

    // 1. Bảng Users: Quản lý đăng nhập và phân quyền RBAC
    await db.execute('''
      CREATE TABLE Users (
        id $idType,
        username $textType UNIQUE,
        password $textType,
        role $textType, -- 'learner' hoặc 'admin'
        createdAt $textType
      )
    ''');

    // 2. Bảng Vocabulary_Notebook: Sổ tay từ vựng của Học viên
    await db.execute('''
      CREATE TABLE Vocabulary_Notebook (
        id $idType,
        userId $intType,
        label $textType,
        word $textType,
        ipa $textType,
        translation $textNullable,
        example $textNullable,
        exampleTranslation $textNullable,
        bandScore $textType,
        collocations $textNullable,
        idioms $textNullable,
        createdAt $textType,
        FOREIGN KEY (userId) REFERENCES Users (id) ON DELETE CASCADE
      )
    ''');

    // 3. Bảng Object_Mappings: Kho từ điển IELTS chuẩn hóa cho các nhãn nhận diện AI
    await db.execute('''
      CREATE TABLE Object_Mappings (
        id $idType,
        label $textType UNIQUE,
        commonWord $textType,
        vietnameseMeaning $textType,
        academicWord $textType,
        ipa $textType,
        bandScore $textType,
        collocations $textNullable,
        idioms $textNullable,
        speakingPart1Example $textNullable,
        speakingPart1Translation $textNullable
      )
    ''');

    // 4. Bảng Notes: Sổ tay ghi chú đa năng (Vocab, Sentence, Feedback, Free)
    await _ensureNotesTable(db);

    // Nạp dữ liệu mẫu ban đầu (Admin, Learner mẫu và 80 nhãn từ vựng)
    await _seedInitialUsers(db);
    await _seedObjectMappings(db);
  }

  /// Khởi tạo tài khoản Admin và Học viên mẫu để kiểm thử
  Future<void> _seedInitialUsers(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Tài khoản Admin quản trị
    await db.insert('Users', {
      'username': 'admin',
      'password': 'password123',
      'role': 'admin',
      'createdAt': now,
    });

    // Tài khoản Học viên trải nghiệm
    await db.insert('Users', {
      'username': 'learner',
      'password': 'password123',
      'role': 'learner',
      'createdAt': now,
    });

    log('✅ Đã seed tài khoản mẫu: admin/password123 và learner/password123');
  }

  /// Nạp tự động 80 nhãn từ vựng IELTS chuẩn học thuật (có tiếng Việt) từ file JSON assets
  Future<void> _seedObjectMappings(Database db) async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/ielts_vocab_80_labels.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);

      final batch = db.batch();
      for (final item in jsonList) {
        final mapping = ObjectMappingModel.fromJson(item as Map<String, dynamic>);
        batch.insert(
          'Object_Mappings',
          mapping.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      log('✅ Đã seed thành công ${jsonList.length} nhãn từ vựng IELTS vào SQLite!');
    } catch (e) {
      log('⚠️ Lỗi khi seed dữ liệu Object_Mappings: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PHƯƠNG THỨC TRUY VẤN: OBJECT_MAPPINGS (DÀNH CHO AI CAMERA & ADMIN)
  // ─────────────────────────────────────────────────────────────

  /// Lấy thông tin từ vựng IELTS tương ứng với nhãn nhận diện từ YOLO
  Future<ObjectMappingModel?> getMappingByLabel(String label) async {
    final db = await instance.database;
    final normalized = label.trim().toLowerCase();
    final results = await db.query(
      'Object_Mappings',
      where: 'LOWER(label) = ?',
      whereArgs: [normalized],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return ObjectMappingModel.fromMap(results.first);
    }
    return null;
  }

  /// Lấy toàn bộ kho từ vựng mapping (dành cho Admin Dashboard)
  Future<List<ObjectMappingModel>> getAllMappings() async {
    final db = await instance.database;
    final results = await db.query('Object_Mappings', orderBy: 'id ASC');
    return results.map((map) => ObjectMappingModel.fromMap(map)).toList();
  }

  /// Cập nhật dữ liệu từ vựng (dành cho Admin chỉnh sửa từ, collocations, ví dụ...)
  Future<int> updateMapping(ObjectMappingModel mapping) async {
    final db = await instance.database;
    return await db.update(
      'Object_Mappings',
      mapping.toMap(),
      where: 'id = ?',
      whereArgs: [mapping.id],
    );
  }

  /// Thêm mới một nhãn / từ vựng mapping vào kho từ điển
  Future<int> insertMapping(ObjectMappingModel mapping) async {
    final db = await instance.database;
    return await db.insert(
      'Object_Mappings',
      mapping.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Xóa một bản ghi mapping theo ID
  Future<int> deleteMapping(int id) async {
    final db = await instance.database;
    return await db.delete(
      'Object_Mappings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Khôi phục toàn bộ 82 nhãn từ vựng IELTS mặc định từ file JSON assets
  Future<void> resetDefaultMappings() async {
    final db = await instance.database;
    await db.delete('Object_Mappings');
    await _seedObjectMappings(db);
  }

  /// Đếm tổng số lượng từ vựng trong kho mapping
  Future<int> getMappingCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM Object_Mappings');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ─────────────────────────────────────────────────────────────
  // PHƯƠNG THỨC TRUY VẤN: VOCABULARY_NOTEBOOK (SỔ TAY CỦA HỌC VIÊN)
  // ─────────────────────────────────────────────────────────────

  /// Lưu một từ vựng mới vào Sổ tay của Học viên (SQLite & Supabase)
  Future<int> insertNotebookItem(
    VocabularyItemModel item, {
    String? username,
    bool skipCloudSync = false,
  }) async {
    final db = await instance.database;
    final id = await db.insert(
      'Vocabulary_Notebook',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (!skipCloudSync) {
      // Tự động đẩy lên Supabase Cloud chạy ngầm
      NotebookService.syncItemToSupabase(item, username: username);
    }

    return id;
  }

  /// Lấy toàn bộ danh sách từ vựng đã lưu của một Học viên cụ thể
  Future<List<VocabularyItemModel>> getNotebookItemsByUser(int userId) async {
    final db = await instance.database;
    final results = await db.query(
      'Vocabulary_Notebook',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
    return results.map((map) => VocabularyItemModel.fromMap(map)).toList();
  }

  /// Xóa một từ vựng khỏi Sổ tay theo ID (và Supabase)
  Future<int> deleteNotebookItem(
    int id, {
    String? word,
    String? username,
    int? localUserId,
  }) async {
    final db = await instance.database;

    // Nếu chưa truyền word, query từ db để biết từ nào cần xóa trên Supabase
    String? targetWord = word;
    int? targetUserId = localUserId;
    if (targetWord == null) {
      final res = await db.query(
        'Vocabulary_Notebook',
        columns: ['word', 'userId'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (res.isNotEmpty) {
        targetWord = res.first['word'] as String?;
        targetUserId ??= res.first['userId'] as int?;
      }
    }

    final result = await db.delete(
      'Vocabulary_Notebook',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (targetWord != null && targetWord.isNotEmpty) {
      NotebookService.deleteFromSupabase(
        word: targetWord,
        username: username,
        localUserId: targetUserId,
      );
    }

    return result;
  }

  /// Kiểm tra xem học viên này đã lưu nhãn/từ này vào Sổ tay chưa
  Future<bool> isWordSaved(int userId, String label) async {
    final db = await instance.database;
    final results = await db.query(
      'Vocabulary_Notebook',
      where: 'userId = ? AND LOWER(label) = ?',
      whereArgs: [userId, label.trim().toLowerCase()],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Đếm số từ vựng mà học viên đã lưu vào sổ tay
  Future<int> getNotebookCountByUser(int userId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM Vocabulary_Notebook WHERE userId = ?',
      [userId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ─────────────────────────────────────────────────────────────
  // THỐNG KÊ QUẢN TRỊ (DÀNH CHO ADMIN)
  // ─────────────────────────────────────────────────────────────

  /// Đếm tổng số người dùng trong hệ thống
  Future<int> getUserCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM Users');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Đếm tổng số học viên (role = 'learner')
  Future<int> getLearnerCount() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM Users WHERE role = 'learner'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Đếm tổng số từ vựng mà tất cả học viên đã lưu vào Sổ tay
  Future<int> getTotalNotebookSavedCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM Vocabulary_Notebook');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Lấy thống kê phân bố số lượng từ vựng theo từng Band điểm (7.0, 7.5, 8.0, 8.5)
  Future<Map<String, int>> getBandDistribution() async {
    final db = await instance.database;
    final results = await db.rawQuery(
      'SELECT bandScore, COUNT(*) as count FROM Object_Mappings GROUP BY bandScore ORDER BY bandScore ASC',
    );
    final Map<String, int> distribution = {};
    for (final row in results) {
      final band = row['bandScore'] as String? ?? 'Khác';
      final count = row['count'] as int? ?? 0;
      distribution[band] = count;
    }
    return distribution;
  }

  /// Lấy danh sách toàn bộ người dùng trong hệ thống
  Future<List<UserModel>> getAllUsers() async {
    final db = await instance.database;
    final results = await db.query('Users', orderBy: 'id ASC');
    return results.map((m) => UserModel.fromMap(m)).toList();
  }

  /// Thêm người dùng mới trực tiếp (bởi Admin)
  Future<int> insertUser({
    required String username,
    required String password,
    required String role,
  }) async {
    final db = await instance.database;
    final nowStr = DateTime.now().toIso8601String();
    final res = await db.insert('Users', {
      'username': username,
      'password': password,
      'role': role,
      'createdAt': nowStr,
    });

    // 🌐 ĐỒNG BỘ NGUỜI DÙNG MỚI LÊN SUPABASE (PROFILES)
    try {
      await SupabaseConfig.client.from('profiles').upsert({
        'username': username,
        'role': role,
        'created_at': nowStr,
        'updated_at': nowStr,
      }, onConflict: 'username');
      log('✅ Đã đồng bộ tài khoản mới "$username" ($role) lên Supabase profiles!');
    } catch (e) {
      log('⚠️ Lỗi đồng bộ tài khoản mới lên Supabase: $e');
    }

    return res;
  }

  /// Đồng bộ toàn bộ danh sách tài khoản từ SQLite lên Supabase profiles
  Future<void> syncAllUsersToSupabase() async {
    try {
      final db = await instance.database;
      final users = await db.query('Users');
      for (final u in users) {
        final username = u['username'] as String;
        final role = u['role'] as String? ?? 'learner';
        final createdAt = u['createdAt'] as String? ?? DateTime.now().toIso8601String();

        // Thử đăng ký qua Auth trước để thỏa mãn ràng buộc auth.users(id)
        try {
          await SupabaseConfig.client.auth.signUp(
            email: '$username@app.com',
            password: 'password123',
            data: {'username': username, 'role': role},
          );
        } catch (_) {}

        await SupabaseConfig.client.from('profiles').upsert({
          'username': username,
          'role': role,
          'created_at': createdAt,
          'updated_at': createdAt,
        }, onConflict: 'username');
        log('✅ Đã đồng bộ tài khoản "$username" ($role) lên Supabase profiles!');
      }
    } catch (e) {
      log('⚠️ Lỗi đồng bộ tài khoản lên Supabase: $e');
    }
  }

  /// Xóa người dùng theo ID (không xóa được tài khoản admin chính)
  Future<int> deleteUser(int id) async {
    final db = await instance.database;
    return await db.delete('Users', where: 'id = ?', whereArgs: [id]);
  }

  /// Xác thực đăng nhập người dùng từ SQLite cục bộ (chế độ offline fallback)
  Future<UserModel?> getUserByCredentials(String username, String password) async {
    final db = await instance.database;
    final results = await db.query(
      'Users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    if (results.isNotEmpty) {
      return UserModel.fromMap(results.first);
    }
    return null;
  }

  /// Đóng cơ sở dữ liệu khi app dừng
  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  // ─────────────────────────────────────────────────────────────
  // QUẢN LÝ VÀ DI CHUYỂN BẢNG NOTES (SỔ TAY GHI CHÚ ĐA NĂNG)
  // ─────────────────────────────────────────────────────────────

  /// Đảm bảo bảng Notes và index tồn tại
  Future<void> _ensureNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        userId INTEGER NOT NULL,
        type TEXT NOT NULL,
        source TEXT NOT NULL,
        sourceRef TEXT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        userNote TEXT,
        tags TEXT,
        color INTEGER,
        isPinned INTEGER DEFAULT 0,
        vocabData TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        deletedAt TEXT,
        FOREIGN KEY (userId) REFERENCES Users (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_user_type ON Notes(userId, type);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_uuid ON Notes(uuid);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_deleted ON Notes(deletedAt);');
  }

  /// Tự động di chuyển dữ liệu cũ từ Vocabulary_Notebook sang Notes (type = vocab)
  Future<void> _migrateVocabNotebookToNotes(Database db) async {
    try {
      final oldItems = await db.query('Vocabulary_Notebook');
      if (oldItems.isEmpty) return;

      int migratedCount = 0;
      for (final raw in oldItems) {
        final vocab = VocabularyItemModel.fromMap(raw);
        final title = vocab.word.trim();
        final existing = await db.query(
          'Notes',
          columns: ['id'],
          where: 'userId = ? AND LOWER(title) = ? AND type = ? AND deletedAt IS NULL',
          whereArgs: [vocab.userId, title.toLowerCase(), NoteType.vocab],
          limit: 1,
        );

        if (existing.isEmpty) {
          final note = NoteModel.fromVocabItem(vocab);
          await db.insert('Notes', note.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
          migratedCount++;
        }
      }
      if (migratedCount > 0) {
        log('✅ Đã migrate thành công $migratedCount từ vựng sang bảng Notes mới!');
      }
    } catch (e) {
      log('⚠️ Lỗi di chuyển dữ liệu Vocabulary_Notebook -> Notes: $e');
    }
  }

  /// Tự động sửa chữa các ghi chú từ bài Listening nhưng bị gắn nhầm nguồn Reading
  Future<void> _fixListeningNotesSource(Database db) async {
    try {
      final updated = await db.rawUpdate('''
        UPDATE Notes 
        SET source = 'listening',
            tags = REPLACE(tags, '"Reading"', '"Listening"')
        WHERE source = 'reading' 
          AND (
            sourceRef LIKE '%"lesson_id":"l%' 
            OR sourceRef LIKE '%"lesson_id": "l%'
            OR sourceRef LIKE '%lesson_id%l1%'
            OR sourceRef LIKE '%lesson_id%l2%'
            OR sourceRef LIKE '%lesson_id%l3%'
            OR sourceRef LIKE '%lesson_id%l4%'
            OR sourceRef LIKE '%lesson_id%l5%'
            OR title LIKE '%Dr. Marcus%'
          );
      ''');
      if (updated > 0) {
        log('✅ [DatabaseHelper] Đã tự động sửa $updated ghi chú Listening bị gắn nhầm nguồn Reading!');
      }
    } catch (e) {
      log('⚠️ Lỗi fixListeningNotesSource: $e');
    }
  }

  /// Phương thức public để gọi sửa chữa nguồn Listening từ bất cứ đâu
  Future<int> fixListeningNotesSource() async {
    try {
      final db = await instance.database;
      return await db.rawUpdate('''
        UPDATE Notes 
        SET source = 'listening',
            tags = REPLACE(tags, '"Reading"', '"Listening"')
        WHERE source = 'reading' 
          AND (
            sourceRef LIKE '%"lesson_id":"l%' 
            OR sourceRef LIKE '%"lesson_id": "l%'
            OR sourceRef LIKE '%lesson_id%l1%'
            OR sourceRef LIKE '%lesson_id%l2%'
            OR sourceRef LIKE '%lesson_id%l3%'
            OR sourceRef LIKE '%lesson_id%l4%'
            OR sourceRef LIKE '%lesson_id%l5%'
            OR title LIKE '%Dr. Marcus%'
          );
      ''');
    } catch (e) {
      log('Lỗi fixListeningNotesSource: $e');
      return 0;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PHƯƠNG THỨC TRUY VẤN: NOTES (SỔ TAY GHI CHÚ ĐA NĂNG)
  // ─────────────────────────────────────────────────────────────

  /// Thêm mới một ghi chú vào SQLite
  Future<int> insertNote(NoteModel note) async {
    final db = await instance.database;
    return await db.insert(
      'Notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Cập nhật ghi chú
  Future<int> updateNote(NoteModel note) async {
    final db = await instance.database;
    final map = note.toMap();
    map['updatedAt'] = DateTime.now().toIso8601String();
    return await db.update(
      'Notes',
      map,
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  /// Xóa ghi chú (Mặc định là Soft Delete để hỗ trợ đồng bộ đám mây an toàn)
  Future<int> deleteNote(int id, {bool softDelete = true}) async {
    final db = await instance.database;
    if (softDelete) {
      final now = DateTime.now().toIso8601String();
      return await db.update(
        'Notes',
        {
          'deletedAt': now,
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      return await db.delete(
        'Notes',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Khôi phục ghi chú đã bị soft delete
  Future<int> restoreNote(int id) async {
    final db = await instance.database;
    return await db.update(
      'Notes',
      {
        'deletedAt': null,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Lấy danh sách ghi chú theo User, có thể lọc theo type, source, và tìm kiếm
  Future<List<NoteModel>> getNotesByUser(
    int userId, {
    String? type,
    String? source,
    bool includeDeleted = false,
    String? searchQuery,
  }) async {
    final db = await instance.database;
    final whereClauses = <String>['userId = ?'];
    final whereArgs = <dynamic>[userId];

    if (!includeDeleted) {
      whereClauses.add('deletedAt IS NULL');
    }

    if (type != null && type.isNotEmpty && type != 'all') {
      whereClauses.add('type = ?');
      whereArgs.add(type);
    }

    if (source != null && source.isNotEmpty && source != 'all') {
      whereClauses.add('source = ?');
      whereArgs.add(source);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim().toLowerCase()}%';
      whereClauses.add('(LOWER(title) LIKE ? OR LOWER(content) LIKE ? OR LOWER(userNote) LIKE ?)');
      whereArgs.addAll([q, q, q]);
    }

    final results = await db.query(
      'Notes',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'isPinned DESC, updatedAt DESC',
    );

    return results.map((map) => NoteModel.fromMap(map)).toList();
  }

  /// Lấy ghi chú theo ID
  Future<NoteModel?> getNoteById(int id) async {
    final db = await instance.database;
    final results = await db.query(
      'Notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return NoteModel.fromMap(results.first);
    }
    return null;
  }

  /// Lấy ghi chú theo UUID
  Future<NoteModel?> getNoteByUuid(String uuid) async {
    final db = await instance.database;
    final results = await db.query(
      'Notes',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return NoteModel.fromMap(results.first);
    }
    return null;
  }

  /// Kiểm tra nội dung (từ vựng / câu) đã được lưu chưa
  Future<bool> isNoteSaved(int userId, String title, {String? type}) async {
    final db = await instance.database;
    final where = type != null
        ? 'userId = ? AND LOWER(title) = ? AND type = ? AND deletedAt IS NULL'
        : 'userId = ? AND LOWER(title) = ? AND deletedAt IS NULL';
    final args = type != null
        ? [userId, title.trim().toLowerCase(), type]
        : [userId, title.trim().toLowerCase()];

    final results = await db.query(
      'Notes',
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Đếm số ghi chú theo User và loại
  Future<int> getNotesCount(int userId, {String? type}) async {
    final db = await instance.database;
    if (type != null && type.isNotEmpty && type != 'all') {
      final res = await db.rawQuery(
        'SELECT COUNT(*) as count FROM Notes WHERE userId = ? AND type = ? AND deletedAt IS NULL',
        [userId, type],
      );
      return Sqflite.firstIntValue(res) ?? 0;
    } else {
      final res = await db.rawQuery(
        'SELECT COUNT(*) as count FROM Notes WHERE userId = ? AND deletedAt IS NULL',
        [userId],
      );
      return Sqflite.firstIntValue(res) ?? 0;
    }
  }
}
