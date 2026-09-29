import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/object_mapping_model.dart';

/// Modal BottomSheet cho phép Quản trị viên (Admin) Thêm mới hoặc Chỉnh sửa
/// dữ liệu học thuật của nhãn từ vựng AI YOLOv8.
class MappingEditSheet extends StatefulWidget {
  final ObjectMappingModel? initialMapping;

  const MappingEditSheet({
    super.key,
    this.initialMapping,
  });

  static Future<ObjectMappingModel?> show(
    BuildContext context, {
    ObjectMappingModel? initialMapping,
  }) {
    return showModalBottomSheet<ObjectMappingModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MappingEditSheet(initialMapping: initialMapping),
    );
  }

  @override
  State<MappingEditSheet> createState() => _MappingEditSheetState();
}

class _MappingEditSheetState extends State<MappingEditSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _labelController;
  late TextEditingController _commonWordController;
  late TextEditingController _academicWordController;
  late TextEditingController _ipaController;
  late TextEditingController _vietnameseMeaningController;
  late TextEditingController _collocationsController;
  late TextEditingController _idiomsController;
  late TextEditingController _speakingExampleController;
  late TextEditingController _speakingTranslationController;

  String _selectedBand = '8.0';
  final List<String> _bandList = ['7.0', '7.5', '8.0', '8.5'];

  bool get _isEditing => widget.initialMapping != null;

  @override
  void initState() {
    super.initState();
    final m = widget.initialMapping;
    _labelController = TextEditingController(text: m?.label ?? '');
    _commonWordController = TextEditingController(text: m?.commonWord ?? '');
    _academicWordController = TextEditingController(text: m?.academicWord ?? '');
    _ipaController = TextEditingController(text: m?.ipa ?? '');
    _vietnameseMeaningController = TextEditingController(text: m?.vietnameseMeaning ?? '');
    _collocationsController = TextEditingController(text: m?.collocations.join('; ') ?? '');
    _idiomsController = TextEditingController(text: m?.idioms ?? '');
    _speakingExampleController = TextEditingController(text: m?.speakingPart1Example ?? '');
    _speakingTranslationController =
        TextEditingController(text: m?.speakingPart1Translation ?? '');

    if (m != null && _bandList.contains(m.bandScore)) {
      _selectedBand = m.bandScore;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _commonWordController.dispose();
    _academicWordController.dispose();
    _ipaController.dispose();
    _vietnameseMeaningController.dispose();
    _collocationsController.dispose();
    _idiomsController.dispose();
    _speakingExampleController.dispose();
    _speakingTranslationController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final collocationsList = _collocationsController.text
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final result = ObjectMappingModel(
      id: widget.initialMapping?.id,
      label: _labelController.text.trim().toLowerCase(),
      commonWord: _commonWordController.text.trim(),
      vietnameseMeaning: _vietnameseMeaningController.text.trim(),
      academicWord: _academicWordController.text.trim(),
      ipa: _ipaController.text.trim(),
      bandScore: _selectedBand,
      collocations: collocationsList,
      idioms: _idiomsController.text.trim(),
      speakingPart1Example: _speakingExampleController.text.trim(),
      speakingPart1Translation: _speakingTranslationController.text.trim(),
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Chỉnh sửa Từ vựng AI' : 'Thêm mới Nhãn Từ vựng',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      _isEditing
                          ? 'Cập nhật từ vựng tương ứng cho nhãn YOLO'
                          : 'Định nghĩa từ vựng học thuật cho nhãn COCO mới',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 20),

          // Form fields
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  // Hàng: Nhãn YOLO & Từ thông dụng
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _labelController,
                          label: 'Nhãn YOLO (COCO)',
                          hint: 'VD: cell phone, mouse',
                          icon: Icons.tag_rounded,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Nhập nhãn YOLO' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _commonWordController,
                          label: 'Từ thông dụng',
                          hint: 'VD: mouse, mobile phone',
                          icon: Icons.chat_bubble_outline_rounded,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Nhập từ thông dụng' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Từ học thuật IELTS
                  _buildTextField(
                    controller: _academicWordController,
                    label: 'Từ vựng Học thuật IELTS (Target Word)',
                    hint: 'VD: Optical pointing peripheral',
                    icon: Icons.school_rounded,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Bắt buộc nhập từ IELTS' : null,
                  ),
                  const SizedBox(height: 12),

                  // Hàng: Phiên âm IPA & Band điểm
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: _buildTextField(
                          controller: _ipaController,
                          label: 'Phiên âm IPA',
                          hint: "VD: /a:p.ti.kəl pə'rɪf.ə.əl/",
                          icon: Icons.record_voice_over_outlined,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Nhập IPA' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedBand,
                          decoration: InputDecoration(
                            labelText: 'Band IELTS',
                            labelStyle: const TextStyle(fontSize: 13),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          items: _bandList.map((band) {
                            return DropdownMenuItem(
                              value: band,
                              child: Text('Band $band',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedBand = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Nghĩa tiếng Việt
                  _buildTextField(
                    controller: _vietnameseMeaningController,
                    label: 'Nghĩa tiếng Việt 🇻🇳',
                    hint: 'VD: Chuột máy tính, thiết bị trỏ quang học',
                    icon: Icons.translate_rounded,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nhập nghĩa tiếng Việt' : null,
                  ),
                  const SizedBox(height: 12),

                  // Collocations
                  _buildTextField(
                    controller: _collocationsController,
                    label: 'Collocations (phân tách bằng dấu chấm phẩy ;)',
                    hint: 'VD: ergonomic wrist contour; optical navigation',
                    icon: Icons.format_list_bulleted_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  // Idioms
                  _buildTextField(
                    controller: _idiomsController,
                    label: 'Topic Idiom & Dịch nghĩa',
                    hint: 'VD: Quiet as a mouse (Cực kỳ im lặng, nín thin thít)',
                    icon: Icons.lightbulb_outline_rounded,
                  ),
                  const SizedBox(height: 12),

                  // Speaking Part 1 Example
                  _buildTextField(
                    controller: _speakingExampleController,
                    label: 'IELTS Speaking Part 1 Sample (Tiếng Anh)',
                    hint: 'VD: Optical pointing peripherals offer tactile precision...',
                    icon: Icons.forum_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),

                  // Speaking Part 1 Translation
                  _buildTextField(
                    controller: _speakingTranslationController,
                    label: 'Dịch nghĩa câu Speaking (Tiếng Việt)',
                    hint: 'VD: Chuột quang cao cấp mang lại sự chính xác xúc giác...',
                    icon: Icons.g_translate_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Nút xác nhận lưu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_circle_rounded),
              label: Text(_isEditing ? 'LƯU THAY ĐỔI' : 'THÊM MỚI NHÃN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey[700]),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
        prefixIcon: Icon(icon, size: 20, color: AppColors.navy),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
