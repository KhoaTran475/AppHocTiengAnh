/// Model đại diện cho một từ vựng đã được Học viên lưu vào Sổ tay từ vựng nội bộ (SQLite).
class VocabularyItemModel {
  final int? id;
  final int userId;
  final String label;
  final String word;
  final String ipa;
  final String translation;
  final String? example;
  final String? exampleTranslation;
  final String bandScore;
  final String? collocations;
  final String? idioms;
  final String createdAt;

  VocabularyItemModel({
    this.id,
    required this.userId,
    required this.label,
    required this.word,
    required this.ipa,
    required this.translation,
    this.example,
    this.exampleTranslation,
    required this.bandScore,
    this.collocations,
    this.idioms,
    required this.createdAt,
  });

  /// Chuyển thành Map để lưu vào SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'label': label,
      'word': word,
      'ipa': ipa,
      'translation': translation,
      'example': example,
      'exampleTranslation': exampleTranslation,
      'bandScore': bandScore,
      'collocations': collocations,
      'idioms': idioms,
      'createdAt': createdAt,
    };
  }

  /// Khởi tạo từ Map của SQLite
  factory VocabularyItemModel.fromMap(Map<String, dynamic> map) {
    return VocabularyItemModel(
      id: map['id'] as int?,
      userId: map['userId'] as int,
      label: map['label'] as String? ?? '',
      word: map['word'] as String? ?? '',
      ipa: map['ipa'] as String? ?? '',
      translation: map['translation'] as String? ?? '',
      example: map['example'] as String?,
      exampleTranslation: map['exampleTranslation'] as String?,
      bandScore: map['bandScore'] as String? ?? '7.0',
      collocations: map['collocations'] as String?,
      idioms: map['idioms'] as String?,
      createdAt: map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}
