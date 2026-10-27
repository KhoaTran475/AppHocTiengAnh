import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../../core/services/practice_service.dart';
import '../../../core/services/skill_progress_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/skill_models.dart';
import '../../../data/repositories/skill_repository.dart';
import '../../../data/datasources/api_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Màn hình Luyện thi IELTS Speaking chuyên sâu theo cơ chế Vượt ải (Gamified Stages).
/// Tính năng:
/// 1. Bản đồ vượt ải 5 Cấp độ (Band 6.0 đến Boss Stage Band 8.5+) mở khóa tuần tự.
/// 2. Hộp thoại Chiến thắng (Victory Celebration Dialog) khi đạt đủ điểm qua ải.
/// 3. Hệ thống đánh giá Sao (1⭐, 2⭐⭐, 3⭐⭐⭐) lưu điểm kỷ lục.
/// 4. Part 1: Luyện phản xạ phỏng vấn, nghe câu trả lời mẫu AI & học từ vựng/collocations.
/// 5. Part 2: Cue Card chuẩn IELTS, đồng hồ đếm ngược 1 phút chuẩn bị + 2 phút nói.
/// 6. Luyện nói Shadowing với âm thanh phát âm bản xứ (TTS điều chỉnh tốc độ).
/// 7. Đánh giá hoàn thành & Đồng bộ kết quả lên Backend và Supabase.
class SpeakingPracticeScreen extends StatefulWidget {
  const SpeakingPracticeScreen({super.key});

  @override
  State<SpeakingPracticeScreen> createState() => _SpeakingPracticeScreenState();
}

class _SpeakingPracticeScreenState extends State<SpeakingPracticeScreen> {
  List<SpeakingLessonModel> _lessons = List.from(SkillRepository.sampleSpeakingLessons);
  late SpeakingLessonModel _selectedLesson;
  final FlutterTts _flutterTts = FlutterTts();

  // Bộ đếm thời gian cho Part 2 (1 phút chuẩn bị, 2 phút nói)
  Timer? _timer;
  int _secondsLeft = 60;
  bool _isTimerRunning = false;
  String _activeTimerMode = 'prep'; // 'prep' (60s) hoặc 'talk' (120s)

  // Trạng thái phát âm
  bool _isPlayingAudio = false;
  final double _speechRate = 0.9; // Tốc độ đọc tự nhiên

  // Bộ đánh giá hoàn thành bài nói
  bool _isSubmitted = false;
  int _fluencyRating = 8;
  int _vocabularyRating = 8;
  int _pronunciationRating = 7;

  // Trạng thái Vượt ải Gamification (Theme Tím / Violet)
  int _highestUnlockedStage = 1;
  Map<int, int> _stageStars = {};
  Map<int, int> _stageBestScores = {};

  // Hằng số màu chủ đạo Violet
  static const Color _violetColor = Color(0xFF7C3AED);
  static const Color _violetDark = Color(0xFF5B21B6);

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

    // Tải danh sách bài nói từ API để hỗ trợ mở rộng ải động (> 5 ải)
    try {
      final apiLessons = await ApiService.instance.getSpeakingLessons();
      if (apiLessons.isNotEmpty) {
        _lessons = apiLessons;
        _lessons.sort((a, b) => a.stageNumber.compareTo(b.stageNumber));
      }
    } catch (_) {}

    if (!_lessons.any((l) => l.id == _selectedLesson.id)) {
      _selectedLesson = _lessons.first;
    }

    try {
      final prog = await ApiService.instance.getSkillProgress('speaking');
      highest = prog['highest_unlocked_stage'] as int? ?? 1;
      final rawStages = prog['stages'] as List<dynamic>? ?? [];
      for (final s in rawStages) {
        final stNum = s['stage_number'] as int;
        stars[stNum] = s['stars'] as int? ?? 0;
        bestScores[stNum] = s['best_score'] as int? ?? 0;
      }
    } catch (_) {}

