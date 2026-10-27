import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/dictionary_service.dart';
import '../../../core/services/practice_service.dart';
import '../../../core/services/skill_progress_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/skill_models.dart';
import '../../../data/models/vocabulary_item_model.dart';
import '../../../data/repositories/skill_repository.dart';
import '../../../data/datasources/api_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Màn hình Luyện thi IELTS Reading Chuyên sâu theo cơ chế Vượt ải (Gamified Stages).
/// Tính năng:
/// 1. Bản đồ vượt ải 5 Cấp độ (Band 6.0 đến Boss Stage Band 8.5+) mở khóa tuần tự.
/// 2. Hộp thoại Chiến thắng (Victory Celebration Dialog) khi đạt đủ điểm qua ải.
/// 3. Hệ thống đánh giá Sao (1⭐, 2⭐⭐, 3⭐⭐⭐) lưu điểm cao nhất.
/// 4. Tra từ tại chỗ (Tap-to-Translate): Chạm từ bất kỳ để xem IPA & Nghĩa tiếng Việt.
/// 5. Làm bài tập trắc nghiệm & Chấm điểm tự động quy đổi IELTS Band.
/// 6. Đồng bộ tiến độ ải với Backend và Supabase.
class ReadingPracticeScreen extends StatefulWidget {
  const ReadingPracticeScreen({super.key});

  @override
  State<ReadingPracticeScreen> createState() => _ReadingPracticeScreenState();
}

class _ReadingPracticeScreenState extends State<ReadingPracticeScreen> {
  List<ReadingPassageModel> _passages = List.from(SkillRepository.sampleReadingPassages);
  late ReadingPassageModel _selectedPassage;
  final Map<int, String> _userAnswers = {};
  bool _isSubmitted = false;
  int _correctCount = 0;
  final FlutterTts _flutterTts = FlutterTts();

  // Trạng thái Vượt ải Gamification (Theme Xanh ngọc / Teal)
  int _highestUnlockedStage = 1;
  Map<int, int> _stageStars = {};
  Map<int, int> _stageBestScores = {};

  @override
  void initState() {
    super.initState();
    _selectedPassage = _passages.first;
    _initTts();
    _loadStageProgress(autoSelectNextStage: true);
  }

