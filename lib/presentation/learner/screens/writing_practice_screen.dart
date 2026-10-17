import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/practice_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/skill_models.dart';
import '../../../data/repositories/skill_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Màn hình Luyện thi IELTS Writing chuyên sâu.
/// Tính năng:
/// 1. Task 1 (Báo cáo số liệu >= 150 từ) & Task 2 (Bài luận nghị luận >= 250 từ).
/// 2. Bộ đếm thời gian thi thực tế (20 phút Task 1, 40 phút Task 2).
/// 3. Trình soạn thảo thông minh kèm bộ đếm từ tự động (Live Word Counter).
/// 4. Thanh công cụ gợi ý từ nối Cohesive Devices (chèn nhanh vào bài viết).
/// 5. Tham khảo bài mẫu Band 8.0+ song ngữ & Đồng bộ điểm lên Supabase.
class WritingPracticeScreen extends StatefulWidget {
  const WritingPracticeScreen({super.key});

  @override
  State<WritingPracticeScreen> createState() => _WritingPracticeScreenState();
}

class _WritingPracticeScreenState extends State<WritingPracticeScreen> {
  late WritingLessonModel _selectedLesson;
  final TextEditingController _essayController = TextEditingController();

  // Bộ đếm thời gian
  Timer? _timer;
  int _secondsLeft = 1200; // Mặc định 20 phút (Task 1)
  bool _isTimerRunning = false;

  // Trạng thái bài nộp
  bool _isSubmitted = false;
  String _estimatedBand = '6.5';

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
    _selectedLesson = SkillRepository.sampleWritingLessons.first;
    _secondsLeft = _selectedLesson.suggestedTimeMinutes * 60;
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
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final band = _calculateBandScore();
    setState(() {
      _estimatedBand = band;
      _isSubmitted = true;
    });

    final currentUser = context.read<AuthProvider>().currentUser;

    // Lưu kết quả bài viết lên Supabase
    final success = await PracticeService.savePracticeResult(
      skillType: 'writing',
      lessonId: _selectedLesson.id,
      lessonTitle: '${_selectedLesson.taskType}: ${_selectedLesson.title}',
      score: words,
      totalQuestions: _selectedLesson.minWordCount,
      bandScore: band,
      username: currentUser?.username,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Đã lưu bài viết (Band $band - $words từ) lên hệ thống Supabase!'
                : '⚠️ Không thể đồng bộ kết quả lên máy chủ cloud.',
          ),
          backgroundColor: success ? Colors.green[700] : Colors.orange[800],
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
          'IELTS Writing Practice',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          PopupMenuButton<WritingLessonModel>(
            icon: const Icon(Icons.description_rounded, color: Colors.teal),
            tooltip: 'Chọn đề bài Writing',
            onSelected: _switchLesson,
            itemBuilder: (ctx) => SkillRepository.sampleWritingLessons.map((lesson) {
              return PopupMenuItem(
                value: lesson,
                child: Row(
                  children: [
                    Icon(
                      lesson.id == _selectedLesson.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: Colors.teal,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${lesson.taskType} - ${lesson.title}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: lesson.id == _selectedLesson.id
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _selectedLesson.taskType,
                          style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Tối thiểu ${_selectedLesson.minWordCount} từ',
                          style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Target Band ${_selectedLesson.bandScoreTarget}',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedLesson.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedLesson.prompt,
                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Dàn ý gợi ý có thể bấm mở ra
            ExpansionTile(
              backgroundColor: Colors.white,
              collapsedBackgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey[200]!)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey[200]!)),
              leading: const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber),
              title: const Text('Gợi ý Dàn ý chuẩn IELTS (Outline)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy)),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: _selectedLesson.keyOutline.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(item, style: const TextStyle(fontSize: 13, height: 1.3))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Thanh đồng hồ đếm ngược & Thống kê số từ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.teal, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '$minutes:$seconds',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_isTimerRunning ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.teal, size: 28),
                    onPressed: _isTimerRunning ? _pauseTimer : _startTimer,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Colors.grey),
                    onPressed: _resetTimer,
                  ),
                  const Spacer(),
                  // Bộ đếm từ thời gian thực
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isEnoughWords ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$words / ${_selectedLesson.minWordCount} từ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isEnoughWords ? Colors.green[800] : Colors.deepOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Thanh công cụ gợi ý từ nối Cohesive Devices
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFB2DFDB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.teal, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Chèn nhanh Từ nối học thuật (Cohesive Devices):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _cohesiveDevices.entries.expand((cat) {
                        return cat.value.map((word) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(word, style: const TextStyle(fontSize: 12, color: Colors.teal)),
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF80CBC4)),
                              onPressed: () => _insertCohesiveDevice(word),
                            ),
                          );
                        });
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Ô soạn thảo bài viết IELTS Writing
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
                      const Text(
                        'Bài luận của bạn:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
                      ),
                      const Spacer(),
                      Text(
                        '$_paragraphCount đoạn văn',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _essayController,
                    maxLines: null,
                    minLines: 12,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 15, height: 1.6),
                    decoration: InputDecoration(
                      hintText: 'Nhập nội dung bài viết học thuật của bạn tại đây...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
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
                        borderSide: const BorderSide(color: Colors.teal, width: 1.5),
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
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                label: Text(
                  _isSubmitted ? 'CẬP NHẬT KẾT QUẢ WRITING (BAND $_estimatedBand)' : 'NỘP BÀI WRITING & LƯU SUPABASE',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
              leading: const Icon(Icons.menu_book_rounded, color: Colors.teal),
              title: const Text('Xem Bài viết mẫu Band 8.0+ & Bản dịch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'English Model Essay:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.teal),
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
                            label: Text(vocab, style: const TextStyle(fontSize: 12, color: Colors.teal)),
                            backgroundColor: Colors.teal.withValues(alpha: 0.1),
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
}
