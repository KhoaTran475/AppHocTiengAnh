import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/note_model.dart';
import '../../../data/repositories/note_repository.dart';

/// Modal Bottom Sheet hiển thị và chỉnh sửa chi tiết Ghi chú đa ngữ cảnh (NoteModel)
class NoteDetailBottomSheet extends StatefulWidget {
  final NoteModel note;
  final String? username;
  final VoidCallback? onNoteChanged;

  const NoteDetailBottomSheet({
    super.key,
    required this.note,
    this.username,
    this.onNoteChanged,
  });

  /// Mở BottomSheet thuận tiện từ bất cứ đâu
  static Future<void> show(
    BuildContext context,
    NoteModel note, {
    String? username,
    VoidCallback? onNoteChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteDetailBottomSheet(
        note: note,
        username: username,
        onNoteChanged: onNoteChanged,
      ),
    );
  }

  @override
  State<NoteDetailBottomSheet> createState() => _NoteDetailBottomSheetState();
}

class _NoteDetailBottomSheetState extends State<NoteDetailBottomSheet> {
  final FlutterTts _flutterTts = FlutterTts();
  late NoteModel _currentNote;
  late TextEditingController _userNoteController;
  bool _isEditingNote = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _userNoteController = TextEditingController(text: _currentNote.userNote ?? '');
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _userNoteController.dispose();
    super.dispose();
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case NoteType.vocab:
        return const Color(0xFF10B981); // Emerald Green
      case NoteType.sentence:
        return const Color(0xFF3B82F6); // Blue
      case NoteType.feedback:
        return const Color(0xFF8B5CF6); // Purple / AI
      case NoteType.free:
      default:
        return const Color(0xFFF59E0B); // Amber / Yellow
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

  Future<void> _togglePin() async {
    if (_currentNote.id == null) return;
    final newPinned = !_currentNote.isPinned;
    await NoteRepository.instance.togglePin(
      _currentNote.id!,
      newPinned,
      username: widget.username,
    );
    setState(() {
      _currentNote = _currentNote.copyWith(isPinned: newPinned);
    });
    widget.onNoteChanged?.call();
  }

