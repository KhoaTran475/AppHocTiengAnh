library;

import 'package:flutter/material.dart';

/// Model dữ liệu cho bài học IELTS Reading
class ReadingQuestion {
  final int id;
  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final String? paragraphRef; // Ví dụ: "Đoạn A"

  ReadingQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    this.paragraphRef,
  });
}

class ReadingPassageModel {
  final String id;
  final int? stageNumberValue;
  final String? difficultyLabelValue;
  final String title;
  final String category;
  final String bandScoreTarget;
  final int? passScoreRequiredValue;
  final Map<String, String> paragraphs; // {'A': 'Chữ...', 'B': 'Chữ...'}
  final List<ReadingQuestion> questions;

  int get stageNumber => stageNumberValue ?? 1;
  String get difficultyLabel => difficultyLabelValue ?? 'Ải Cơ Bản';
  int get passScoreRequired => passScoreRequiredValue ?? 2;

  ReadingPassageModel({
    required this.id,
    int? stageNumber,
    String? difficultyLabel,
    required this.title,
    required this.category,
    required this.bandScoreTarget,
    int? passScoreRequired,
    required this.paragraphs,
    required this.questions,
  })  : stageNumberValue = stageNumber,
        difficultyLabelValue = difficultyLabel,
        passScoreRequiredValue = passScoreRequired;
}

class ListeningQuestion {
  final int id;
  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final String explanation;

  ListeningQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });
}

class ListeningLessonModel {
  final String id;
  final int? stageNumberValue;
  final String? difficultyLabelValue;
  final String title;
  final String topic;
  final String bandScoreTarget;
  final String audioScript;
  final int? passScoreRequiredValue;
  final List<ListeningQuestion> questions;

  int get stageNumber => stageNumberValue ?? 1;
  String get difficultyLabel => difficultyLabelValue ?? 'Ải Cơ Bản';
  int get passScoreRequired => passScoreRequiredValue ?? 2;

  ListeningLessonModel({
    required this.id,
    int? stageNumber,
    String? difficultyLabel,
    required this.title,
    required this.topic,
    required this.bandScoreTarget,
    required this.audioScript,
    int? passScoreRequired,
    required this.questions,
  })  : stageNumberValue = stageNumber,
        difficultyLabelValue = difficultyLabel,
        passScoreRequiredValue = passScoreRequired;
}

/// Model cho câu hỏi IELTS Speaking Part 1
class SpeakingPart1Item {
  final String question;
  final String sampleAnswer;
  final String translation;
  final List<String> keyVocabulary;

  SpeakingPart1Item({
    required this.question,
    required this.sampleAnswer,
    required this.translation,
    required this.keyVocabulary,
  });
}

/// Model cho bài thi IELTS Speaking (Part 1 & Part 2 Cue Card)
class SpeakingLessonModel {
  final String id;
  final int? stageNumberValue;
  final String? difficultyLabelValue;
  final String title;
  final String topic;
  final String bandScoreTarget;
  final int? passScoreRequiredValue;
  final List<SpeakingPart1Item> part1Questions;
  final String part2CueCardPrompt;
  final List<String> part2BulletPoints;
  final String part2SampleAnswer;
  final String part2SampleTranslation;
  final List<String> part2Collocations;

  int get stageNumber => stageNumberValue ?? 1;
  String get difficultyLabel => difficultyLabelValue ?? 'Ải Cơ Bản';
  int get passScoreRequired => passScoreRequiredValue ?? 6;

  SpeakingLessonModel({
    required this.id,
    int? stageNumber,
    String? difficultyLabel,
    required this.title,
    required this.topic,
    required this.bandScoreTarget,
    int? passScoreRequired,
    required this.part1Questions,
    required this.part2CueCardPrompt,
    required this.part2BulletPoints,
    required this.part2SampleAnswer,
    required this.part2SampleTranslation,
    required this.part2Collocations,
  })  : stageNumberValue = stageNumber,
        difficultyLabelValue = difficultyLabel,
        passScoreRequiredValue = passScoreRequired;
}

/// Model cho bài thi IELTS Writing (Task 1 hoặc Task 2)
class WritingLessonModel {
  final String id;
  final int? stageNumberValue;
  final String? difficultyLabelValue;
  final String taskType; // 'Task 1' hoặc 'Task 2'
  final String title;
  final String topic;
  final String bandScoreTarget;
  final int? passScoreRequiredValue;
  final String prompt;
  final int minWordCount; // 120, 150, 200, 250
  final int suggestedTimeMinutes; // 20 hoặc 40
  final List<String> keyOutline;
  final String sampleEssay;
  final String sampleTranslation;
  final List<String> academicVocabulary;
  final ChartDataModel? chartData; // Cấu hình biểu đồ động hoặc ảnh Supabase

