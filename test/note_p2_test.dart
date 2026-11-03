import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:doancuoiki/data/models/note_model.dart';
import 'package:doancuoiki/presentation/learner/widgets/note_button.dart';

void main() {
  group('P2: Reading & Listening Note Integration Tests', () {
    test('NoteButton can be initialized with sentence parameters', () {
      const button = NoteButton(
        title: 'Although fossil fuels dominate the energy sector...',
        type: NoteType.sentence,
        source: NoteSource.reading,
        content: 'Mặc dù nhiên liệu hóa thạch chiếm ưu thế...',
        sourceRef: 'Reading Passage 1',
        tags: ['Reading', 'IELTS Sentence'],
      );

      expect(button.title, startsWith('Although'));
      expect(button.type, NoteType.sentence);
      expect(button.source, NoteSource.reading);
      expect(button.tags.length, 2);
    });

    test('Reading: Automatic sentence extraction from paragraph', () {
      const paragraph =
          'Renewable energy has gained significant momentum in recent decades. '
          'Wind and solar power now generate a substantial proportion of global electricity! '
          'Can sustainable resources completely replace fossil fuels in the near future?';

      // Function under test
      String extractSentence(String text, String targetWord) {
        final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
        final cleanWord = targetWord.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
        for (final s in sentences) {
          if (s.toLowerCase().contains(cleanWord)) {
            return s.trim();
          }
        }
        return text.trim();
      }

      final sentence1 = extractSentence(paragraph, 'momentum');
      expect(sentence1, 'Renewable energy has gained significant momentum in recent decades.');

      final sentence2 = extractSentence(paragraph, 'solar');
      expect(sentence2, 'Wind and solar power now generate a substantial proportion of global electricity!');

      final sentence3 = extractSentence(paragraph, 'sustainable');
      expect(sentence3, 'Can sustainable resources completely replace fossil fuels in the near future?');
    });

    test('Listening: Transcript sentence bookmark with timestamp_ms', () {
      const audioScript =
          'Welcome to the campus tour. The library is located right on your left. '
          'It is open 24 hours during exam periods.';

      final segments = audioScript
          .split(RegExp(r'(?<=[.!?])\s+|\n+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      expect(segments.length, 3);
      expect(segments[0], 'Welcome to the campus tour.');
      expect(segments[1], 'The library is located right on your left.');

      // Check sourceRef structure
      const sampleTimestampMs = 12500;
      final sourceRef = jsonEncode({
        'lesson_id': 'listening_stage_1',
        'lesson_title': 'Campus Tour',
        'stage': 1,
        'timestamp_ms': sampleTimestampMs,
      });

      final decoded = jsonDecode(sourceRef) as Map<String, dynamic>;
      expect(decoded['timestamp_ms'], 12500);
      expect(decoded['lesson_id'], 'listening_stage_1');

      final note = NoteModel(
        userId: 1,
        type: NoteType.sentence,
        source: NoteSource.listening,
        sourceRef: sourceRef,
        title: segments[1],
        content: 'Trích từ bài nghe "Campus Tour" (Stage 1)',
        userNote: 'Đoạn nghe tại thời điểm ${(sampleTimestampMs / 1000).toStringAsFixed(1)}s',
        tags: ['Listening', 'Transcript'],
      );

      expect(note.type, NoteType.sentence);
      expect(note.source, NoteSource.listening);
      expect(note.userNote, 'Đoạn nghe tại thời điểm 12.5s');
    });

    test('AI Explanation: Feedback note generation', () {
      final explanationData = {
        'why_correct': 'Dẫn chứng tại dòng 4 cho thấy công nghệ mới giúp giảm 40% chi phí.',
        'why_trap': 'Đáp án B là bẫy từ đồng âm nhưng khác nghĩa trong ngữ cảnh.',
        'strategy_tips': 'Gạch chân từ khóa chỉ số lượng và trạng từ chỉ tần suất.',
      };

      final buffer = StringBuffer();
      buffer.writeln('Đáp án chính xác: A');
      buffer.writeln('\n🎯 Giải thích dẫn chứng:\n${explanationData['why_correct']}');
      buffer.writeln('\n⚠️ Bẫy đề & Sai lầm thường gặp:\n${explanationData['why_trap']}');
      buffer.writeln('\n💡 Mẹo làm bài:\n${explanationData['strategy_tips']}');

      final note = NoteModel(
        userId: 1,
        type: NoteType.feedback,
        source: NoteSource.reading,
        sourceRef: jsonEncode({
          'lesson_id': 'reading_stage_2',
          'question_id': 3,
          'correct_answer': 'A',
        }),
        title: 'Giải thích AI câu 3: What is the main benefit of the new system?',
        content: buffer.toString().trim(),
        userNote: 'Lưu ý bẫy paraphrase cho bài sau',
        tags: ['AI Giải thích', 'Reading'],
      );

      expect(note.type, NoteType.feedback);
      expect(note.source, NoteSource.reading);
      expect(note.content, contains('Đáp án chính xác: A'));
      expect(note.content, contains('Dẫn chứng tại dòng 4'));
      expect(note.content, contains('Đáp án B là bẫy'));
    });
  });
}

