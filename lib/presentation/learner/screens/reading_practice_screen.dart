import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/dictionary_service.dart';
import '../../../core/services/practice_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/skill_models.dart';
import '../../../data/models/vocabulary_item_model.dart';
import '../../../data/repositories/skill_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Màn hình Luyện thi IELTS Reading Chuyên sâu.
/// Tính năng:
/// 1. Đọc bài học thuật IELTS chia theo từng đoạn Paragraph A, B, C.
/// 2. Tra từ tại chỗ (Tap-to-Translate): Chạm từ bất kỳ để xem IPA & Nghĩa tiếng Việt.
/// 3. Làm bài tập trắc nghiệm & Chấm điểm tự động quy đổi IELTS Band.
/// 4. Xem giải thích chi tiết vị trí đáp án (Key location explanation).
class ReadingPracticeScreen extends StatefulWidget {
  const ReadingPracticeScreen({super.key});

  @override
  State<ReadingPracticeScreen> createState() => _ReadingPracticeScreenState();
}

class _ReadingPracticeScreenState extends State<ReadingPracticeScreen> {
  late ReadingPassageModel _selectedPassage;
  final Map<int, String> _userAnswers = {};
  bool _isSubmitted = false;
  int _correctCount = 0;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _selectedPassage = SkillRepository.sampleReadingPassages.first;
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _submitTest() async {
    int score = 0;
    final total = _selectedPassage.questions.length;
    for (final q in _selectedPassage.questions) {
      if (_userAnswers[q.id] == q.correctAnswer) {
        score++;
      }
    }

    String estimatedBand = '7.5+';
    if (score == total) {
      estimatedBand = '8.5+';
    } else if (score >= 2) {
      estimatedBand = '7.5';
    } else {
      estimatedBand = '6.5';
    }

    setState(() {
      _correctCount = score;
      _isSubmitted = true;
    });

    final currentUser = context.read<AuthProvider>().currentUser;

    // Lưu kết quả lên Supabase
    final success = await PracticeService.savePracticeResult(
      skillType: 'reading',
      lessonId: _selectedPassage.id,
      lessonTitle: _selectedPassage.title,
      score: score,
      totalQuestions: total,
      bandScore: estimatedBand,
      username: currentUser?.username,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Đã lưu kết quả bài đọc lên hệ thống Supabase!'
                : '⚠️ Không thể đồng bộ kết quả lên máy chủ cloud.',
          ),
          backgroundColor: success ? Colors.green[700] : Colors.orange[800],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _resetTest() {
    setState(() {
      _userAnswers.clear();
      _isSubmitted = false;
      _correctCount = 0;
    });
  }

  /// Tra từ tại chỗ khi học viên chạm vào từ vựng bất kỳ trong bài đọc
  Future<void> _handleWordTap(String word) async {
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
    if (cleanWord.isEmpty) return;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _WordLookupSheet(
        word: cleanWord,
        flutterTts: _flutterTts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'IELTS Reading Practice',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          actions: [
            DropdownButton<ReadingPassageModel>(
              value: _selectedPassage,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
              items: SkillRepository.sampleReadingPassages.map((passage) {
                return DropdownMenuItem(
                  value: passage,
                  child: Text(
                    passage.title.length > 18
                        ? '${passage.title.substring(0, 18)}...'
                        : passage.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedPassage = val;
                    _resetTest();
                  });
                }
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(icon: Icon(Icons.article_rounded), text: 'Bài đọc Học thuật'),
              Tab(icon: Icon(Icons.quiz_rounded), text: 'Câu hỏi & Chấm điểm'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPassageView(),
            _buildQuestionsView(),
          ],
        ),
      ),
    );
  }

  /// Hiển thị bài đọc phân theo đoạn Paragraph A, B, C kèm Tap-to-Translate
  Widget _buildPassageView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header tiêu đề & Band target
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _selectedPassage.category,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Target Band ${_selectedPassage.bandScoreTarget}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedPassage.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.touch_app_rounded,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Mẹo: Chạm vào từ bất kỳ để tra nghĩa tiếng Việt tại chỗ',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Các đoạn văn Paragraph A, B, C
          ..._selectedPassage.paragraphs.entries.map((entry) {
            final pLetter = entry.key;
            final pText = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PARAGRAPH $pLetter',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.navy,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Render từng từ có thể chạm vào (Tap-to-Translate)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: pText.split(' ').map((word) {
                      return InkWell(
                        onTap: () => _handleWordTap(word),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 2, vertical: 1),
                          child: Text(
                            word,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Hiển thị danh sách câu hỏi & nút Nộp bài chấm điểm
  Widget _buildQuestionsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner kết quả sau khi nộp bài
          if (_isSubmitted) _buildScoreBanner(),

          const SizedBox(height: 12),

          // Danh sách câu hỏi
          ..._selectedPassage.questions.map((q) {
            final selected = _userAnswers[q.id];
            final isCorrect = selected == q.correctAnswer;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isSubmitted
                      ? (isCorrect ? Colors.green : Colors.redAccent)
                      : Colors.grey[200]!,
                  width: _isSubmitted ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          '${q.id}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (q.paragraphRef != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            q.paragraphRef!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    q.questionText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Các lựa chọn đáp án
                  ...q.options.map((opt) {
                    final isChoiceSelected = selected == opt;
                    Color optColor = Colors.grey[100]!;
                    Color textColor = Colors.black87;

                    if (_isSubmitted) {
                      if (opt == q.correctAnswer) {
                        optColor = Colors.green.withValues(alpha: 0.15);
                        textColor = Colors.green[800]!;
                      } else if (isChoiceSelected && !isCorrect) {
                        optColor = Colors.red.withValues(alpha: 0.15);
                        textColor = Colors.red[800]!;
                      }
                    } else if (isChoiceSelected) {
                      optColor = AppColors.primary.withValues(alpha: 0.15);
                      textColor = AppColors.primary;
                    }

                    return InkWell(
                      onTap: _isSubmitted
                          ? null
                          : () {
                              setState(() {
                                _userAnswers[q.id] = opt;
                              });
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: optColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChoiceSelected
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isChoiceSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 20,
                              color: textColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                opt,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isChoiceSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Giải thích chi tiết sau khi nộp bài
                  if (_isSubmitted) ...[
                    const Divider(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_rounded,
                              color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Giải thích: ${q.explanation}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[900],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // Nút Nộp bài / Làm lại
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitted
                  ? _resetTest
                  : (_userAnswers.length == _selectedPassage.questions.length
                      ? _submitTest
                      : null),
              icon: Icon(_isSubmitted
                  ? Icons.refresh_rounded
                  : Icons.check_circle_rounded),
              label: Text(_isSubmitted
                  ? 'LÀM LẠI BÀI ĐỌC'
                  : 'NỘP BÀI & CHẤM ĐIỂM (${_userAnswers.length}/${_selectedPassage.questions.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isSubmitted ? AppColors.navy : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Banner tổng kết kết quả chấm điểm IELTS Band Reading
  Widget _buildScoreBanner() {
    final total = _selectedPassage.questions.length;
    final pct = (_correctCount / total * 100).toStringAsFixed(0);

    String estimatedBand = '7.5+';
    if (_correctCount == total) {
      estimatedBand = '8.5+';
    } else if (_correctCount >= 2) {
      estimatedBand = '7.5';
    } else {
      estimatedBand = '6.5';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$_correctCount/$total',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KẾT QUẢ ĐÃ CHẤM ĐIỂM',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Đạt $pct% câu đúng',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Ước tính IELTS Reading: Band $estimatedBand',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom Sheet tra từ vựng chuyên sâu (Hiển thị IPA + Nghĩa tiếng Việt + Lưu vào Sổ tay)
class _WordLookupSheet extends StatefulWidget {
  final String word;
  final FlutterTts flutterTts;

  const _WordLookupSheet({
    required this.word,
    required this.flutterTts,
  });

  @override
  State<_WordLookupSheet> createState() => _WordLookupSheetState();
}

class _WordLookupSheetState extends State<_WordLookupSheet> {
  late Future<DictionaryEntry> _lookupFuture;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _lookupFuture = _resolveWordDetails();
    widget.flutterTts.speak(widget.word);
  }

  Future<DictionaryEntry> _resolveWordDetails() async {
    // 1. Kiểm tra trong ObjectMappingModel của DB cục bộ
    final mapping = await DatabaseHelper.instance.getMappingByLabel(widget.word);
    if (mapping != null && mapping.vietnameseMeaning.isNotEmpty) {
      return DictionaryEntry(
        word: mapping.academicWord.isNotEmpty ? mapping.academicWord : widget.word,
        ipa: mapping.ipa,
        vietnameseMeaning: mapping.vietnameseMeaning,
        partOfSpeech: 'IELTS Academic',
        bandScore: '7.5',
      );
    }
    // 2. Tra cứu qua DictionaryService (Local IELTS Dict + Online Fallback)
    return await DictionaryService.lookup(widget.word);
  }

  Future<void> _saveToNotebook(DictionaryEntry entry) async {
    final user = context.read<AuthProvider>().currentUser;
    final userId = user?.id ?? 1;

    final item = VocabularyItemModel(
      userId: userId,
      label: widget.word,
      word: entry.word,
      ipa: entry.ipa,
      translation: entry.vietnameseMeaning,
      bandScore: entry.bandScore ?? '7.5',
      example: entry.example ?? 'Từ vựng học thuật trong bài đọc IELTS.',
      createdAt: DateTime.now().toIso8601String(),
    );

    await DatabaseHelper.instance.insertNotebookItem(item, username: user?.username);

    setState(() {
      _isSaved = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã lưu "${entry.word}" vào Sổ tay từ vựng!'),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: FutureBuilder<DictionaryEntry>(
        future: _lookupFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.word.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary),
                      onPressed: () => widget.flutterTts.speak(widget.word),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Đang tra từ điển học thuật...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 24),
              ],
            );
          }

          final entry = snapshot.data ??
              DictionaryEntry(
                word: widget.word,
                ipa: '/${widget.word}/',
                vietnameseMeaning: widget.word,
              );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.word.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => widget.flutterTts.speak(widget.word),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.volume_up_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Badges: IPA + Loại từ + Band target
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      entry.ipa,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.partOfSpeech,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  if (entry.bandScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Band ${entry.bandScore}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 24),

              // Khung hiển thị Nghĩa tiếng Việt
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('🇻🇳 ', style: TextStyle(fontSize: 15)),
                        Text(
                          'NGHĨA TIẾNG VIỆT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Color(0xFFC62828),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.vietnameseMeaning,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB71C1C),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              if (entry.example != null && entry.example!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.format_quote_rounded, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry.example!,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Hai nút hành động: Lưu sổ tay & Đóng
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaved ? null : () => _saveToNotebook(entry),
                      icon: Icon(
                        _isSaved ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
                        color: _isSaved ? Colors.green : AppColors.primary,
                        size: 20,
                      ),
                      label: Text(
                        _isSaved ? 'Đã lưu sổ tay' : 'Lưu vào sổ tay',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isSaved ? Colors.green : AppColors.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: _isSaved ? Colors.green : AppColors.primary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'ĐÓNG',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
