import 'package:flutter_test/flutter_test.dart';
import 'package:doancuoiki/data/models/note_model.dart';
import 'package:doancuoiki/data/models/vocabulary_item_model.dart';
import 'package:doancuoiki/core/services/note_export_service.dart';

void main() {
  group('P4: Note Export to TXT and CSV Tests', () {
    final sampleNotes = [
      NoteModel(
        userId: 1,
        type: NoteType.vocab,
        source: NoteSource.reading,
        title: 'ephemeral',
        content: 'chóng tàn, phù du',
        userNote: 'Học từ bài đọc Cam 18',
        tags: const ['Reading', 'Band 8.0'],
        vocabData: VocabularyItemModel(
          userId: 1,
          label: 'ephemeral',
          word: 'ephemeral',
          ipa: '/ɪˈfem.ər.əl/',
          translation: 'chóng tàn, phù du',
          bandScore: '8.0',
          collocations: 'ephemeral nature; ephemeral pleasure',
          example: 'Fashion is by nature ephemeral.',
          exampleTranslation: 'Thời trang vốn dĩ mang tính chất chóng tàn.',
          createdAt: DateTime.now().toIso8601String(),
        ),
      ),
      NoteModel(
        userId: 1,
        type: NoteType.sentence,
        source: NoteSource.writing,
        title: 'Although renewable energy is becoming more prevalent...',
        content: 'Mặc dù năng lượng tái tạo đang trở nên phổ biến hơn...',
        userNote: 'Mẫu câu mở bài Task 2',
        tags: const ['Writing', 'Task 2'],
      ),
      NoteModel(
        userId: 1,
        type: NoteType.feedback,
        source: NoteSource.speaking,
        title: 'Đánh giá Speaking Part 2',
        content: 'Cần chú ý nối âm và ngữ điệu câu hỏi.',
        tags: const ['Speaking', 'Pronunciation'],
      ),
      NoteModel(
        userId: 1,
        type: NoteType.free,
        source: NoteSource.manual,
        title: 'Mục tiêu tuần 4',
        content: 'Luyện 2 đề Full Test và sửa kỹ lỗi sai.',
        tags: const ['Checklist'],
      ),
    ];

    test('generateTxt includes headers, all 4 sections and accurate note counts', () {
      final txt = NoteExportService.generateTxt(sampleNotes);

      expect(txt, contains('IELTS VISION - SỔ TAY GHI CHÚ'));
      expect(txt, contains('Tổng số ghi chú: 4'));
      expect(txt, contains('1. TỪ VỰNG HỌC THUẬT (VOCABULARY)'));
      expect(txt, contains('ephemeral /ɪˈfem.ər.əl/ [Band 8.0]'));
      expect(txt, contains('Collocations: ephemeral nature'));
      expect(txt, contains('2. CÂU MẪU & NGỮ CẢNH (SENTENCES)'));
      expect(txt, contains('Although renewable energy is becoming more prevalent...'));
      expect(txt, contains('3. NHẬN XÉT & PHÂN TÍCH AI (AI FEEDBACK)'));
      expect(txt, contains('Đánh giá Speaking Part 2'));
      expect(txt, contains('4. GHI CHÚ TỰ DO (FREE NOTES)'));
      expect(txt, contains('Mục tiêu tuần 4'));
      expect(txt, contains('HẾT TÀI LIỆU'));
    });

    test('generateCsv outputs standard RFC 4180 format with escaped quotes', () {
      final csv = NoteExportService.generateCsv(sampleNotes);

      // Verify header
      expect(csv, contains('"Loại Ghi Chú","Nguồn","Tiêu Đề","Nội Dung / Nghĩa","Ghi Chú Riêng","Tags","Ngày Tạo"'));

      // Verify row contents
      expect(csv, contains('"Từ vựng"'));
      expect(csv, contains('"ephemeral"'));
      expect(csv, contains('"chóng tàn, phù du"'));
      expect(csv, contains('"Câu & Ngữ cảnh"'));
      expect(csv, contains('"Nhận xét AI"'));
      expect(csv, contains('"Ghi chú tự do"'));

      // Check quote escaping
      final noteWithQuotes = [
        NoteModel(
          userId: 1,
          type: NoteType.sentence,
          source: NoteSource.reading,
          title: 'He said "Hello" to everyone',
          content: 'Anh ấy nói "Xin chào"',
        ),
      ];
      final csvWithQuotes = NoteExportService.generateCsv(noteWithQuotes);
      expect(csvWithQuotes, contains('""Hello""'));
      expect(csvWithQuotes, contains('""Xin chào""'));
    });
  });
}

