import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/api_service.dart';
import '../../../data/models/vocab_learning_models.dart';
import '../../auth/providers/auth_provider.dart';

/// Màn hình Học Từ Vựng Phân Cấp (Cơ bản -> Nâng cao 5 Level) tích hợp Ollama Qwen 2.5 Local.
/// Bao gồm 3 chế độ học tập chuyên sâu:
/// 1. Thẻ Từ & Thang Nâng Cấp (Word Upgrade Ladder: Basic -> Intermediate -> Advanced + SRS).
/// 2. Phòng Luyện Đặt Câu AI (Qwen 2.5 Sentence Lab: Chấm điểm & Nâng cấp câu 3 cấp độ).
/// 3. Thử Thách Vượt Cấp (Gamified Level-Up Quiz: Tích sao 1⭐-3⭐ & mở khóa Level tiếp theo).
class VocabularyLearningScreen extends StatefulWidget {
  final int initialLevel;

  const VocabularyLearningScreen({
    super.key,
    this.initialLevel = 1,
  });

  @override
  State<VocabularyLearningScreen> createState() =>
      _VocabularyLearningScreenState();
}

/// Quản lý trạng thái bài kiểm tra độc lập theo Cấp độ và Chủ đề
class LevelQuizState {
  VocabQuizModel? quiz;
  final Map<int, String> userAnswers = {};
  bool isSubmitted = false;
  int correctCount = 0;

  void resetForNewQuiz(VocabQuizModel newQuiz) {
    quiz = newQuiz;
    userAnswers.clear();
    isSubmitted = false;
    correctCount = 0;
  }

  void clearAnswers() {
    userAnswers.clear();
    isSubmitted = false;
    correctCount = 0;
  }
}

