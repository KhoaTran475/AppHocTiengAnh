import 'dart:convert';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../data/models/object_mapping_model.dart';
import '../../data/models/vocabulary_item_model.dart';
import '../../data/models/user_model.dart';

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

  /// Lưu một từ vựng mới vào Sổ tay của Học viên
  Future<int> insertNotebookItem(VocabularyItemModel item) async {
    final db = await instance.database;
    return await db.insert(
      'Vocabulary_Notebook',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  /// Xóa một từ vựng khỏi Sổ tay theo ID
  Future<int> deleteNotebookItem(int id) async {
    final db = await instance.database;
    return await db.delete(
      'Vocabulary_Notebook',
      where: 'id = ?',
      whereArgs: [id],
    );
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
    return await db.insert('Users', {
      'username': username,
      'password': password,
      'role': role,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Xóa người dùng theo ID (không xóa được tài khoản admin chính)
  Future<int> deleteUser(int id) async {
    final db = await instance.database;
    return await db.delete('Users', where: 'id = ?', whereArgs: [id]);
  }

  /// Đóng cơ sở dữ liệu khi app dừng
  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
