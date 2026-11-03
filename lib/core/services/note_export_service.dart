import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/note_model.dart';

/// Dịch vụ xuất dữ liệu Sổ tay (Export Notes Service) hỗ trợ TXT và CSV.
class NoteExportService {
  /// Sinh nội dung văn bản TXT có cấu trúc rõ ràng, nhóm theo từng loại ghi chú
  static String generateTxt(List<NoteModel> notes, {String title = 'IELTS VISION - SỔ TAY GHI CHÚ'}) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    buffer.writeln('================================================================');
    buffer.writeln('          $title');
    buffer.writeln('================================================================');
    buffer.writeln('Tổng số ghi chú: ${notes.length} | Thời gian xuất: $dateStr');
    buffer.writeln('Ứng dụng: IELTS Vision - Học tiếng Anh 4 Kỹ Năng & Vision AI');
    buffer.writeln('================================================================\n');

    final vocabNotes = notes.where((n) => n.type == NoteType.vocab).toList();
    final sentenceNotes = notes.where((n) => n.type == NoteType.sentence).toList();
    final feedbackNotes = notes.where((n) => n.type == NoteType.feedback).toList();
    final freeNotes = notes.where((n) => n.type == NoteType.free).toList();

    // 1. TỪ VỰNG
    if (vocabNotes.isNotEmpty) {
      buffer.writeln('----------------------------------------------------------------');
      buffer.writeln(' 1. TỪ VỰNG HỌC THUẬT (VOCABULARY) - [${vocabNotes.length} mục]');
      buffer.writeln('----------------------------------------------------------------');
      for (int i = 0; i < vocabNotes.length; i++) {
        final n = vocabNotes[i];
        final ipa = (n.vocabData?.ipa.isNotEmpty == true) ? ' ${n.vocabData!.ipa}' : '';
        final band = n.vocabData?.bandScore.isNotEmpty == true ? ' [Band ${n.vocabData!.bandScore}]' : '';
        final sourceStr = ' [Nguồn: ${NoteSource.getDisplayName(n.source)}]';

        buffer.writeln('${i + 1}. ${n.title}$ipa$band$sourceStr');
        buffer.writeln('   - Nghĩa tiếng Việt: ${n.content}');
        if (n.vocabData?.collocations?.isNotEmpty == true) {
          buffer.writeln('   - Collocations: ${n.vocabData!.collocations}');
        }
        if (n.vocabData?.example?.isNotEmpty == true) {
          buffer.writeln('   - Ví dụ: "${n.vocabData!.example}"');
          if (n.vocabData?.exampleTranslation?.isNotEmpty == true) {
            buffer.writeln('     👉 ${n.vocabData!.exampleTranslation}');
          }
        }
        if (n.userNote != null && n.userNote!.trim().isNotEmpty) {
          buffer.writeln('   - Ghi chú riêng: ${n.userNote}');
        }
        if (n.tags.isNotEmpty) {
          buffer.writeln('   - Thẻ tag: #${n.tags.join(" #")}');
        }
        buffer.writeln('');
      }
      buffer.writeln('');
    }

    // 2. CÂU MẪU & NGỮ CẢNH
    if (sentenceNotes.isNotEmpty) {
      buffer.writeln('----------------------------------------------------------------');
      buffer.writeln(' 2. CÂU MẪU & NGỮ CẢNH (SENTENCES) - [${sentenceNotes.length} mục]');
      buffer.writeln('----------------------------------------------------------------');
      for (int i = 0; i < sentenceNotes.length; i++) {
        final n = sentenceNotes[i];
        final sourceStr = ' [Nguồn: ${NoteSource.getDisplayName(n.source)}]';

        buffer.writeln('${i + 1}. "${n.title}"$sourceStr');
        buffer.writeln('   - Bản dịch / Ngữ cảnh: ${n.content}');
        if (n.userNote != null && n.userNote!.trim().isNotEmpty) {
          buffer.writeln('   - Ghi chú riêng: ${n.userNote}');
        }
        if (n.tags.isNotEmpty) {
          buffer.writeln('   - Thẻ tag: #${n.tags.join(" #")}');
        }
        buffer.writeln('');
      }
      buffer.writeln('');
    }

    // 3. NHẬN XÉT AI
    if (feedbackNotes.isNotEmpty) {
      buffer.writeln('----------------------------------------------------------------');
      buffer.writeln(' 3. NHẬN XÉT & PHÂN TÍCH AI (AI FEEDBACK) - [${feedbackNotes.length} mục]');
      buffer.writeln('----------------------------------------------------------------');
      for (int i = 0; i < feedbackNotes.length; i++) {
        final n = feedbackNotes[i];
        final sourceStr = ' [Kỹ năng: ${NoteSource.getDisplayName(n.source)}]';

        buffer.writeln('${i + 1}. ${n.title}$sourceStr');
        buffer.writeln('   - Chi tiết nhận xét:');
        for (final line in n.content.split('\n')) {
          buffer.writeln('     $line');
        }
        if (n.userNote != null && n.userNote!.trim().isNotEmpty) {
          buffer.writeln('   - Ghi chú riêng: ${n.userNote}');
        }
        if (n.tags.isNotEmpty) {
          buffer.writeln('   - Thẻ tag: #${n.tags.join(" #")}');
        }
        buffer.writeln('');
      }
      buffer.writeln('');
    }

