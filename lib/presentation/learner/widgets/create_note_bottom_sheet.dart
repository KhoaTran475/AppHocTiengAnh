import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/note_model.dart';
import '../../../data/repositories/note_repository.dart';

/// Modal Bottom Sheet cho phép học viên tự tạo mới một ghi chú vào Sổ tay
class CreateNoteBottomSheet extends StatefulWidget {
  final int userId;
  final String? username;
  final String? initialType;
  final String? initialSource;
  final String? initialTitle;
  final String? initialContent;
  final String? initialSourceRef;
  final List<String> initialTags;

  const CreateNoteBottomSheet({
    super.key,
    required this.userId,
    this.username,
    this.initialType,
    this.initialSource,
    this.initialTitle,
    this.initialContent,
    this.initialSourceRef,
    this.initialTags = const [],
  });

  /// Tiện ích hiển thị BottomSheet tạo ghi chú
  static Future<NoteModel?> show(
    BuildContext context, {
    required int userId,
    String? username,
    String? initialType,
    String? initialSource,
    String? initialTitle,
    String? initialContent,
    String? initialSourceRef,
    List<String> initialTags = const [],
  }) {
    return showModalBottomSheet<NoteModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateNoteBottomSheet(
        userId: userId,
        username: username,
        initialType: initialType,
        initialSource: initialSource,
        initialTitle: initialTitle,
        initialContent: initialContent,
        initialSourceRef: initialSourceRef,
        initialTags: initialTags,
      ),
    );
  }

  @override
  State<CreateNoteBottomSheet> createState() => _CreateNoteBottomSheetState();
}

class _CreateNoteBottomSheetState extends State<CreateNoteBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedType;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _userNoteController;
  late TextEditingController _tagsController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? NoteType.free;
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _contentController = TextEditingController(text: widget.initialContent ?? '');
    _userNoteController = TextEditingController();
    _tagsController = TextEditingController(text: widget.initialTags.join(', '));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _userNoteController.dispose();
    _tagsController.dispose();
    super.dispose();
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

  String _getTitleLabel() {
    switch (_selectedType) {
      case NoteType.vocab:
        return 'Từ vựng tiếng Anh *';
      case NoteType.sentence:
        return 'Câu tiếng Anh / Cấu trúc ngữ pháp *';
      case NoteType.feedback:
        return 'Tiêu đề nhận xét / kinh nghiệm *';
      case NoteType.free:
      default:
        return 'Tiêu đề ghi chú *';
    }
  }

  String _getContentLabel() {
    switch (_selectedType) {
      case NoteType.vocab:
        return 'Nghĩa tiếng Việt & Định nghĩa *';
      case NoteType.sentence:
        return 'Bản dịch tiếng Việt / Ý nghĩa câu *';
      case NoteType.feedback:
        return 'Chi tiết nhận xét / Điểm cần cải thiện *';
      case NoteType.free:
      default:
        return 'Nội dung ghi chú *';
    }
  }

  Future<void> _submitSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final savedNote = await NoteRepository.instance.saveQuickNote(
        userId: widget.userId,
        type: _selectedType,
        source: widget.initialSource ?? NoteSource.manual,
        sourceRef: widget.initialSourceRef,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        userNote: _userNoteController.text.trim().isNotEmpty
            ? _userNoteController.text.trim()
            : null,
        tags: tags,
        username: widget.username,
      );

      if (mounted) {
        Navigator.pop(context, savedNote);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm "${savedNote.title}" vào Sổ tay!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu ghi chú: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;
    final typeColor = _getTypeColor(_selectedType);

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.9),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.note_add_rounded, color: typeColor, size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'Thêm Ghi Chú Mới',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Loại ghi chú (4 loại)
          const Text(
            'Loại ghi chú:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: NoteType.all.map((t) {
                final isSelected = _selectedType == t;
                final col = _getTypeColor(t);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(NoteType.getDisplayName(t)),
                    selected: isSelected,
                    selectedColor: col.withValues(alpha: 0.15),
                    backgroundColor: Colors.grey[100],
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? col : Colors.black87,
                    ),
                    side: BorderSide(
                      color: isSelected ? col : Colors.transparent,
                      width: 1.5,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedType = t);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Form fields
          Flexible(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: _getTitleLabel(),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập trường này';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: _getContentLabel(),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Vui lòng nhập nội dung';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _userNoteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú cá nhân (tùy chọn)',
                        hintText: 'Mẹo nhớ, lỗi sai thường gặp...',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tagsController,
                      decoration: InputDecoration(
                        labelText: 'Nhãn (Tags, cách nhau bởi dấu phẩy)',
                        hintText: 'IELTS, Reading, Collocation...',
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: typeColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSaving ? null : _submitSave,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.bookmark_add_rounded, color: Colors.white),
                        label: Text(
                          _isSaving ? 'ĐANG LƯU...' : 'LƯU VÀO SỔ TAY',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

