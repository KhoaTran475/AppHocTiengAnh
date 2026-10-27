library;

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
  })  : stageNumberValue = stageNumber,
        difficultyLabelValue = difficultyLabel,
        passScoreRequiredValue = passScoreRequired;
}