    // Kết hợp SharedPreferences cục bộ
    final localHighest = await SkillProgressService.getHighestUnlockedStage(userId, 'speaking');
    if (localHighest > highest) {
      highest = localHighest;
    }
    for (final lesson in _lessons) {
      final s = await SkillProgressService.getStageStars(userId, 'speaking', lesson.stageNumber);
      final b = await SkillProgressService.getStageBestScore(userId, 'speaking', lesson.stageNumber);
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
          SpeakingLessonModel targetLesson = _lessons.first;
          for (final lesson in _lessons) {
            if (lesson.stageNumber <= highest) {
              targetLesson = lesson;
              if ((stars[lesson.stageNumber] ?? 0) == 0) {
                break;
              }
            }
          }
          if (_selectedLesson.id != targetLesson.id) {
            _selectedLesson = targetLesson;
            _isSubmitted = false;
            _isPlayingAudio = false;
            _isTimerRunning = false;
            _secondsLeft = 60;
          }
        }
      });
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  void _switchStage(SpeakingLessonModel lesson) {
    if (_selectedLesson.id == lesson.id) return;
    _flutterTts.stop();
    _timer?.cancel();
    setState(() {
      _selectedLesson = lesson;
      _isSubmitted = false;
      _isPlayingAudio = false;
      _isTimerRunning = false;
      _secondsLeft = 60;
    });
  }

  void _startTimer(int seconds, String mode) {
    _timer?.cancel();
    setState(() {
      _secondsLeft = seconds;
      _activeTimerMode = mode;
      _isTimerRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        setState(() => _isTimerRunning = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                mode == 'prep'
                    ? '⏰ Hết 1 phút chuẩn bị! Bắt đầu 2 phút nói ngay.'
                    : '🎉 Hết 2 phút nói! Bạn đã hoàn thành phần thi Part 2.',
              ),
              backgroundColor: _violetColor,
            ),
          );
        }
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isTimerRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = _activeTimerMode == 'prep' ? 60 : 120;
      _isTimerRunning = false;
    });
  }

  Future<void> _speakText(String text) async {
    if (_isPlayingAudio) {
      await _flutterTts.stop();
      setState(() => _isPlayingAudio = false);
    } else {
      setState(() => _isPlayingAudio = true);
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.speak(text);
    }
  }

  Future<void> _submitSpeakingResult() async {
    final avgScore = ((_fluencyRating + _vocabularyRating + _pronunciationRating) / 3.0);
    final bandScore = avgScore.toStringAsFixed(1);
    final targetBand = _selectedLesson.bandScoreTarget;
    final targetFloat = double.tryParse(targetBand.replaceAll('+', '')) ?? 6.0;

    bool isPassed = avgScore >= _selectedLesson.passScoreRequired;
    int calculatedStars = 0;
    if (isPassed) {
      if (avgScore >= targetFloat + 0.5) {
        calculatedStars = 3;
      } else if (avgScore >= targetFloat) {
        calculatedStars = 2;
      } else {
        calculatedStars = 1;
      }
    }

    final currentUser = context.read<AuthProvider>().currentUser;
    final userId = currentUser?.id ?? 1;

    // 1. Gửi kết quả tới FastAPI Backend
    try {
      final res = await ApiService.instance.submitTest(
        lessonId: _selectedLesson.id,
        skillType: 'speaking',
        ratings: {
          'fluency': _fluencyRating,
          'vocabulary': _vocabularyRating,
          'pronunciation': _pronunciationRating,
        },
      );
      if (res['band_score'] != null) {
        // bandScore
      }
      if (res['passed'] != null) isPassed = res['passed'] as bool;
      if (res['stars'] != null) calculatedStars = res['stars'] as int;
    } catch (_) {}

    setState(() {
      _isSubmitted = true;
    });

    // 2. Ghi nhận tiến độ Vượt ải Speaking
    final int scoreInt = (avgScore * 10).round();
    final newlyUnlocked = await SkillProgressService.recordStageResult(
      userId: userId,
      skillType: 'speaking',
      stageNumber: _selectedLesson.stageNumber,
      score: scoreInt,
      totalQuestions: 90, // thang điểm 9.0 x 10
      passScoreRequired: (_selectedLesson.passScoreRequired * 10).round(),
      totalStagesAvailable: _lessons.length,
      overrideStars: isPassed ? calculatedStars : 0,
    );

    await _loadStageProgress(autoSelectNextStage: false);

    // 3. Đồng bộ Supabase
    try {
      await PracticeService.savePracticeResult(
        skillType: 'speaking',
        lessonId: _selectedLesson.id,
        lessonTitle: 'Ải ${_selectedLesson.stageNumber}: ${_selectedLesson.title}',
        score: (_fluencyRating + _vocabularyRating + _pronunciationRating),
        totalQuestions: 30, // Thang điểm tổng 10 x 3 tiêu chí
        bandScore: bandScore,
        username: currentUser?.username,
      );
    } catch (_) {}

    // 4. Hiển thị Dialog chúc mừng hoặc nhắc nhở làm lại
    if (mounted) {
      if (isPassed) {
        _showVictoryDialog(bandScore, calculatedStars, newlyUnlocked);
      } else {
        _showFailedDialog(bandScore);
      }
    }
  }

  void _showVictoryDialog(String band, int stars, bool newlyUnlocked) {
    final hasNextStage =
        _lessons.any((l) => l.stageNumber == _selectedLesson.stageNumber + 1);

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
                color: _violetColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 54, color: _violetColor),
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
                color: _violetColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Đạt IELTS Speaking: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _violetDark,
                    ),
                  ),
                  Text(
                    'Band $band',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _violetColor,
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
                  const Icon(Icons.lock_open_rounded, size: 16, color: _violetColor),
                  const SizedBox(width: 4),
                  Text(
                    'Đã mở khóa Ải ${_selectedLesson.stageNumber + 1} tiếp theo!',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _violetColor,
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
                    backgroundColor: _violetColor,
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
                  foregroundColor: _violetColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('XEM LẠI BÀI NÓI NÀY'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFailedDialog(String band) {
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
              'Điểm trung bình hiện tại: Band $band.\nCần đạt tối thiểu Band ${_selectedLesson.passScoreRequired.toStringAsFixed(1)} để vượt qua ải này.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _violetColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded, color: _violetColor, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mẹo: Nghe lại phát âm mẫu và luyện tập Shadowing từng câu để cải thiện Fluency & Pronunciation nhé!',
                      style: TextStyle(fontSize: 12, color: _violetDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _violetColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.record_voice_over_rounded, color: Colors.white),
                label: const Text(
                  'LUYỆN NÓI LẠI ĐỂ NÂNG ĐIỂM',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
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
            'IELTS Speaking Vượt Ải',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 18),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _violetColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _violetColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_rounded, color: _violetColor, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'Ải ${_selectedLesson.stageNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _violetColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
          bottom: const TabBar(
            labelColor: _violetColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _violetColor,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.record_voice_over_rounded), text: 'Part 1: Phỏng vấn'),
              Tab(icon: Icon(Icons.mic_external_on_rounded), text: 'Part 2: Cue Card'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPart1View(),
            _buildPart2View(),
          ],
        ),
      ),
    );
  }

  /// Giao diện Part 1: Các câu hỏi phỏng vấn ngắn & câu trả lời mẫu
  Widget _buildPart1View() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 0. Lộ trình vượt ải 5 Cấp độ (Theme Violet) ──
          _buildStageRoadmap(),
          const SizedBox(height: 16),

          // ── Banner thông báo khi xem lại Ải đã vượt qua ──
          if ((_stageStars[_selectedLesson.stageNumber] ?? 0) > 0 && !_isSubmitted) ...[
            _buildPassedStageNoticeBanner(),
            const SizedBox(height: 16),
          ],

          _buildHeaderInfo(partTitle: 'IELTS SPEAKING PART 1: INTRODUCTION & INTERVIEW'),
          const SizedBox(height: 16),
          ..._selectedLesson.part1Questions.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final item = entry.value;
            return _buildPart1QuestionCard(idx, item);
          }),
          const SizedBox(height: 20),
          _buildEvaluationSection(),
        ],
      ),
    );
  }

  Widget _buildPart1QuestionCard(int index, SpeakingPart1Item item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _violetColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q$index',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _violetColor,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.question,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Khung câu trả lời mẫu
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Câu trả lời mẫu Band 8.0+:',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: _violetColor, size: 22),
                      tooltip: 'Nghe phát âm AI',
                      onPressed: () => _speakText(item.sampleAnswer),
                    ),
                  ],
                ),
                Text(
                  item.sampleAnswer,
                  style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  '🇻🇳 ${item.translation}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700], fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Từ vựng ăn điểm
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: item.keyVocabulary.map((vocab) {
              return Chip(
                label: Text(vocab, style: const TextStyle(fontSize: 12, color: _violetDark)),
                backgroundColor: _violetColor.withValues(alpha: 0.08),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Giao diện Part 2: Cue Card & Đồng hồ bấm giờ chuẩn thi
  Widget _buildPart2View() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 0. Lộ trình vượt ải 5 Cấp độ (Theme Violet) ──
          _buildStageRoadmap(),
          const SizedBox(height: 16),

          // ── Banner thông báo khi xem lại Ải đã vượt qua ──
          if ((_stageStars[_selectedLesson.stageNumber] ?? 0) > 0 && !_isSubmitted) ...[
            _buildPassedStageNoticeBanner(),
            const SizedBox(height: 16),
          ],

          _buildHeaderInfo(partTitle: 'IELTS SPEAKING PART 2: INDIVIDUAL LONG TURN'),
          const SizedBox(height: 16),

          // Khung Cue Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_outlined, color: _violetColor, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'CANDIDATE CUE CARD',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: _violetColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedLesson.part2CueCardPrompt,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'You should say:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                ..._selectedLesson.part2BulletPoints.map((point) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: _violetColor, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            point,
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Đồng hồ bấm giờ phòng thi
          _buildTimerCard(),
          const SizedBox(height: 16),

          // Bài nói mẫu Band 8.0+ & Phụ đề
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
                    const Icon(Icons.record_voice_over_rounded, color: _violetColor, size: 20),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Bài nói mẫu Band 8.0+ (Full Response):',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: _violetColor, size: 24),
                      tooltip: 'Nghe toàn bộ bài nói Part 2',
                      onPressed: () => _speakText(_selectedLesson.part2SampleAnswer),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedLesson.part2SampleAnswer,
                  style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                ),
                const Divider(height: 24),
                const Text(
                  '🇻🇳 Bản dịch tiếng Việt:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedLesson.part2SampleTranslation,
                  style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey[800], fontStyle: FontStyle.italic),
                ),
                const Divider(height: 24),
                const Text(
                  'Collocations & Idioms ghi điểm:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _selectedLesson.part2Collocations.map((colloc) {
                    return Chip(
                      label: Text(colloc, style: const TextStyle(fontSize: 12, color: _violetDark)),
                      backgroundColor: _violetColor.withValues(alpha: 0.1),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildEvaluationSection(),
        ],
      ),
    );
  }

  /// Đồng hồ bấm giờ thực tế cho Part 2
  Widget _buildTimerCard() {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('1 Phút Chuẩn bị (Prep)'),
                selected: _activeTimerMode == 'prep',
                selectedColor: _violetColor.withValues(alpha: 0.15),
                onSelected: (val) {
                  if (val) _startTimer(60, 'prep');
                },
              ),
              ChoiceChip(
                label: const Text('2 Phút Nói (Talk)'),
                selected: _activeTimerMode == 'talk',
                selectedColor: _violetColor.withValues(alpha: 0.15),
                onSelected: (val) {
                  if (val) _startTimer(120, 'talk');
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$minutes:$seconds',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _secondsLeft <= 10 ? Colors.red : _violetColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  if (_isTimerRunning) {
                    _pauseTimer();
                  } else {
                    _startTimer(_secondsLeft, _activeTimerMode);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTimerRunning ? Colors.grey[800] : _violetColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(_isTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                label: Text(
                  _isTimerRunning ? 'TẠM DỪNG' : 'BẮT ĐẦU',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Đặt lại thời gian',
                onPressed: _resetTimer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Header thông tin bài học & mục tiêu Band
  Widget _buildHeaderInfo({required String partTitle}) {
    return Container(
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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _violetColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedLesson.topic,
                  style: const TextStyle(color: _violetColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Mục tiêu Band ${_selectedLesson.bandScoreTarget}',
                  style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _selectedLesson.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const SizedBox(height: 4),
          Text(
            partTitle,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// Phần đánh giá hoàn thành & Đồng bộ Supabase
  Widget _buildEvaluationSection() {
    final avgBand = ((_fluencyRating + _vocabularyRating + _pronunciationRating) / 3.0).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(18),
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
              const Expanded(
                child: Text(
                  'Tự đánh giá & Chấm điểm IELTS',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _violetColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Band $avgBand',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _violetColor),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildRatingRow('Độ lưu loát & Mạch lạc (Fluency)', _fluencyRating, (v) => setState(() => _fluencyRating = v)),
          _buildRatingRow('Vốn từ vựng (Lexical Resource)', _vocabularyRating, (v) => setState(() => _vocabularyRating = v)),
          _buildRatingRow('Phát âm chuẩn (Pronunciation)', _pronunciationRating, (v) => setState(() => _pronunciationRating = v)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitSpeakingResult,
              style: ElevatedButton.styleFrom(
                backgroundColor: _violetColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
              label: Text(
                _isSubmitted
                    ? 'LÀM LẠI HOẶC NÂNG ĐIỂM ẢI ${_selectedLesson.stageNumber}'
                    : (((_stageStars[_selectedLesson.stageNumber] ?? 0) > 0)
                        ? 'NỘP ĐÁNH GIÁ ĐỂ NÂNG ĐIỂM ẢI ${_selectedLesson.stageNumber}'
                        : 'NỘP BÀI NÓI & VƯỢT ẢI ${_selectedLesson.stageNumber}'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow(String title, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            Text('$value/10', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _violetColor)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 4,
          max: 10,
          divisions: 6,
          activeColor: _violetColor,
          onChanged: (val) => onChanged(val.round()),
        ),
      ],
    );
  }

  /// Banner thông báo khi người học đang xem lại một Ải Speaking đã từng vượt qua thành công
  Widget _buildPassedStageNoticeBanner() {
    final stars = _stageStars[_selectedLesson.stageNumber] ?? 0;
    final bestScore = (_stageBestScores[_selectedLesson.stageNumber] ?? 0) / 10.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _violetColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: _violetColor, size: 28),
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
                          color: _violetDark,
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
                  'Kỷ lục: Band ${bestScore.toStringAsFixed(1)}. Bạn có thể luyện nói lại để nâng cao điểm hoặc chọn Ải tiếp theo.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4C1D95),
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

  /// Bản đồ Vượt ải (Gamified Stage Roadmap) Cấp độ động (Theme Tím / Violet)
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
              const Icon(Icons.sports_esports_rounded, color: _violetColor, size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'LỘ TRÌNH VƯỢT ẢI (SPEAKING)',
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
                  color: _violetColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Đã mở: $_highestUnlockedStage / ${stages.length} Ải',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _violetColor,
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
                            backgroundColor: _violetColor,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 115,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _violetColor.withValues(alpha: 0.1)
                            : (isUnlocked ? Colors.grey[50] : const Color(0xFFF0F0F0)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? _violetColor
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
                                const Icon(Icons.play_circle_outline_rounded, size: 14, color: _violetColor),
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
                              'Band ${((_stageBestScores[stage.stageNumber] ?? 0) / 10.0).toStringAsFixed(1)}',
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
