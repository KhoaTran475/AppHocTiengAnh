import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/api_service.dart';

/// Modal Bottom Sheet hiển thị Giải thích chi tiết, Phân tích Bẫy đề & Từ vựng then chốt
/// được sinh thông minh bởi mô hình AI Qwen 2.5 7B Local (có lưu cache trên Supabase PostgreSQL).
class AiExplanationBottomSheet extends StatefulWidget {
  final String lessonId;
  final dynamic questionId;
  final String userChoice;
  final String questionText;
  final String correctAnswer;
  final String? initialExplanation;

  const AiExplanationBottomSheet({
    super.key,
    required this.lessonId,
    required this.questionId,
    required this.userChoice,
    required this.questionText,
    required this.correctAnswer,
    this.initialExplanation,
  });

  static Future<void> show(
    BuildContext context, {
    required String lessonId,
    required dynamic questionId,
    required String userChoice,
    required String questionText,
    required String correctAnswer,
    String? initialExplanation,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiExplanationBottomSheet(
        lessonId: lessonId,
        questionId: questionId,
        userChoice: userChoice,
        questionText: questionText,
        correctAnswer: correctAnswer,
        initialExplanation: initialExplanation,
      ),
    );
  }

  @override
  State<AiExplanationBottomSheet> createState() => _AiExplanationBottomSheetState();
}

class _AiExplanationBottomSheetState extends State<AiExplanationBottomSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _explanationData;

  int _loadingSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchExplanation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _loadingSeconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _loadingSeconds++;
        });
      }
    });
  }

  Future<void> _fetchExplanation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _startTimer();

    try {
      final res = await ApiService.instance.explainAnswer(
        lessonId: widget.lessonId,
        questionId: widget.questionId,
        userChoice: widget.userChoice.isNotEmpty ? widget.userChoice : widget.correctAnswer,
      );
      if (mounted) {
        setState(() {
          _explanationData = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    } finally {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCorrect = widget.userChoice.trim().toLowerCase() == widget.correctAnswer.trim().toLowerCase();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Tiêu đề Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.psychology_rounded, color: Colors.indigo, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Phân Tích & Giải Mã Bẫy',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Qwen 2.5 7B Local',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              if (_explanationData != null && _explanationData!['from_cache'] == true) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '⚡ Supabase Cache',
                                    style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.black54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Nội dung chính
              Expanded(
                child: _isLoading
                    ? _buildLoadingView()
                    : _errorMessage != null
                        ? _buildErrorView()
                        : _buildContentView(scrollController, isCorrect),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Qwen 2.5 đang giải mã câu hỏi...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            Text(
              'Đang đối chiếu dẫn chứng, phân tích bẫy paraphrase và trích xuất từ vựng (${_loadingSeconds}s)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            if (_loadingSeconds >= 15) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed_rounded, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Mô hình 7B đang suy luận cục bộ trên RTX 5050 GPU...',
                        style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Không thể kết nối tới mô hình AI',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Lỗi không xác định hoặc hết thời gian chờ kết nối proxy.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchExplanation,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (widget.initialExplanation != null && widget.initialExplanation!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gợi ý chuẩn có sẵn:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(widget.initialExplanation!, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContentView(ScrollController scrollController, bool isCorrect) {
    final data = _explanationData ?? {};
    final whyCorrect = data['why_correct'] as String? ?? '';
    final whyTrap = data['why_trap'] as String? ?? '';
    final strategyTips = data['strategy_tips'] as String? ?? '';
    final rawVocab = data['key_vocabulary'] as List<dynamic>? ?? [];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Câu hỏi và Đáp án bạn chọn
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.questionText,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: isCorrect ? Colors.green : Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Lựa chọn của bạn: ${widget.userChoice.isNotEmpty ? widget.userChoice : "(Bỏ trống)"}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isCorrect ? Colors.green[800] : Colors.redAccent[700],
                      ),
                    ),
                  ),
                ],
              ),
              if (!isCorrect) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Đáp án chính xác: ${widget.correctAnswer}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green[800]),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 1. Phân tích bẫy (Nếu sai) hoặc Khẳng định độ chính xác (Nếu đúng)
        if (whyTrap.isNotEmpty) ...[
          _buildAnalysisCard(
            title: isCorrect ? 'Phân tích phương án & Bẫy cần tránh' : 'Tại sao lựa chọn của bạn chưa đúng (Phân tích bẫy)',
            content: whyTrap,
            icon: isCorrect ? Icons.verified_rounded : Icons.warning_amber_rounded,
            headerColor: isCorrect ? Colors.teal : Colors.deepOrange,
            bgColor: isCorrect ? Colors.teal.withValues(alpha: 0.05) : Colors.deepOrange.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 14),
        ],

        // 2. Dẫn chứng & Tại sao đáp án đúng
        if (whyCorrect.isNotEmpty) ...[
          _buildAnalysisCard(
            title: 'Dẫn chứng câu gốc & Lý do đáp án đúng',
            content: whyCorrect,
            icon: Icons.check_circle_rounded,
            headerColor: Colors.green[800]!,
            bgColor: Colors.green.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 14),
        ],

        // 3. Mẹo chiến thuật làm bài IELTS
        if (strategyTips.isNotEmpty) ...[
          _buildAnalysisCard(
            title: 'Chiến thuật làm bài (Strategy Tips)',
            content: strategyTips,
            icon: Icons.tips_and_updates_rounded,
            headerColor: Colors.indigo,
            bgColor: Colors.indigo.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 14),
        ],

        // 4. Từ vựng then chốt & Paraphrase
        if (rawVocab.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_stories_rounded, color: Colors.purple, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Từ vựng then chốt & Paraphrase đáng học',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...rawVocab.map((v) {
                  final word = v['word'] ?? '';
                  final meaning = v['meaning'] ?? '';
                  final paraphrase = v['paraphrase_with'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purple.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          flex: 9,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              word,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 11,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meaning,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                  height: 1.35,
                                ),
                              ),
                              if (paraphrase.toString().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  '≈ $paraphrase',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[700],
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAnalysisCard({
    required String title,
    required String content,
    required IconData icon,
    required Color headerColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: headerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: headerColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: headerColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