  Future<void> _loadStageProgress({bool autoSelectNextStage = false}) async {
    final user = context.read<AuthProvider>().currentUser;
    final userId = user?.id ?? 1;

    int highest = 1;
    final Map<int, int> stars = {};
    final Map<int, int> bestScores = {};

    // Tải danh sách bài đọc từ API để hỗ trợ mở rộng ải động (> 5 ải)
    try {
      final apiPassages = await ApiService.instance.getReadingLessons();
      if (apiPassages.isNotEmpty) {
        _passages = apiPassages;
        _passages.sort((a, b) => a.stageNumber.compareTo(b.stageNumber));
      }
    } catch (_) {}

    // Đồng bộ lại _selectedPassage nếu danh sách thay đổi
    if (!_passages.any((p) => p.id == _selectedPassage.id)) {
      _selectedPassage = _passages.first;
    }

    try {
      final prog = await ApiService.instance.getSkillProgress('reading');
      highest = prog['highest_unlocked_stage'] as int? ?? 1;
      final rawStages = prog['stages'] as List<dynamic>? ?? [];
      for (final s in rawStages) {
        final stNum = s['stage_number'] as int;
        stars[stNum] = s['stars'] as int? ?? 0;
        bestScores[stNum] = s['best_score'] as int? ?? 0;
      }
    } catch (_) {}

    // Kết hợp SharedPreferences cục bộ để đảm bảo "Tiến độ cao hơn luôn thắng"
    final localHighest = await SkillProgressService.getHighestUnlockedStage(userId, 'reading');
    if (localHighest > highest) {
      highest = localHighest;
    }
    for (final passage in _passages) {
      final s = await SkillProgressService.getStageStars(userId, 'reading', passage.stageNumber);
      final b = await SkillProgressService.getStageBestScore(userId, 'reading', passage.stageNumber);
      if (s > (stars[passage.stageNumber] ?? 0)) {
        stars[passage.stageNumber] = s;
      }
      if (b > (bestScores[passage.stageNumber] ?? 0)) {
        bestScores[passage.stageNumber] = b;
      }
    }

    if (mounted) {
      setState(() {
        _highestUnlockedStage = highest;
        _stageStars = stars;
        _stageBestScores = bestScores;

        if (autoSelectNextStage) {
          ReadingPassageModel targetPassage = _passages.first;
          for (final passage in _passages) {
            if (passage.stageNumber <= highest) {
              targetPassage = passage;
              if ((stars[passage.stageNumber] ?? 0) == 0) {
                break;
              }
            }
          }
          if (_selectedPassage.id != targetPassage.id) {
            _selectedPassage = targetPassage;
            _userAnswers.clear();
            _isSubmitted = false;
            _correctCount = 0;
          }
        }
      });
    }
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

  void _switchStage(ReadingPassageModel passage) {
    if (_selectedPassage.id == passage.id) return;
    setState(() {
      _selectedPassage = passage;
      _resetTest();
    });
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

    bool isPassed = score >= _selectedPassage.passScoreRequired;

    // Nộp bài và chấm điểm qua FastAPI Backend
    try {
      final Map<String, String> stringAnswers =
          _userAnswers.map((k, v) => MapEntry(k.toString(), v));
      final res = await ApiService.instance.submitTest(
        lessonId: _selectedPassage.id,
        skillType: 'reading',
        answers: stringAnswers,
      );
      if (res['score'] != null) score = res['score'] as int;
      if (res['band_score'] != null) estimatedBand = res['band_score'] as String;
      if (res['passed'] != null) isPassed = res['passed'] as bool;
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _correctCount = score;
      _isSubmitted = true;
    });

    final currentUser = context.read<AuthProvider>().currentUser;
    final userId = currentUser?.id ?? 1;

    // 1. Lưu tiến độ Vượt ải cục bộ & Mở khóa ải tiếp theo nếu đủ điểm
    final newlyUnlocked = await SkillProgressService.recordStageResult(
      userId: userId,
      skillType: 'reading',
      stageNumber: _selectedPassage.stageNumber,
      score: score,
      totalQuestions: total,
      passScoreRequired: _selectedPassage.passScoreRequired,
      totalStagesAvailable: _passages.length,
    );

    await _loadStageProgress(autoSelectNextStage: false);

    // 2. Đồng bộ kết quả bài đọc lên Supabase
    try {
      await PracticeService.savePracticeResult(
        skillType: 'reading',
        lessonId: _selectedPassage.id,
        lessonTitle: 'Ải ${_selectedPassage.stageNumber}: ${_selectedPassage.title}',
        score: score,
        totalQuestions: total,
        bandScore: estimatedBand,
        username: currentUser?.username,
      );
    } catch (_) {}

    // 3. Hiển thị Dialog chúc mừng Vượt ải hoặc Nhắc nhở làm lại
    if (mounted) {
      if (isPassed) {
        _showVictoryDialog(score, total, estimatedBand, newlyUnlocked);
      } else {
        _showFailedDialog(score, total, estimatedBand);
      }
    }
  }

