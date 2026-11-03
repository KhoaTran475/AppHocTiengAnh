import 'dart:convert';
import 'dart:math';
import 'vocabulary_item_model.dart';

/// Các loại ghi chú được hỗ trợ trong Sổ tay
class NoteType {
  static const String vocab = 'vocab';
  static const String sentence = 'sentence';
  static const String feedback = 'feedback';
  static const String free = 'free';

  static const List<String> all = [vocab, sentence, feedback, free];

  static String getDisplayName(String type) {
    switch (type) {
      case vocab:
        return 'Từ vựng';
      case sentence:
        return 'Câu & Ngữ cảnh';
      case feedback:
        return 'Nhận xét AI';
      case free:
        return 'Ghi chú tự do';
      default:
        return 'Ghi chú';
    }
  }
}

/// Nguồn gốc tạo ra ghi chú
class NoteSource {
  static const String reading = 'reading';
  static const String listening = 'listening';
  static const String writing = 'writing';
  static const String speaking = 'speaking';
  static const String camera = 'camera';
  static const String vocabLearning = 'vocab_learning';
  static const String aiGrading = 'ai_grading';
  static const String manual = 'manual';

  static String getDisplayName(String source) {
    switch (source) {
      case reading:
        return 'Reading';
      case listening:
        return 'Listening';
      case writing:
        return 'Writing';
      case speaking:
        return 'Speaking';
      case camera:
        return 'Camera Scan';
      case vocabLearning:
        return 'Học Từ vựng';
      case aiGrading:
        return 'Lịch sử Chấm điểm';
      case manual:
      default:
        return 'Thủ công';
    }
  }
}

/// Cấu trúc chuẩn hóa cho tham chiếu nguồn gốc (sourceRef) dạng JSON
class NoteSourceRef {
  final String screen; // reading | listening | writing | speaking | vocab_learning | manual
  final dynamic lessonId; // Chấp nhận cả String và int
  final int? stageNumber;
  final String? title;
  final String? subtitle;
  final Map<String, dynamic>? extra;

  const NoteSourceRef({
    required this.screen,
    this.lessonId,
    this.stageNumber,
    this.title,
    this.subtitle,
    this.extra,
  });

  /// Tạo chuỗi JSON chuẩn hóa
  static String encode({
    required String screen,
    dynamic lessonId,
    int? stageNumber,
    String? title,
    String? subtitle,
    Map<String, dynamic>? extra,
  }) {
    final map = <String, dynamic>{
      'screen': screen,
      if (lessonId != null) 'lesson_id': lessonId,
      if (stageNumber != null) 'stage_number': stageNumber,
      if (title != null && title.isNotEmpty) 'title': title,
      if (subtitle != null && subtitle.isNotEmpty) 'subtitle': subtitle,
      if (extra != null && extra.isNotEmpty) ...extra,
    };
    return jsonEncode(map);
  }

  /// Phân tích an toàn chuỗi sourceRef (hỗ trợ cả JSON chuẩn và chuỗi văn bản thuần)
  static NoteSourceRef parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const NoteSourceRef(screen: 'manual');
    }
    final trimmed = raw.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return NoteSourceRef(
            screen: decoded['screen']?.toString() ?? 'manual',
            lessonId: decoded['lesson_id'],
            stageNumber: decoded['stage_number'] is int
                ? decoded['stage_number'] as int
                : (decoded['stage'] is int
                    ? decoded['stage'] as int
                    : int.tryParse(decoded['stage_number']?.toString() ?? decoded['stage']?.toString() ?? '')),
            title: decoded['title']?.toString(),
            subtitle: decoded['subtitle']?.toString(),
            extra: decoded,
          );
        }
      } catch (_) {
        // Fallback bên dưới
      }
    }
    // Nếu là văn bản thuần legacy
    return NoteSourceRef(
      screen: 'manual',
      title: trimmed,
    );
  }

  /// Lấy tiêu đề hiển thị thân thiện trên UI
  static String getDisplayText(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final parsed = parse(raw);
    if (parsed.title != null && parsed.title!.isNotEmpty) {
      if (parsed.stageNumber != null) {
        return 'Ải ${parsed.stageNumber}: ${parsed.title}';
      }
      return parsed.title!;
    }
    if (parsed.stageNumber != null) {
      return 'Ải ${parsed.stageNumber}';
    }
    return raw;
  }
}

