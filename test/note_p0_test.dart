import 'package:flutter_test/flutter_test.dart';
import 'package:doancuoiki/data/models/note_model.dart';
import 'package:doancuoiki/data/models/vocabulary_item_model.dart';

void main() {
  group('P0: NoteModel Tests', () {
    test('NoteType scope contains 4 required types', () {
      expect(NoteType.vocab, 'vocab');
      expect(NoteType.sentence, 'sentence');
      expect(NoteType.feedback, 'feedback');
      expect(NoteType.free, 'free');
      expect(NoteType.all, containsAll(['vocab', 'sentence', 'feedback', 'free']));
      expect(NoteType.all.length, 4);
    });

    test('Create vocab NoteModel and convert to/from SQLite map', () {
      final vocabItem = VocabularyItemModel(
        userId: 1,
        label: 'resilient',
        word: 'resilient',
        ipa: '/rɪˈzɪl.jənt/',
        translation: 'kiên cường',
        example: 'She is very resilient.',
        bandScore: '7.5',
        createdAt: DateTime.now().toIso8601String(),
      );

      final note = NoteModel.fromVocabItem(
        vocabItem,
        source: NoteSource.reading,
        userNote: 'Từ vựng hay gặp trong Reading Passage 2',
      );

      expect(note.type, NoteType.vocab);
      expect(note.source, NoteSource.reading);
      expect(note.title, 'resilient');
      expect(note.content, 'kiên cường');
      expect(note.userNote, 'Từ vựng hay gặp trong Reading Passage 2');
      expect(note.vocabData, isNotNull);

      // SQLite serialization
      final map = note.toMap();
      expect(map['uuid'], note.uuid);
      expect(map['type'], NoteType.vocab);
      expect(map['title'], 'resilient');

      // SQLite deserialization
      final restored = NoteModel.fromMap(map);
      expect(restored.uuid, note.uuid);
      expect(restored.title, 'resilient');
      expect(restored.type, NoteType.vocab);
      expect(restored.vocabData?.word, 'resilient');
      expect(restored.vocabData?.ipa, '/rɪˈzɪl.jənt/');
    });

    test('Create sentence NoteModel and convert to Supabase map', () {
      final note = NoteModel(
        userId: 2,
        type: NoteType.sentence,
        source: NoteSource.reading,
        title: 'Although renewable energy is gaining traction...',
        content: 'Mặc dù năng lượng tái tạo đang ngày càng phổ biến...',
        userNote: 'Cấu trúc mặc dù ghi điểm Task 2',
        tags: ['Task 2', 'Grammar'],
      );

      expect(note.type, NoteType.sentence);
      expect(note.tags.length, 2);

      final supabaseMap = note.toSupabaseMap('user-uuid-1234');
      expect(supabaseMap['user_id'], 'user-uuid-1234');
      expect(supabaseMap['type'], 'sentence');
      expect(supabaseMap['title'], startsWith('Although'));
      expect(supabaseMap['tags'], ['Task 2', 'Grammar']);

      // Supabase deserialization
      final fromCloud = NoteModel.fromMap(supabaseMap);
      expect(fromCloud.uuid, note.uuid);
      expect(fromCloud.type, NoteType.sentence);
      expect(fromCloud.tags, ['Task 2', 'Grammar']);
    });

    test('Create feedback NoteModel (consolidated writing/speaking/AI explanation)', () {
      final note = NoteModel(
        userId: 1,
        type: NoteType.feedback,
        source: NoteSource.writing,
        title: 'Feedback Task 2 - Grammar & Cohesion',
        content: 'Cần chú ý chia thì quá khứ ở đoạn thân bài 1.',
        userNote: 'Cần xem lại irregular verbs',
        tags: ['Writing Task 2'],
      );

      expect(note.type, NoteType.feedback);
      expect(NoteType.getDisplayName(note.type), 'Nhận xét AI');
    });

    test('Create free NoteModel', () {
      final note = NoteModel(
        userId: 1,
        type: NoteType.free,
        source: NoteSource.manual,
        title: 'Lộ trình tuần tới',
        content: 'Tập trung ôn tập Reading Section 3 và Writing Task 1.',
      );

      expect(note.type, NoteType.free);
      expect(NoteType.getDisplayName(note.type), 'Ghi chú tự do');
    });
  });
}
