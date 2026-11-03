class AiGradingHistoryItem {
  final String id;
  final DateTime createdAt;
  final String feature;
  final String skillType;
  final String? lessonId;
  final String? lessonTitle;
  final String? questionId;
  final String? vocabWord;
  final int? vocabLevel;
  final String? inputText;
  final int? inputWordCount;
  final String? bandScore;
  final double? scoreNumeric;
  final bool? isCorrect;
  final Map<String, dynamic>? resultJson;
  final String status;
  final String? modelName;
  final bool aiUsed;
  final bool fromCache;
  final int latencyMs;
  final String? errorMessage;

  AiGradingHistoryItem({
    required this.id,
    required this.createdAt,
    required this.feature,
    required this.skillType,
    this.lessonId,
    this.lessonTitle,
    this.questionId,
    this.vocabWord,
    this.vocabLevel,
    this.inputText,
    this.inputWordCount,
    this.bandScore,
    this.scoreNumeric,
    this.isCorrect,
    this.resultJson,
    required this.status,
    this.modelName,
    required this.aiUsed,
    required this.fromCache,
    required this.latencyMs,
    this.errorMessage,
  });

  factory AiGradingHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['created_at'].toString());
    } catch (_) {
      parsedDate = DateTime.now();
    }

    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString());
    }

    return AiGradingHistoryItem(
      id: json['id']?.toString() ?? '',
      createdAt: parsedDate,
      feature: json['feature']?.toString() ?? '',
      skillType: json['skill_type']?.toString() ?? '',
      lessonId: json['lesson_id']?.toString(),
      lessonTitle: json['lesson_title']?.toString(),
      questionId: json['question_id']?.toString(),
      vocabWord: json['vocab_word']?.toString(),
      vocabLevel: parseInt(json['vocab_level']),
      inputText: json['input_text']?.toString(),
      inputWordCount: parseInt(json['input_word_count']),
      bandScore: json['band_score']?.toString(),
      scoreNumeric: parseDouble(json['score_numeric']),
      isCorrect: json['is_correct'] as bool?,
      resultJson: json['result_json'] is Map<String, dynamic>
          ? json['result_json'] as Map<String, dynamic>
          : null,
      status: json['status']?.toString() ?? 'success',
      modelName: json['model_name']?.toString(),
      aiUsed: json['ai_used'] == true,
      fromCache: json['from_cache'] == true,
      latencyMs: parseInt(json['latency_ms']) ?? 0,
      errorMessage: json['error_message']?.toString(),
    );
  }
}

class AiGradingHistoryPage {
  final List<AiGradingHistoryItem> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  AiGradingHistoryPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory AiGradingHistoryPage.fromJson(Map<String, dynamic> json) {
    final rawList = json['items'] as List<dynamic>? ?? [];
    return AiGradingHistoryPage(
      items: rawList
          .map((e) => AiGradingHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] is int ? json['total'] : int.tryParse(json['total'].toString()) ?? 0,
      page: json['page'] is int ? json['page'] : int.tryParse(json['page'].toString()) ?? 1,
      pageSize: json['page_size'] is int ? json['page_size'] : int.tryParse(json['page_size'].toString()) ?? 20,
      totalPages: json['total_pages'] is int ? json['total_pages'] : int.tryParse(json['total_pages'].toString()) ?? 1,
    );
  }
}

