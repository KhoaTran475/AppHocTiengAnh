import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/practice_service.dart';
import '../../../core/services/skill_progress_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/skill_models.dart';
import '../../../data/repositories/skill_repository.dart';
import '../../../data/datasources/api_service.dart';
import '../../auth/providers/auth_provider.dart';

/// Màn hình Luyện thi IELTS Writing chuyên sâu theo cơ chế Vượt ải (Gamified Stages).
/// Tính năng:
/// 1. Bản đồ vượt ải 5 Cấp độ (Band 6.0 đến Boss Stage Band 8.5+) mở khóa tuần tự.
/// 2. Hộp thoại Chiến thắng (Victory Celebration Dialog) khi đạt đủ từ & Band điểm.
/// 3. Hệ thống đánh giá Sao (1⭐, 2⭐⭐, 3⭐⭐⭐) lưu kỷ lục số từ và Band điểm.
/// 4. Task 1 (Báo cáo số liệu >= 150 từ) & Task 2 (Bài luận nghị luận >= 250 từ).
/// 5. Bộ đếm thời gian thi thực tế (20 phút Task 1, 40 phút Task 2).
/// 6. Trình soạn thảo thông minh kèm bộ đếm từ tự động (Live Word Counter).
/// 7. Thanh công cụ gợi ý từ nối Cohesive Devices (chèn nhanh vào bài viết).
/// 8. Tham khảo bài mẫu Band 8.0+ song ngữ & Đồng bộ tiến độ lên Backend và Supabase.
class WritingPracticeScreen extends StatefulWidget {
  const WritingPracticeScreen({super.key});

  @override
  State<WritingPracticeScreen> createState() => _WritingPracticeScreenState();
}

class _WritingPracticeScreenState extends State<WritingPracticeScreen> {
  List<WritingLessonModel> _lessons = List.from(SkillRepository.sampleWritingLessons);
  late WritingLessonModel _selectedLesson;
  final TextEditingController _essayController = TextEditingController();

  // Bộ đếm thời gian
  Timer? _timer;
  int _secondsLeft = 1200; // Mặc định 20 phút (Task 1)
  bool _isTimerRunning = false;

  // Trạng thái bài nộp
  bool _isSubmitted = false;
  String _estimatedBand = '6.5';

  // Trạng thái Vượt ải Gamification (Theme Cam / Amber)
  int _highestUnlockedStage = 1;
  Map<int, int> _stageStars = {};
  Map<int, int> _stageBestScores = {};

  // Danh mục từ nối IELTS Cohesive Devices
  final Map<String, List<String>> _cohesiveDevices = {
    'Thêm ý': ['Furthermore,', 'Moreover,', 'In addition,', 'Notably,'],
    'Tương phản': ['However,', 'In contrast,', 'On the other hand,', 'Whereas,'],
    'Kết quả': ['Consequently,', 'Therefore,', 'As a result,', 'Thus,'],
    'Kết luận': ['In conclusion,', 'Overall,', 'To summarize,', 'Manifestly,'],
  };

  @override
  void initState() {
    super.initState();
    _selectedLesson = _lessons.first;
    _secondsLeft = _selectedLesson.suggestedTimeMinutes * 60;
    _loadStageProgress(autoSelectNextStage: true);
  }