  int get stageNumber => stageNumberValue ?? 1;
  String get difficultyLabel => difficultyLabelValue ?? 'Ải Cơ Bản';
  int get passScoreRequired => passScoreRequiredValue ?? 6;

  WritingLessonModel({
    required this.id,
    int? stageNumber,
    String? difficultyLabel,
    required this.taskType,
    required this.title,
    required this.topic,
    required this.bandScoreTarget,
    int? passScoreRequired,
    required this.prompt,
    required this.minWordCount,
    required this.suggestedTimeMinutes,
    required this.keyOutline,
    required this.sampleEssay,
    required this.sampleTranslation,
    required this.academicVocabulary,
    this.chartData,
  })  : stageNumberValue = stageNumber,
        difficultyLabelValue = difficultyLabel,
        passScoreRequiredValue = passScoreRequired;
}

/// Model đại diện cho một chuỗi dữ liệu trong biểu đồ Task 1 (VD: Nhóm Đô thị, Nông thôn)
class ChartSeriesModel {
  final String name;
  final String hexColor;
  final List<double> values;

  const ChartSeriesModel({
    required this.name,
    this.hexColor = '#1E3A8A',
    required this.values,
  });

  /// Getter chuyển đổi mã màu Hex (VD: "#1E3A8A") sang Color an toàn
  Color get color => parseHexColor(hexColor);

  /// Hàm tiện ích chuyển mã màu Hex sang Flutter Color an toàn, có màu mặc định khi chuỗi không hợp lệ
  static Color parseHexColor(String? hexString, [Color defaultColor = const Color(0xFF1E3A8A)]) {
    if (hexString == null || hexString.isEmpty) return defaultColor;
    try {
      String cleanHex = hexString.replaceAll('#', '').trim();
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      } else if (cleanHex.length == 3) {
        cleanHex = 'FF${cleanHex[0]}${cleanHex[0]}${cleanHex[1]}${cleanHex[1]}${cleanHex[2]}${cleanHex[2]}';
      }
      final intVal = int.tryParse(cleanHex, radix: 16);
      if (intVal != null) {
        return Color(intVal);
      }
    } catch (_) {}
    return defaultColor;
  }

  factory ChartSeriesModel.fromMap(Map<String, dynamic> map) {
    final rawValues = map['values'] as List<dynamic>? ?? [];
    final List<double> vals = rawValues.map((v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }).toList();

    return ChartSeriesModel(
      name: map['name']?.toString() ?? 'Nhóm số liệu',
      hexColor: map['color']?.toString() ?? '#1E3A8A',
      values: vals,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'color': hexColor,
      'values': values,
    };
  }
}

/// Model cấu hình biểu đồ cho IELTS Writing Task 1
/// Hỗ trợ cả 2 dạng: Biểu đồ số liệu động ('bar' / 'line') hoặc Ảnh đề thi ('image' lưu trên Supabase Storage)
class ChartDataModel {
  final String type; // 'bar', 'line', 'image'
  final String? title;
  final String? unit; // Đơn vị trục tung, VD: '%', 'TWh', 'Triệu người'
  final List<String> categories; // Các mốc trục hoành, VD: ['2015', '2018', '2020', '2025']
  final List<ChartSeriesModel> series;
  final String? imageUrl; // Đường dẫn ảnh Supabase Storage (khi type == 'image')

  const ChartDataModel({
    required this.type,
    this.title,
    this.unit,
    this.categories = const [],
    this.series = const [],
    this.imageUrl,
  });

  bool get isImage => type == 'image' && (imageUrl != null && imageUrl!.isNotEmpty);
  bool get isBarChart => type == 'bar';
  bool get isLineGraph => type == 'line';

  factory ChartDataModel.fromMap(Map<String, dynamic> map) {
    final rawType = (map['type']?.toString() ?? 'bar').toLowerCase();
    final rawCats = (map['categories'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final rawSeries = (map['series'] as List<dynamic>? ?? []);
    final seriesList = rawSeries.map((s) => ChartSeriesModel.fromMap(s as Map<String, dynamic>)).toList();

    return ChartDataModel(
      type: rawType,
      title: map['title']?.toString(),
      unit: map['unit']?.toString() ?? '%',
      categories: rawCats,
      series: seriesList,
      imageUrl: map['image_url']?.toString() ?? map['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (title != null) 'title': title,
      if (unit != null) 'unit': unit,
      'categories': categories,
      'series': series.map((s) => s.toMap()).toList(),
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }
}