/// Model đại diện cho một bản ghi trong Sổ tay ghi chú đa năng (Notes).
class NoteModel {
  final int? id;
  final String uuid;
  final int userId;
  final String type; // NoteType: vocab | sentence | feedback | free
  final String source; // NoteSource: reading | listening | writing | ...
  final String? sourceRef; // json hoặc chuỗi tham chiếu đến bài học / câu hỏi
  final String title;
  final String content;
  final String? userNote;
  final List<String> tags;
  final int? color;
  final bool isPinned;
  final VocabularyItemModel? vocabData;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  NoteModel({
    this.id,
    String? uuid,
    required this.userId,
    required this.type,
    required this.source,
    this.sourceRef,
    required this.title,
    required this.content,
    this.userNote,
    this.tags = const [],
    this.color,
    this.isPinned = false,
    this.vocabData,
    String? createdAt,
    String? updatedAt,
    this.deletedAt,
  })  : uuid = uuid ?? generateUuid(),
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  /// Tạo ngẫu nhiên chuỗi UUID v4 chuẩn (không cần thêm dependency ngoài)
  static String generateUuid() {
    final Random random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    // Set version 4
    values[6] = (values[6] & 0x0f) | 0x40;
    // Set variant 10xx
    values[8] = (values[8] & 0x3f) | 0x80;

    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-${hex.sublist(10, 16).join()}';
  }

  /// Chuyển đổi từ `VocabularyItemModel` cũ sang `NoteModel`
  factory NoteModel.fromVocabItem(
    VocabularyItemModel item, {
    String source = NoteSource.camera,
    String? userNote,
    List<String> tags = const [],
  }) {
    return NoteModel(
      id: null,
      userId: item.userId,
      type: NoteType.vocab,
      source: source,
      title: item.word,
      content: item.translation.isNotEmpty ? item.translation : item.word,
      userNote: userNote,
      tags: tags.isNotEmpty ? tags : [item.bandScore.isNotEmpty ? 'Band ${item.bandScore}' : 'IELTS'],
      vocabData: item,
      createdAt: item.createdAt,
      updatedAt: item.createdAt,
    );
  }

  /// Chuyển thành VocabularyItemModel tương thích ngược nếu là loại từ vựng
  VocabularyItemModel? toVocabItem() {
    if (vocabData != null) return vocabData;
    if (type != NoteType.vocab) return null;

    return VocabularyItemModel(
      id: id,
      userId: userId,
      label: title.toLowerCase().trim(),
      word: title.trim(),
      ipa: '',
      translation: content.trim(),
      example: userNote,
      bandScore: '7.0',
      createdAt: createdAt,
    );
  }