  Future<void> _loadStageProgress({bool autoSelectNextStage = false}) async {
    final user = context.read<AuthProvider>().currentUser;
    final userId = user?.id ?? 1;

    int highest = 1;
    final Map<int, int> stars = {};
    final Map<int, int> bestScores = {};

    // Tải danh sách bài viết từ API để hỗ trợ mở rộng ải động (> 5 ải)
    try {
      final apiLessons = await ApiService.instance.getWritingLessons();
      if (apiLessons.isNotEmpty) {
        _lessons = apiLessons;
        _lessons.sort((a, b) => a.stageNumber.compareTo(b.stageNumber));
      }
    } catch (_) {}

    if (!_lessons.any((l) => l.id == _selectedLesson.id)) {
      _selectedLesson = _lessons.first;
    }

    try {
      final prog = await ApiService.instance.getSkillProgress('writing');
      highest = prog['highest_unlocked_stage'] as int? ?? 1;
      final rawStages = prog['stages'] as List<dynamic>? ?? [];
      for (final s in rawStages) {
        final stNum = s['stage_number'] as int;
        stars[stNum] = s['stars'] as int? ?? 0;
        bestScores[stNum] = s['best_score'] as int? ?? 0;
      }
    } catch (_) {}

    // Kết hợp SharedPreferences cục bộ
    final localHighest = await SkillProgressService.getHighestUnlockedStage(userId, 'writing');
    if (localHighest > highest) {
      highest = localHighest;
    }
    for (final lesson in _lessons) {
      final s = await SkillProgressService.getStageStars(userId, 'writing', lesson.stageNumber);
      final b = await SkillProgressService.getStageBestScore(userId, 'writing', lesson.stageNumber);
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
          WritingLessonModel targetLesson = _lessons.first;
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
            _essayController.clear();
            _secondsLeft = targetLesson.suggestedTimeMinutes * 60;
            _isTimerRunning = false;
            _isSubmitted = false;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _essayController.dispose();
    super.dispose();
  }

  void _switchLesson(WritingLessonModel lesson) {
    _timer?.cancel();
    setState(() {
      _selectedLesson = lesson;
      _essayController.clear();
      _secondsLeft = lesson.suggestedTimeMinutes * 60;
      _isTimerRunning = false;
      _isSubmitted = false;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _isTimerRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        t.cancel();
        setState(() => _isTimerRunning = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⏰ Hết giờ làm bài viết! Vui lòng hoàn tất và nộp bài.'),
              backgroundColor: Colors.deepOrange,
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
      _secondsLeft = _selectedLesson.suggestedTimeMinutes * 60;
      _isTimerRunning = false;
    });
  }

  /// Đếm số từ trong văn bản
  int get _wordCount {
    final text = _essayController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }

  /// Đếm số đoạn văn
  int get _paragraphCount {
    final text = _essayController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\n+')).where((s) => s.isNotEmpty).length;
  }

  /// Chèn từ nối vào vị trí con trỏ
  void _insertCohesiveDevice(String device) {
    final text = _essayController.text;
    final selection = _essayController.selection;
    final newText = text.replaceRange(
      selection.start < 0 ? text.length : selection.start,
      selection.end < 0 ? text.length : selection.end,
      '$device ',
    );
    _essayController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (selection.start < 0 ? text.length : selection.start) + device.length + 1,
      ),
    );
  }

  /// Tính điểm Band IELTS Writing ước tính dựa trên độ dài & từ vựng học thuật
  String _calculateBandScore() {
    final words = _wordCount;
    final minWords = _selectedLesson.minWordCount;

    if (words < minWords * 0.7) return '5.5';
    if (words < minWords) return '6.0';

    int bonusScore = 0;
    final textLower = _essayController.text.toLowerCase();

    // Kiểm tra số lượng từ học thuật xuất hiện
    for (final vocab in _selectedLesson.academicVocabulary) {
      final cleanWord = vocab.split('(').first.trim().toLowerCase();
      if (textLower.contains(cleanWord)) bonusScore++;
    }

    if (words >= minWords && bonusScore >= 3) return '8.0';
    if (words >= minWords && bonusScore >= 1) return '7.5';
    return '7.0';
  }