    // 4. GHI CHÚ TỰ DO
    if (freeNotes.isNotEmpty) {
      buffer.writeln('----------------------------------------------------------------');
      buffer.writeln(' 4. GHI CHÚ TỰ DO (FREE NOTES) - [${freeNotes.length} mục]');
      buffer.writeln('----------------------------------------------------------------');
      for (int i = 0; i < freeNotes.length; i++) {
        final n = freeNotes[i];
        buffer.writeln('${i + 1}. ${n.title}');
        buffer.writeln('   - Nội dung: ${n.content}');
        if (n.userNote != null && n.userNote!.trim().isNotEmpty) {
          buffer.writeln('   - Ghi chú riêng: ${n.userNote}');
        }
        if (n.tags.isNotEmpty) {
          buffer.writeln('   - Thẻ tag: #${n.tags.join(" #")}');
        }
        buffer.writeln('');
      }
      buffer.writeln('');
    }

    buffer.writeln('====================== HẾT TÀI LIỆU ======================');
    return buffer.toString();
  }

  /// Sinh nội dung định dạng CSV chuẩn RFC 4180 (dễ dàng mở bằng Microsoft Excel hoặc import vào Anki/Quizlet)
  static String generateCsv(List<NoteModel> notes) {
    final buffer = StringBuffer();

    // Dòng tiêu đề cột CSV
    buffer.writeln('"Loại Ghi Chú","Nguồn","Tiêu Đề","Nội Dung / Nghĩa","Ghi Chú Riêng","Tags","Ngày Tạo"');

    for (final n in notes) {
      final type = _escapeCsv(NoteType.getDisplayName(n.type));
      final source = _escapeCsv(NoteSource.getDisplayName(n.source));
      final title = _escapeCsv(n.title);
      final content = _escapeCsv(n.content);
      final userNote = _escapeCsv(n.userNote ?? '');
      final tags = _escapeCsv(n.tags.join(', '));
      final createdAt = _escapeCsv(n.createdAt);

      buffer.writeln('$type,$source,$title,$content,$userNote,$tags,$createdAt');
    }

    return buffer.toString();
  }

  /// Thoát chuỗi chuẩn CSV: bao quanh bằng dấu ngoặc kép và nhân đôi dấu ngoặc kép bên trong
  static String _escapeCsv(String field) {
    final escaped = field.replaceAll('"', '""');
    return '"$escaped"';
  }

  /// Hiển thị Modal Bottom Sheet hỗ trợ xuất dữ liệu ra TXT hoặc CSV
  static Future<void> showExportBottomSheet(
    BuildContext context,
    List<NoteModel> notes,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoteExportBottomSheet(notes: notes),
    );
  }
}

class _NoteExportBottomSheet extends StatefulWidget {
  final List<NoteModel> notes;

  const _NoteExportBottomSheet({required this.notes});

  @override
  State<_NoteExportBottomSheet> createState() => _NoteExportBottomSheetState();
}

class _NoteExportBottomSheetState extends State<_NoteExportBottomSheet> {
  int _selectedFormatIndex = 0; // 0: TXT, 1: CSV

  String _getGeneratedContent() {
    if (_selectedFormatIndex == 0) {
      return NoteExportService.generateTxt(widget.notes);
    } else {
      return NoteExportService.generateCsv(widget.notes);
    }
  }

  void _copyToClipboard() {
    final content = _getGeneratedContent();
    Clipboard.setData(ClipboardData(text: content));

    final formatName = _selectedFormatIndex == 0 ? 'TXT' : 'CSV';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Đã sao chép toàn bộ ${widget.notes.length} ghi chú định dạng $formatName vào Clipboard!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final generatedContent = _getGeneratedContent();
    final formatName = _selectedFormatIndex == 0 ? 'TXT' : 'CSV';

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenH * 0.88,
        minHeight: screenH * 0.5,
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
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.file_download_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Xuất Dữ Liệu Sổ Tay',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.navy),
                      ),
                      Text(
                        'Tổng cộng ${widget.notes.length} ghi chú đã sẵn sàng xuất',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Định dạng xuất (TXT vs CSV Segmented Button)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  icon: Icon(Icons.text_snippet_rounded, size: 18),
                  label: Text('Văn bản TXT'),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.table_chart_rounded, size: 18),
                  label: Text('Bảng tính CSV (Excel/Anki)'),
                ),
              ],
              selected: {_selectedFormatIndex},
              onSelectionChanged: (val) {
                setState(() => _selectedFormatIndex = val.first);
              },
            ),
          ),

          // Preview Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  generatedContent,
                  style: TextStyle(
                    fontFamily: _selectedFormatIndex == 1 ? 'monospace' : null,
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                    label: Text(
                      'SAO CHÉP TOÀN BỘ ($formatName)',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    onPressed: _copyToClipboard,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