  Future<void> _saveUserNote() async {
    if (_currentNote.id == null) return;
    setState(() => _isSaving = true);
    final text = _userNoteController.text.trim();
    await NoteRepository.instance.updateUserNote(
      _currentNote.id!,
      text.isNotEmpty ? text : null,
      username: widget.username,
    );
    setState(() {
      _currentNote = _currentNote.copyWith(userNote: text);
      _isEditingNote = false;
      _isSaving = false;
    });
    widget.onNoteChanged?.call();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật ghi chú cá nhân thành công!'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteNote() async {
    if (_currentNote.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa "${_currentNote.title}" khỏi Sổ tay?'),
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
        _currentNote.id!,
        softDelete: true,
        username: widget.username,
      );
      widget.onNoteChanged?.call();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa "${_currentNote.title}" khỏi sổ tay.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final typeColor = _getTypeColor(_currentNote.type);

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenH * 0.88,
        minHeight: screenH * 0.45,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getTypeIcon(_currentNote.type), size: 14, color: typeColor),
                      const SizedBox(width: 5),
                      Text(
                        NoteType.getDisplayName(_currentNote.type),
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Source badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    NoteSource.getDisplayName(_currentNote.source),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const Spacer(),
                // Pin button
                IconButton(
                  tooltip: _currentNote.isPinned ? 'Bỏ ghim' : 'Ghim lên đầu',
                  icon: Icon(
                    _currentNote.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    color: _currentNote.isPinned ? AppColors.primary : Colors.grey,
                  ),
                  onPressed: _togglePin,
                ),
                // Delete button
                IconButton(
                  tooltip: 'Xóa ghi chú',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: _deleteNote,
                ),
                // Close button
                IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Audio Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          _currentNote.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (_currentNote.type == NoteType.vocab || _currentNote.type == NoteType.sentence) ...[
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            foregroundColor: AppColors.primary,
                          ),
                          icon: const Icon(Icons.volume_up_rounded, size: 22),
                          onPressed: () {
                            final toSpeak = _currentNote.type == NoteType.vocab
                                ? (_currentNote.title.contains('/') ? _currentNote.title.split('/').first.trim() : _currentNote.title)
                                : _currentNote.content;
                            _flutterTts.speak(toSpeak);
                          },
                          tooltip: 'Nghe phát âm',
                        ),
                      ],
                    ],
                  ),

                  // If Vocab: show IPA
                  if (_currentNote.vocabData != null && _currentNote.vocabData!.ipa.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _currentNote.vocabData!.ipa,
                      style: TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],

                  // Nguồn gốc bài học chi tiết (sourceRef)
                  if (_currentNote.sourceRef != null && _currentNote.sourceRef!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.link_rounded, size: 15, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            NoteSourceRef.getDisplayText(_currentNote.sourceRef),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Main Content Card
                  _buildContentSection(typeColor),

                  // Extra Vocab Details (Collocations, Idioms, IELTS Speaking)
                  if (_currentNote.vocabData != null) ...[
                    _buildVocabAcademicDetails(_currentNote.vocabData!),
                  ],

                  const SizedBox(height: 18),

                  // Tags list
                  if (_currentNote.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _currentNote.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // User Personal Note Section (Editable)
                  _buildUserNoteSection(),

                  const SizedBox(height: 14),

                  // Footer Meta (Creation Date)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Tạo ngày: ${_formatDate(_currentNote.createdAt)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Khung hiển thị nội dung chính dựa theo loại ghi chú
  Widget _buildContentSection(Color typeColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: typeColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getContentHeaderIcon(), size: 16, color: typeColor),
              const SizedBox(width: 6),
              Text(
                _getContentHeaderTitle(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            _currentNote.content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getContentHeaderIcon() {
    switch (_currentNote.type) {
      case NoteType.vocab:
        return Icons.language_rounded;
      case NoteType.sentence:
        return Icons.translate_rounded;
      case NoteType.feedback:
        return Icons.insights_rounded;
      case NoteType.free:
      default:
        return Icons.description_outlined;
    }
  }

  String _getContentHeaderTitle() {
    switch (_currentNote.type) {
      case NoteType.vocab:
        return 'Định nghĩa & Nghĩa tiếng Việt';
      case NoteType.sentence:
        return 'Nguyên văn & Bản dịch';
      case NoteType.feedback:
        return 'Chi tiết nhận xét từ AI';
      case NoteType.free:
      default:
        return 'Nội dung ghi chú';
    }
  }

  /// Hiển thị chi tiết học thuật cho từ vựng (Collocations, Idiom, Ví dụ)
  Widget _buildVocabAcademicDetails(dynamic vocab) {
    final collocations = vocab.collocations;
    final idioms = vocab.idioms;
    final example = vocab.example;
    final exampleTranslation = vocab.exampleTranslation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),

        // Collocations
        if (collocations != null && collocations.toString().isNotEmpty) ...[
          const Text(
            '📝  Collocations nâng cao:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: SelectableText(
              collocations.toString(),
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Idiom
        if (idioms != null && idioms.toString().isNotEmpty) ...[
          const Text(
            '💡  Topic Idiom:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFFB45309),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: SelectableText(
              idioms.toString(),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF78350F),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Example
        if (example != null && example.toString().isNotEmpty) ...[
          const Text(
            '💬  IELTS Speaking Sample:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
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
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  '"$example"',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                    color: AppColors.navy,
                  ),
                ),
                if (exampleTranslation != null && exampleTranslation.toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SelectableText(
                    '👉 $exampleTranslation',
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
    );
  }

  /// Phần ghi chú riêng của học viên (Editable)
  Widget _buildUserNoteSection() {
    final hasUserNote = _currentNote.userNote != null && _currentNote.userNote!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE047).withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Color(0xFFCA8A04), size: 20),
              const SizedBox(width: 6),
              const Text(
                'Ghi chú cá nhân của bạn',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFF854D0E),
                ),
              ),
              const Spacer(),
              if (!_isEditingNote)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF854D0E),
                  ),
                  onPressed: () {
                    setState(() => _isEditingNote = true);
                  },
                  child: Text(hasUserNote ? 'Sửa' : '+ Thêm ghi chú'),
                ),
            ],
          ),
          if (_isEditingNote) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _userNoteController,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nhập mẹo nhớ, lỗi cần tránh hoặc ngữ cảnh của bạn...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFFDE047)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    _userNoteController.text = _currentNote.userNote ?? '';
                    setState(() => _isEditingNote = false);
                  },
                  child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCA8A04),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: _isSaving ? null : _saveUserNote,
                  child: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Lưu'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            SelectableText(
              hasUserNote ? _currentNote.userNote! : 'Chưa có ghi chú riêng. Nhấn "+ Thêm ghi chú" để ghi lại mẹo học hoặc ngữ cảnh áp dụng.',
              style: TextStyle(
                fontSize: 13.5,
                color: hasUserNote ? const Color(0xFF713F12) : Colors.grey[500],
                fontStyle: hasUserNote ? FontStyle.normal : FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}