  Future<void> _submitEssay() async {
    final words = _wordCount;
    if (words < 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Bài viết quá ngắn! Vui lòng viết ít nhất 30 từ trước khi nộp bài.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    String band = _calculateBandScore();
    final targetBand = _selectedLesson.bandScoreTarget;
    final targetFloat = double.tryParse(targetBand.replaceAll('+', '')) ?? 6.0;
    final bandFloat = double.tryParse(band.replaceAll('+', '')) ?? 6.0;

    bool isPassed = words >= _selectedLesson.minWordCount && bandFloat >= targetFloat;
    int calculatedStars = 0;
    if (isPassed) {
      if (bandFloat >= targetFloat + 0.5) {
        calculatedStars = 3;
      } else if (bandFloat >= targetFloat) {
        calculatedStars = 2;
      } else {
        calculatedStars = 1;
      }
    }

    final currentUser = context.read<AuthProvider>().currentUser;
    final userId = currentUser?.id ?? 1;

    // 1. Gửi bài tới FastAPI Backend
    try {
      final res = await ApiService.instance.submitTest(
        lessonId: _selectedLesson.id,
        skillType: 'writing',
        essayText: _essayController.text,
        taskType: _selectedLesson.taskType == 'Task 1' ? 1 : 2,
      );
      if (res['band_score'] != null) band = res['band_score'] as String;
      if (res['passed'] != null) isPassed = res['passed'] as bool;
      if (res['stars'] != null) calculatedStars = res['stars'] as int;
    } catch (_) {}

    setState(() {
      _estimatedBand = band;
      _isSubmitted = true;
    });

    // 2. Ghi nhận tiến độ Vượt ải Writing
    final newlyUnlocked = await SkillProgressService.recordStageResult(
      userId: userId,
      skillType: 'writing',
      stageNumber: _selectedLesson.stageNumber,
      score: words,
      totalQuestions: _selectedLesson.minWordCount,
      passScoreRequired: _selectedLesson.minWordCount,
      totalStagesAvailable: _lessons.length,
      overrideStars: isPassed ? calculatedStars : 0,
    );

    await _loadStageProgress(autoSelectNextStage: false);

    // 3. Đồng bộ lên Supabase
    try {
      await PracticeService.savePracticeResult(
        skillType: 'writing',
        lessonId: _selectedLesson.id,
        lessonTitle: 'Ải ${_selectedLesson.stageNumber}: ${_selectedLesson.title}',
        score: words,
        totalQuestions: _selectedLesson.minWordCount,
        bandScore: band,
        username: currentUser?.username,
      );
    } catch (_) {}

    // 4. Hiển thị Dialog chúc mừng hoặc nhắc nhở
    if (mounted) {
      if (isPassed) {
        _showVictoryDialog(words, band, calculatedStars, newlyUnlocked);
      } else {
        _showFailedDialog(words, band);
      }
    }
  }

  void _showVictoryDialog(int words, String band, int stars, bool newlyUnlocked) {
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
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$words từ (>= ${_selectedLesson.minWordCount})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• Band $band',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFB45309),
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
                    _switchLesson(nextLesson);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
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
                  foregroundColor: const Color(0xFFD97706),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('XEM LẠI BÀI VIẾT NÀY'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFailedDialog(int words, String band) {
    final minWords = _selectedLesson.minWordCount;
    final targetBand = _selectedLesson.bandScoreTarget;

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
              'CHƯA ĐỦ ĐIỀU KIỆN VƯỢT ẢI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bài viết: $words/$minWords từ (Band $band).\nĐể qua ải này bạn cần đạt tối thiểu $minWords từ VÀ Band ước lượng >= $targetBand.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mẹo: Dùng thêm các từ nối Cohesive Devices phía dưới và chèn các từ vựng học thuật gợi ý để nâng điểm Band nhé!',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
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
                  backgroundColor: const Color(0xFFD97706),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
                label: const Text(
                  'TIẾP TỤC VIẾT THÊM',
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
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    final words = _wordCount;
    final isEnoughWords = words >= _selectedLesson.minWordCount;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'IELTS Writing Vượt Ải',
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD97706),
                    fontSize: 13,
                  ),
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
            // ── 0. Bản đồ vượt ải (Gamified Stage Roadmap - Amber Theme) ──
            _buildStageRoadmap(),
            const SizedBox(height: 16),

            // ── Banner thông báo khi người học xem lại ải đã vượt qua ──
            if ((_stageStars[_selectedLesson.stageNumber] ?? 0) > 0 && !_isSubmitted) ...[
              _buildPassedStageNoticeBanner(),
              const SizedBox(height: 16),
            ],

            // Header đề bài & Mục tiêu Band
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
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _selectedLesson.taskType,
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Yêu cầu >= ${_selectedLesson.minWordCount} từ',
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Target Band ${_selectedLesson.bandScoreTarget}',
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedLesson.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedLesson.prompt,
                    style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey[800]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bộ đếm thời gian thi thực tế (Timer Bar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: _secondsLeft < 300 ? Colors.red : const Color(0xFFD97706),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$minutes:$seconds',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _secondsLeft < 300 ? Colors.red : AppColors.navy,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isTimerRunning ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      color: const Color(0xFFD97706),
                      size: 28,
                    ),
                    onPressed: _isTimerRunning ? _pauseTimer : _startTimer,
                    tooltip: _isTimerRunning ? 'Tạm dừng đếm giờ' : 'Bắt đầu tính giờ thi',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.grey, size: 22),
                    onPressed: _resetTimer,
                    tooltip: 'Đặt lại thời gian',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Thanh gợi ý từ nối IELTS Cohesive Devices
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'TỪ NỐI HỌC THUẬT (COHESIVE DEVICES) - CHẠM ĐỂ CHÈN NHANH',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _cohesiveDevices.entries.expand((entry) {
                        return entry.value.map((device) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(device, style: const TextStyle(fontSize: 11, color: Color(0xFFB45309))),
                              backgroundColor: Colors.amber.withValues(alpha: 0.12),
                              side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                              onPressed: () => _insertCohesiveDevice(device),
                            ),
                          );
                        });
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Khung soạn thảo văn bản
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
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isEnoughWords
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Số từ: $words / ${_selectedLesson.minWordCount}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isEnoughWords ? Colors.green[800] : Colors.deepOrange,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Đoạn văn: $_paragraphCount',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                      if (words > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Ước tính: Band ${_calculateBandScore()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _essayController,
                    maxLines: 12,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Bắt đầu gõ bài luận của bạn tại đây... Hãy cấu trúc rõ ràng Mở bài, Thân bài và Kết luận.',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nút Nộp bài viết
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitEssay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                label: Text(
                  _isSubmitted
                      ? 'LÀM LẠI HOẶC NÂNG ĐIỂM (BAND $_estimatedBand)'
                      : (((_stageStars[_selectedLesson.stageNumber] ?? 0) > 0)
                          ? 'NỘP BÀI ĐỂ NÂNG ĐIỂM ẢI ${_selectedLesson.stageNumber}'
                          : 'NỘP BÀI WRITING & VƯỢT ẢI ${_selectedLesson.stageNumber}'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Khung Xem Bài mẫu Band 8.0+ Song ngữ
            ExpansionTile(
              backgroundColor: Colors.white,
              collapsedBackgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey[200]!)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey[200]!)),
              leading: const Icon(Icons.menu_book_rounded, color: Color(0xFFD97706)),
              title: const Text('Xem Bài viết mẫu Band 8.0+ & Bản dịch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'English Model Essay:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedLesson.sampleEssay,
                        style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                      ),
                      const Divider(height: 24),
                      const Text(
                        '🇻🇳 Bản dịch tiếng Việt:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedLesson.sampleTranslation,
                        style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey[800], fontStyle: FontStyle.italic),
                      ),
                      const Divider(height: 24),
                      const Text(
                        'Từ vựng học thuật ghi điểm:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _selectedLesson.academicVocabulary.map((vocab) {
                          return Chip(
                            label: Text(vocab, style: const TextStyle(fontSize: 12, color: Color(0xFFB45309))),
                            backgroundColor: Colors.amber.withValues(alpha: 0.12),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Banner thông báo khi người học đang xem lại một Ải Writing đã từng vượt qua thành công
  Widget _buildPassedStageNoticeBanner() {
    final stars = _stageStars[_selectedLesson.stageNumber] ?? 0;
    final bestScore = _stageBestScores[_selectedLesson.stageNumber] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFFD97706), size: 28),
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
                          color: Color(0xFFB45309),
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
                  'Kỷ lục: $bestScore từ. Bạn có thể làm lại để nâng cao Band điểm hoặc chọn Ải tiếp theo trên lộ trình.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF78350F),
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

  /// Bản đồ Vượt ải (Gamified Stage Roadmap) Cấp độ động (Theme Cam / Amber)
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
              const Icon(Icons.sports_esports_rounded, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'LỘ TRÌNH VƯỢT ẢI (WRITING)',
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
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Đã mở: $_highestUnlockedStage / ${stages.length} Ải',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD97706),
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
                        _switchLesson(stage);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '🔒 Ải ${stage.stageNumber} đang bị khóa! Vui lòng vượt qua Ải ${stage.stageNumber - 1} để mở khóa.',
                            ),
                            backgroundColor: const Color(0xFFD97706),
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
                            ? Colors.amber.withValues(alpha: 0.12)
                            : (isUnlocked ? Colors.grey[50] : const Color(0xFFF0F0F0)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFD97706)
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
                                const Icon(Icons.play_circle_outline_rounded, size: 14, color: Color(0xFFD97706)),
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
                              'Đạt: ${_stageBestScores[stage.stageNumber]} từ',
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
