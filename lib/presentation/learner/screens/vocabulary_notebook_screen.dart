import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/note_model.dart';
import '../../../data/repositories/note_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/note_export_service.dart';
import 'camera_scan_screen.dart';
import 'vocabulary_learning_screen.dart';
import '../widgets/note_detail_bottom_sheet.dart';
import '../widgets/create_note_bottom_sheet.dart';

/// Màn hình Sổ tay Ghi chú Đa ngữ cảnh IELTS (Multi-context IELTS Notebook).
/// Hỗ trợ 4 loại ghi chú: Từ vựng (vocab), Câu & Ngữ cảnh (sentence), 
/// Nhận xét AI (feedback), và Ghi chú tự do (free).
/// Hỗ trợ lọc theo tab, nguồn gốc kỹ năng, tìm kiếm nhanh, ghim lên đầu và nghe TTS.
class VocabularyNotebookScreen extends StatefulWidget {
  const VocabularyNotebookScreen({super.key});

  @override
  State<VocabularyNotebookScreen> createState() =>
      _VocabularyNotebookScreenState();
}

class _VocabularyNotebookScreenState extends State<VocabularyNotebookScreen>
    with SingleTickerProviderStateMixin {
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _searchController = TextEditingController();

  List<NoteModel> _allNotes = [];
  List<NoteModel> _filteredNotes = [];
  bool _isLoading = true;

  // Tab & Filters
  late TabController _tabController;
  final List<String> _tabTypes = [
    'all',
    NoteType.vocab,
    NoteType.sentence,
    NoteType.feedback,
    NoteType.free,
  ];

  String _selectedSource = 'all';
  final Set<String> _expandedVocabIds = {};
  StreamSubscription<void>? _notesSubscription;

  final List<Map<String, String>> _sourceFilterOptions = [
    {'key': 'all', 'label': 'Tất cả nguồn'},
    {'key': NoteSource.reading, 'label': 'Reading'},
    {'key': NoteSource.listening, 'label': 'Listening'},
    {'key': NoteSource.writing, 'label': 'Writing'},
    {'key': NoteSource.speaking, 'label': 'Speaking'},
    {'key': NoteSource.camera, 'label': 'Camera AI'},
    {'key': NoteSource.vocabLearning, 'label': 'Học từ vựng'},
    {'key': NoteSource.manual, 'label': 'Thủ công'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTypes.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initTts();
    _loadNotes();
    _searchController.addListener(_applyFilter);

    // Lắng nghe thay đổi tức thì từ NoteRepository khi ghi chú được thêm/sửa/xóa ở bất kỳ màn hình nào
    _notesSubscription = NoteRepository.instance.onNotesChanged.listen((_) {
      if (mounted) {
        _loadNotes(showLoading: false);
      }
    });
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
  }

  @override
  void dispose() {
    _notesSubscription?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _flutterTts.stop();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _applyFilter();
  }

  Future<void> _loadNotes({bool showLoading = true}) async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final userId = currentUser.id ?? 1;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // 0. Tự động kiểm tra và sửa nguồn các ghi chú Listening nếu bị gắn nhầm Reading
      await NoteRepository.instance.fixListeningNotesSource();

      // 1. Tải tức thì từ SQLite nội bộ (Offline-first)
      final localNotes = await NoteRepository.instance.getNotes(userId);

      if (mounted) {
        setState(() {
          _allNotes = localNotes;
          _isLoading = false;
        });
        _applyFilter();
      }

      // 2. Tự động đồng bộ Supabase Cloud ngầm
      NoteRepository.instance
          .syncWithCloud(userId, username: currentUser.username)
          .then((_) async {
        if (!mounted) return;
        final updatedNotes = await NoteRepository.instance.getNotes(userId);
        if (mounted) {
          setState(() {
            _allNotes = updatedNotes;
          });
          _applyFilter();
        }
      }).catchError((e) {
        log('Lỗi chạy sync ngầm sổ tay: $e');
      });
    } catch (e) {
      log('Lỗi tải danh sách ghi chú: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    final currentTabType = _tabTypes[_tabController.index];

    setState(() {
      _filteredNotes = _allNotes.where((note) {
        // 1. Lọc theo Tab loại ghi chú
        if (currentTabType != 'all' && note.type != currentTabType) {
          return false;
        }

        // 2. Lọc theo nguồn gốc (source)
        if (_selectedSource != 'all' && note.source != _selectedSource) {
          return false;
        }

        // 3. Lọc theo từ khóa tìm kiếm
        if (query.isNotEmpty) {
          final matchesTitle = note.title.toLowerCase().contains(query);
          final matchesContent = note.content.toLowerCase().contains(query);
          final matchesUserNote =
              note.userNote?.toLowerCase().contains(query) ?? false;
          final matchesTags =
              note.tags.any((t) => t.toLowerCase().contains(query));
          final matchesVocabLabel =
              note.vocabData?.label.toLowerCase().contains(query) ?? false;

          if (!matchesTitle &&
              !matchesContent &&
              !matchesUserNote &&
              !matchesTags &&
              !matchesVocabLabel) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  Future<void> _deleteNote(NoteModel note) async {
    if (note.id == null) return;
    final currentUser = context.read<AuthProvider>().currentUser;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa "${note.title}" khỏi Sổ tay?'),
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

    if (confirmed == true && mounted) {
      await NoteRepository.instance.deleteNote(
        note.id!,
        softDelete: true,
        username: currentUser?.username,
      );
      await _loadNotes(showLoading: false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa "${note.title}" khỏi sổ tay.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _togglePin(NoteModel note) async {
    if (note.id == null) return;
    final currentUser = context.read<AuthProvider>().currentUser;
    final newPinned = !note.isPinned;

    await NoteRepository.instance.togglePin(
      note.id!,
      newPinned,
      username: currentUser?.username,
    );
    await _loadNotes(showLoading: false);
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case NoteType.vocab:
        return const Color(0xFF10B981);
      case NoteType.sentence:
        return const Color(0xFF3B82F6);
      case NoteType.feedback:
        return const Color(0xFF8B5CF6);
      case NoteType.free:
      default:
        return const Color(0xFFF59E0B);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case NoteType.vocab:
        return Icons.translate_rounded;
      case NoteType.sentence:
        return Icons.format_quote_rounded;
      case NoteType.feedback:
        return Icons.auto_awesome_rounded;
      case NoteType.free:
      default:
        return Icons.edit_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final userId = currentUser?.id ?? 1;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Thêm Ghi Chú', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: () async {
          final res = await CreateNoteBottomSheet.show(
            context,
            userId: userId,
            username: currentUser?.username,
            initialType: _tabTypes[_tabController.index] != 'all'
                ? _tabTypes[_tabController.index]
                : NoteType.free,
          );
          if (res != null) {
            _loadNotes(showLoading: false);
          }
        },
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _loadNotes(showLoading: false),
        child: CustomScrollView(
          slivers: [
            // ── 1. Collapsible AppBar + Compact TabBar ──
            SliverAppBar(
              title: const Text(
                'Sổ tay Ghi chú IELTS',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 18),
              ),
              backgroundColor: Colors.white,
              elevation: 0.5,
              floating: true,
              snap: true,
              pinned: true,
              actions: [
                IconButton(
                  tooltip: 'Xuất Sổ tay (TXT / CSV)',
                  icon: const Icon(Icons.file_download_outlined, color: AppColors.primary),
                  onPressed: () {
                    final notesToExport = _filteredNotes.isNotEmpty ? _filteredNotes : _allNotes;
                    if (notesToExport.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sổ tay đang trống, chưa có ghi chú để xuất.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    NoteExportService.showExportBottomSheet(context, notesToExport);
                  },
                ),
                IconButton(
                  tooltip: 'Làm mới & Đồng bộ',
                  icon: const Icon(Icons.sync_rounded, color: AppColors.primary),
                  onPressed: () => _loadNotes(showLoading: true),
                ),
                IconButton(
                  tooltip: 'Học Từ Vựng 5 Cấp Độ',
                  icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VocabularyLearningScreen()),
                    ).then((_) => _loadNotes(showLoading: false));
                  },
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Container(
                  height: 40,
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 2.5,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    tabs: const [
                      Tab(text: 'Tất cả'),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.translate_rounded, size: 14),
                            SizedBox(width: 4),
                            Text('Từ vựng'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.format_quote_rounded, size: 14),
                            SizedBox(width: 4),
                            Text('Câu mẫu'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 14),
                            SizedBox(width: 4),
                            Text('Nhận xét AI'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note_rounded, size: 14),
                            SizedBox(width: 4),
                            Text('Tự do'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 2. Cuộn được (Scrollable): Khung Tìm Kiếm & Lọc Nguồn ──
            SliverToBoxAdapter(
              child: _buildSearchAndFilterHeader(),
            ),

            // ── 3. Danh Sách Ghi Chú / Trạng Thái Trống ──
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_filteredNotes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildCardForNote(_filteredNotes[index], currentUser?.username);
                    },
                    childCount: _filteredNotes.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Khung tìm kiếm, filter theo kỹ năng và thống kê số lượng (Compact UI)
  Widget _buildSearchAndFilterHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search box (Compact)
          SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm từ vựng, câu, bài học, thẻ tag...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Horizontal Source Filters + Counter Badge
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _sourceFilterOptions.map((opt) {
                      final isSelected = _selectedSource == opt['key'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          selected: isSelected,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          label: Text(
                            opt['label']!,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          backgroundColor: Colors.grey[100],
                          selectedColor: AppColors.navy,
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? AppColors.navy : Colors.grey[300]!,
                            ),
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedSource = opt['key']!;
                              _applyFilter();
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Count badge
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_filteredNotes.length}/${_allNotes.length}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Điều phối xây dựng Card theo từng loại ghi chú
  Widget _buildCardForNote(NoteModel note, String? username) {
    switch (note.type) {
      case NoteType.vocab:
        return _buildVocabCard(note, username);
      case NoteType.sentence:
        return _buildSentenceCard(note, username);
      case NoteType.feedback:
        return _buildFeedbackCard(note, username);
      case NoteType.free:
      default:
        return _buildFreeCard(note, username);
    }
  }

  /// 1. Card Từ vựng (Vocab)
  Widget _buildVocabCard(NoteModel note, String? username) {
    final vocab = note.vocabData;
    final isExpanded = _expandedVocabIds.contains(note.uuid);
    final bandScore = vocab?.bandScore ?? '7.0';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: note.isPinned ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: note.isPinned
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : Colors.grey[200]!,
          width: note.isPinned ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          NoteDetailBottomSheet.show(
            context,
            note,
            username: username,
            onNoteChanged: () => _loadNotes(showLoading: false),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Band + Source + Pin + TTS + Delete
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Band $bandScore',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            NoteSource.getDisplayName(note.source),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pin
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                          color: note.isPinned ? AppColors.primary : Colors.grey[400],
                          size: 20,
                        ),
                        onPressed: () => _togglePin(note),
                        tooltip: note.isPinned ? 'Bỏ ghim' : 'Ghim',
                      ),
                      const SizedBox(width: 8),
                      // TTS
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 22),
                        onPressed: () {
                          final wordToSpeak = note.title.contains('/')
                              ? note.title.split('/').first.trim()
                              : note.title;
                          _flutterTts.speak(wordToSpeak);
                        },
                        tooltip: 'Phát âm',
                      ),
                      const SizedBox(width: 8),
                      // Delete
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteNote(note),
                        tooltip: 'Xóa',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Word Title
              Text(
                note.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),

              // IPA
              if (vocab != null && vocab.ipa.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  vocab.ipa,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ],

              // Translation
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🇻🇳 ', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Text(
                        note.content,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD61C2C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // User note preview
              if (note.userNote != null && note.userNote!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(top: 4, bottom: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          note.userNote!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Expand / Collapse toggler
              if (vocab != null && (vocab.collocations?.isNotEmpty == true || vocab.example?.isNotEmpty == true)) ...[
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedVocabIds.remove(note.uuid);
                      } else {
                        _expandedVocabIds.add(note.uuid);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          isExpanded ? 'Thu gọn' : 'Xem Collocations & Speaking',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey[600],
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Expanded Details
              if (isExpanded && vocab != null) ...[
                const Divider(height: 16),
                if (vocab.collocations?.isNotEmpty == true) ...[
                  const Text(
                    '📝 Collocations:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  Text(vocab.collocations!, style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 6),
                ],
                if (vocab.example?.isNotEmpty == true) ...[
                  const Text(
                    '💬 Speaking Sample:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  Text('"${vocab.example!}"', style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 2. Card Câu & Ngữ cảnh (Sentence)
  Widget _buildSentenceCard(NoteModel note, String? username) {
    const col = Color(0xFF3B82F6);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: note.isPinned ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: note.isPinned ? col.withValues(alpha: 0.5) : Colors.grey[200]!,
          width: note.isPinned ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          NoteDetailBottomSheet.show(
            context,
            note,
            username: username,
            onNoteChanged: () => _loadNotes(showLoading: false),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: col.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.format_quote_rounded, size: 13, color: col),
                              SizedBox(width: 4),
                              Text(
                                'Câu mẫu',
                                style: TextStyle(color: col, fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            NoteSource.getDisplayName(note.source),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                          color: note.isPinned ? AppColors.primary : Colors.grey[400],
                          size: 20,
                        ),
                        onPressed: () => _togglePin(note),
                        tooltip: 'Ghim',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 22),
                        onPressed: () => _flutterTts.speak(note.title),
                        tooltip: 'Phát âm câu',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteNote(note),
                        tooltip: 'Xóa',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Original English Sentence
              Text(
                note.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),

              // Meaning / Translation
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: col.withValues(alpha: 0.15)),
                ),
                child: Text(
                  note.content,
                  style: TextStyle(fontSize: 13.5, color: Colors.blueGrey[800], height: 1.4),
                ),
              ),

              // User personal note
              if (note.userNote != null && note.userNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        note.userNote!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF92400E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  /// 3. Card Nhận xét AI (Feedback)
  Widget _buildFeedbackCard(NoteModel note, String? username) {
    const col = Color(0xFF8B5CF6);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: note.isPinned ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: note.isPinned ? col.withValues(alpha: 0.5) : Colors.grey[200]!,
          width: note.isPinned ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          NoteDetailBottomSheet.show(
            context,
            note,
            username: username,
            onNoteChanged: () => _loadNotes(showLoading: false),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: col.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 13, color: col),
                              SizedBox(width: 4),
                              Text(
                                'Nhận xét AI',
                                style: TextStyle(color: col, fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            NoteSource.getDisplayName(note.source),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                          color: note.isPinned ? AppColors.primary : Colors.grey[400],
                          size: 20,
                        ),
                        onPressed: () => _togglePin(note),
                        tooltip: 'Ghim',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteNote(note),
                        tooltip: 'Xóa',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                note.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),

              // Feedback Content preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: col.withValues(alpha: 0.15)),
                ),
                child: Text(
                  note.content,
                  style: TextStyle(fontSize: 13.5, color: Colors.purple[900], height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Tags
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: note.tags.map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$t',
                        style: TextStyle(fontSize: 11, color: Colors.purple[800], fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 4. Card Ghi chú tự do (Free)
  Widget _buildFreeCard(NoteModel note, String? username) {
    const col = Color(0xFFF59E0B);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: note.isPinned ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: note.isPinned ? col.withValues(alpha: 0.5) : Colors.grey[200]!,
          width: note.isPinned ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          NoteDetailBottomSheet.show(
            context,
            note,
            username: username,
            onNoteChanged: () => _loadNotes(showLoading: false),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note_rounded, size: 14, color: col),
                            SizedBox(width: 4),
                            Text(
                              'Ghi chú tự do',
                              style: TextStyle(color: col, fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                          color: note.isPinned ? AppColors.primary : Colors.grey[400],
                          size: 20,
                        ),
                        onPressed: () => _togglePin(note),
                        tooltip: 'Ghim',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () => _deleteNote(note),
                        tooltip: 'Xóa',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                note.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),

              // Content preview
              Text(
                note.content,
                style: TextStyle(fontSize: 13.5, color: Colors.grey[800], height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // Tags
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: note.tags.map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$t',
                        style: TextStyle(fontSize: 11, color: Colors.amber[900], fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Trạng thái trống
  Widget _buildEmptyState() {
    final query = _searchController.text.trim();
    final isSearching = query.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching ? Icons.search_off_rounded : Icons.menu_book_rounded,
                size: 52,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'Không tìm thấy kết quả!' : 'Sổ tay của bạn đang trống!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Không tìm thấy ghi chú nào khớp với "$query".\nHãy thử đổi từ khóa hoặc bộ lọc.'
                  : 'Hãy lưu các từ vựng, câu mẫu, nhận xét AI từ các bài luyện Reading, Listening, Writing, Speaking hoặc quét Camera AI!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScanScreen()),
                ).then((_) => _loadNotes(showLoading: false));
              },
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('QUÉT TỪ VỰNG CAMERA AI'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
