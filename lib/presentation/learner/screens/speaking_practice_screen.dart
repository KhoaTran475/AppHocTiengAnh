import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../../core/services/practice_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/skill_models.dart';
import '../../../data/repositories/skill_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Màn hình Luyện thi IELTS Speaking chuyên sâu.
/// Tính năng:
/// 1. Part 1: Luyện phản xạ phỏng vấn, nghe câu trả lời mẫu AI & học từ vựng/collocations.
/// 2. Part 2: Cue Card chuẩn IELTS, đồng hồ đếm ngược 1 phút chuẩn bị + 2 phút nói.
/// 3. Luyện nói Shadowing với âm thanh phát âm bản xứ (TTS điều chỉnh tốc độ).
/// 4. Đánh giá hoàn thành & Đồng bộ kết quả lên Supabase (practice_history).
class SpeakingPracticeScreen extends StatefulWidget {
  const SpeakingPracticeScreen({super.key});

  @override
  State<SpeakingPracticeScreen> createState() => _SpeakingPracticeScreenState();
}

class _SpeakingPracticeScreenState extends State<SpeakingPracticeScreen> {
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

  @override
  void initState() {
    super.initState();
    _selectedLesson = SkillRepository.sampleSpeakingLessons.first;
    _initTts();
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

    setState(() {
      _isSubmitted = true;
    });

    final currentUser = context.read<AuthProvider>().currentUser;

    // Lưu kết quả bài nói lên Supabase
    final success = await PracticeService.savePracticeResult(
      skillType: 'speaking',
      lessonId: _selectedLesson.id,
      lessonTitle: _selectedLesson.title,
      score: (_fluencyRating + _vocabularyRating + _pronunciationRating),
      totalQuestions: 30, // Thang điểm tổng 10 x 3 tiêu chí
      bandScore: bandScore,
      username: currentUser?.username,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Đã lưu kết quả bài nói (Band $bandScore) lên hệ thống Supabase!'
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'IELTS Speaking Practice',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          actions: [
            PopupMenuButton<SpeakingLessonModel>(
              icon: const Icon(Icons.playlist_play_rounded, color: AppColors.primary),
              tooltip: 'Chọn chủ đề Speaking',
              onSelected: (lesson) {
                _flutterTts.stop();
                _timer?.cancel();
                setState(() {
                  _selectedLesson = lesson;
                  _isSubmitted = false;
                  _isPlayingAudio = false;
                  _isTimerRunning = false;
                  _secondsLeft = 60;
                });
              },
              itemBuilder: (ctx) => SkillRepository.sampleSpeakingLessons.map((lesson) {
                return PopupMenuItem(
                  value: lesson,
                  child: Row(
                    children: [
                      Icon(
                        lesson.id == _selectedLesson.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lesson.title,
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
          bottom: const TabBar(
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepOrange,
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
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q$index',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
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
                    const Text(
                      'Câu trả lời mẫu Band 8.0+:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.navy,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: Colors.deepOrange, size: 22),
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
                label: Text(vocab, style: const TextStyle(fontSize: 12, color: AppColors.navy)),
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
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
          _buildHeaderInfo(partTitle: 'IELTS SPEAKING PART 2: INDIVIDUAL LONG TURN'),
          const SizedBox(height: 16),

          // Khung Cue Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_outlined, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'CANDIDATE CUE CARD',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Colors.deepOrange,
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
                        const Text('• ', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
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
                    const Text(
                      'Bài nói mẫu Band 8.5+',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _speakText(_selectedLesson.part2SampleAnswer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: Icon(_isPlayingAudio ? Icons.stop_rounded : Icons.volume_up_rounded, size: 18),
                      label: Text(_isPlayingAudio ? 'DỪNG' : 'NGHE MẪU'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _selectedLesson.part2SampleAnswer,
                  style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                Text(
                  '🇻🇳 Dịch nghĩa: ${_selectedLesson.part2SampleTranslation}',
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                ),
                const Divider(height: 24),
                const Text(
                  'Collocations & Idioms ghi điểm:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedLesson.part2Collocations.map((colloc) {
                    return Chip(
                      label: Text(colloc, style: const TextStyle(fontSize: 12, color: Colors.deepOrange)),
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
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

  /// Thẻ đồng hồ đếm ngược phòng thi
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('1 Phút Chuẩn bị'),
                selected: _activeTimerMode == 'prep',
                onSelected: (val) {
                  if (val) _startTimer(60, 'prep');
                },
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('2 Phút Nói'),
                selected: _activeTimerMode == 'talk',
                onSelected: (val) {
                  if (val) _startTimer(120, 'talk');
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$minutes:$seconds',
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _isTimerRunning ? _pauseTimer : () => _startTimer(_secondsLeft, _activeTimerMode),
                icon: Icon(_isTimerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(_isTimerRunning ? 'TẠM DỪNG' : 'BẮT ĐẦU'),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedLesson.topic,
                  style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Mục tiêu Band ${_selectedLesson.bandScoreTarget}',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _selectedLesson.title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.navy),
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
              const Text(
                'Tự đánh giá & Chấm điểm IELTS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Band $avgBand',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green),
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
                backgroundColor: Colors.deepOrange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
              label: Text(
                _isSubmitted ? 'CẬP NHẬT KẾT QUẢ SUPABASE' : 'NỘP BÀI NÓI & LƯU SUPABASE',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
            Text('$value/10', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 4,
          max: 10,
          divisions: 6,
          activeColor: Colors.deepOrange,
          onChanged: (val) => onChanged(val.round()),
        ),
      ],
    );
  }
}
