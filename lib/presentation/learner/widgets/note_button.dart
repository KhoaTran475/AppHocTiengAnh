import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/note_model.dart';
import '../../../data/models/vocabulary_item_model.dart';
import '../../../data/repositories/note_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// Widget nút Bookmark/Ghim dùng chung cho các màn hình (Reading, Listening, AI Sheet...).
/// Tự động kiểm tra `NoteRepository.isSaved()` để hiển thị icon bookmark đặc/rỗng,
/// và hỗ trợ lưu/xóa nhanh với SnackBar phản hồi người dùng.
class NoteButton extends StatefulWidget {
  final String title;
  final String type; // NoteType: vocab | sentence | feedback | free
  final String source; // NoteSource: reading | listening | writing | ...
  final String? content;
  final String? sourceRef;
  final String? userNote;
  final List<String> tags;
  final VocabularyItemModel? vocabData;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool showBorder;
  final String? tooltip;
  final VoidCallback? onSavedChanged;

  const NoteButton({
    super.key,
    required this.title,
    required this.type,
    required this.source,
    this.content,
    this.sourceRef,
    this.userNote,
    this.tags = const [],
    this.vocabData,
    this.size = 20.0,
    this.activeColor,
    this.inactiveColor,
    this.showBorder = false,
    this.tooltip,
    this.onSavedChanged,
  });

  @override
  State<NoteButton> createState() => _NoteButtonState();
}

class _NoteButtonState extends State<NoteButton> {
  bool _isSaved = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkSavedStatus();
  }

  @override
  void didUpdateWidget(covariant NoteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title || oldWidget.type != widget.type) {
      _checkSavedStatus();
    }
  }

  Future<void> _checkSavedStatus() async {
    final user = context.read<AuthProvider>().currentUser;
    final userId = user?.id ?? 1;

    final saved = await NoteRepository.instance.isSaved(
      userId,
      widget.title,
      type: widget.type,
    );
    if (mounted) {
      setState(() => _isSaved = saved);
    }
  }

  Future<void> _handleToggle() async {
    if (_isProcessing) return;
    final user = context.read<AuthProvider>().currentUser;
    final userId = user?.id ?? 1;
    final username = user?.username;

    setState(() => _isProcessing = true);

    try {
      if (_isSaved) {
        // Tìm note để soft delete
        final notes = await NoteRepository.instance.getNotes(
          userId,
          type: widget.type,
          searchQuery: widget.title.trim(),
        );

        final match = notes.firstWhere(
          (n) => n.title.trim().toLowerCase() == widget.title.trim().toLowerCase(),
          orElse: () => notes.isNotEmpty ? notes.first : throw Exception('Không tìm thấy ghi chú để xóa'),
        );

        if (match.id != null) {
          await NoteRepository.instance.deleteNote(
            match.id!,
            softDelete: true,
            username: username,
          );
        }

        if (mounted) {
          setState(() {
            _isSaved = false;
            _isProcessing = false;
          });
          widget.onSavedChanged?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã bỏ lưu "${_truncate(widget.title)}" khỏi Sổ tay.'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Lưu nhanh ghi chú mới
        await NoteRepository.instance.saveQuickNote(
          userId: userId,
          type: widget.type,
          source: widget.source,
          sourceRef: widget.sourceRef,
          title: widget.title.trim(),
          content: (widget.content?.trim().isNotEmpty == true)
              ? widget.content!.trim()
              : widget.title.trim(),
          userNote: widget.userNote,
          tags: widget.tags,
          vocabData: widget.vocabData,
          username: username,
        );

        if (mounted) {
          setState(() {
            _isSaved = true;
            _isProcessing = false;
          });
          widget.onSavedChanged?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã lưu "${_truncate(widget.title)}" vào Sổ tay!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật sổ tay: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _truncate(String text, {int maxLen = 30}) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }

  @override
  Widget build(BuildContext context) {
    final activeCol = widget.activeColor ?? AppColors.primary;
    final inactiveCol = widget.inactiveColor ?? Colors.grey[400]!;

    Widget buttonChild = Icon(
      _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
      color: _isSaved ? activeCol : inactiveCol,
      size: widget.size,
    );

    if (_isProcessing) {
      buttonChild = SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: activeCol,
        ),
      );
    }

    if (widget.showBorder) {
      return InkWell(
        onTap: _handleToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _isSaved ? activeCol.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isSaved ? activeCol : Colors.grey[300]!,
            ),
          ),
          child: buttonChild,
        ),
      );
    }

    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: buttonChild,
      tooltip: widget.tooltip ?? (_isSaved ? 'Đã lưu sổ tay' : 'Lưu vào sổ tay'),
      onPressed: _handleToggle,
    );
  }
}