  void _showVictoryDialog(int score, int total, String band, bool newlyUnlocked) {
    final stars = SkillProgressService.calculateStars(
      score,
      total,
      _selectedPassage.passScoreRequired,
    );
    final hasNextStage =
        _passages.any((p) => p.stageNumber == _selectedPassage.stageNumber + 1);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 54, color: Colors.teal),
            ),
            const SizedBox(height: 16),
            const Text(
              '🎉 VƯỢT ẢI THÀNH CÔNG!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bạn đã chinh phục ${_selectedPassage.difficultyLabel}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 14),
            // Hàng hiển thị Sao vàng
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final isLit = index < stars;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    isLit ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 38,
                    color: isLit ? Colors.amber : Colors.grey[300],
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Đúng $score/$total câu',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• Band $band',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.teal[800],
                    ),
                  ),
                ],
              ),
            ),
            if (newlyUnlocked && hasNextStage) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_open_rounded, size: 16, color: Colors.teal),
                  const SizedBox(width: 4),
                  Text(
                    'Đã mở khóa Ải ${_selectedPassage.stageNumber + 1} tiếp theo!',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (hasNextStage)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final nextPassage = _passages.firstWhere(
                      (p) => p.stageNumber == _selectedPassage.stageNumber + 1,
                      orElse: () => _passages.last,
                    );
                    _switchStage(nextPassage);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  label: const Text(
                    'TIẾN TỚI ẢI TIẾP THEO',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('XEM LẠI ĐÁP ÁN ẢI NÀY'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFailedDialog(int score, int total, String band) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sentiment_dissatisfied_rounded,
                  size: 54, color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            const Text(
              'CHƯA ĐỦ ĐIỂM VƯỢT ẢI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn trả lời đúng $score/$total câu (Band $band).\nCần đạt tối thiểu ${_selectedPassage.passScoreRequired}/$total câu đúng để vượt qua ải này.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded, color: Colors.teal, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mẹo: Chạm vào từ vựng mới để tra nghĩa ngay, đọc kỹ từ khóa trong câu hỏi đối chiếu với đoạn văn nhé!',
                      style: TextStyle(fontSize: 12, color: Colors.teal),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resetTest();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.replay_rounded, color: Colors.white),
                label: const Text(
                  'LÀM LẠI ẢI NÀY',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('XEM LẠI ĐÁP ÁN'),
              ),
            ),
          ],
        ),
      ),
    );
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
            'IELTS Reading Vượt Ải',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.navy,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Colors.teal, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'Ải ${_selectedPassage.stageNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
          bottom: const TabBar(
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.teal,
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
          // ── 0. Bản đồ vượt ải (Gamified Stage Roadmap - Teal Theme) ──
          _buildStageRoadmap(),
          const SizedBox(height: 16),

          // ── Banner thông báo khi xem lại ải đã vượt qua ──
          if ((_stageStars[_selectedPassage.stageNumber] ?? 0) > 0 && !_isSubmitted) ...[
            _buildPassedStageNoticeBanner(),
            const SizedBox(height: 16),
          ],

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
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.touch_app_rounded,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Mẹo: Chạm vào từ bất kỳ để tra nghĩa tiếng Việt tại chỗ',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
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
          // ── 0. Bản đồ vượt ải (Gamified Stage Roadmap) ──
          _buildStageRoadmap(),
          const SizedBox(height: 16),

          // Banner kết quả sau khi nộp bài
          if (_isSubmitted) ...[
            _buildScoreBanner(),
            const SizedBox(height: 16),
          ] else if ((_stageStars[_selectedPassage.stageNumber] ?? 0) > 0) ...[
            _buildPassedStageNoticeBanner(),
            const SizedBox(height: 16),
          ],

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
                  : (((_stageStars[_selectedPassage.stageNumber] ?? 0) > 0)
                      ? 'NỘP BÀI ĐỂ NÂNG ĐIỂM (${_userAnswers.length}/${_selectedPassage.questions.length})'
                      : 'NỘP BÀI & CHẤM ĐIỂM (${_userAnswers.length}/${_selectedPassage.questions.length})')),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isSubmitted ? AppColors.navy : Colors.teal,
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

  /// Banner thông báo khi người học đang xem lại một Ải Reading đã từng vượt qua thành công
  Widget _buildPassedStageNoticeBanner() {
    final stars = _stageStars[_selectedPassage.stageNumber] ?? 0;
    final bestScore = _stageBestScores[_selectedPassage.stageNumber] ?? 0;
    final total = _selectedPassage.questions.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.teal, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'ẢI ${_selectedPassage.stageNumber} ĐÃ VƯỢT QUA!',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF15803D),
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      children: List.generate(3, (i) {
                        final lit = i < stars;
                        return Icon(
                          lit ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 16,
                          color: lit ? Colors.amber : Colors.grey[300],
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Kỷ lục: Đúng $bestScore/$total câu. Bạn có thể làm lại bài này để nâng điểm hoặc bấm sang Ải tiếp theo trên lộ trình.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[900],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bản đồ Vượt ải (Gamified Stage Roadmap) Cấp độ động (Theme Teal)
  Widget _buildStageRoadmap() {
    final stages = _passages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_esports_rounded, color: Colors.teal, size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'LỘ TRÌNH VƯỢT ẢI (READING)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Đã mở: $_highestUnlockedStage / ${stages.length} Ải',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: stages.map((stage) {
                final isSelected = stage.id == _selectedPassage.id;
                final isUnlocked = stage.stageNumber <= _highestUnlockedStage;
                final stars = _stageStars[stage.stageNumber] ?? 0;
                final isPassed = stars > 0;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () {
                      if (isUnlocked) {
                        _switchStage(stage);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '🔒 Ải ${stage.stageNumber} đang bị khóa! Vui lòng vượt qua Ải ${stage.stageNumber - 1} để mở khóa.',
                            ),
                            backgroundColor: Colors.teal,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 110,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.teal.withValues(alpha: 0.08)
                            : (isUnlocked ? Colors.grey[50] : const Color(0xFFF0F0F0)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? Colors.teal
                              : (isPassed
                                  ? Colors.green.withValues(alpha: 0.6)
                                  : Colors.grey[300]!),
                          width: isSelected ? 2 : 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ải ${stage.stageNumber}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isUnlocked ? AppColors.navy : Colors.grey[500],
                                ),
                              ),
                              if (!isUnlocked)
                                const Icon(Icons.lock_rounded, size: 14, color: Colors.grey)
                              else if (isPassed)
                                const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green)
                              else
                                const Icon(Icons.play_circle_outline_rounded, size: 14, color: Colors.teal),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Hàng sao vàng đạt được
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (sIdx) {
                              final lit = sIdx < stars;
                              return Icon(
                                lit ? Icons.star_rounded : Icons.star_outline_rounded,
                                size: 14,
                                color: lit ? Colors.amber : Colors.grey[300],
                              );
                            }),
                          ),
                          const SizedBox(height: 6),
                          if (isPassed && (_stageBestScores[stage.stageNumber] ?? 0) > 0)
                            Text(
                              'Điểm: ${_stageBestScores[stage.stageNumber]}/${stage.questions.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            )
                          else
                            Text(
                              'Target ${stage.bandScoreTarget}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isUnlocked ? Colors.grey[700] : Colors.grey[400],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
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
    _checkSavedStatus();
    widget.flutterTts.speak(widget.word);
  }

  Future<void> _checkSavedStatus() async {
    final user = context.read<AuthProvider>().currentUser;
    final userId = user?.id ?? 1;
    final isSavedLocal = await DatabaseHelper.instance.isWordSaved(userId, widget.word.toLowerCase().trim());
    if (isSavedLocal && mounted) {
      setState(() => _isSaved = true);
      return;
    }
    try {
      final isSavedApi = await ApiService.instance.checkWordSaved(widget.word.toLowerCase().trim());
      if (isSavedApi && mounted) {
        setState(() => _isSaved = true);
      }
    } catch (_) {}
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
      label: widget.word.trim().toLowerCase(),
      word: entry.word.trim(),
      ipa: entry.ipa.trim().isNotEmpty ? entry.ipa.trim() : '/${entry.word.trim()}/',
      translation: entry.vietnameseMeaning.trim(),
      bandScore: entry.bandScore ?? '7.5',
      example: entry.example ?? 'Từ vựng học thuật trong bài đọc IELTS.',
      createdAt: DateTime.now().toIso8601String(),
    );

    // 1. Lưu vào SQLite cục bộ và tự động sync lên Supabase
    await DatabaseHelper.instance.insertNotebookItem(item, username: user?.username);

    // 2. Đồng bộ lên Backend FastAPI
    try {
      await ApiService.instance.saveToNotebook(item);
    } catch (_) {}

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
