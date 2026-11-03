import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:doancuoiki/data/models/note_model.dart';
import 'package:doancuoiki/presentation/learner/widgets/note_button.dart';

void main() {
  group('P3: Writing & Speaking Note Integration Tests', () {
    test('Writing: Error correction note generation', () {
      const quote = 'the chart show';
      const fix = 'the chart shows';
      const explain = 'Chia động từ số ít theo chủ ngữ the chart';

      final note = NoteModel(
        userId: 1,
        type: NoteType.sentence,
        source: NoteSource.writing,
        sourceRef: jsonEncode({'lesson_id': 'writing_task1_stage1', 'quote': quote, 'fix': fix}),
        title: 'Sửa lỗi: "$quote" -> "$fix"',
        content: 'Cụm gốc: "$quote"\nSửa thành: "$fix"\nGiải thích: $explain',
        tags: const ['Writing', 'Sửa lỗi'],
      );

      expect(note.type, NoteType.sentence);
      expect(note.source, NoteSource.writing);
      expect(note.title, contains('the chart shows'));
      expect(note.content, contains(explain));
    });

    test('Writing: Band 8.0+ rewritten sample paragraph note', () {
      const improved =
          'It is manifest that renewable energy adoption has witnessed an unprecedented surge, '
          'thereby mitigating carbon footprint across diverse industrial sectors.';

      final note = NoteModel(
        userId: 1,
        type: NoteType.sentence,
        source: NoteSource.writing,
        sourceRef: jsonEncode({'lesson_id': 'writing_task2_stage3', 'stage': 3}),
        title: 'Đoạn văn Band 8.0+ Writing Stage 3',
        content: improved,
        userNote: 'Học cấu trúc "thereby + V-ing" ghi điểm Cohesion & Grammar',
        tags: const ['Writing', 'Band 8.0+'],
      );

      expect(note.type, NoteType.sentence);
      expect(note.source, NoteSource.writing);
      expect(note.content, startsWith('It is manifest that'));
      expect(note.tags, contains('Band 8.0+'));
    });

    test('Writing: Full AI scorecard evaluation note', () {
      final note = NoteModel(
        userId: 1,
        type: NoteType.feedback,
        source: NoteSource.writing,
        sourceRef: jsonEncode({'lesson_id': 'writing_stage_2', 'stage': 2, 'band': '7.5'}),
        title: 'Đánh giá AI Writing Stage 2: Renewable Energy',
        content:
            'Overall Band: 7.5\n'
            '🎯 Task Response (7.5): Clear stance throughout\n'
            '🔗 Cohesion (7.0): Effective paragraphing\n'
            '📚 Lexical (8.0): Sophisticated vocabulary\n'
            '✍️ Grammar (7.5): Good mix of complex sentences',
        userNote: 'Cần chú ý lỗi mạo từ a/an/the ở phần thân bài 2',
        tags: const ['Writing', 'Stage 2', 'Band 7.5'],
      );

      expect(note.type, NoteType.feedback);
      expect(note.source, NoteSource.writing);
      expect(note.content, contains('Overall Band: 7.5'));
    });

    test('Speaking: Part 1 & Part 2 sample answers and evaluation notes', () {
      // Part 1 sample note
      const p1Answer = 'To be honest, I find listening to acoustic music exceptionally soothing after strenuous working hours.';
      final p1Note = NoteModel(
        userId: 1,
        type: NoteType.sentence,
        source: NoteSource.speaking,
        sourceRef: jsonEncode({'lesson_id': 'speaking_stage_1', 'part': 1, 'question': 'Do you like music?'}),
        title: p1Answer,
        content: 'Câu trả lời mẫu Part 1:\n"$p1Answer"',
        tags: const ['Speaking', 'Part 1'],
      );

      expect(p1Note.type, NoteType.sentence);
      expect(p1Note.source, NoteSource.speaking);

      // Part 2 Cue card note
      const p2Answer = 'I would like to describe a memorable vacation that left a profound impression on me...';
      final p2Note = NoteModel(
        userId: 1,
        type: NoteType.sentence,
        source: NoteSource.speaking,
        sourceRef: jsonEncode({'lesson_id': 'speaking_stage_1', 'part': 2, 'topic': 'A memorable holiday'}),
        title: 'Bài mẫu Part 2 Band 8.0+: A memorable holiday',
        content: p2Answer,
        tags: const ['Speaking', 'Part 2', 'Band 8.0+'],
      );

      expect(p2Note.type, NoteType.sentence);
      expect(p2Note.title, contains('Part 2 Band 8.0+'));

      // Speaking Evaluation note
      final evalNote = NoteModel(
        userId: 1,
        type: NoteType.feedback,
        source: NoteSource.speaking,
        sourceRef: jsonEncode({'lesson_id': 'speaking_stage_1', 'stage': 1, 'band': '7.0'}),
        title: 'Đánh giá Speaking Stage 1 (Band 7.0)',
        content: 'Fluency: 7.0\nLexical: 7.0\nPronunciation: 7.0',
        tags: const ['Speaking', 'Stage 1', 'Band 7.0'],
      );

      expect(evalNote.type, NoteType.feedback);
      expect(evalNote.source, NoteSource.speaking);
    });

    test('NoteButton widget integration compatibility', () {
      const button = NoteButton(
        title: 'Writing error fix',
        type: NoteType.sentence,
        source: NoteSource.writing,
        content: 'Fix details',
      );
      expect(button.type, NoteType.sentence);
      expect(button.source, NoteSource.writing);
    });
  });
}

