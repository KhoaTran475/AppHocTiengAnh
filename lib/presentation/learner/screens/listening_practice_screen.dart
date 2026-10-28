import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../../core/services/listening_progress_service.dart';
import '../../../core/services/practice_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/skill_models.dart';
import '../../../data/repositories/skill_repository.dart';
import '../../../data/datasources/api_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Màn hình Luyện thi IELTS Listening Chuyên sâu theo cơ chế Vượt ải (Gamified Stages).
/// Tính năng:
/// 1. Bản đồ vượt ải 5 Cấp độ (Level 1 đến Level 5) mở khóa tuần tự.
/// 2. Hộp thoại Chiến thắng (Victory Celebration Dialog) khi đạt đủ điểm qua ải.
/// 3. Hệ thống đánh giá Sao (1⭐, 2⭐⭐, 3⭐⭐⭐) lưu điểm cao nhất.
/// 4. Hỗ trợ xem lại và làm lại bất kỳ ải nào đã vượt qua.
/// 5. Đồng bộ tiến độ với Supabase cloud practice_history.
class ListeningPracticeScreen extends StatefulWidget {
  const ListeningPracticeScreen({super.key});

  @override
  State<ListeningPracticeScreen> createState() =>
      _ListeningPracticeScreenState();
}

class _ListeningPracticeScreenState extends State<ListeningPracticeScreen> {
  List<ListeningLessonModel> _lessons = List.from(SkillRepository.sampleListeningLessons);
  late ListeningLessonModel _selectedLesson;
  final FlutterTts _flutterTts = FlutterTts();

  bool _isPlaying = false;
  double _speechRate = 0.45; // Tương đương tốc độ nói chuẩn 1.0x
  final Map<int, String> _userAnswers = {};
  bool _isSubmitted = false;
  int _correctCount = 0;
  bool _showTranscript = false;

  // Trạng thái Vượt ải Gamification
  int _highestUnlockedStage = 1;
  Map<int, int> _stageStars = {};
  Map<int, int> _stageBestScores = {};

  @override
  void initState() {
    super.initState();
    _selectedLesson = _lessons.first;
    _initTts();
    _loadStageProgress(autoSelectNextStage: true);
  }

