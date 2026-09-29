import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/vision/vision_service.dart';
import '../../../data/models/object_mapping_model.dart';
import '../../../data/models/vocabulary_item_model.dart';
import '../../auth/providers/auth_provider.dart';

/// Modal Bottom Sheet hiển thị chi tiết từ vựng IELTS Band 7.0 - 8.5
/// được nạp động từ SQLite (Object_Mappings) khi quét nhận diện vật thể bằng AI.
class VocabularyDetailBottomSheet extends StatefulWidget {
  final Recognition recognition;

  const VocabularyDetailBottomSheet({
    super.key,
    required this.recognition,
  });

  /// Hàm tiện ích mở Bottom Sheet
  static Future<void> show(BuildContext context, Recognition recognition) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VocabularyDetailBottomSheet(recognition: recognition),
    );
  }

  @override
  State<VocabularyDetailBottomSheet> createState() =>
      _VocabularyDetailBottomSheetState();
}

class _VocabularyDetailBottomSheetState
    extends State<VocabularyDetailBottomSheet> {
  final FlutterTts _flutterTts = FlutterTts();
  ObjectMappingModel? _mapping;
  bool _isLoading = true;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadVocabularyData();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.45);
  }

  Future<void> _loadVocabularyData() async {
    final label = widget.recognition.label;
    final mapping = await DatabaseHelper.instance.getMappingByLabel(label);

    if (!mounted) return;
    final currentUser = context.read<AuthProvider>().currentUser;
    bool saved = false;
    if (currentUser != null && currentUser.id != null) {
      saved = await DatabaseHelper.instance.isWordSaved(currentUser.id!, label);
    }

    if (mounted) {
      setState(() {
        _mapping = mapping;
        _isSaved = saved;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToNotebook() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null || currentUser.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để lưu từ vào sổ tay!'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (_mapping == null) return;

    final item = VocabularyItemModel(
      userId: currentUser.id!,
      label: _mapping!.label,
      word: _mapping!.academicWord.isNotEmpty
          ? _mapping!.academicWord
          : _mapping!.commonWord,
      ipa: _mapping!.ipa,
      translation: _mapping!.vietnameseMeaning,
      example: _mapping!.speakingPart1Example,
      exampleTranslation: _mapping!.speakingPart1Translation,
      bandScore: _mapping!.bandScore,
      collocations: _mapping!.collocations.join('; '),
      idioms: _mapping!.idioms,
      createdAt: DateTime.now().toIso8601String(),
    );

    await DatabaseHelper.instance.insertNotebookItem(item);

    if (mounted) {
      setState(() => _isSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã lưu "${_mapping!.commonWord}" vào Sổ tay từ vựng!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar kéo trượt
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Nội dung chính
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              : Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const Divider(height: 24, thickness: 1),
                        _buildMainWordSection(),
                        const SizedBox(height: 16),
                        _buildCollocationsSection(),
                        _buildIdiomsSection(),
                        _buildSpeakingSection(),
                        const SizedBox(height: 16),
                        _buildConfidenceInfo(),
                        const SizedBox(height: 20),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  /// Tiêu đề + Nhãn phát hiện + Band Score Badge
  Widget _buildHeader() {
    final label = widget.recognition.label;
    final band = _mapping?.bandScore ?? '7.0';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.center_focus_strong_rounded,
            color: AppColors.primary,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI DETECTED OBJECT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
        // Badge Band Score
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                'Band $band',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Phần hiển thị Từ vựng học thuật + Nghĩa tiếng Việt + Phát âm
  Widget _buildMainWordSection() {
    final academic = _mapping?.academicWord ?? widget.recognition.label;
    final common = _mapping?.commonWord ?? widget.recognition.label;
    final vietnamese = _mapping?.vietnameseMeaning ?? 'Đang cập nhật nghĩa';
    final ipa = _mapping?.ipa ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  academic,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                    height: 1.2,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () {
                  final wordToSpeak = academic.contains('/')
                      ? academic.split('/').first.trim()
                      : common;
                  _flutterTts.speak(wordToSpeak);
                },
                icon: const Icon(Icons.volume_up_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  foregroundColor: AppColors.primary,
                ),
                tooltip: 'Nghe phát âm',
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Phiên âm IPA + Từ thông dụng ZIM
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              if (ipa.isNotEmpty)
                Text(
                  ipa,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Base: $common',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Bản dịch tiếng Việt nổi bật
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🇻🇳 ',
                style: TextStyle(fontSize: 16),
              ),
              Expanded(
                child: Text(
                  vietnamese,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD61C2C),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Mục Collocations có giải nghĩa tiếng Việt
  Widget _buildCollocationsSection() {
    final collocations = _mapping?.collocations ?? [];
    if (collocations.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_stories_rounded,
                  size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Collocations (Cụm từ ghi điểm)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...collocations.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  /// Mục Idioms theo chủ đề
  Widget _buildIdiomsSection() {
    final idioms = _mapping?.idioms ?? '';
    if (idioms.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_rounded,
                color: Color(0xFFD97706), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Topic Idiom (Thành ngữ chủ đề)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    idioms,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF78350F),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mục Ví dụ IELTS Speaking Part 1 song ngữ
  Widget _buildSpeakingSection() {
    final example = _mapping?.speakingPart1Example ?? '';
    final trans = _mapping?.speakingPart1Translation ?? '';
    if (example.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.record_voice_over_rounded,
                  size: 20, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'IELTS Speaking Sample (Part 1)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '"$example"',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                          color: AppColors.navy,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_up_outlined, size: 20),
                      color: AppColors.primary,
                      onPressed: () => _flutterTts.speak(example),
                      tooltip: 'Nghe cả câu',
                    ),
                  ],
                ),
                if (trans.isNotEmpty) ...[
                  const Divider(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('👉 ', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Text(
                          trans,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Colors.grey[800],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Thông tin độ tin cậy AI
  Widget _buildConfidenceInfo() {
    final conf = (widget.recognition.confidence * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology_rounded,
              color: Colors.blueAccent, size: 18),
          const SizedBox(width: 8),
          Text(
            'YOLOv8n Confidence: $conf%',
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Nút LƯU VÀO SỔ TAY THỰC TẾ
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSaved ? null : _saveToNotebook,
        icon: Icon(
          _isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_add_rounded,
          size: 22,
        ),
        label: Text(
          _isSaved ? 'ĐÃ LƯU TRONG SỔ TAY' : 'LƯU VÀO SỔ TAY TỪ VỰNG',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isSaved ? Colors.grey[400] : AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: _isSaved ? 0 : 2,
        ),
      ),
    );
  }
}
