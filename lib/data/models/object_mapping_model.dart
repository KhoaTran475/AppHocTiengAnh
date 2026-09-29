import 'dart:convert';

/// Model đại diện cho một bản ghi mapping giữa nhãn nhận diện AI (YOLO)
/// và dữ liệu học thuật IELTS tương ứng (Band 7.0 - 8.5) kết hợp tài liệu ZIM.
class ObjectMappingModel {
  final int? id;
  final String label;
  final String commonWord;
  final String vietnameseMeaning;
  final String academicWord;
  final String ipa;
  final String bandScore;
  final List<String> collocations;
  final String idioms;
  final String speakingPart1Example;
  final String speakingPart1Translation;

  ObjectMappingModel({
    this.id,
    required this.label,
    required this.commonWord,
    required this.vietnameseMeaning,
    required this.academicWord,
    required this.ipa,
    required this.bandScore,
    required this.collocations,
    required this.idioms,
    required this.speakingPart1Example,
    required this.speakingPart1Translation,
  });

  /// Chuyển thành Map để lưu vào SQLite
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'label': label,
      'commonWord': commonWord,
      'vietnameseMeaning': vietnameseMeaning,
      'academicWord': academicWord,
      'ipa': ipa,
      'bandScore': bandScore,
      'collocations': jsonEncode(collocations),
      'idioms': idioms,
      'speakingPart1Example': speakingPart1Example,
      'speakingPart1Translation': speakingPart1Translation,
    };
  }

  /// Khởi tạo từ Map của SQLite
  factory ObjectMappingModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedCollocations = [];
    if (map['collocations'] != null) {
      try {
        final decoded = jsonDecode(map['collocations'] as String);
        if (decoded is List) {
          parsedCollocations = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        parsedCollocations = [];
      }
    }

    return ObjectMappingModel(
      id: map['id'] as int?,
      label: map['label'] as String? ?? '',
      commonWord: map['commonWord'] as String? ?? '',
      vietnameseMeaning: map['vietnameseMeaning'] as String? ?? '',
      academicWord: map['academicWord'] as String? ?? '',
      ipa: map['ipa'] as String? ?? '',
      bandScore: map['bandScore'] as String? ?? '7.0',
      collocations: parsedCollocations,
      idioms: map['idioms'] as String? ?? '',
      speakingPart1Example: map['speakingPart1Example'] as String? ?? '',
      speakingPart1Translation: map['speakingPart1Translation'] as String? ?? '',
    );
  }

  /// Khởi tạo từ file JSON assets
  factory ObjectMappingModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedCollocations = [];
    if (json['collocations'] is List) {
      parsedCollocations = (json['collocations'] as List).map((e) => e.toString()).toList();
    }

    return ObjectMappingModel(
      label: json['label'] as String? ?? '',
      commonWord: json['common_word'] as String? ?? '',
      vietnameseMeaning: json['vietnamese_meaning'] as String? ?? '',
      academicWord: json['academic_word'] as String? ?? '',
      ipa: json['ipa'] as String? ?? '',
      bandScore: json['band_score'] as String? ?? '7.0',
      collocations: parsedCollocations,
      idioms: json['idioms'] as String? ?? '',
      speakingPart1Example: json['speaking_part1_example'] as String? ?? '',
      speakingPart1Translation: json['speaking_part1_translation'] as String? ?? '',
    );
  }

  /// Tạo bản sao có cập nhật trường (hỗ trợ Admin chỉnh sửa)
  ObjectMappingModel copyWith({
    int? id,
    String? label,
    String? commonWord,
    String? vietnameseMeaning,
    String? academicWord,
    String? ipa,
    String? bandScore,
    List<String>? collocations,
    String? idioms,
    String? speakingPart1Example,
    String? speakingPart1Translation,
  }) {
    return ObjectMappingModel(
      id: id ?? this.id,
      label: label ?? this.label,
      commonWord: commonWord ?? this.commonWord,
      vietnameseMeaning: vietnameseMeaning ?? this.vietnameseMeaning,
      academicWord: academicWord ?? this.academicWord,
      ipa: ipa ?? this.ipa,
      bandScore: bandScore ?? this.bandScore,
      collocations: collocations ?? this.collocations,
      idioms: idioms ?? this.idioms,
      speakingPart1Example: speakingPart1Example ?? this.speakingPart1Example,
      speakingPart1Translation: speakingPart1Translation ?? this.speakingPart1Translation,
    );
  }
}
