import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vocabulary_item_model.dart';
import '../../auth/providers/auth_provider.dart';
import 'camera_scan_screen.dart';

/// Màn hình Sổ tay từ vựng nội bộ (Local Vocabulary Notebook) của Học viên.
/// Hỗ trợ tìm kiếm, lọc theo band điểm, nghe phát âm TTS và xem lại chi tiết từ đã lưu từ camera.
class VocabularyNotebookScreen extends StatefulWidget {
  const VocabularyNotebookScreen({super.key});

  @override
  State<VocabularyNotebookScreen> createState() =>
      _VocabularyNotebookScreenState();
}

class _VocabularyNotebookScreenState extends State<VocabularyNotebookScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _searchController = TextEditingController();

  List<VocabularyItemModel> _allWords = [];
  List<VocabularyItemModel> _filteredWords = [];
  bool _isLoading = true;
  String _selectedBand = 'Tất cả';

  // Lưu trữ id của các thẻ đang mở rộng xem chi tiết
  final Set<int> _expandedCardIds = {};

  final List<String> _bandOptions = ['Tất cả', 'Band 7.0', 'Band 7.5', 'Band 8.0+'];

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadWords();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
  }

  Future<void> _loadWords() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null || currentUser.id == null) return;

    final words =
        await DatabaseHelper.instance.getNotebookItemsByUser(currentUser.id!);

    if (mounted) {
      setState(() {
        _allWords = words;
        _applyFilter();
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    _applyFilter();
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredWords = _allWords.where((item) {
        // Lọc theo từ khóa tìm kiếm (từ tiếng Anh hoặc nghĩa tiếng Việt)
        final matchesQuery = query.isEmpty ||
            item.word.toLowerCase().contains(query) ||
            (item.translation.toLowerCase().contains(query)) ||
            item.label.toLowerCase().contains(query);

        // Lọc theo Band score
        bool matchesBand = true;
        if (_selectedBand == 'Band 7.0') {
          matchesBand = item.bandScore == '7.0';
        } else if (_selectedBand == 'Band 7.5') {
          matchesBand = item.bandScore == '7.5';
        } else if (_selectedBand == 'Band 8.0+') {
          final bandNum = double.tryParse(item.bandScore) ?? 0.0;
          matchesBand = bandNum >= 8.0;
        }

        return matchesQuery && matchesBand;
      }).toList();
    });
  }

  Future<void> _deleteWord(VocabularyItemModel item) async {
    if (item.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa từ "${item.word}" khỏi sổ tay?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('HỦY', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('XÓA'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteNotebookItem(item.id!);
      await _loadWords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa "${item.word}" khỏi Sổ tay từ vựng'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Sổ tay Từ vựng IELTS',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadWords,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Khung tìm kiếm & Thống kê ──
          _buildSearchAndFilterHeader(),

          // ── Danh sách từ vựng ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _filteredWords.isEmpty
                    ? _buildEmptyState()
                    : _buildWordList(),
          ),
        ],
      ),
    );
  }

  /// Khung tìm kiếm và bộ lọc Band điểm
  Widget _buildSearchAndFilterHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search box
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm từ vựng hoặc nghĩa tiếng Việt...',
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Filter chips theo Band + Thống kê số lượng
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _bandOptions.map((band) {
                      final isSelected = _selectedBand == band;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(
                            band,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          backgroundColor: Colors.grey[100],
                          selectedColor: AppColors.primary,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : Colors.grey[300]!,
                            ),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedBand = band;
                              _applyFilter();
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Badge đếm số từ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_filteredWords.length}/${_allWords.length} từ',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Danh sách từ vựng dạng thẻ tương tác
  Widget _buildWordList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _filteredWords.length,
      itemBuilder: (context, index) {
        final item = _filteredWords[index];
        final isExpanded = _expandedCardIds.contains(item.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCardIds.remove(item.id);
                } else {
                  if (item.id != null) _expandedCardIds.add(item.id!);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hàng trên cùng: Band Badge + Nhãn vật thể + Nút Phát âm & Xóa
                  Row(
                    children: [
                      // Band Score Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Band ${item.bandScore}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Nhãn đối tượng gốc (COCO Label)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Nút phát âm TTS
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.volume_up_rounded,
                            color: AppColors.primary, size: 24),
                        onPressed: () {
                          final wordToSpeak = item.word.contains('/')
                              ? item.word.split('/').first.trim()
                              : item.word;
                          _flutterTts.speak(wordToSpeak);
                        },
                        tooltip: 'Phát âm',
                      ),
                      const SizedBox(width: 12),
                      // Nút xóa từ
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent, size: 22),
                        onPressed: () => _deleteWord(item),
                        tooltip: 'Xóa khỏi sổ tay',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Từ vựng học thuật (chiếm trọn chiều rộng thẻ, không bị chèn ép)
                  Text(
                    item.word,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Phiên âm IPA
                  Text(
                    item.ipa,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),

                  // Dòng nghĩa tiếng Việt nổi bật
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🇻🇳 ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            item.translation,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD61C2C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Nút mở rộng/thu gọn chi tiết học thuật
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        isExpanded ? 'Thu gọn' : 'Xem chi tiết (Collocations, Speaking)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey[600],
                        size: 18,
                      ),
                    ],
                  ),

                  // Nội dung mở rộng chi tiết
                  if (isExpanded) ...[
                    const Divider(height: 20),

                    // Collocations
                    if (item.collocations != null && item.collocations!.isNotEmpty) ...[
                      const Text(
                        '📝  Collocations:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          item.collocations!,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Idioms
                    if (item.idioms != null && item.idioms!.isNotEmpty) ...[
                      const Text(
                        '💡  Topic Idiom:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          item.idioms!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF78350F),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Speaking Example
                    if (item.example != null && item.example!.isNotEmpty) ...[
                      const Text(
                        '💬  IELTS Speaking Sample:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '"${item.example!}"',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                                color: AppColors.navy,
                              ),
                            ),
                            if (item.exampleTranslation != null &&
                                item.exampleTranslation!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                '👉 ${item.exampleTranslation!}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey[800],
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Trạng thái khi chưa lưu từ nào
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sổ tay của bạn đang trống!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hãy mở Camera Quét AI để nhận diện các đồ vật xung quanh bạn và lưu lại các từ vựng IELTS Band 7.0 - 8.5.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScanScreen()),
                ).then((_) => _loadWords());
              },
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('BẮT ĐẦU QUÉT AI NGAY'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
