import 'vocabulary_item_model.dart';

/// Model đại diện cho một Thẻ Học Từ Vựng Phân Cấp (Cơ bản -> Trung cấp -> Nâng cao)
class VocabCardModel {
  final int id;
  final int level;
  final String cefrLevel;
  final String bandTarget;
  final String topic;

  final String word;
  final String basicWord;
  final String intermediateWord;
  final String advancedWord;

  final String ipa;
  final String partOfSpeech;
  final String vietnameseMeaning;

  final List<String> collocations;
  final Map<String, String> wordFamily;
  final List<String> synonyms;

  final String exampleBasic;
  final String exampleAdvanced;
  final String exampleTranslation;
  final String nuanceNote;
  final String source;

  int masteryLevel; // 0: Chưa học, 1: Quên, 2: Nhớ sơ, 3: Đã thuộc
  int reviewCount;
  int correctStreak;

  VocabCardModel({
    required this.id,
    required this.level,
    required this.cefrLevel,
    required this.bandTarget,
    required this.topic,
    required this.word,
    required this.basicWord,
    required this.intermediateWord,
    required this.advancedWord,
    required this.ipa,
    required this.partOfSpeech,
    required this.vietnameseMeaning,
    required this.collocations,
    required this.wordFamily,
    required this.synonyms,
    required this.exampleBasic,
    required this.exampleAdvanced,
    required this.exampleTranslation,
    required this.nuanceNote,
    required this.source,
    this.masteryLevel = 0,
    this.reviewCount = 0,
    this.correctStreak = 0,
  });