  Future<void> _loadStageProgress({bool autoSelectNextStage = false}) async {
    final user = context.read<AuthProvider>().currentUser;
    final userId = user?.id ?? 1;

    int highest = 1;
    final Map<int, int> stars = {};
    final Map<int, int> bestScores = {};

    // Tải danh sách bài nghe từ API để hỗ trợ mở rộng ải động (> 5 ải)
    try {
      final apiLessons = await ApiService.instance.getListeningLessons();
      if (apiLessons.isNotEmpty) {
        _lessons = apiLessons;
        _lessons.sort((a, b) => a.stageNumber.compareTo(b.stageNumber));
      }
    } catch (_) {}

    if (!_lessons.any((l) => l.id == _selectedLesson.id)) {
      _selectedLesson = _lessons.first;
    }

    try {
      final prog = await ApiService.instance.getListeningProgress();
      highest = prog['highest_unlocked_stage'] as int? ?? 1;
      final rawStages = prog['stages'] as List<dynamic>? ?? [];
      for (final s in rawStages) {
        final stNum = s['stage_number'] as int;
        stars[stNum] = s['stars'] as int? ?? 0;
        bestScores[stNum] = s['best_score'] as int? ?? 0;
      }
    } catch (_) {}

    // Kết hợp thêm từ SharedPreferences cục bộ để đảm bảo tiến độ luôn được giữ vững
    final localHighest = await ListeningProgressService.getHighestUnlockedStage(userId);
    if (localHighest > highest) {
      highest = localHighest;
    }
    for (final lesson in _lessons) {
      final s = await ListeningProgressService.getStageStars(userId, lesson.stageNumber);
      final b = await ListeningProgressService.getStageBestScore(userId, lesson.stageNumber);
      if (s > (stars[lesson.stageNumber] ?? 0)) {
        stars[lesson.stageNumber] = s;
      }
      if (b > (bestScores[lesson.stageNumber] ?? 0)) {
        bestScores[lesson.stageNumber] = b;
      }
    }

    if (mounted) {
      setState(() {
        _highestUnlockedStage = highest;
        _stageStars = stars;
        _stageBestScores = bestScores;

        if (autoSelectNextStage) {
          // Tự động tìm Ải tiếp theo chưa hoàn thành để mở trực tiếp cho người học
          ListeningLessonModel targetLesson = _lessons.first;
          for (final lesson in _lessons) {
            if (lesson.stageNumber <= highest) {
              targetLesson = lesson;
              // Nếu ải này chưa có sao (chưa vượt qua), chọn ngay ải này để làm tiếp
              if ((stars[lesson.stageNumber] ?? 0) == 0) {
                break;
              }
            }
          }
          if (_selectedLesson.id != targetLesson.id) {
            _selectedLesson = targetLesson;
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
    await _flutterTts.setSpeechRate(_speechRate);

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });

    _flutterTts.setErrorHandler((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _flutterTts.stop();
      setState(() => _isPlaying = false);
    } else {
      await _flutterTts.setSpeechRate(_speechRate);
      setState(() => _isPlaying = true);
      await _flutterTts.speak(_selectedLesson.audioScript);
    }
  }

  Future<void> _changeSpeechRate(double rate) async {
    setState(() => _speechRate = rate);
    await _flutterTts.setSpeechRate(rate);
    if (_isPlaying) {
      await _flutterTts.stop();
      await _flutterTts.speak(_selectedLesson.audioScript);
    }
  }

  void _switchStage(ListeningLessonModel lesson) {
    if (_selectedLesson.id == lesson.id) return;
    _flutterTts.stop();
    setState(() {
      _selectedLesson = lesson;
      _resetTest();
    });
  }

  Future<void> _submitTest() async {
    int score = 0;
    final total = _selectedLesson.questions.length;
    for (final q in _selectedLesson.questions) {
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

    bool isPassed = score >= _selectedLesson.passScoreRequired;

    // Nộp bài và chấm điểm qua FastAPI Backend
    final Map<String, String> stringAnswers = _userAnswers.map((k, v) => MapEntry(k.toString(), v));
    bool apiSynced = false;
    try {
      final res = await ApiService.instance.submitTest(
        lessonId: _selectedLesson.id,
        skillType: 'listening',
        answers: stringAnswers,
      );
      apiSynced = true;
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
    final newlyUnlocked = await ListeningProgressService.recordStageResult(
      userId: userId,
      stageNumber: _selectedLesson.stageNumber,
      score: score,
      totalQuestions: total,
      passScoreRequired: _selectedLesson.passScoreRequired,
      totalStagesAvailable: _lessons.length,
    );

    await _loadStageProgress(autoSelectNextStage: false);

    // 2. Lưu kết quả bài nghe lên Supabase (nếu FastAPI chưa đồng bộ)
    try {
      await PracticeService.savePracticeResult(
        skillType: 'listening',
        lessonId: _selectedLesson.id,
        lessonTitle: 'Ải ${_selectedLesson.stageNumber}: ${_selectedLesson.title}',
        score: score,
        totalQuestions: total,
        bandScore: estimatedBand,
        username: currentUser?.username,
        alreadySyncedByBackend: apiSynced,
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
    final stars = ListeningProgressService.calculateStars(score, total, _selectedLesson.passScoreRequired);
    final hasNextStage = _lessons.any((l) => l.stageNumber == _selectedLesson.stageNumber + 1);

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
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 54, color: Colors.amber),
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
              'Bạn đã chinh phục ${_selectedLesson.difficultyLabel}',
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
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Đúng $score/$total câu',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• Band $band',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green[800]),
                  ),
                ],
              ),
            ),
            if (newlyUnlocked && hasNextStage) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_open_rounded, size: 16, color: Colors.deepOrange),
                  const SizedBox(width: 4),
                  Text(
                    'Đã mở khóa Ải ${_selectedLesson.stageNumber + 1} tiếp theo!',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
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
                    final nextLesson = _lessons.firstWhere(
                      (l) => l.stageNumber == _selectedLesson.stageNumber + 1,
                      orElse: () => _lessons.last,
                    );
                    _switchStage(nextLesson);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
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
              child: const Icon(Icons.sentiment_dissatisfied_rounded, size: 54, color: Colors.redAccent),
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
              'Bạn trả lời đúng $score/$total câu (Band $band).\nCần đạt tối thiểu ${_selectedLesson.passScoreRequired}/$total câu đúng để vượt qua ải này.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded, color: Colors.deepOrange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mẹo: Hãy bật phần Transcript để xem phụ đề bài nghe và các từ khóa quan trọng nhé!',
                      style: TextStyle(fontSize: 12, color: Colors.deepOrange),
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
                  backgroundColor: AppColors.primary,
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
    _flutterTts.stop();
    setState(() {
      _isPlaying = false;
      _userAnswers.clear();
      _isSubmitted = false;
      _correctCount = 0;
      _showTranscript = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'IELTS Listening Vượt Ải',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  'Ải ${_selectedLesson.stageNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 0. Bản đồ vượt ải (Gamified Stage Roadmap) ──
            _buildStageRoadmap(),
            const SizedBox(height: 16),

            // ── 1. Audio Player Card ──
            _buildAudioPlayerCard(),
            const SizedBox(height: 16),

            // ── 2. Banner kết quả chấm điểm (Nếu đã nộp bài) ──
            if (_isSubmitted) ...[
              _buildScoreBanner(),
              const SizedBox(height: 16),
            ] else if ((_stageStars[_selectedLesson.stageNumber] ?? 0) > 0) ...[
              // Banner thông báo ải đã vượt qua khi người học xem lại ải cũ
              _buildPassedStageNoticeBanner(),
              const SizedBox(height: 16),
            ],

            // ── 3. Transcript Toggle ──
            _buildTranscriptToggle(),
            const SizedBox(height: 16),

            // ── 4. Danh sách câu hỏi ──
            ..._selectedLesson.questions.map((q) {
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
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
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
                        const Expanded(
                          child: Text(
                            'QUESTION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1,
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

                    // Lựa chọn đáp án
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

                    // Giải thích chi tiết
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

            // Nút Nộp bài & Chấm điểm
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitted
                    ? _resetTest
                    : (_userAnswers.length == _selectedLesson.questions.length
                        ? _submitTest
                        : null),
                icon: Icon(_isSubmitted
                    ? Icons.refresh_rounded
                    : Icons.check_circle_rounded),
                label: Text(_isSubmitted
                    ? 'LÀM LẠI BÀI NGHE'
                    : (((_stageStars[_selectedLesson.stageNumber] ?? 0) > 0)
                        ? 'NỘP BÀI ĐỂ NÂNG ĐIỂM (${_userAnswers.length}/${_selectedLesson.questions.length})'
                        : 'NỘP BÀI & CHẤM ĐIỂM (${_userAnswers.length}/${_selectedLesson.questions.length})')),
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
      ),
    );
  }

  /// Trình phát Audio bài nghe IELTS Listening
  Widget _buildAudioPlayerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedLesson.topic,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Band ${_selectedLesson.bandScoreTarget}',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _selectedLesson.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Nút Play/Pause & Điều chỉnh tốc độ
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Nút tốc độ 0.8x
              TextButton(
                onPressed: () => _changeSpeechRate(0.35),
                style: TextButton.styleFrom(
                  foregroundColor:
                      _speechRate == 0.35 ? Colors.amber : Colors.white70,
                ),
                child: const Text('0.8x',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              const SizedBox(width: 12),

              // Nút Play / Pause chính
              ElevatedButton(
                onPressed: _toggleAudio,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(18),
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 4,
                ),
                child: Icon(
                  _isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 32,
                ),
              ),

              const SizedBox(width: 12),

              // Nút tốc độ 1.0x (Chuẩn)
              TextButton(
                onPressed: () => _changeSpeechRate(0.45),
                style: TextButton.styleFrom(
                  foregroundColor:
                      _speechRate == 0.45 ? Colors.amber : Colors.white70,
                ),
                child: const Text('1.0x',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Khung mở rộng hiển thị kịch bản bài nghe (Audio Transcript)
  Widget _buildTranscriptToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        initiallyExpanded: _showTranscript,
        onExpansionChanged: (val) => setState(() => _showTranscript = val),
        leading: const Icon(Icons.subtitles_rounded, color: AppColors.primary),
        title: const Text(
          'Audio Transcript (Lời thoại bài nghe)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.navy,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                _selectedLesson.audioScript,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner tổng kết kết quả chấm điểm IELTS Band Listening kèm trạng thái Vượt ải
  Widget _buildScoreBanner() {
    final total = _selectedLesson.questions.length;
    final pct = (_correctCount / total * 100).toStringAsFixed(0);
    final isPassed = _correctCount >= _selectedLesson.passScoreRequired;
    final stars = ListeningProgressService.calculateStars(_correctCount, total, _selectedLesson.passScoreRequired);

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
        gradient: isPassed
            ? const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isPassed ? '🏆 VƯỢT ẢI THÀNH CÔNG' : '⚠️ CHƯA ĐỦ ĐIỂM QUA ẢI',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isPassed ? Colors.amberAccent : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Hiển thị số sao
                        Row(
                          children: List.generate(3, (i) {
                            final lit = i < stars;
                            return Icon(
                              lit ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 18,
                              color: lit ? Colors.amber : Colors.white30,
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Đạt $pct% câu đúng (Band $estimatedBand)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isPassed
                          ? 'Đã đủ điều kiện mở khóa ải kế tiếp!'
                          : 'Cần đạt tối thiểu ${_selectedLesson.passScoreRequired}/$total câu để vượt ải.',
                      style: TextStyle(
                        color: isPassed ? Colors.white70 : Colors.amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Banner thông báo khi người học đang xem lại một Ải đã từng vượt qua thành công
  Widget _buildPassedStageNoticeBanner() {
    final stars = _stageStars[_selectedLesson.stageNumber] ?? 0;
    final bestScore = _stageBestScores[_selectedLesson.stageNumber] ?? 0;
    final total = _selectedLesson.questions.length;

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
              color: Colors.green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
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
                        'ẢI ${_selectedLesson.stageNumber} ĐÃ VƯỢT QUA!',
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

  /// Bản đồ Vượt ải (Gamified Stage Roadmap) hiển thị toàn bộ các ải
  Widget _buildStageRoadmap() {
    final stages = _lessons;

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
              const Icon(Icons.sports_esports_rounded, color: Colors.deepOrange, size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'LỘ TRÌNH VƯỢT ẢI',
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
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Đã mở: $_highestUnlockedStage / ${stages.length} Ải',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
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
                final isSelected = stage.id == _selectedLesson.id;
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
                            backgroundColor: Colors.deepOrange,
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
                            ? Colors.deepOrange.withValues(alpha: 0.08)
                            : (isUnlocked ? Colors.grey[50] : const Color(0xFFF0F0F0)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? Colors.deepOrange
                              : (isPassed
                                  ? Colors.green.withValues(alpha: 0.6)
                                  : (isUnlocked ? Colors.grey[300]! : Colors.grey[300]!)),
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
                                const Icon(Icons.play_circle_outline_rounded, size: 14, color: Colors.deepOrange),
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
