import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/note_model.dart';
import '../../../data/repositories/note_repository.dart';
import '../../auth/providers/auth_provider.dart';
import 'create_note_bottom_sheet.dart';

/// Nút bấm nổi hình Cây Bút (Quick Note FAB) cho phép học viên ghi chú tức thời
/// trên mọi màn hình luyện tập kỹ năng và học từ vựng.
class QuickNoteFab extends StatelessWidget {
  final String source;
  final String? sourceRef;
  final List<String> initialTags;
  final String? initialType;
  final String? initialTitle;
  final String? initialContent;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Object? heroTag;
  final String tooltip;
  final bool isMini;
  final ValueChanged<NoteModel>? onNoteCreated;

  const QuickNoteFab({
    super.key,
    required this.source,
    this.sourceRef,
    this.initialTags = const [],
    this.initialType,
    this.initialTitle,
    this.initialContent,
    this.backgroundColor,
    this.foregroundColor,
    this.heroTag,
    this.tooltip = 'Ghi chú nhanh',
    this.isMini = false,
    this.onNoteCreated,
  });

  Future<void> _openCreateNoteSheet(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final int userId = currentUser?.id ?? 1;

    final createdNote = await CreateNoteBottomSheet.show(
      context,
      userId: userId,
      username: currentUser?.username,
      initialType: initialType ?? NoteType.free,
      initialSource: source,
      initialSourceRef: sourceRef,
      initialTitle: initialTitle,
      initialContent: initialContent,
      initialTags: initialTags,
    );

    if (createdNote != null) {
      NoteRepository.instance.notifyNotesChanged();
      if (onNoteCreated != null) {
        onNoteCreated!(createdNote);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color effectiveBgColor = backgroundColor ?? AppColors.primary;
    final Color effectiveFgColor = foregroundColor ?? Colors.white;

    if (isMini) {
      return FloatingActionButton.small(
        heroTag: heroTag ?? 'quick_note_fab_$source',
        tooltip: tooltip,
        backgroundColor: effectiveBgColor,
        foregroundColor: effectiveFgColor,
        elevation: 4,
        onPressed: () => _openCreateNoteSheet(context),
        child: const Icon(Icons.edit_note_rounded, size: 22),
      );
    }

    return FloatingActionButton(
      heroTag: heroTag ?? 'quick_note_fab_$source',
      tooltip: tooltip,
      backgroundColor: effectiveBgColor,
      foregroundColor: effectiveFgColor,
      elevation: 4,
      onPressed: () => _openCreateNoteSheet(context),
      child: const Icon(Icons.edit_note_rounded, size: 28),
    );
  }
}

