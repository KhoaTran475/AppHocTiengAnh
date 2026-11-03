import 'package:flutter_test/flutter_test.dart';
import 'package:doancuoiki/data/models/note_model.dart';
import 'package:doancuoiki/presentation/learner/screens/vocabulary_notebook_screen.dart';
import 'package:doancuoiki/presentation/learner/widgets/note_detail_bottom_sheet.dart';
import 'package:doancuoiki/presentation/learner/widgets/create_note_bottom_sheet.dart';

void main() {
  group('P1: Notebook UI Components & Screen Instantiation Tests', () {
    test('VocabularyNotebookScreen can be instantiated', () {
      const screen = VocabularyNotebookScreen();
      expect(screen, isNotNull);
    });

    test('NoteDetailBottomSheet can be instantiated with different note types', () {
      final vocabNote = NoteModel(
        userId: 1,
        type: NoteType.vocab,
        source: NoteSource.reading,
        title: 'ephemeral',
        content: 'chóng tàn, phù du',
      );
      final sheet = NoteDetailBottomSheet(note: vocabNote);
      expect(sheet.note.title, 'ephemeral');
      expect(sheet.note.type, NoteType.vocab);
    });

    test('CreateNoteBottomSheet can be instantiated with initial values', () {
      const sheet = CreateNoteBottomSheet(
        userId: 1,
        initialType: NoteType.sentence,
        initialSource: NoteSource.listening,
        initialTitle: 'It goes without saying that...',
        initialContent: 'Không cần phải nói thì ai cũng hiểu rằng...',
        initialTags: ['Idiom', 'Writing'],
      );
      expect(sheet.userId, 1);
      expect(sheet.initialType, NoteType.sentence);
      expect(sheet.initialTags.length, 2);
    });
  });
}