class _VocabularyLearningScreenState extends State<VocabularyLearningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _sentenceController = TextEditingController();

  // Trạng thái Lộ trình 5 Cấp độ & Ollama Qwen 2.5
  bool _isLoading = true;
  bool _isOllamaOnline = false;
  String _ollamaModelName = 'qwen2.5:latest';
  VocabSystemConfigModel? _systemConfig; // Cấu hình động từ Web Admin Portal
  int _selectedLevel = 1;
  int _highestUnlockedLevel = 1;
  int _totalMastered = 0;
  int _totalSystemCards = 30;
  bool _isLevelRoadmapExpanded = true;
  final ScrollController _levelScrollController = ScrollController();

  List<VocabLevelInfoModel> _levels = [];
  List<VocabCardModel> _allCards = [];
  List<VocabCardModel> _filteredCards = [];
  String _selectedTopic = 'Tất cả';
  final Set<int> _expandedCardIds = {};

  // Trạng thái Tab 2: Phòng Luyện Đặt Câu AI Qwen 2.5
  VocabCardModel? _selectedLabCard;
  bool _isEvaluatingSentence = false;
  SentenceEvaluationModel? _sentenceEvalResult;

  // Trạng thái Tab 3: Thử Thách Vượt Cấp (Quiz) độc lập theo Cấp độ & Chủ đề
  bool _isGeneratingQuiz = false;
  bool _useAiQwenQuiz = true;
  final Map<String, LevelQuizState> _quizStates = {};

  String get _currentQuizKey => '$_selectedLevel|${_selectedTopic.trim().toLowerCase()}';
  LevelQuizState get _activeQuizState =>
      _quizStates.putIfAbsent(_currentQuizKey, () => LevelQuizState());

  VocabQuizModel? get _currentQuiz => _activeQuizState.quiz;
  Map<int, String> get _quizUserAnswers => _activeQuizState.userAnswers;
  bool get _isQuizSubmitted => _activeQuizState.isSubmitted;
  int get _quizCorrectCount => _activeQuizState.correctCount;

  static const Map<int, Map<String, dynamic>> _levelMetaUI = {
    1: {
      'badge': 'Level 1 • A2-B1',
      'name': 'Cơ bản',
      'band': 'Band 4.5 - 5.5',
      'color': Color(0xFF10B981),
      'icon': Icons.spa_rounded,
    },
    2: {
      'badge': 'Level 2 • B1-B2',
      'name': 'Trung cấp',
      'band': 'Band 6.0 - 6.5',
      'color': Color(0xFF3B82F6),
      'icon': Icons.trending_up_rounded,
    },
    3: {
      'badge': 'Level 3 • B2-C1',
      'name': 'Nâng cao',
      'band': 'Band 7.0',
      'color': Color(0xFF8B5CF6),
      'icon': Icons.auto_stories_rounded,
    },
    4: {
      'badge': 'Level 4 • C1',
      'name': 'Học thuật',
      'band': 'Band 7.5 - 8.0',
      'color': Color(0xFFF59E0B),
      'icon': Icons.local_fire_department_rounded,
    },
    5: {
      'badge': 'Level 5 • C2',
      'name': 'Bậc thầy',
      'band': 'Band 8.5+',
      'color': Color(0xFFE11D48),
      'icon': Icons.workspace_premium_rounded,
    },
  };

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.initialLevel.clamp(1, 5);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _initTts();
    _loadInitialData();
    _searchController.addListener(_applyCardFilters);
  }

  void _handleTabChange() {
    if (_tabController.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
  }

  Future<void> _speak(String text) async {
    final cleaned = text.contains('/') ? text.split('/').first.trim() : text.trim();
    if (cleaned.isNotEmpty) {
      await _flutterTts.speak(cleaned);
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    // 1. Kiểm tra trạng thái Ollama Qwen 2.5 & Nạp Cấu hình Động từ Web Admin
    try {
      final config = await ApiService.instance.getVocabSystemConfig();
      if (mounted) {
        setState(() {
          _systemConfig = config;
          _isOllamaOnline = config.isOllamaOnline;
          _ollamaModelName = config.activeModel;
        });
      }
    } catch (_) {
      try {
        final st = await ApiService.instance.getVocabLearningStatus();
        if (mounted) {
          setState(() {
            _isOllamaOnline = st['online'] as bool? ?? false;
            _ollamaModelName = st['resolved_model']?.toString() ?? 'qwen2.5:latest';
          });
        }
      } catch (_) {}
    }

    // 2. Tải lộ trình 5 cấp độ
    try {
      final roadmap = await ApiService.instance.getVocabRoadmap();
      if (mounted) {
        setState(() {
          _levels = roadmap.levels;
          _highestUnlockedLevel = roadmap.highestUnlockedLevel;
          _totalMastered = roadmap.totalMasteredByUser;
          _totalSystemCards = roadmap.totalCardsInSystem;
        });
      }
    } catch (_) {}

    // 3. Tải danh sách thẻ từ của cấp độ đang chọn
    await _loadCardsForLevel(_selectedLevel);
  }

  Future<void> _loadCardsForLevel(int level) async {
    setState(() {
      _selectedLevel = level;
      _selectedTopic = 'Tất cả';
      _isLoading = true;
    });

    List<VocabCardModel> loaded = [];
    try {
      loaded = await ApiService.instance.getVocabLearningCards(level: level);
    } catch (_) {
      loaded = VocabCardModel.offlineSeedCards
          .where((c) => c.level == level)
          .toList();
    }

    if (loaded.isEmpty) {
      loaded = VocabCardModel.offlineSeedCards
          .where((c) => c.level == level)
          .toList();
    }

    if (mounted) {
      setState(() {
        _allCards = loaded;
        _selectedLabCard = loaded.isNotEmpty ? loaded.first : null;
        if (_allCards.isNotEmpty) {
          _expandedCardIds.add(_allCards.first.id);
        }
        _applyCardFilters();
        _isLoading = false;
      });

      if (_levelScrollController.hasClients) {
        final targetOffset = ((level - 1) * 156.0).clamp(0.0, _levelScrollController.position.maxScrollExtent);
        _levelScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _applyCardFilters() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredCards = _allCards.where((c) {
        final matchTopic =
            _selectedTopic == 'Tất cả' || c.topic.toLowerCase() == _selectedTopic.toLowerCase();
        final matchQuery = q.isEmpty ||
            c.word.toLowerCase().contains(q) ||
            c.basicWord.toLowerCase().contains(q) ||
            c.intermediateWord.toLowerCase().contains(q) ||
            c.advancedWord.toLowerCase().contains(q) ||
            c.vietnameseMeaning.toLowerCase().contains(q);
        return matchTopic && matchQuery;
      }).toList();
    });
  }

  List<String> get _availableTopics {
    final set = <String>{'Tất cả'};
    for (final c in _allCards) {
      if (c.topic.isNotEmpty) set.add(c.topic);
    }
    return set.toList();
  }

  /// Hộp thoại gọi Ollama Qwen 2.5 sinh bộ thẻ từ vựng mới theo chủ đề bất kỳ
  Future<void> _showGenerateWithQwenDialog() async {
    final topicCtrl = TextEditingController();
    int selectedCount = _systemConfig?.defaultGenCount ?? 5;
    bool isGenerating = false;

    final suggestedTopics = [
      'Artificial Intelligence',
      'Climate Change & Ecology',
      'Mental Health & Well-being',
      'Global Economy & Trade',
      'Higher Education',
      'Space Exploration',
      'Cybersecurity & Privacy',
      'Sustainable Urbanization',
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final meta = _levelMetaUI[_selectedLevel] ?? _levelMetaUI[1]!;
            final Color levelColor = meta['color'] as Color;

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.auto_awesome_rounded, color: levelColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sinh Từ Vựng Với Ollama Qwen 2.5',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy,
                                ),
                              ),
                              Text(
                                '${meta['badge']} (${meta['band']}) • Model: $_ollamaModelName',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isGenerating ? null : () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nhập chủ đề bạn muốn học hoặc chọn gợi ý:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: topicCtrl,
                      enabled: !isGenerating,
                      decoration: InputDecoration(
                        hintText: 'VD: Renewable Energy, Remote Work, Food Culture...',
                        prefixIcon: const Icon(Icons.topic_rounded),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestedTopics.map((t) {
                        return ActionChip(
                          label: Text(t, style: const TextStyle(fontSize: 12)),
                          backgroundColor: Colors.grey[100],
                          onPressed: isGenerating
                              ? null
                              : () {
                                  setModalState(() => topicCtrl.text = t);
                                },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const Text(
                          'Số lượng thẻ từ muốn sinh:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                        Wrap(
                          spacing: 6,
                          children: ({3, 5, 8, _systemConfig?.defaultGenCount ?? 5}.toList()..sort()).map((cnt) {
                            final selected = selectedCount == cnt;
                            return ChoiceChip(
                              label: Text('$cnt từ'),
                              visualDensity: VisualDensity.compact,
                              selected: selected,
                              selectedColor: levelColor,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : AppColors.navy,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                              onSelected: isGenerating
                                  ? null
                                  : (_) => setModalState(() => selectedCount = cnt),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: levelColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: isGenerating
                            ? null
                            : () async {
                                final topic = topicCtrl.text.trim();
                                if (topic.length < 2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Vui lòng nhập hoặc chọn một chủ đề!'),
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() => isGenerating = true);
                                try {
                                  final res = await ApiService.instance.generateVocabWithQwen(
                                    topic: topic,
                                    level: _selectedLevel,
                                    count: selectedCount,
                                  );
                                  final newCards = res['cards'] as List<VocabCardModel>? ?? [];
                                  final src = res['source']?.toString() ?? 'qwen2.5';
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  await _loadInitialData();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFF059669),
                                      behavior: SnackBarBehavior.floating,
                                      content: Text(
                                        '✨ Đã nạp ${newCards.length} thẻ từ chủ đề "$topic" (Nguồn: $src)!',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!ctx.mounted) return;
                                  setModalState(() => isGenerating = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: Colors.redAccent,
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                    ),
                                  );
                                }
                              },
                        icon: isGenerating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.bolt_rounded),
                        label: Text(
                          isGenerating
                              ? 'Qwen 2.5 đang phân tích & sinh từ vựng...'
                              : 'BẮT ĐẦU SINH TỪ VỚI QWEN 2.5',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Cập nhật trạng thái thuộc từ (Spaced Repetition SRS)
  Future<void> _updateCardMastery(VocabCardModel card, int newMastery) async {
    final oldMastery = card.masteryLevel;
    setState(() {
      card.masteryLevel = newMastery;
      card.reviewCount += 1;
      if (oldMastery < 3 && newMastery == 3) {
        _totalMastered += 1;
      } else if (oldMastery == 3 && newMastery < 3 && _totalMastered > 0) {
        _totalMastered -= 1;
      }
    });

    try {
      await ApiService.instance.updateVocabMastery(
        cardId: card.id,
        masteryLevel: newMastery,
      );
    } catch (_) {}

    if (!mounted) return;
    final labels = {
      1: 'Đã đánh dấu: Cần ôn lại 🔄',
      2: 'Đã đánh dấu: Nhớ mang máng 💡',
      3: 'Tuyệt vời! Đã thuộc lòng từ "${card.word}" 🎉',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        content: Text(labels[newMastery] ?? 'Đã cập nhật tiến độ'),
      ),
    );
  }

  /// Lưu 1-chạm thẻ từ vào Sổ tay từ vựng hiện có
  Future<void> _saveCardToNotebook(VocabCardModel card) async {
    final user = context.read<AuthProvider>().currentUser;
    final userId = user?.id ?? 1;
    final item = card.toVocabularyItemModel(userId: userId);

    try {
      await DatabaseHelper.instance.insertNotebookItem(
        item,
        username: user?.username,
      );
    } catch (_) {}

    try {
      await ApiService.instance.saveToNotebook(item);
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        content: Text('📌 Đã lưu "${card.word}" vào Sổ tay từ vựng IELTS!'),
      ),
    );
  }

  /// Chấm điểm câu đặt của học viên bằng Ollama Qwen 2.5
  Future<void> _evaluateUserSentence() async {
    final targetWord = _selectedLabCard?.word ?? '';
    final sentence = _sentenceController.text.trim();
    if (targetWord.isEmpty || sentence.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập một câu tiếng Anh hoàn chỉnh chứa từ đang học!'),
        ),
      );
      return;
    }

    setState(() => _isEvaluatingSentence = true);
    try {
      final res = await ApiService.instance.evaluateSentenceWithQwen(
        word: targetWord,
        level: _selectedLevel,
        userSentence: sentence,
      );
      if (mounted) {
        setState(() {
          _sentenceEvalResult = res;
          _isEvaluatingSentence = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEvaluatingSentence = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    }
  }

  /// Tạo đề Quiz kiểm tra vượt cấp
  Future<void> _startLevelQuiz() async {
    // Chặn gọi API sinh đề nếu cấp độ này chưa được mở khóa
    if (_selectedLevel > _highestUnlockedLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange[800],
          content: Text(
            'Cấp độ $_selectedLevel đang bị khóa. Bạn cần vượt qua Cấp độ $_highestUnlockedLevel trước!',
          ),
        ),
      );
      return;
    }

    final quizKey = _currentQuizKey;
    final state = _quizStates.putIfAbsent(quizKey, () => LevelQuizState());

    setState(() {
      _isGeneratingQuiz = true;
      state.clearAnswers();
    });

    try {
      final quiz = await ApiService.instance.generateVocabQuiz(
        level: _selectedLevel,
        topic: _selectedTopic == 'Tất cả' ? null : _selectedTopic,
        questionCount: _systemConfig?.quizQuestionCount ?? 5,
        useAiQwen: _useAiQwenQuiz,
      );
      if (mounted) {
        setState(() {
          state.resetForNewQuiz(quiz);
          _isGeneratingQuiz = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingQuiz = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    }
  }

  /// Nộp bài Quiz & Mở khóa cấp độ tiếp theo
  Future<void> _submitQuiz() async {
    final state = _activeQuizState;
    final quiz = state.quiz;
    if (quiz == null || quiz.questions.isEmpty) return;

    int correct = 0;
    final List<int> masteredIds = [];
    for (final q in quiz.questions) {
      final userAns = state.userAnswers[q.id];
      if (userAns != null && userAns.trim() == q.correctAnswer.trim()) {
        correct += 1;
        final matchedCard = _allCards
            .where((c) => c.word.toLowerCase() == q.targetWord.toLowerCase())
            .firstOrNull;
        if (matchedCard != null) {
          masteredIds.add(matchedCard.id);
        }
      }
    }

    setState(() {
      state.isSubmitted = true;
      state.correctCount = correct;
    });

    final quizLevel = quiz.level;
    try {
      final res = await ApiService.instance.submitVocabQuiz(
        level: quizLevel,
        score: correct,
        totalQuestions: quiz.questions.length,
        masteredCardIds: masteredIds,
      );
      final passed = res['passed'] as bool? ?? (correct >= quiz.passScoreRequired);
      final stars = (res['stars_earned'] as num?)?.toInt() ?? (passed ? 2 : 0);
      final highest = (res['highest_unlocked_level'] as num?)?.toInt() ?? _highestUnlockedLevel;
      final feedback = res['feedback']?.toString() ?? '';

      if (mounted) {
        setState(() {
          if (highest > _highestUnlockedLevel) {
            _highestUnlockedLevel = highest;
          }
        });
        _showQuizResultDialog(
          passed: passed,
          stars: stars,
          score: correct,
          total: quiz.questions.length,
          feedback: feedback,
        );
      }
    } catch (_) {
      final passed = correct >= quiz.passScoreRequired;
      final stars = passed ? (correct == quiz.questions.length ? 3 : 2) : 0;
      if (passed && quizLevel < 5 && (quizLevel + 1) > _highestUnlockedLevel) {
        setState(() => _highestUnlockedLevel = quizLevel + 1);
      }
      if (mounted) {
        _showQuizResultDialog(
          passed: passed,
          stars: stars,
          score: correct,
          total: quiz.questions.length,
          feedback: passed
              ? 'Chúc mừng bạn đã vượt qua Cấp độ $quizLevel!'
              : 'Hãy ôn lại các thẻ từ và thử sức lại nhé!',
        );
      }
    }
  }

  void _showQuizResultDialog({
    required bool passed,
    required int stars,
    required int score,
    required int total,
    required String feedback,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              passed ? Icons.emoji_events_rounded : Icons.lightbulb_outline_rounded,
              color: passed ? Colors.amber[700] : Colors.orange,
              size: 30,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                passed ? 'Vượt Cấp Thành Công!' : 'Cố Gắng Lên Nhé!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (passed)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Icon(
                    i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 40,
                  );
                }),
              ),
            const SizedBox(height: 12),
            Text(
              'Điểm số: $score / $total câu đúng',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              feedback,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.grey[700], height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('XEM GIẢI THÍCH CHI TIẾT'),
          ),
          if (passed && _selectedLevel < 5)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _tabController.animateTo(0);
                _loadCardsForLevel(_selectedLevel + 1);
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text('LÊN CẤP ĐỘ ${_selectedLevel + 1}'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _levelScrollController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _sentenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMeta = _levelMetaUI[_selectedLevel] ?? _levelMetaUI[1]!;
    final Color activeColor = currentMeta['color'] as Color;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              pinned: true,
              floating: true,
              forceElevated: innerBoxIsScrolled,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Học Từ Vựng Cơ Bản → Nâng Cao',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: AppColors.navy,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: _isOllamaOnline ? const Color(0xFF10B981) : Colors.orange,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Ollama Local: $_ollamaModelName',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Sinh từ mới bằng Qwen 2.5',
                  icon: Icon(Icons.auto_awesome_rounded, color: activeColor),
                  onPressed: _showGenerateWithQwenDialog,
                ),
                IconButton(
                  tooltip: 'Làm mới dữ liệu',
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.navy),
                  onPressed: _loadInitialData,
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                onTap: (idx) {
                  if (idx != _currentTabIndex) {
                    setState(() => _currentTabIndex = idx);
                  }
                },
                labelColor: activeColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: activeColor,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                tabs: const [
                  Tab(icon: Icon(Icons.style_rounded, size: 20), text: 'Thang Từ Vựng'),
                  Tab(icon: Icon(Icons.psychology_alt_rounded, size: 20), text: 'Đặt Câu Qwen 2.5'),
                  Tab(icon: Icon(Icons.workspace_premium_rounded, size: 20), text: 'Thi Vượt Cấp'),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: _buildLevelRoadmapHeader(),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildWordLadderTab(activeColor),
            _buildSentenceLabTab(activeColor),
            _buildQuizTab(activeColor),
          ],
        ),
      ),
      floatingActionButton: (_currentTabIndex == 0 && MediaQuery.of(context).viewInsets.bottom == 0)
          ? FloatingActionButton.extended(
              onPressed: _showGenerateWithQwenDialog,
              backgroundColor: activeColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text(
                'SINH TỪ QWEN 2.5',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  /// Thanh chọn 5 Cấp độ từ Cơ bản (A2-B1) đến Bậc thầy (C2)
  Widget _buildLevelRoadmapHeader() {
    final bool isQuizTab = _currentTabIndex == 2;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Lộ trình 5 Cấp độ • Đã thuộc: $_totalMastered/$_totalSystemCards từ',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() {
                      _isLevelRoadmapExpanded = !_isLevelRoadmapExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isQuizTab ? AppColors.primary : const Color(0xFF059669)).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isQuizTab
                              ? 'Mở khóa: $_highestUnlockedLevel/5'
                              : 'Level $_selectedLevel/5',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isQuizTab ? AppColors.primary : const Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isLevelRoadmapExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: isQuizTab ? AppColors.primary : const Color(0xFF059669),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 84,
                child: ListView.builder(
                  controller: _levelScrollController,
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: 5,
                  itemBuilder: (context, idx) {
                    final lvl = idx + 1;
                    final meta = _levelMetaUI[lvl]!;
                    final Color color = meta['color'] as Color;
                    final bool isSelected = _selectedLevel == lvl;
                    // Chỉ áp dụng khóa level cho riêng Tab 3 (Thi Vượt Cấp). Tab 1 & Tab 2 luôn mở khóa tự do.
                    final bool isUnlocked = !isQuizTab || (lvl <= _highestUnlockedLevel);

                    final levelApiInfo = _levels.where((e) => e.level == lvl).firstOrNull;
                    final int stars = levelApiInfo?.stars ?? 0;

                    return GestureDetector(
                      onTap: () => _loadCardsForLevel(lvl),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 148,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? color : Colors.grey[50],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? color : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isUnlocked
                                      ? (meta['icon'] as IconData)
                                      : Icons.lock_outline_rounded,
                                  size: 16,
                                  color: isSelected ? Colors.white : color,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    meta['badge'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : color,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              meta['name'] as String,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppColors.navy,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    meta['band'] as String,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isSelected ? Colors.white70 : Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  children: List.generate(3, (sIdx) {
                                    return Icon(
                                      sIdx < stars ? Icons.star_rounded : Icons.star_border_rounded,
                                      size: 12,
                                      color: isSelected ? Colors.amberAccent : Colors.amber,
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isLevelRoadmapExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: THẺ TỪ & THANG NÂNG CẤP TỪ VỰNG (BASIC -> INTERMEDIATE -> ADVANCED)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildWordLadderTab(Color activeColor) {
    return Column(
      children: [
        // Thanh tìm kiếm và lọc theo Chủ đề
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm từ cơ bản, từ học thuật hoặc nghĩa tiếng Việt...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _availableTopics.map((topic) {
                    final selected = _selectedTopic == topic;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: selected,
                        label: Text(
                          topic,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            color: selected ? Colors.white : AppColors.navy,
                          ),
                        ),
                        selectedColor: activeColor,
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() {
                            _selectedTopic = topic;
                            _applyCardFilters();
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Danh sách thẻ từ vựng
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: activeColor))
              : _filteredCards.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.menu_book_rounded, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'Chưa có thẻ từ nào khớp bộ lọc hiện tại.',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _showGenerateWithQwenDialog,
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: const Text('Sinh từ mới bằng AI Qwen 2.5'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                      itemCount: _filteredCards.length,
                      itemBuilder: (context, index) {
                        return _buildVocabLadderCard(_filteredCards[index], activeColor);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildVocabLadderCard(VocabCardModel card, Color activeColor) {
    final isExpanded = _expandedCardIds.contains(card.id);
    final masteryColors = {
      0: Colors.grey,
      1: Colors.redAccent,
      2: Colors.amber[800]!,
      3: const Color(0xFF059669),
    };
    final masteryLabels = {
      0: 'Chưa học',
      1: 'Cần ôn lại',
      2: 'Nhớ sơ',
      3: 'Đã thuộc ✓',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: card.masteryLevel == 3
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : Colors.grey[200]!,
          width: card.masteryLevel == 3 ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedCardIds.remove(card.id);
            } else {
              _expandedCardIds.add(card.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng 1: Topic + Source Badge + Mastery Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${card.cefrLevel} • Band ${card.bandTarget}',
                            style: TextStyle(
                              color: activeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
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
                            card.topic,
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (card.source.contains('qwen'))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '✨ Qwen 2.5',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (masteryColors[card.masteryLevel] ?? Colors.grey)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      masteryLabels[card.masteryLevel] ?? 'Chưa học',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: masteryColors[card.masteryLevel] ?? Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Hàng 2: Từ trọng tâm + IPA + Nút phát âm TTS + Lưu sổ tay
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                card.word,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${card.partOfSpeech})',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        if (card.ipa.isNotEmpty)
                          Text(
                            card.ipa,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Nghe phát âm',
                    icon: Icon(Icons.volume_up_rounded, color: activeColor, size: 26),
                    onPressed: () => _speak(card.word),
                  ),
                  IconButton(
                    tooltip: 'Lưu vào Sổ tay từ vựng',
                    icon: const Icon(Icons.bookmark_add_outlined, color: AppColors.primary),
                    onPressed: () => _saveCardToNotebook(card),
                  ),
                ],
              ),

              // Nghĩa tiếng Việt
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '🇻🇳 ${card.vietnameseMeaning}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),

              // ── THANG NÂNG CẤP TỪ 3 BẬC (WORD UPGRADE LADDER) ──
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🪜 Thang Nâng Cấp Từ (Cơ bản → Trung cấp → Nâng cao):',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildLadderStep(
                          label: 'Cơ bản (A2-B1)',
                          word: card.basicWord,
                          color: const Color(0xFF10B981),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                        ),
                        _buildLadderStep(
                          label: 'Trung cấp (B2)',
                          word: card.intermediateWord,
                          color: const Color(0xFF3B82F6),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                        ),
                        _buildLadderStep(
                          label: 'Nâng cao (C1-C2)',
                          word: card.advancedWord,
                          color: const Color(0xFFE11D48),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chi tiết mở rộng
              if (isExpanded) ...[
                const Divider(height: 22),

                // Collocations
                if (card.collocations.isNotEmpty) ...[
                  const Text(
                    '📌 Cụm từ cố định (Collocations):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: card.collocations.map((col) {
                      return InkWell(
                        onTap: () => _speak(col),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: activeColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.volume_up_rounded, size: 13, color: activeColor),
                              const SizedBox(width: 4),
                              Text(
                                col,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: activeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Word Family
                if (card.wordFamily.isNotEmpty) ...[
                  const Text(
                    '🧬 Gia đình từ (Word Family):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: card.wordFamily.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${entry.key}: ${entry.value}',
                          style: const TextStyle(fontSize: 12, color: AppColors.navy),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // So sánh câu ví dụ Cơ bản vs Nâng cao
                if (card.exampleBasic.isNotEmpty || card.exampleAdvanced.isNotEmpty) ...[
                  const Text(
                    '💬 So sánh Ngữ cảnh Câu (Cơ bản vs. IELTS Học thuật):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                  ),
                  const SizedBox(height: 6),
                  if (card.exampleBasic.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '🟢 Cơ bản: "${card.exampleBasic}"',
                              style: const TextStyle(fontSize: 12.5, height: 1.35),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.volume_up_rounded, size: 18),
                            onPressed: () => _speak(card.exampleBasic),
                          ),
                        ],
                      ),
                    ),
                  if (card.exampleAdvanced.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: activeColor.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '🟣 Nâng cao: "${card.exampleAdvanced}"',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.navy,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.volume_up_rounded, size: 18, color: activeColor),
                                onPressed: () => _speak(card.exampleAdvanced),
                              ),
                            ],
                          ),
                          if (card.exampleTranslation.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '👉 ${card.exampleTranslation}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                ],

                // Ghi chú sắc thái từ AI Qwen 2.5
                if (card.nuanceNote.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Text(
                      '💡 Mẹo nâng Band (Qwen 2.5): ${card.nuanceNote}',
                      style: TextStyle(fontSize: 12.5, color: Colors.brown[800], height: 1.35),
                    ),
                  ),

                const SizedBox(height: 12),

                // Hàng nút đánh giá SRS & Chuyển sang Luyện đặt câu AI
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _updateCardMastery(card, 1),
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.redAccent),
                      label: const Text('Quên', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _updateCardMastery(card, 2),
                      icon: Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.amber[800]),
                      label: Text('Nhớ sơ', style: TextStyle(fontSize: 12, color: Colors.amber[800])),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _updateCardMastery(card, 3),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Đã thuộc', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedLabCard = card;
                          _sentenceEvalResult = null;
                        });
                        _tabController.animateTo(1);
                      },
                      icon: Icon(Icons.edit_note_rounded, color: activeColor),
                      label: Text(
                        'Đặt câu với AI',
                        style: TextStyle(fontWeight: FontWeight.bold, color: activeColor, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLadderStep({
    required String label,
    required String word,
    required Color color,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => _speak(word),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                word,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: PHÒNG LUYỆN ĐẶT CÂU & NÂNG CẤP CÂU CÙNG OLLAMA QWEN 2.5
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSentenceLabTab(Color activeColor) {
    final targetCard = _selectedLabCard ?? (_allCards.isNotEmpty ? _allCards.first : null);
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, isKeyboardOpen ? 30 : 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hướng dẫn & Chọn từ mục tiêu
            Container(
              padding: const EdgeInsets.all(14),
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
                      Icon(Icons.psychology_rounded, color: activeColor, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Phòng Luyện Đặt Câu Qwen 2.5',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: activeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Level $_selectedLevel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            color: activeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Đặt câu chứa từ mục tiêu để AI Qwen 2.5 chấm điểm, sửa lỗi và nâng cấp câu lên Band 8.0+.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.35),
                  ),
                  const SizedBox(height: 12),

                  // Chọn thẻ từ mục tiêu
                  const Text(
                    'Từ vựng mục tiêu:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _allCards.map((c) {
                        final isSelected = targetCard?.id == c.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c.word),
                            selected: isSelected,
                            selectedColor: activeColor,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.navy,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedLabCard = c;
                                _sentenceEvalResult = null;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  if (targetCard != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: activeColor.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${targetCard.word} (${targetCard.ipa})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: AppColors.navy,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: activeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Band ${targetCard.bandTarget}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                    color: activeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '🇻🇳 Nghĩa: ${targetCard.vietnameseMeaning}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.primary),
                          ),
                          if (targetCard.collocations.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              '💡 Gợi ý: ${targetCard.collocations.join(" • ")}',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextField(
                    controller: _sentenceController,
                    maxLines: 3,
                    scrollPadding: const EdgeInsets.only(bottom: 140),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_isEvaluatingSentence && _sentenceController.text.trim().isNotEmpty) {
                        _evaluateUserSentence();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: targetCard != null
                          ? 'Viết câu tiếng Anh của bạn có chứa từ "${targetCard.word}"...'
                          : 'Nhập câu tiếng Anh của bạn...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.all(12),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _sentenceController,
                        builder: (context, value, _) {
                          final hasText = value.text.trim().isNotEmpty;
                          return IconButton(
                            tooltip: 'Gửi chấm câu nhanh',
                            icon: Icon(
                              Icons.send_rounded,
                              color: hasText && !_isEvaluatingSentence ? activeColor : Colors.grey[300],
                              size: 20,
                            ),
                            onPressed: (hasText && !_isEvaluatingSentence) ? _evaluateUserSentence : null,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeColor,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isEvaluatingSentence ? null : _evaluateUserSentence,
                      icon: _isEvaluatingSentence
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_fix_high_rounded, size: 20),
                      label: Text(
                        _isEvaluatingSentence
                          ? 'Qwen 2.5 đang chấm điểm & nâng cấp câu...'
                          : 'CHẤM ĐIỂM & NÂNG CẤP CÂU VỚI QWEN 2.5',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Kết quả chấm điểm từ Qwen 2.5
            if (_sentenceEvalResult != null) ...[
              const SizedBox(height: 18),
              _buildSentenceEvaluationResultCard(_sentenceEvalResult!, activeColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSentenceEvaluationResultCard(
    SentenceEvaluationModel res,
    Color activeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: activeColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: activeColor.withValues(alpha: 0.15),
                child: Text(
                  '${res.score}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: activeColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.isCorrectUsage
                          ? 'Sử dụng từ chuẩn xác! 🎉'
                          : 'Cần cải thiện cách dùng từ 💡',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      'Ước tính câu: IELTS Band ${res.estimatedBand} • Model: ${res.modelUsed}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22),

          // Nhận xét tiếng Việt
          const Text(
            '📝 Nhận xét từ Giám khảo AI Qwen 2.5:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.navy),
          ),
          const SizedBox(height: 4),
          Text(
            res.feedbackVi,
            style: const TextStyle(fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 12),

          // Câu đã sửa lỗi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '✅ Câu chuẩn hóa: "${res.correctedSentence}"',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  onPressed: () => _speak(res.correctedSentence),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Ba cấp độ nâng cấp câu (Basic -> Intermediate -> Advanced)
          const Text(
            '🚀 Nâng Cấp Câu Của Bạn Theo 3 Cấp Độ IELTS:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.navy),
          ),
          const SizedBox(height: 8),
          _buildUpgradedSentenceBox(
            levelLabel: '🟢 Mức Cơ bản (Band 5.0 - 5.5)',
            sentence: res.upgradedBasic,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 8),
          _buildUpgradedSentenceBox(
            levelLabel: '🔵 Mức Trung cấp (Band 6.5)',
            sentence: res.upgradedIntermediate,
            color: const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 8),
          _buildUpgradedSentenceBox(
            levelLabel: '🟣 Mức Nâng cao / Học thuật (Band 8.0+)',
            sentence: res.upgradedAdvanced,
            color: const Color(0xFFE11D48),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradedSentenceBox({
    required String levelLabel,
    required String sentence,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  levelLabel,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  '"$sentence"',
                  style: const TextStyle(fontSize: 13, color: AppColors.navy, height: 1.35),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.volume_up_rounded, size: 18, color: color),
            onPressed: () => _speak(sentence),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 3: THỬ THÁCH VƯỢT CẤP (GAMIFIED LEVEL-UP QUIZ)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLockedLevelQuizView(Color activeColor) {
    final meta = _levelMetaUI[_selectedLevel] ?? _levelMetaUI[1]!;
    final highestMeta = _levelMetaUI[_highestUnlockedLevel] ?? _levelMetaUI[1]!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Colors.orange,
              size: 44,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cấp độ $_selectedLevel (${meta['name']}) đang bị khóa',
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: AppColors.navy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Bạn cần hoàn thành bài kiểm tra và vượt qua Cấp độ $_highestUnlockedLevel (${highestMeta['name']}) để mở khóa bài thi cấp độ này.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: highestMeta['color'] as Color? ?? AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _loadCardsForLevel(_highestUnlockedLevel),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(
              'Chuyển về Cấp độ $_highestUnlockedLevel (${highestMeta['name']})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizTab(Color activeColor) {
    if (_selectedLevel > _highestUnlockedLevel) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        child: _buildLockedLevelQuizView(activeColor),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Khung điều khiển tạo đề Quiz
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: activeColor, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Thử Thách Vượt Cấp Độ $_selectedLevel${_selectedTopic != 'Tất cả' ? ' • $_selectedTopic' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Hoàn thành bài kiểm tra để nhận tối đa 3⭐ và mở khóa Cấp độ tiếp theo trong lộ trình từ Cơ bản đến Bậc thầy.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: activeColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 16, color: activeColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cấu hình thi: ${_systemConfig?.quizQuestionCount ?? 5} câu • Đỗ khi đúng ≥ ${_currentQuiz?.passScoreRequired ?? (_systemConfig?.minPassRequired ?? 3)} câu (${_systemConfig?.passPercentage ?? 60}%) • Model: ${_systemConfig?.activeModel ?? _ollamaModelName}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: activeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: activeColor,
                  title: const Text(
                    'Sử dụng Ollama Qwen 2.5 tạo đề ngữ cảnh mới',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Tắt tùy chọn này nếu muốn tạo đề tức thì từ bộ thẻ từ trong máy',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                  ),
                  value: _useAiQwenQuiz,
                  onChanged: (val) => setState(() => _useAiQwenQuiz = val),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeColor,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: _isGeneratingQuiz ? null : _startLevelQuiz,
                    icon: _isGeneratingQuiz
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _isGeneratingQuiz
                          ? 'Đang khởi tạo câu hỏi kiểm tra...'
                          : (_currentQuiz == null ? 'BẮT ĐẦU BÀI KIỂM TRA' : 'TẠO ĐỀ KIỂM TRA MỚI'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_currentQuiz != null) ...[
            const SizedBox(height: 16),
            ..._currentQuiz!.questions.map((q) => _buildQuizQuestionCard(q, activeColor)),
            const SizedBox(height: 12),
            if (!_isQuizSubmitted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _quizUserAnswers.length < _currentQuiz!.questions.length
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Vui lòng chọn đáp án cho tất cả các câu hỏi trước khi nộp bài!'),
                            ),
                          );
                        }
                      : _submitQuiz,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    'NỘP BÀI KIỂM TRA (${_quizUserAnswers.length}/${_currentQuiz!.questions.length} CÂU)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Text(
                  'Kết quả đã nộp: Đúng $_quizCorrectCount / ${_currentQuiz!.questions.length} câu. Xem giải thích chi tiết ở từng câu bên trên!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizQuestionCard(VocabQuizQuestionModel q, Color activeColor) {
    final selectedAns = _quizUserAnswers[q.id];

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
          Text(
            'Câu ${q.id}: ${q.prompt}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.5,
              color: AppColors.navy,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          ...q.options.map((opt) {
            final isSelected = selectedAns == opt;
            final isCorrect = opt.trim() == q.correctAnswer.trim();

            Color tileColor = Colors.grey[50]!;
            Color borderColor = Colors.grey[300]!;
            if (_isQuizSubmitted) {
              if (isCorrect) {
                tileColor = Colors.green[50]!;
                borderColor = const Color(0xFF10B981);
              } else if (isSelected && !isCorrect) {
                tileColor = Colors.red[50]!;
                borderColor = Colors.redAccent;
              }
            } else if (isSelected) {
              tileColor = activeColor.withValues(alpha: 0.1);
              borderColor = activeColor;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isQuizSubmitted
                    ? null
                    : () {
                        setState(() => _quizUserAnswers[q.id] = opt);
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: isSelected ? 1.6 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isQuizSubmitted
                            ? (isCorrect
                                ? Icons.check_circle_rounded
                                : (isSelected ? Icons.cancel_rounded : Icons.radio_button_unchecked))
                            : (isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded),
                        size: 20,
                        color: _isQuizSubmitted
                            ? (isCorrect
                                ? const Color(0xFF10B981)
                                : (isSelected ? Colors.redAccent : Colors.grey))
                            : (isSelected ? activeColor : Colors.grey),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (_isQuizSubmitted && q.explanationVi.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '💡 Giải thích: ${q.explanationVi}',
                style: TextStyle(fontSize: 12.5, color: Colors.brown[800]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