  factory VocabCardModel.fromJson(Map<String, dynamic> json) {
    final rawColls = json['collocations'];
    final List<String> parsedColls = rawColls is List
        ? rawColls.map((e) => e.toString()).toList()
        : <String>[];

    final rawSyns = json['synonyms'];
    final List<String> parsedSyns = rawSyns is List
        ? rawSyns.map((e) => e.toString()).toList()
        : <String>[];

    final rawFam = json['word_family'];
    final Map<String, String> parsedFam = {};
    if (rawFam is Map) {
      rawFam.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          parsedFam[key.toString()] = value.toString();
        }
      });
    }

    return VocabCardModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      cefrLevel: json['cefr_level']?.toString() ?? 'A2-B1',
      bandTarget: json['band_target']?.toString() ?? '5.5',
      topic: json['topic']?.toString() ?? 'General IELTS',
      word: json['word']?.toString() ?? '',
      basicWord: json['basic_word']?.toString() ?? '',
      intermediateWord: json['intermediate_word']?.toString() ?? '',
      advancedWord: json['advanced_word']?.toString() ?? '',
      ipa: json['ipa']?.toString() ?? '',
      partOfSpeech: json['part_of_speech']?.toString() ?? 'noun',
      vietnameseMeaning: json['vietnamese_meaning']?.toString() ?? '',
      collocations: parsedColls,
      wordFamily: parsedFam,
      synonyms: parsedSyns,
      exampleBasic: json['example_basic']?.toString() ?? '',
      exampleAdvanced: json['example_advanced']?.toString() ?? '',
      exampleTranslation: json['example_translation']?.toString() ?? '',
      nuanceNote: json['nuance_note']?.toString() ?? '',
      source: json['source']?.toString() ?? 'seed',
      masteryLevel: (json['mastery_level'] as num?)?.toInt() ?? 0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      correctStreak: (json['correct_streak'] as num?)?.toInt() ?? 0,
    );
  }

  /// Chuyển đổi sang VocabularyItemModel để lưu 1-chạm vào Sổ tay từ vựng hiện có
  VocabularyItemModel toVocabularyItemModel({required int userId}) {
    return VocabularyItemModel(
      userId: userId,
      label: topic,
      word: word,
      ipa: ipa,
      translation: vietnameseMeaning,
      example: exampleAdvanced.isNotEmpty ? exampleAdvanced : exampleBasic,
      exampleTranslation: exampleTranslation,
      bandScore: bandTarget.replaceAll('+', '').split('-').last.trim(),
      collocations: collocations.join('; '),
      idioms: 'Basic: $basicWord → Inter: $intermediateWord → Adv: $advancedWord',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  /// Dữ liệu dự phòng khi offline (đủ 5 cấp độ từ Cơ bản đến Bậc thầy)
  static List<VocabCardModel> get offlineSeedCards => [
        VocabCardModel(
          id: 101,
          level: 1,
          cefrLevel: 'A2-B1',
          bandTarget: '5.0',
          topic: 'Daily Life & Habits',
          word: 'essential',
          basicWord: 'important / needed',
          intermediateWord: 'essential / vital',
          advancedWord: 'indispensable / paramount',
          ipa: '/ɪˈsen.ʃəl/',
          partOfSpeech: 'adjective',
          vietnameseMeaning: 'Cần thiết, thiết yếu, vô cùng quan trọng',
          collocations: ['essential for health', 'essential skill', 'play an essential role'],
          wordFamily: {'noun': 'essence', 'adjective': 'essential', 'adverb': 'essentially'},
          synonyms: ['vital', 'crucial', 'necessary', 'indispensable'],
          exampleBasic: 'Water is very important for our body every day.',
          exampleAdvanced: 'Balanced nutrition and regular exercise are essential for maintaining long-term physical well-being.',
          exampleTranslation: 'Dinh dưỡng cân bằng và tập thể dục thường xuyên là yếu tố thiết yếu để duy trì sức khỏe thể chất lâu dài.',
          nuanceNote: 'Thay vì lặp lại từ "important" ở mức A2, dùng "essential" giúp câu văn đạt chuẩn B1-B2 tự nhiên hơn.',
          source: 'seed',
        ),
        VocabCardModel(
          id: 102,
          level: 1,
          cefrLevel: 'A2-B1',
          bandTarget: '5.5',
          topic: 'Education & Learning',
          word: 'improve',
          basicWord: 'make better',
          intermediateWord: 'improve / enhance',
          advancedWord: 'ameliorate / elevate',
          ipa: '/ɪmˈpruːv/',
          partOfSpeech: 'verb',
          vietnameseMeaning: 'Cải thiện, nâng cao, làm cho tốt hơn',
          collocations: ['improve communication skills', 'improve academic performance'],
          wordFamily: {'noun': 'improvement', 'verb': 'improve', 'adjective': 'improved'},
          synonyms: ['enhance', 'upgrade', 'boost'],
          exampleBasic: 'I practice speaking every day to make my English better.',
          exampleAdvanced: 'Consistent daily practice can significantly improve a learner\'s pronunciation and fluency.',
          exampleTranslation: 'Luyện tập đều đặn hàng ngày có thể cải thiện đáng kể khả năng phát âm và độ trôi chảy.',
          nuanceNote: '"Improve" là động từ nền tảng. Khi lên Band 6.5+, có thể nâng cấp thành "enhance".',
          source: 'seed',
        ),
        VocabCardModel(
          id: 201,
          level: 2,
          cefrLevel: 'B1-B2',
          bandTarget: '6.5',
          topic: 'Social Issues',
          word: 'significant',
          basicWord: 'big / large',
          intermediateWord: 'significant / considerable',
          advancedWord: 'substantial / profound',
          ipa: '/sɪɡˈnɪf.ɪ.kənt/',
          partOfSpeech: 'adjective',
          vietnameseMeaning: 'Đáng kể, quan trọng, có ý nghĩa lớn',
          collocations: ['significant impact', 'statistically significant', 'significant proportion'],
          wordFamily: {'noun': 'significance', 'adjective': 'significant', 'adverb': 'significantly'},
          synonyms: ['considerable', 'notable', 'substantial'],
          exampleBasic: 'There was a big increase in the number of online learners.',
          exampleAdvanced: 'The chart illustrates a significant surge in renewable energy consumption over the past decade.',
          exampleTranslation: 'Biểu đồ minh họa mức tăng trưởng đáng kể trong việc tiêu thụ năng lượng tái tạo suốt thập kỷ qua.',
          nuanceNote: 'Từ khóa vàng cho IELTS Writing Task 1 & Task 2 để thay thế "big" hoặc "a lot of".',
          source: 'seed',
        ),
        VocabCardModel(
          id: 202,
          level: 2,
          cefrLevel: 'B1-B2',
          bandTarget: '6.5',
          topic: 'Education & Technology',
          word: 'facilitate',
          basicWord: 'help / make easier',
          intermediateWord: 'facilitate / assist',
          advancedWord: 'catalyze / streamline',
          ipa: '/fəˈsɪl.ɪ.teɪt/',
          partOfSpeech: 'verb',
          vietnameseMeaning: 'Tạo điều kiện thuận lợi, thúc đẩy quá trình dễ dàng hơn',
          collocations: ['facilitate learning', 'facilitate communication', 'facilitate economic growth'],
          wordFamily: {'noun': 'facilitation', 'verb': 'facilitate'},
          synonyms: ['assist', 'ease', 'expedite'],
          exampleBasic: 'The internet helps students find information faster.',
          exampleAdvanced: 'Interactive digital platforms greatly facilitate collaborative learning among remote students.',
          exampleTranslation: 'Các nền tảng kỹ thuật số tương tác tạo điều kiện vô cùng thuận lợi cho việc học tập hợp tác.',
          nuanceNote: 'Tân ngữ của "facilitate" nên là một hoạt động/quá trình (learning, trade) chứ không phải là người.',
          source: 'seed',
        ),
        VocabCardModel(
          id: 301,
          level: 3,
          cefrLevel: 'B2-C1',
          bandTarget: '7.0',
          topic: 'Climate & Environment',
          word: 'mitigate',
          basicWord: 'reduce / make less bad',
          intermediateWord: 'alleviate / lessen',
          advancedWord: 'mitigate / attenuate',
          ipa: '/ˈmɪt.ɪ.ɡeɪt/',
          partOfSpeech: 'verb',
          vietnameseMeaning: 'Giảm thiểu, làm dịu bớt mức độ nghiêm trọng',
          collocations: ['mitigate climate change', 'mitigate the risks', 'mitigating circumstances'],
          wordFamily: {'noun': 'mitigation', 'verb': 'mitigate'},
          synonyms: ['alleviate', 'curb', 'diminish'],
          exampleBasic: 'Planting more trees helps reduce global warming.',
          exampleAdvanced: 'Afforestation and carbon taxation are effective strategies to mitigate the adverse effects of climate change.',
          exampleTranslation: 'Trồng rừng và đánh thuế carbon là những chiến lược hiệu quả nhằm giảm thiểu các tác động bất lợi của biến đổi khí hậu.',
          nuanceNote: 'Cực kỳ chuẩn học thuật khi đi với các danh từ chỉ rủi ro, hậu quả: "mitigate risks / impacts".',
          source: 'seed',
        ),
        VocabCardModel(
          id: 401,
          level: 4,
          cefrLevel: 'C1',
          bandTarget: '8.0',
          topic: 'Socioeconomics & Policy',
          word: 'exacerbate',
          basicWord: 'make worse',
          intermediateWord: 'worsen / aggravate',
          advancedWord: 'exacerbate / compound',
          ipa: '/ɪɡˈzæs.ə.beɪt/',
          partOfSpeech: 'verb',
          vietnameseMeaning: 'Làm trầm trọng thêm (một vấn đề hoặc tình trạng xấu)',
          collocations: ['exacerbate social inequality', 'exacerbate traffic congestion'],
          wordFamily: {'noun': 'exacerbation', 'verb': 'exacerbate'},
          synonyms: ['aggravate', 'intensify', 'compound'],
          exampleBasic: 'Uncontrolled migration can make city traffic worse.',
          exampleAdvanced: 'Rapid, unplanned urbanization tends to exacerbate housing shortages and environmental degradation.',
          exampleTranslation: 'Quá trình đô thị hóa nhanh chóng thiếu quy hoạch có xu hướng làm trầm trọng thêm tình trạng thiếu nhà ở.',
          nuanceNote: 'Đối lập hoàn toàn với "mitigate / alleviate". Cặp từ "exacerbate vs. mitigate" là vũ khí sắc bén cho Band 7.5+.',
          source: 'seed',
        ),
        VocabCardModel(
          id: 501,
          level: 5,
          cefrLevel: 'C2',
          bandTarget: '8.5',
          topic: 'Macroeconomics & Policy',
          word: 'panacea',
          basicWord: 'cure-all / perfect solution',
          intermediateWord: 'universal remedy',
          advancedWord: 'panacea / silver bullet',
          ipa: '/ˌpæn.əˈsiː.ə/',
          partOfSpeech: 'noun',
          vietnameseMeaning: 'Thuốc tiên chữa bách bệnh, giải pháp vạn năng cho mọi vấn đề',
          collocations: ['no panacea for', 'viewed as a panacea', 'universal panacea'],
          wordFamily: {'noun': 'panacea'},
          synonyms: ['universal cure', 'elixir', 'silver bullet'],
          exampleBasic: 'Technology alone cannot solve all social problems.',
          exampleAdvanced: 'While technological innovation is indispensable, it should not be regarded as a panacea for deep-rooted societal inequities.',
          exampleTranslation: 'Mặc dù đổi mới công nghệ là không thể thiếu, nó không nên được coi là giải pháp vạn năng cho những bất công xã hội.',
          nuanceNote: 'Thường dùng ở dạng phủ định ("is by no means a panacea for...") để thể hiện tư duy phản biện sắc sảo ở mức Band 8.5+.',
          source: 'seed',
        ),
      ];
}

/// Model thông tin tóm tắt của 1 Cấp độ trong Lộ trình 5 Cấp độ
class VocabLevelInfoModel {
  final int level;
  final String title;
  final String subtitle;
  final String cefrLevel;
  final String bandTarget;
  final int totalCards;
  final int masteredCards;
  final int learningCards;
  final int stars;
  final int bestScore;
  final bool isUnlocked;
  final List<String> topics;

  VocabLevelInfoModel({
    required this.level,
    required this.title,
    required this.subtitle,
    required this.cefrLevel,
    required this.bandTarget,
    required this.totalCards,
    required this.masteredCards,
    required this.learningCards,
    required this.stars,
    required this.bestScore,
    required this.isUnlocked,
    required this.topics,
  });

  factory VocabLevelInfoModel.fromJson(Map<String, dynamic> json) {
    final rawTopics = json['topics'];
    return VocabLevelInfoModel(
      level: (json['level'] as num?)?.toInt() ?? 1,
      title: json['title']?.toString() ?? 'Cấp độ 1: Cơ bản',
      subtitle: json['subtitle']?.toString() ?? '',
      cefrLevel: json['cefr_level']?.toString() ?? 'A2-B1',
      bandTarget: json['band_target']?.toString() ?? '5.0',
      totalCards: (json['total_cards'] as num?)?.toInt() ?? 0,
      masteredCards: (json['mastered_cards'] as num?)?.toInt() ?? 0,
      learningCards: (json['learning_cards'] as num?)?.toInt() ?? 0,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      bestScore: (json['best_score'] as num?)?.toInt() ?? 0,
      isUnlocked: json['is_unlocked'] as bool? ?? true,
      topics: rawTopics is List ? rawTopics.map((e) => e.toString()).toList() : <String>[],
    );
  }
}

/// Model toàn bộ lộ trình 5 cấp độ học từ vựng
class VocabRoadmapModel {
  final int highestUnlockedLevel;
  final int totalCardsInSystem;
  final int totalMasteredByUser;
  final int totalLearningByUser;
  final String ollamaModel;
  final List<VocabLevelInfoModel> levels;

  VocabRoadmapModel({
    required this.highestUnlockedLevel,
    required this.totalCardsInSystem,
    required this.totalMasteredByUser,
    required this.totalLearningByUser,
    required this.ollamaModel,
    required this.levels,
  });

  factory VocabRoadmapModel.fromJson(Map<String, dynamic> json) {
    final rawLevels = json['levels'];
    return VocabRoadmapModel(
      highestUnlockedLevel: (json['highest_unlocked_level'] as num?)?.toInt() ?? 1,
      totalCardsInSystem: (json['total_cards_in_system'] as num?)?.toInt() ?? 0,
      totalMasteredByUser: (json['total_mastered_by_user'] as num?)?.toInt() ?? 0,
      totalLearningByUser: (json['total_learning_by_user'] as num?)?.toInt() ?? 0,
      ollamaModel: json['ollama_model']?.toString() ?? 'qwen2.5:latest',
      levels: rawLevels is List
          ? rawLevels
              .whereType<Map<String, dynamic>>()
              .map(VocabLevelInfoModel.fromJson)
              .toList()
          : <VocabLevelInfoModel>[],
    );
  }
}

/// Model kết quả chấm điểm & nâng cấp câu bằng Ollama Qwen 2.5
class SentenceEvaluationModel {
  final String word;
  final String userSentence;
  final bool isCorrectUsage;
  final int score;
  final String estimatedBand;
  final String correctedSentence;
  final String feedbackVi;
  final String upgradedBasic;
  final String upgradedIntermediate;
  final String upgradedAdvanced;
  final List<String> keyCollocationsUsed;
  final String modelUsed;

  SentenceEvaluationModel({
    required this.word,
    required this.userSentence,
    required this.isCorrectUsage,
    required this.score,
    required this.estimatedBand,
    required this.correctedSentence,
    required this.feedbackVi,
    required this.upgradedBasic,
    required this.upgradedIntermediate,
    required this.upgradedAdvanced,
    required this.keyCollocationsUsed,
    required this.modelUsed,
  });

  factory SentenceEvaluationModel.fromJson(Map<String, dynamic> json) {
    final rawColls = json['key_collocations_used'];
    return SentenceEvaluationModel(
      word: json['word']?.toString() ?? '',
      userSentence: json['user_sentence']?.toString() ?? '',
      isCorrectUsage: json['is_correct_usage'] as bool? ?? true,
      score: (json['score'] as num?)?.toInt() ?? 75,
      estimatedBand: json['estimated_band']?.toString() ?? '6.5',
      correctedSentence: json['corrected_sentence']?.toString() ?? '',
      feedbackVi: json['feedback_vi']?.toString() ?? '',
      upgradedBasic: json['upgraded_basic']?.toString() ?? '',
      upgradedIntermediate: json['upgraded_intermediate']?.toString() ?? '',
      upgradedAdvanced: json['upgraded_advanced']?.toString() ?? '',
      keyCollocationsUsed: rawColls is List
          ? rawColls.map((e) => e.toString()).toList()
          : <String>[],
      modelUsed: json['model_used']?.toString() ?? 'qwen2.5:latest',
    );
  }
}

/// Model câu hỏi kiểm tra vượt cấp từ vựng
class VocabQuizQuestionModel {
  final int id;
  final String questionType;
  final String prompt;
  final String targetWord;
  final List<String> options;
  final String correctAnswer;
  final String explanationVi;

  VocabQuizQuestionModel({
    required this.id,
    required this.questionType,
    required this.prompt,
    required this.targetWord,
    required this.options,
    required this.correctAnswer,
    required this.explanationVi,
  });

  factory VocabQuizQuestionModel.fromJson(Map<String, dynamic> json) {
    final rawOpts = json['options'];
    return VocabQuizQuestionModel(
      id: (json['id'] as num?)?.toInt() ?? 1,
      questionType: json['question_type']?.toString() ?? 'contextual_mcq',
      prompt: json['prompt']?.toString() ?? '',
      targetWord: json['target_word']?.toString() ?? '',
      options: rawOpts is List ? rawOpts.map((e) => e.toString()).toList() : <String>[],
      correctAnswer: json['correct_answer']?.toString() ?? '',
      explanationVi: json['explanation_vi']?.toString() ?? '',
    );
  }
}

/// Model đề kiểm tra từ vựng của 1 cấp độ
class VocabQuizModel {
  final int level;
  final String topic;
  final String source;
  final int passScoreRequired;
  final List<VocabQuizQuestionModel> questions;

  VocabQuizModel({
    required this.level,
    required this.topic,
    required this.source,
    required this.passScoreRequired,
    required this.questions,
  });

  factory VocabQuizModel.fromJson(Map<String, dynamic> json) {
    final rawQ = json['questions'];
    return VocabQuizModel(
      level: (json['level'] as num?)?.toInt() ?? 1,
      topic: json['topic']?.toString() ?? 'Tổng hợp',
      source: json['source']?.toString() ?? 'qwen2.5',
      passScoreRequired: (json['pass_score_required'] as num?)?.toInt() ?? 3,
      questions: rawQ is List
          ? rawQ
              .whereType<Map<String, dynamic>>()
              .map(VocabQuizQuestionModel.fromJson)
              .toList()
          : <VocabQuizQuestionModel>[],
    );
  }
}

/// Model cấu hình hệ thống học từ vựng và AI Qwen được đồng bộ từ Web Admin Portal
class VocabSystemConfigModel {
  final int id;
  final String activeModel;
  final double temperature;
  final int defaultGenCount;
  final int quizQuestionCount;
  final int passPercentage;
  final Map<String, int> starThresholds;
  final bool autoCacheEnabled;
  final bool isOllamaOnline;
  final List<String> availableModels;
  final String ollamaBaseUrl;

  VocabSystemConfigModel({
    required this.id,
    required this.activeModel,
    required this.temperature,
    required this.defaultGenCount,
    required this.quizQuestionCount,
    required this.passPercentage,
    required this.starThresholds,
    required this.autoCacheEnabled,
    required this.isOllamaOnline,
    required this.availableModels,
    required this.ollamaBaseUrl,
  });

  factory VocabSystemConfigModel.fromJson(Map<String, dynamic> json) {
    final rawThresholds = json['star_thresholds'];
    final Map<String, int> parsedThresholds = {};
    if (rawThresholds is Map) {
      rawThresholds.forEach((k, v) {
        if (v is num) parsedThresholds[k.toString()] = v.toInt();
      });
    }

    final rawModels = json['available_models'];
    final List<String> parsedModels = rawModels is List
        ? rawModels.map((e) => e.toString()).toList()
        : <String>[];

    return VocabSystemConfigModel(
      id: (json['id'] as num?)?.toInt() ?? 1,
      activeModel: json['active_model']?.toString() ?? 'qwen2.5:7b',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.3,
      defaultGenCount: (json['default_gen_count'] as num?)?.toInt() ?? 5,
      quizQuestionCount: (json['quiz_question_count'] as num?)?.toInt() ?? 5,
      passPercentage: (json['pass_percentage'] as num?)?.toInt() ?? 60,
      starThresholds: parsedThresholds.isNotEmpty
          ? parsedThresholds
          : {'star1': 60, 'star2': 80, 'star3': 100},
      autoCacheEnabled: json['auto_cache_enabled'] == true || json['auto_cache_enabled'] == 1,
      isOllamaOnline: json['is_ollama_online'] == true,
      availableModels: parsedModels,
      ollamaBaseUrl: json['ollama_base_url']?.toString() ?? 'http://localhost:11434',
    );
  }

  /// Tính số câu đúng tối thiểu cần đạt để đỗ ải
  int get minPassRequired {
    return ((quizQuestionCount * passPercentage) / 100.0).ceil().clamp(1, quizQuestionCount);
  }
}


