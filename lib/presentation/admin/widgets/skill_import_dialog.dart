import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/api_service.dart';

/// Hộp thoại Import File Đề thi & Tải File Mẫu cho 4 Kỹ Năng IELTS
class SkillImportDialog extends StatefulWidget {
  final String initialSkill;

  const SkillImportDialog({
    super.key,
    this.initialSkill = 'reading',
  });

  static Future<bool?> show(BuildContext context, {String initialSkill = 'reading'}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SkillImportDialog(initialSkill: initialSkill),
    );
  }

  @override
  State<SkillImportDialog> createState() => _SkillImportDialogState();
}

class _SkillImportDialogState extends State<SkillImportDialog> {
  late String _selectedSkill;
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _previewJson;
  int _parsedItemCount = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedSkill = widget.initialSkill;
  }

  Future<void> _pickFile() async {
    setState(() {
      _errorMessage = null;
      _previewJson = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        setState(() {
          _selectedFile = file;
        });

        // Nếu là JSON, hiển thị preview ngay
        if (file.name.toLowerCase().endsWith('.json') && file.bytes != null) {
          try {
            final content = utf8.decode(file.bytes!);
            final dynamic parsed = jsonDecode(content);
            if (parsed is List) {
              _parsedItemCount = parsed.length;
            } else if (parsed is Map && parsed.containsKey('lessons')) {
              _parsedItemCount = (parsed['lessons'] as List).length;
            } else {
              _parsedItemCount = 1;
            }
            setState(() {
              _previewJson = const JsonEncoder.withIndent('  ').convert(parsed);
            });
          } catch (e) {
            setState(() {
              _errorMessage = 'File JSON không hợp lệ: $e';
            });
          }
        } else {
          setState(() {
            _parsedItemCount = 1;
            _previewJson = 'Đã chọn file: ${file.name} (${(file.size / 1024).toStringAsFixed(1)} KB)';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi chọn file: $e';
      });
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final templates = await ApiService.instance.getSkillTemplate(_selectedSkill);
      final jsonString = const JsonEncoder.withIndent('  ').convert(templates);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.description_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('File mẫu ${_selectedSkill.toUpperCase()} JSON'),
            ],
          ),
          content: SizedBox(
            width: 550,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bạn có thể sao chép cấu trúc mẫu này, chỉnh sửa nội dung bài thi và lưu thành file .json để tải lên:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        jsonString,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.lightGreenAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Sao chép vào Clipboard'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonString));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép file mẫu vào Clipboard!')),
                );
                Navigator.of(ctx).pop();
              },
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải file mẫu: $e')),
        );
      }
    }
  }

  Future<void> _submitImport() async {
    if (_selectedFile == null || _selectedFile!.bytes == null) {
      setState(() {
        _errorMessage = 'Vui lòng chọn file đề thi trước khi nạp!';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.instance.importSkillLessonsFile(
        fileBytes: _selectedFile!.bytes!,
        fileName: _selectedFile!.name,
      );

      if (!mounted) return;

      final success = res['success'] == true;
      final count = res['imported_count'] ?? 0;
      final message = res['message'] ?? 'Import thành công';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success ? Colors.green[700] : Colors.amber[800],
          content: Text(
            success
                ? '✅ $message ($count bài học mới/cập nhật)'
                : '⚠️ $message',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.file_upload_rounded, color: AppColors.primary, size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Import File Đề Thi & 5 Ải',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tải lên file đề thi định dạng .json, .xlsx hoặc .csv để nạp hàng loạt bài học cho học viên mà không cần gõ code:',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 14),

              // Chọn kỹ năng
              Row(
                children: [
                  const Text('Kỹ năng: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSkill,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'reading', child: Text('📖 Reading')),
                        DropdownMenuItem(value: 'listening', child: Text('🎧 Listening')),
                        DropdownMenuItem(value: 'writing', child: Text('✍️ Writing')),
                        DropdownMenuItem(value: 'speaking', child: Text('🗣️ Speaking')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSkill = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('File Mẫu', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Khu vực chọn file
              InkWell(
                onTap: _isUploading ? null : _pickFile,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedFile != null ? Colors.green : Colors.blue.withValues(alpha: 0.3),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                        size: 40,
                        color: _selectedFile != null ? Colors.green : AppColors.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFile != null
                            ? 'Đã chọn: ${_selectedFile!.name}'
                            : 'Nhấp để chọn file (.json, .xlsx, .csv)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedFile != null ? Colors.green[800] : AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_selectedFile != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Kích thước: ${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB (Khoảng $_parsedItemCount bài học)',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_previewJson != null) ...[
                const SizedBox(height: 16),
                const Text('Xem trước dữ liệu bài thi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  height: 160,
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _previewJson!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        ElevatedButton.icon(
          onPressed: _isUploading || _selectedFile == null ? null : _submitImport,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          icon: _isUploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save_alt_rounded, color: Colors.white, size: 18),
          label: Text(
            _isUploading ? 'Đang nạp đề thi...' : 'Xác nhận Nạp đề thi',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