  /// Chuyển thành Map để lưu vào bảng SQLite `Notes`
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'uuid': uuid,
      'userId': userId,
      'type': type,
      'source': source,
      'sourceRef': sourceRef,
      'title': title,
      'content': content,
      'userNote': userNote,
      'tags': tags.isNotEmpty ? jsonEncode(tags) : null,
      'color': color,
      'isPinned': isPinned ? 1 : 0,
      'vocabData': vocabData != null ? jsonEncode(vocabData!.toMap()) : null,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
    };
  }

  /// Chuyển thành Map chuẩn cho bảng `notes` trên Supabase (PostgreSQL schema)
  Map<String, dynamic> toSupabaseMap(String userUuid) {
    DateTime parsedCreated;
    try {
      parsedCreated = DateTime.parse(createdAt);
    } catch (_) {
      parsedCreated = DateTime.now();
    }

    DateTime parsedUpdated;
    try {
      parsedUpdated = DateTime.parse(updatedAt);
    } catch (_) {
      parsedUpdated = DateTime.now();
    }

    String? parsedDeleted;
    if (deletedAt != null) {
      try {
        parsedDeleted = DateTime.parse(deletedAt!).toUtc().toIso8601String();
      } catch (_) {
        parsedDeleted = DateTime.now().toUtc().toIso8601String();
      }
    }

    return {
      'uuid': uuid,
      'user_id': userUuid,
      'type': type,
      'source': source,
      'source_ref': sourceRef,
      'title': title,
      'content': content,
      'user_note': userNote,
      'tags': tags,
      'color': color,
      'is_pinned': isPinned,
      'vocab_data': vocabData != null ? vocabData!.toMap() : null,
      'created_at': parsedCreated.toUtc().toIso8601String(),
      'updated_at': parsedUpdated.toUtc().toIso8601String(),
      'deleted_at': parsedDeleted,
    };
  }

  /// Khởi tạo từ Map của bảng SQLite `Notes` hoặc Supabase
  factory NoteModel.fromMap(Map<String, dynamic> map) {
    int parsedUserId = 1;
    final rawUserId = map['userId'] ?? map['user_id'];
    if (rawUserId is int) {
      parsedUserId = rawUserId;
    } else if (rawUserId != null) {
      parsedUserId = int.tryParse(rawUserId.toString()) ?? 1;
    }

    // Parse tags
    List<String> parsedTags = [];
    final rawTags = map['tags'];
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList();
    } else if (rawTags is String && rawTags.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTags);
        if (decoded is List) {
          parsedTags = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        parsedTags = rawTags.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }

    // Parse vocabData
    VocabularyItemModel? parsedVocabData;
    final rawVocab = map['vocabData'] ?? map['vocab_data'];
    if (rawVocab is Map<String, dynamic>) {
      parsedVocabData = VocabularyItemModel.fromMap(rawVocab);
    } else if (rawVocab is String && rawVocab.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawVocab);
        if (decoded is Map<String, dynamic>) {
          parsedVocabData = VocabularyItemModel.fromMap(decoded);
        }
      } catch (_) {}
    }

    final rawPinned = map['isPinned'] ?? map['is_pinned'];
    final bool parsedIsPinned = rawPinned == 1 || rawPinned == true;

    return NoteModel(
      id: map['id'] as int?,
      uuid: map['uuid'] as String? ?? generateUuid(),
      userId: parsedUserId,
      type: map['type'] as String? ?? NoteType.free,
      source: map['source'] as String? ?? NoteSource.manual,
      sourceRef: map['sourceRef'] as String? ?? map['source_ref'] as String?,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      userNote: map['userNote'] as String? ?? map['user_note'] as String?,
      tags: parsedTags,
      color: map['color'] as int?,
      isPinned: parsedIsPinned,
      vocabData: parsedVocabData,
      createdAt: map['createdAt'] as String? ?? map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: map['updatedAt'] as String? ?? map['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      deletedAt: map['deletedAt'] as String? ?? map['deleted_at'] as String?,
    );
  }

  factory NoteModel.fromJson(Map<String, dynamic> json) => NoteModel.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  NoteModel copyWith({
    int? id,
    String? uuid,
    int? userId,
    String? type,
    String? source,
    String? sourceRef,
    String? title,
    String? content,
    String? userNote,
    List<String>? tags,
    int? color,
    bool? isPinned,
    VocabularyItemModel? vocabData,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return NoteModel(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      title: title ?? this.title,
      content: content ?? this.content,
      userNote: userNote ?? this.userNote,
      tags: tags ?? this.tags,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      vocabData: vocabData ?? this.vocabData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}

