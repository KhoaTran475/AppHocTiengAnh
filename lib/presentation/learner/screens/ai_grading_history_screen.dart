import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/api_service.dart';
import '../../../data/models/ai_grading_history_model.dart';

class AiGradingHistoryScreen extends StatefulWidget {
  const AiGradingHistoryScreen({super.key});

  @override
  State<AiGradingHistoryScreen> createState() => _AiGradingHistoryScreenState();
}

class _AiGradingHistoryScreenState extends State<AiGradingHistoryScreen> {
  final ApiService _apiService = ApiService.instance;

  String _selectedFeature = 'all';
  bool _isLoading = true;
  String? _errorMessage;
  List<AiGradingHistoryItem> _items = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _featureTabs = [
    {'id': 'all', 'label': 'Tất cả'},
    {'id': 'writing_grading', 'label': '✍️ Writing'},
    {'id': 'vocab_sentence', 'label': '🧠 Từ vựng'},
    {'id': 'reading_explain', 'label': '📖 Reading'},
    {'id': 'listening_explain', 'label': '🎧 Listening'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchHistory(page: 1);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _currentPage < _totalPages) {
        _loadMore();
      }
    }
  }

  Future<void> _fetchHistory({int page = 1}) async {
    setState(() {
      _isLoading = page == 1;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.getMyAiGradingHistory(
        feature: _selectedFeature,
        page: page,
        pageSize: 15,
      );
      setState(() {
        _items = res.items;
        _currentPage = res.page;
        _totalPages = res.totalPages;
        _totalCount = res.total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final res = await _apiService.getMyAiGradingHistory(
        feature: _selectedFeature,
        page: nextPage,
        pageSize: 15,
      );
      setState(() {
        _items.addAll(res.items);
        _currentPage = res.page;
        _totalPages = res.totalPages;
        _totalCount = res.total;
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lịch sử chấm AI Qwen',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.navy,
              ),
            ),
            Text(
              '$_totalCount lượt đánh giá & giải thích',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Làm mới',
            onPressed: () => _fetchHistory(page: 1),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _featureTabs.map((tab) {
            final isSelected = _selectedFeature == tab['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tab['label']!),
                selected: isSelected,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
                selectedColor: AppColors.primary,
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (selected) {
                  if (selected && _selectedFeature != tab['id']) {
                    setState(() {
                      _selectedFeature = tab['id']!;
                    });
                    _fetchHistory(page: 1);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.navy, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _fetchHistory(page: 1),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_edu_rounded, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 14),
              const Text(
                'Chưa có lịch sử chấm AI',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Khi bạn nộp bài viết IELTS, luyện đặt câu từ vựng hoặc xem giải thích chi tiết, kết quả chấm của AI Qwen 2.5 sẽ hiển thị tại đây.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _fetchHistory(page: 1),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                ),
              ),
            );
          }
          final item = _items[index];
          return _buildHistoryCard(item);
        },
      ),
    );
  }

  String _formatDateTime(DateTime dt, {bool includeSeconds = false}) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    if (includeSeconds) {
      final s = local.second.toString().padLeft(2, '0');
      return '$d/$m/$y $h:$min:$s';
    }
    return '$d/$m/$y $h:$min';
  }

  Widget _buildHistoryCard(AiGradingHistoryItem item) {
    Color featureColor;
    IconData featureIcon;
    String featureName;

    switch (item.feature) {
      case 'writing_grading':
        featureColor = const Color(0xFF2563EB);
        featureIcon = Icons.edit_note_rounded;
        featureName = 'IELTS Writing';
        break;
      case 'vocab_sentence':
        featureColor = const Color(0xFF7C3AED);
        featureIcon = Icons.psychology_rounded;
        featureName = 'Đặt câu từ vựng';
        break;
      case 'reading_explain':
        featureColor = const Color(0xFF059669);
        featureIcon = Icons.menu_book_rounded;
        featureName = 'Reading Explain';
        break;
      case 'listening_explain':
        featureColor = const Color(0xFFD97706);
        featureIcon = Icons.headphones_rounded;
        featureName = 'Listening Explain';
        break;
      default:
        featureColor = Colors.grey;
        featureIcon = Icons.auto_awesome_rounded;
        featureName = item.skillType.toUpperCase();
    }

    final dateStr = _formatDateTime(item.createdAt);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetailBottomSheet(item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng trên: Tag phân hệ & Ngày giờ
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: featureColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(featureIcon, size: 14, color: featureColor),
                        const SizedBox(width: 4),
                        Text(
                          featureName,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: featureColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Tiêu đề bài thi hoặc Từ vựng mục tiêu
              Text(
                item.lessonTitle ?? (item.vocabWord != null ? 'Từ vựng: "${item.vocabWord}" (Level ${item.vocabLevel ?? 1})' : 'Bài học'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Trích dẫn bài làm / câu đặt
              if (item.inputText != null && item.inputText!.isNotEmpty)
                Text(
                  '"${item.inputText!.replaceAll('\n', ' ')}"',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 12),

              // Hàng dưới: Kết quả điểm & Nguồn AI
              Row(
                children: [
                  if (item.feature == 'writing_grading')
                    _buildResultBadge('Band ${item.bandScore ?? "--"}', const Color(0xFF2563EB))
                  else if (item.feature == 'vocab_sentence')
                    _buildResultBadge('${item.scoreNumeric?.toInt() ?? "--"}/100', const Color(0xFF7C3AED))
                  else
                    _buildResultBadge(
                      item.isCorrect == true ? 'Đúng' : 'Chưa đúng',
                      item.isCorrect == true ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                    ),
                  const SizedBox(width: 8),

                  // Badge model / fallback
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.status == 'success'
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF9C3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.fromCache
                          ? '⚡ Cache'
                          : (item.status == 'success' ? '🤖 Qwen 2.5' : '🛡️ Fallback'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.status == 'success'
                            ? const Color(0xFF15803D)
                            : const Color(0xFFA16207),
                      ),
                    ),
                  ),

                  const Spacer(),
                  const Text(
                    'Xem chi tiết',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM SHEET CHI TIẾT ĐÁNH GIÁ AI
  // ─────────────────────────────────────────────────────────────

  void _showDetailBottomSheet(AiGradingHistoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Chi Tiết Nhận Xét AI Qwen',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Nội dung chi tiết
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailMetaBox(item),
                      const SizedBox(height: 18),
                      _buildDetailInputSection(item),
                      const SizedBox(height: 18),
                      if (item.feature == 'writing_grading')
                        _buildWritingDetail(item)
                      else if (item.feature == 'vocab_sentence')
                        _buildVocabDetail(item)
                      else
                        _buildExplainDetail(item),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailMetaBox(AiGradingHistoryItem item) {
    final dStr = _formatDateTime(item.createdAt, includeSeconds: true);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildMetaRow('Thời gian:', dStr),
          const SizedBox(height: 6),
          _buildMetaRow('Mô hình AI:', item.modelName ?? 'qwen2.5:7b'),
          const SizedBox(height: 6),
          _buildMetaRow('Thời gian phản hồi:', item.fromCache ? '0 ms (Cache)' : '${item.latencyMs} ms'),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildDetailInputSection(AiGradingHistoryItem item) {
    String title = 'Bài làm của bạn';
    if (item.feature == 'writing_grading') {
      title = 'Bài viết đã nộp (${item.inputWordCount ?? 0} từ):';
    } else if (item.feature == 'vocab_sentence') {
      title = 'Câu bạn đã đặt với từ "${item.vocabWord ?? ""}":';
    } else {
      title = 'Lựa chọn của bạn:';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            item.inputText ?? '(Không có dữ liệu)',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B), height: 1.5),
          ),
        ),
      ],
    );
  }

  // Chi tiết IELTS Writing
  Widget _buildWritingDetail(AiGradingHistoryItem item) {
    final res = item.resultJson ?? {};
    final criteria = [
      {'name': 'Task Achievement', 'band': res['task_response_band'], 'comment': res['task_response_comment']},
      {'name': 'Coherence & Cohesion', 'band': res['coherence_band'], 'comment': res['coherence_comment']},
      {'name': 'Lexical Resource', 'band': res['lexical_band'], 'comment': res['lexical_comment']},
      {'name': 'Grammatical Accuracy', 'band': res['grammar_band'], 'comment': res['grammar_comment']},
    ];

    final errors = res['errors'] as List<dynamic>? ?? [];
    final strengths = res['strengths'] as List<dynamic>? ?? [];
    final improvements = res['improvements'] as List<dynamic>? ?? [];
    final improvedPara = res['improved_paragraph']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 Tiêu chí
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '4 Tiêu Chí Chấm IELTS',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Band Tổng: ${item.bandScore ?? "--"}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...criteria.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(c['name'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Band ${c['band'] ?? "--"}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c['comment']?.toString() ?? 'Không có nhận xét',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                  ),
                ],
              ),
            )),

        // Lỗi sai phát hiện
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Lỗi Sai Cần Chú Ý (${errors.length})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent),
          ),
          const SizedBox(height: 8),
          ...errors.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(left: BorderSide(color: Color(0xFFF43F5E), width: 3.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('❌ Trích câu: "${e['quote'] ?? ""}"', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFBE123C))),
                    const SizedBox(height: 3),
                    Text('✅ Cách sửa: ${e['fix'] ?? ""}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                    if (e['explain_vi'] != null)
                      Text('💡 ${e['explain_vi']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              )),
        ],

        // Điểm mạnh
        if (strengths.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Điểm Mạnh Đã Đạt Được',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
          ),
          const SizedBox(height: 8),
          ...strengths.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🌟 ', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Text(
                        s.toString(),
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF065F46)),
                      ),
                    ),
                  ],
                ),
              )),
        ],

        // Điểm cần cải thiện
        if (improvements.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Điểm Cần Khắc Phục / Nâng Cao',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
          ),
          const SizedBox(height: 8),
          ...improvements.map((imp) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📌 ', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Text(
                        imp.toString(),
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              )),
        ],

        // Đoạn văn Band 8.0+
        if (improvedPara != null && improvedPara.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Đoạn Văn Mẫu Band 8.0+',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Text(
              improvedPara,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4C1D95), height: 1.5),
            ),
          ),
        ],
      ],
    );
  }

  // Chi tiết Đặt câu Từ vựng
  Widget _buildVocabDetail(AiGradingHistoryItem item) {
    final res = item.resultJson ?? {};
    final corrected = res['corrected_sentence']?.toString() ?? item.inputText;
    final feedback = res['feedback_vi']?.toString() ?? '';
    final upgradedBasic = res['upgraded_basic']?.toString();
    final upgradedInter = res['upgraded_intermediate']?.toString();
    final upgradedAdv = res['upgraded_advanced']?.toString();
    final colls = (res['key_collocations_used'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Câu hoàn thiện
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                  SizedBox(width: 6),
                  Text('Câu sửa hoàn thiện:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                ],
              ),
              const SizedBox(height: 6),
              Text('"$corrected"', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF14532D))),
              if (feedback.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('💡 Nhận xét: $feedback', style: const TextStyle(fontSize: 12.5, color: Color(0xFF166534), height: 1.4)),
              ],
            ],
          ),
        ),

        // Thang nâng cấp 3 bậc
        const SizedBox(height: 18),
        const Text(
          'Thang Nâng Cấp Câu 3 Bậc',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
        const SizedBox(height: 8),
        _buildLadderStep('Cơ bản (Band 5.0 - 5.5)', upgradedBasic ?? '', const Color(0xFF64748B), const Color(0xFFF8FAFC)),
        _buildLadderStep('Trung cấp (Band 6.5)', upgradedInter ?? '', const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
        _buildLadderStep('Nâng cao (Band 8.0+)', upgradedAdv ?? '', const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),

        if (colls.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Collocations Gợi Ý:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: colls
                .map((c) => Chip(
                      label: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                      backgroundColor: const Color(0xFFF1F5F9),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildLadderStep(String title, String text, Color titleColor, Color bgColor) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: titleColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.4)),
        ],
      ),
    );
  }

  // Chi tiết AI Giải thích Reading/Listening
  Widget _buildExplainDetail(AiGradingHistoryItem item) {
    final res = item.resultJson ?? {};
    final whyCorrect = res['why_correct']?.toString() ?? '';
    final whyTrap = res['why_trap']?.toString() ?? '';
    final strategy = res['strategy_tips']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (whyCorrect.isNotEmpty)
          _buildInfoBox('Dẫn chứng câu gốc vì sao đúng:', whyCorrect, const Color(0xFF16A34A), const Color(0xFFF0FDF4)),
        if (whyTrap.isNotEmpty)
          _buildInfoBox('Phân tích bẫy đề thi:', whyTrap, const Color(0xFFD97706), const Color(0xFFFFFBEB)),
        if (strategy.isNotEmpty)
          _buildInfoBox('Mẹo chiến thuật:', strategy, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
      ],
    );
  }

  Widget _buildInfoBox(String title, String content, Color color, Color bgColor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 6),
          Text(content, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.45)),
        ],
      ),
    );
  }
}

