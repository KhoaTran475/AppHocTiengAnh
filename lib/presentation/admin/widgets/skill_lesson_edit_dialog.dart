import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/api_service.dart';

/// Hộp thoại Thêm mới hoặc Chỉnh sửa bài học / ải cho 4 kỹ năng IELTS
/// Thiết kế trực quan 100% dạng Form nhập liệu, Giáo viên / Admin không cần biết lập trình.
class SkillLessonEditDialog extends StatefulWidget {
  final Map<String, dynamic>? initialLesson;
  final String defaultSkill;

  const SkillLessonEditDialog({
    super.key,
    this.initialLesson,
    this.defaultSkill = 'reading',
  });

  static Future<bool?> show(
    BuildContext context, {
    Map<String, dynamic>? initialLesson,
    String defaultSkill = 'reading',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SkillLessonEditDialog(
        initialLesson: initialLesson,
        defaultSkill: defaultSkill,
      ),
    );
  }

  @override
  State<SkillLessonEditDialog> createState() => _SkillLessonEditDialogState();
}

class _SkillLessonEditDialogState extends State<SkillLessonEditDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool get _isEditing => widget.initialLesson != null;

  late String _skillType;
  late int _stageNumber;
  late TextEditingController _stageNumberController;
  late TextEditingController _titleController;
  late TextEditingController _topicController;
  late TextEditingController _difficultyController;
  late TextEditingController _targetBandController;


  // Điều kiện qua ải
  late TextEditingController _minCorrectController;
  late TextEditingController _minWordsController;
  late TextEditingController _minBandController;

  // Reading & Listening
  late TextEditingController _readingParagraphAController;
  late TextEditingController _readingParagraphBController;
  late TextEditingController _audioScriptController;
  List<_EditableQuestion> _questions = [];

  // Writing
  late TextEditingController _writingTaskTypeController;
  late TextEditingController _writingPromptController;
  late TextEditingController _writingOutlineController;
  late TextEditingController _writingSampleController;
  late TextEditingController _writingVocabController;

  // Speaking
  late TextEditingController _speakingPart1QController;
  late TextEditingController _speakingPart1AController;
  late TextEditingController _speakingPart2PromptController;
  late TextEditingController _speakingPart2SampleController;
  late TextEditingController _speakingCollocationsController;

  @override
  void initState() {
    super.initState();
    final item = widget.initialLesson ?? {};

    _skillType = item['skill_type'] as String? ?? widget.defaultSkill;
    _stageNumber = (item['stage_number'] as num?)?.toInt() ?? 1;
    _stageNumberController = TextEditingController(text: _stageNumber.toString());

    _titleController = TextEditingController(text: item['title'] as String? ?? '');

    _topicController = TextEditingController(text: item['category_or_topic'] as String? ?? 'General');
    _difficultyController = TextEditingController(
      text: item['difficulty_label'] as String? ?? 'Ải $_stageNumber: Cấp độ $_stageNumber',
    );
    _targetBandController = TextEditingController(
      text: (item['target_band'] ?? item['band_score_target'] ?? '7.0').toString(),
    );

    // Pass conditions
    final passCond = item['pass_condition'] as Map<String, dynamic>? ?? {};
    final passReq = item['pass_score_required'] as num? ?? 2;
    _minCorrectController = TextEditingController(
      text: (passCond['min_correct'] ?? passReq).toString(),
    );
    _minWordsController = TextEditingController(
      text: (passCond['min_words'] ?? 150).toString(),
    );
    _minBandController = TextEditingController(
      text: (passCond['min_band'] ?? 6.0).toString(),
    );

    // Reading & Listening Content
    final content = item['content_json'] as Map<String, dynamic>? ?? {};
    final paragraphs = content['paragraphs'] as Map<String, dynamic>? ?? {};
    _readingParagraphAController = TextEditingController(text: paragraphs['A'] as String? ?? '');
    _readingParagraphBController = TextEditingController(text: paragraphs['B'] as String? ?? '');
    _audioScriptController = TextEditingController(text: content['audioScript'] as String? ?? '');

    // Parse Questions
    final rawQuestions = content['questions'] as List<dynamic>? ?? [];
    if (rawQuestions.isNotEmpty) {
      _questions = rawQuestions.map((q) {
        final opts = (q['options'] as List<dynamic>? ?? []).map((o) => o.toString()).toList();
        return _EditableQuestion(
          questionText: q['questionText'] as String? ?? '',
          optionA: opts.isNotEmpty ? opts[0] : '',
          optionB: opts.length > 1 ? opts[1] : '',
          optionC: opts.length > 2 ? opts[2] : '',
          optionD: opts.length > 3 ? opts[3] : '',
          correctAnswer: q['correctAnswer'] as String? ?? '',
          explanation: q['explanation'] as String? ?? '',
        );
      }).toList();
    } else if (_skillType == 'reading' || _skillType == 'listening') {
      _questions = [
        _EditableQuestion(
          questionText: 'Câu hỏi số 1?',
          optionA: 'Lựa chọn A',
          optionB: 'Lựa chọn B',
          optionC: 'Lựa chọn C',
          optionD: 'Lựa chọn D',
          correctAnswer: 'Lựa chọn A',
          explanation: 'Giải thích vì sao đúng...',
        ),
      ];
    }

    // Writing Content
    _writingTaskTypeController = TextEditingController(text: content['taskType'] as String? ?? 'Task 2');
    _writingPromptController = TextEditingController(text: content['prompt'] as String? ?? '');
    final outlines = (content['keyOutline'] as List<dynamic>? ?? []).join('\n');
    _writingOutlineController = TextEditingController(text: outlines);
    _writingSampleController = TextEditingController(text: content['sampleEssay'] as String? ?? '');
    final vocabs = (content['academicVocabulary'] as List<dynamic>? ?? []).join(', ');
    _writingVocabController = TextEditingController(text: vocabs);

    // Speaking Content
    final part1List = content['part1Questions'] as List<dynamic>? ?? [];
    final firstPart1 = part1List.isNotEmpty ? part1List[0] as Map<String, dynamic> : {};
    _speakingPart1QController = TextEditingController(text: firstPart1['question'] as String? ?? '');
    _speakingPart1AController = TextEditingController(text: firstPart1['sampleAnswer'] as String? ?? '');
    _speakingPart2PromptController = TextEditingController(text: content['part2CueCardPrompt'] as String? ?? '');
    _speakingPart2SampleController = TextEditingController(text: content['part2SampleAnswer'] as String? ?? '');
    final colocs = (content['part2Collocations'] as List<dynamic>? ?? []).join(', ');
    _speakingCollocationsController = TextEditingController(text: colocs);
  }

  @override
  void dispose() {
    _stageNumberController.dispose();
    _titleController.dispose();

    _topicController.dispose();
    _difficultyController.dispose();
    _targetBandController.dispose();
    _minCorrectController.dispose();
    _minWordsController.dispose();
    _minBandController.dispose();
    _readingParagraphAController.dispose();
    _readingParagraphBController.dispose();
    _audioScriptController.dispose();
    _writingTaskTypeController.dispose();
    _writingPromptController.dispose();
    _writingOutlineController.dispose();
    _writingSampleController.dispose();
    _writingVocabController.dispose();
    _speakingPart1QController.dispose();
    _speakingPart1AController.dispose();
    _speakingPart2PromptController.dispose();
    _speakingPart2SampleController.dispose();
    _speakingCollocationsController.dispose();
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(
        _EditableQuestion(
          questionText: 'Câu hỏi mới số ${_questions.length + 1}',
          optionA: 'Lựa chọn A',
          optionB: 'Lựa chọn B',
          optionC: 'Lựa chọn C',
          optionD: 'Lựa chọn D',
          correctAnswer: 'Lựa chọn A',
          explanation: '',
        ),
      );
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length > 1) {
      setState(() => _questions.removeAt(index));
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Đóng gói content_json theo từng kỹ năng
      final Map<String, dynamic> contentJson = {};

      if (_skillType == 'reading') {
        contentJson['paragraphs'] = {
          'A': _readingParagraphAController.text.trim(),
          if (_readingParagraphBController.text.trim().isNotEmpty)
            'B': _readingParagraphBController.text.trim(),
        };
        contentJson['questions'] = _questions.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;
          return {
            'id': idx + 1,
            'questionText': q.questionText,
            'options': [q.optionA, q.optionB, q.optionC, q.optionD],
            'correctAnswer': q.correctAnswer,
            'explanation': q.explanation,
            'paragraphRef': 'Đoạn A',
          };
        }).toList();
      } else if (_skillType == 'listening') {
        contentJson['audioScript'] = _audioScriptController.text.trim();
        contentJson['questions'] = _questions.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;
          return {
            'id': idx + 1,
            'questionText': q.questionText,
            'options': [q.optionA, q.optionB, q.optionC, q.optionD],
            'correctAnswer': q.correctAnswer,
            'explanation': q.explanation,
          };
        }).toList();
      } else if (_skillType == 'writing') {
        contentJson['taskType'] = _writingTaskTypeController.text.trim();
        contentJson['prompt'] = _writingPromptController.text.trim();
        contentJson['minWordCount'] = int.tryParse(_minWordsController.text.trim()) ?? 150;
        contentJson['keyOutline'] = _writingOutlineController.text
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        contentJson['sampleEssay'] = _writingSampleController.text.trim();
        contentJson['academicVocabulary'] = _writingVocabController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      } else if (_skillType == 'speaking') {
        contentJson['part1Questions'] = [
          {
            'question': _speakingPart1QController.text.trim(),
            'sampleAnswer': _speakingPart1AController.text.trim(),
            'keyVocabulary': ['fluent', 'academic'],
          }
        ];
        contentJson['part2CueCardPrompt'] = _speakingPart2PromptController.text.trim();
        contentJson['part2SampleAnswer'] = _speakingPart2SampleController.text.trim();
        contentJson['part2Collocations'] = _speakingCollocationsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      // Đóng gói điều kiện qua ải
      final Map<String, dynamic> passCondition = {};
      int? passScoreReq;
      if (_skillType == 'reading' || _skillType == 'listening') {
        passScoreReq = int.tryParse(_minCorrectController.text.trim()) ?? 2;
        passCondition['min_correct'] = passScoreReq;
      } else if (_skillType == 'writing') {
        passCondition['min_words'] = int.tryParse(_minWordsController.text.trim()) ?? 150;
        passCondition['min_band'] = double.tryParse(_minBandController.text.trim()) ?? 6.0;
      } else {
        passCondition['min_band'] = double.tryParse(_minBandController.text.trim()) ?? 6.0;
      }

      final targetBand = double.tryParse(_targetBandController.text.trim()) ?? 7.0;
      final parsedStage = int.tryParse(_stageNumberController.text.trim()) ?? _stageNumber;
      _stageNumber = parsedStage >= 1 ? parsedStage : 1;

      final payload = {
        'skill_type': _skillType,
        'stage_number': _stageNumber,

        'title': _titleController.text.trim(),
        'category_or_topic': _topicController.text.trim(),
        'difficulty_label': _difficultyController.text.trim(),
        'target_band': targetBand,
        'band_score_target': targetBand.toString(),
        'pass_score_required': passScoreReq,
        'pass_condition': passCondition,
        'content_json': contentJson,
      };

      if (_isEditing) {
        final lessonId = widget.initialLesson!['id'] as String;
        await ApiService.instance.updateSkillLesson(lessonId, payload);
      } else {
        await ApiService.instance.createSkillLesson(payload);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green[700],
          content: Text(
            _isEditing
                ? '✅ Đã cập nhật ải "$_stageNumber - ${_titleController.text}" thành công!'
                : '✅ Đã tạo mới ải "$_stageNumber - ${_titleController.text}" thành công!',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Lỗi: ${e.toString().replaceAll("Exception: ", "")}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    _isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isEditing
                          ? 'Chỉnh sửa (${widget.initialLesson!['id']})'
                          : 'Thêm mới Đề thi & Cấu hình Ải',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Form body scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Thông tin cơ bản & Cấu hình Ải
                      _buildSectionTitle('1. Thông tin Cơ bản & Phân cấp Ải'),
                      const SizedBox(height: 10),
                      // Hàng 1: Kỹ năng (Toàn bộ chiều ngang)
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _skillType,
                        decoration: const InputDecoration(labelText: 'Kỹ năng IELTS', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'reading', child: Text('📖 Reading (Đọc hiểu)')),
                          DropdownMenuItem(value: 'listening', child: Text('🎧 Listening (Nghe hiểu)')),
                          DropdownMenuItem(value: 'writing', child: Text('✍️ Writing (Viết luận)')),
                          DropdownMenuItem(value: 'speaking', child: Text('🗣️ Speaking (Luyện nói)')),
                        ],
                        onChanged: _isEditing ? null : (val) {
                          if (val != null) setState(() => _skillType = val);
                        },
                      ),
                      const SizedBox(height: 10),

                      // Hàng 2: Cấp độ Ải & Target Band
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stageNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Cấp độ Ải',
                                hintText: 'Nhập số ải (ví dụ: 1, 2, 6, 7...)',
                                isDense: true,
                                prefixIcon: Icon(Icons.military_tech_rounded, size: 20),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Nhập số ải';
                                final n = int.tryParse(v.trim());
                                if (n == null || n < 1) return 'Số ải >= 1';
                                return null;
                              },
                              onChanged: (val) {
                                final n = int.tryParse(val.trim());
                                if (n != null && n >= 1) {
                                  _stageNumber = n;
                                  if (_difficultyController.text.isEmpty ||
                                      _difficultyController.text.startsWith('Ải ')) {
                                    _difficultyController.text = 'Ải $n: Cấp độ $n';
                                  }
                                }
                              },
                            ),
                          ),

                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _targetBandController,
                              decoration: const InputDecoration(labelText: 'Target Band', hintText: '7.0', isDense: true),
                              keyboardType: TextInputType.number,
                              validator: (v) => v == null || v.isEmpty ? 'Nhập Target Band' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Hàng 3: Chủ đề & Tiêu đề
                      TextFormField(
                        controller: _topicController,
                        decoration: const InputDecoration(labelText: 'Chủ đề bài học (Topic)', isDense: true),
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Tiêu đề đề thi / bài học', isDense: true),
                        validator: (v) => v == null || v.isEmpty ? 'Nhập tiêu đề' : null,
                      ),
                      const SizedBox(height: 14),

                      // Section 2: Điều kiện vượt ải
                      _buildSectionTitle('2. Điều kiện Qua ải (Gamification Pass Condition)'),
                      const SizedBox(height: 10),
                      if (_skillType == 'reading' || _skillType == 'listening') ...[
                        TextFormField(
                          controller: _minCorrectController,
                          decoration: const InputDecoration(
                            labelText: 'Số câu trắc nghiệm đúng tối thiểu để mở khóa ải kế tiếp',
                            hintText: 'Ví dụ: 2',
                            prefixIcon: Icon(Icons.check_circle_outline, color: Colors.green),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.isEmpty ? 'Nhập số câu đúng' : null,
                        ),
                      ] else if (_skillType == 'writing') ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _minWordsController,
                                decoration: const InputDecoration(
                                  labelText: 'Số từ tối thiểu (min_words)',
                                  hintText: '150 hoặc 250',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _minBandController,
                                decoration: const InputDecoration(
                                  labelText: 'Band điểm yêu cầu tối thiểu',
                                  hintText: '6.0',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _minBandController,
                          decoration: const InputDecoration(
                            labelText: 'Band điểm Speaking trung bình tối thiểu để qua ải',
                            hintText: '6.0',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Section 3: Nội dung chi tiết bài học
                      _buildSectionTitle('3. Nội dung Chi tiết Đề thi'),
                      const SizedBox(height: 10),

                      if (_skillType == 'reading') ...[
                        TextFormField(
                          controller: _readingParagraphAController,
                          decoration: const InputDecoration(
                            labelText: 'Đoạn văn A (Học thuật)',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                          validator: (v) => v == null || v.isEmpty ? 'Nhập đoạn văn A' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _readingParagraphBController,
                          decoration: const InputDecoration(
                            labelText: 'Đoạn văn B (Tùy chọn)',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        _buildQuestionsEditor(),
                      ] else if (_skillType == 'listening') ...[
                        TextFormField(
                          controller: _audioScriptController,
                          decoration: const InputDecoration(
                            labelText: 'Kịch bản bài nghe (Audio Script)',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 5,
                          validator: (v) => v == null || v.isEmpty ? 'Nhập nội dung audio script' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildQuestionsEditor(),
                      ] else if (_skillType == 'writing') ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _writingTaskTypeController.text.contains('1') ? 'Task 1' : 'Task 2',
                                decoration: const InputDecoration(labelText: 'Dạng bài Writing'),
                                items: const [
                                  DropdownMenuItem(value: 'Task 1', child: Text('Writing Task 1')),
                                  DropdownMenuItem(value: 'Task 2', child: Text('Writing Task 2')),
                                ],
                                onChanged: (val) {
                                  if (val != null) _writingTaskTypeController.text = val;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _writingPromptController,
                          decoration: const InputDecoration(
                            labelText: 'Đề bài (Writing Prompt)',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                          validator: (v) => v == null || v.isEmpty ? 'Nhập đề bài' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _writingOutlineController,
                          decoration: const InputDecoration(
                            labelText: 'Dàn ý gợi ý (Mỗi dòng một ý)',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _writingSampleController,
                          decoration: const InputDecoration(
                            labelText: 'Bài văn mẫu Band 8.0+',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _writingVocabController,
                          decoration: const InputDecoration(
                            labelText: 'Từ vựng học thuật gợi ý (cách nhau dấu phẩy)',
                          ),
                        ),
                      ] else if (_skillType == 'speaking') ...[
                        TextFormField(
                          controller: _speakingPart1QController,
                          decoration: const InputDecoration(labelText: 'Câu hỏi Part 1'),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _speakingPart1AController,
                          decoration: const InputDecoration(
                            labelText: 'Câu trả lời mẫu Part 1',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _speakingPart2PromptController,
                          decoration: const InputDecoration(
                            labelText: 'Đề bài Part 2 Cue Card',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _speakingPart2SampleController,
                          decoration: const InputDecoration(
                            labelText: 'Bài nói mẫu Part 2 (Band 8.0+)',
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _speakingCollocationsController,
                          decoration: const InputDecoration(
                            labelText: 'Collocations & Idioms (phân cách dấu phẩy)',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(height: 20),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Hủy bỏ'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                    label: Text(
                      _isLoading ? 'Đang lưu...' : (_isEditing ? 'Cập nhật ải' : 'Tạo ải mới'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildQuestionsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Câu hỏi trắc nghiệm (${_questions.length} câu):',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _addQuestion,
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Thêm câu', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._questions.asMap().entries.map((entry) {
          final index = entry.key;
          final q = entry.value;

          return Card(
            key: ObjectKey(q),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: q.questionText,
                          decoration: const InputDecoration(
                            labelText: 'Nội dung câu hỏi',
                            isDense: true,
                          ),
                          onChanged: (val) => q.questionText = val,
                        ),
                      ),
                      if (_questions.length > 1) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          tooltip: 'Xóa câu này',
                          onPressed: () => _removeQuestion(index),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: q.optionA,
                          decoration: const InputDecoration(labelText: 'Đáp án A', isDense: true),
                          onChanged: (val) => q.optionA = val,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: q.optionB,
                          decoration: const InputDecoration(labelText: 'Đáp án B', isDense: true),
                          onChanged: (val) => q.optionB = val,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: q.optionC,
                          decoration: const InputDecoration(labelText: 'Đáp án C', isDense: true),
                          onChanged: (val) => q.optionC = val,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: q.optionD,
                          decoration: const InputDecoration(labelText: 'Đáp án D', isDense: true),
                          onChanged: (val) => q.optionD = val,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: q.correctAnswer,
                    decoration: const InputDecoration(
                      labelText: 'Đáp án đúng (khớp 1 trong 4 lựa chọn)',
                      isDense: true,
                      prefixIcon: Icon(Icons.check, color: Colors.green, size: 18),
                    ),
                    onChanged: (val) => q.correctAnswer = val,
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: q.explanation,
                    decoration: const InputDecoration(
                      labelText: 'Giải thích chi tiết (tùy chọn)',
                      isDense: true,
                    ),
                    onChanged: (val) => q.explanation = val,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _EditableQuestion {
  String questionText;
  String optionA;
  String optionB;
  String optionC;
  String optionD;
  String correctAnswer;
  String explanation;

  _EditableQuestion({
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
    required this.explanation,
  });
}
