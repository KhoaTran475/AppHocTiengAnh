library;

/// Model dữ liệu cho bài học IELTS Reading & Listening
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
  final String title;
  final String category;
  final String bandScoreTarget;
  final Map<String, String> paragraphs; // {'A': 'Chữ...', 'B': 'Chữ...'}
  final List<ReadingQuestion> questions;

  ReadingPassageModel({
    required this.id,
    required this.title,
    required this.category,
    required this.bandScoreTarget,
    required this.paragraphs,
    required this.questions,
  });
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
  final String title;
  final String topic;
  final String bandScoreTarget;
  final List<SpeakingPart1Item> part1Questions;
  final String part2CueCardPrompt;
  final List<String> part2BulletPoints;
  final String part2SampleAnswer;
  final String part2SampleTranslation;
  final List<String> part2Collocations;

  SpeakingLessonModel({
    required this.id,
    required this.title,
    required this.topic,
    required this.bandScoreTarget,
    required this.part1Questions,
    required this.part2CueCardPrompt,
    required this.part2BulletPoints,
    required this.part2SampleAnswer,
    required this.part2SampleTranslation,
    required this.part2Collocations,
  });
}

/// Model cho bài thi IELTS Writing (Task 1 hoặc Task 2)
class WritingLessonModel {
  final String id;
  final String taskType; // 'Task 1' hoặc 'Task 2'
  final String title;
  final String topic;
  final String bandScoreTarget;
  final String prompt;
  final int minWordCount; // 150 (Task 1) hoặc 250 (Task 2)
  final int suggestedTimeMinutes; // 20 hoặc 40
  final List<String> keyOutline;
  final String sampleEssay;
  final String sampleTranslation;
  final List<String> academicVocabulary;

  WritingLessonModel({
    required this.id,
    required this.taskType,
    required this.title,
    required this.topic,
    required this.bandScoreTarget,
    required this.prompt,
    required this.minWordCount,
    required this.suggestedTimeMinutes,
    required this.keyOutline,
    required this.sampleEssay,
    required this.sampleTranslation,
    required this.academicVocabulary,
  });
}

