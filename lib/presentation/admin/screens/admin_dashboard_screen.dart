import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/api_service.dart';
import '../../../data/models/object_mapping_model.dart';
import '../../../data/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/mapping_edit_sheet.dart';
import '../widgets/user_create_dialog.dart';
import '../widgets/skill_lesson_edit_dialog.dart';
import '../widgets/skill_import_dialog.dart';

/// Màn hình Quản trị viên Toàn diện (Admin Dashboard)
/// Hoàn thiện Phase 4 đồ án IELTS Vision:
/// 1. Báo cáo KPIs hệ thống (Tổng từ vựng AI, Người dùng, Sổ tay, Model AI).
/// 2. Quản lý toàn bộ 82 nhãn Object_Mappings (Tìm kiếm, Lọc band, Nghe thử TTS, Thêm/Sửa/Xóa).
/// 3. Quản trị 4 Kỹ năng & 5 Ải Vượt bài (CRUD + Import File Đề thi).
/// 4. Quản lý phân quyền tài khoản (Users RBAC) và Khôi phục dữ liệu gốc.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentTabIndex = 0;
  bool _isLoading = true;

  // KPIs
  int _totalMappings = 0;
  int _totalUsers = 0;
  int _totalLearners = 0;
  int _totalSavedNotebook = 0;
  Map<String, int> _bandDistribution = {};

  // Object Mappings
  List<ObjectMappingModel> _allMappings = [];
  List<ObjectMappingModel> _filteredMappings = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedBandFilter = 'Tất cả';
  final List<String> _bandOptions = ['Tất cả', 'Band 7.0', 'Band 7.5', 'Band 8.0', 'Band 8.5'];

  // 4 Kỹ Năng & 5 Ải IELTS
  String _selectedSkill = 'reading';
  List<Map<String, dynamic>> _skillLessons = [];
  bool _isLoadingSkills = false;
  final TextEditingController _skillSearchController = TextEditingController();
  int? _selectedStageFilter;

  // Users
  List<UserModel> _users = [];

  // TTS
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadAllData();
    _searchController.addListener(_applyFilter);
    _skillSearchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _skillSearchController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
    } catch (_) {}
  }

  /// Nạp toàn bộ dữ liệu từ FastAPI Backend (hoặc fallback SQLite)
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Thử tải qua FastAPI backend
      try {
        final kpis = await ApiService.instance.getAdminKpis();
        final mappings = await ApiService.instance.getMappings();
        final users = await ApiService.instance.getAllUsers();

        if (mappings.isNotEmpty) {
          final bandDistRaw = kpis['band_distribution'] as Map<String, dynamic>? ?? {};
          final Map<String, int> bandDist = {};
          bandDistRaw.forEach((k, v) {
            final cleanKey = k.replaceAll('Band ', '').trim();
            bandDist[cleanKey] = (v as num).toInt();
          });

          setState(() {
            _allMappings = mappings;
            _users = users;
            _totalMappings = (kpis['total_mappings'] as num?)?.toInt() ?? mappings.length;
            _totalUsers = (kpis['total_users'] as num?)?.toInt() ?? users.length;
            _totalLearners = (kpis['total_learners'] as num?)?.toInt() ?? 0;
            _totalSavedNotebook = ((kpis['total_notebook_items'] ?? kpis['total_saved_notebook']) as num?)?.toInt() ?? 0;
            _bandDistribution = bandDist;
            _isLoading = false;
          });
          _applyFilter();
          _loadSkillLessons();
          return;
        }
      } catch (_) {}

      // 2. Fallback sang SQLite cục bộ
      final db = DatabaseHelper.instance;
      final mappings = await db.getAllMappings();
      final users = await db.getAllUsers();
      final mappingCount = await db.getMappingCount();
      final userCount = await db.getUserCount();
      final learnerCount = await db.getLearnerCount();
      final savedNotebookCount = await db.getTotalNotebookSavedCount();
      final bandDist = await db.getBandDistribution();

      setState(() {
        _allMappings = mappings;
        _users = users;
        _totalMappings = mappingCount;
        _totalUsers = userCount;
        _totalLearners = learnerCount;
        _totalSavedNotebook = savedNotebookCount;
        _bandDistribution = bandDist;
        _isLoading = false;
      });
      _applyFilter();
      _loadSkillLessons();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredMappings = _allMappings.where((item) {
        final matchesQuery = query.isEmpty ||
            item.label.toLowerCase().contains(query) ||
            item.academicWord.toLowerCase().contains(query) ||
            item.commonWord.toLowerCase().contains(query) ||
            item.vietnameseMeaning.toLowerCase().contains(query);

        final matchesBand = _selectedBandFilter == 'Tất cả' ||
            item.bandScore == _selectedBandFilter.replaceAll('Band ', '');

        return matchesQuery && matchesBand;
      }).toList();
    });
  }

  // ─────────────────────────────────────────────────────────────
  // HÀNH ĐỘNG QUẢN TRỊ 4 KỸ NĂNG & 5 ẢI (SKILLS CRUD & IMPORT)
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadSkillLessons() async {
    setState(() => _isLoadingSkills = true);
    try {
      final lessons = await ApiService.instance.getAdminSkillLessons(_selectedSkill);
      if (mounted) {
        setState(() {
          _skillLessons = lessons;
          _isLoadingSkills = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSkills = false);
    }
  }

  Future<void> _showAddSkillLesson() async {
    final success = await SkillLessonEditDialog.show(
      context,
      defaultSkill: _selectedSkill,
    );
    if (success == true) {
      _loadSkillLessons();
    }
  }

  Future<void> _showEditSkillLesson(Map<String, dynamic> lesson) async {
    final success = await SkillLessonEditDialog.show(
      context,
      initialLesson: lesson,
      defaultSkill: _selectedSkill,
    );
    if (success == true) {
      _loadSkillLessons();
    }
  }

  Future<void> _deleteSkillLesson(Map<String, dynamic> lesson) async {
    final lessonId = lesson['id'] as String;
    final title = lesson['title'] as String? ?? lessonId;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa đề thi / ải', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn xóa vĩnh viễn bài thi "$title" ($lessonId)?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.instance.deleteSkillLesson(lessonId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green[700],
              content: Text('Đã xóa bài thi "$title" thành công!'),
            ),
          );
        }
        _loadSkillLessons();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('Lỗi: $e')),
          );
        }
      }
    }
  }

  Future<void> _showImportSkillDialog() async {
    final success = await SkillImportDialog.show(
      context,
      initialSkill: _selectedSkill,
    );
    if (success == true) {
      _loadSkillLessons();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HÀNH ĐỘNG QUẢN TRỊ TỪ VỰNG (MAPPINGS CRUD)
  // ─────────────────────────────────────────────────────────────

  /// Mở form thêm mới nhãn từ vựng
  Future<void> _showAddMapping() async {
    final newMapping = await MappingEditSheet.show(context);
    if (newMapping != null) {
      bool apiSuccess = false;
      try {
        final created = await ApiService.instance.createMapping(newMapping);
        apiSuccess = created.id != null;
      } catch (_) {}

      await DatabaseHelper.instance.insertMapping(newMapping);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green[700],
            content: Text(
              apiSuccess
                  ? '✅ [FastAPI] Đã thêm mới nhãn "${newMapping.label}" thành công!'
                  : '✅ Đã thêm mới nhãn "${newMapping.label}" thành công!',
            ),
          ),
        );
      }
      _loadAllData();
    }
  }

  /// Mở form chỉnh sửa từ vựng
  Future<void> _showEditMapping(ObjectMappingModel mapping) async {
    final updated = await MappingEditSheet.show(context, initialMapping: mapping);
    if (updated != null) {
      bool apiSuccess = false;
      if (updated.id != null) {
        try {
          final res = await ApiService.instance.updateMapping(updated);
          apiSuccess = res.id != null;
        } catch (_) {}
      }

      await DatabaseHelper.instance.updateMapping(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green[700],
            content: Text(
              apiSuccess
                  ? '✅ [FastAPI] Đã cập nhật từ vựng cho "${updated.label}"!'
                  : '✅ Đã cập nhật từ vựng cho "${updated.label}"!',
            ),
          ),
        );
      }
      _loadAllData();
    }
  }

  /// Xóa nhãn từ vựng
  Future<void> _deleteMapping(ObjectMappingModel mapping) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa từ vựng', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Bạn có chắc muốn xóa nhãn "${mapping.label}" (${mapping.academicWord}) khỏi kho từ điển AI không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirm == true && mapping.id != null) {
      try {
        await ApiService.instance.deleteMapping(mapping.id!);
      } catch (_) {}

      await DatabaseHelper.instance.deleteMapping(mapping.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa nhãn "${mapping.label}"')),
        );
      }
      _loadAllData();
    }
  }

  /// Khôi phục toàn bộ 82 nhãn IELTS gốc từ JSON
  Future<void> _resetDefaultMappings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Khôi phục dữ liệu gốc', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Thao tác này sẽ đặt lại toàn bộ 82 nhãn nhận diện AI IELTS chuẩn học thuật từ file JSON hệ thống. Bạn có chắc chắn không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Đồng ý khôi phục'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await ApiService.instance.resetDefaultMappings();
      } catch (_) {}

      await DatabaseHelper.instance.resetDefaultMappings();
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('✅ Đã khôi phục hoàn chỉnh 82 nhãn IELTS gốc!'),
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HÀNH ĐỘNG QUẢN TRỊ TÀI KHOẢN (USERS)
  // ─────────────────────────────────────────────────────────────

  Future<void> _showAddUser() async {
    final result = await UserCreateDialog.show(context);
    if (result != null) {
      final username = result['username']!;
      final password = result['password']!;
      final role = result['role']!;

      try {
        bool apiSuccess = false;
        try {
          final u = await ApiService.instance.createUser(
            username: username,
            password: password,
            role: role,
          );
          apiSuccess = u.id != null;
        } catch (_) {}

        await DatabaseHelper.instance.insertUser(
          username: username,
          password: password,
          role: role,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green[700],
              content: Text(
                apiSuccess
                    ? '✅ [FastAPI] Đã tạo tài khoản $role: "$username" thành công!'
                    : '✅ Đã tạo tài khoản $role: "$username" thành công!',
              ),
            ),
          );
        }
        _loadAllData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: Colors.red, content: Text('Lỗi: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteUser(UserModel targetUser) async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser?.id == targetUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('⚠️ Bạn không thể xóa tài khoản Admin đang đăng nhập!'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa người dùng', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn xóa tài khoản "${targetUser.username}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );

    if (confirm == true && targetUser.id != null) {
      try {
        await ApiService.instance.deleteUser(targetUser.id!);
      } catch (_) {}

      await DatabaseHelper.instance.deleteUser(targetUser.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa tài khoản "${targetUser.username}"')),
        );
      }
      _loadAllData();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GIAO DIỆN CHÍNH
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 20),
                SizedBox(width: 6),
                Text(
                  'IELTS Vision Admin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Text(
              'Quản trị viên: ${user?.username ?? 'admin'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[300]),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới dữ liệu',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadAllData,
          ),
          IconButton(
            tooltip: 'Khôi phục 82 từ mặc định',
            icon: const Icon(Icons.settings_backup_restore_rounded, color: Colors.amber),
            onPressed: _resetDefaultMappings,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => _confirmLogout(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadAllData,
              color: AppColors.primary,
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  _buildOverviewTab(),
                  _buildMappingsTab(),
                  _buildSkillsTab(),
                  _buildUsersTab(),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() => _currentTabIndex = index);
            if (index == 2) {
              _loadSkillLessons();
            }
          },
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey[500],
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Tổng quan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_stories_rounded),
              label: 'Kho từ vựng AI',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.military_tech_rounded),
              label: '4 Kỹ năng & Ải',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.manage_accounts_rounded),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
      floatingActionButton: _currentTabIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _showAddMapping,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Thêm nhãn mới',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : _currentTabIndex == 2
              ? FloatingActionButton.extended(
                  onPressed: _showAddSkillLesson,
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.add_task_rounded, color: Colors.white),
                  label: const Text(
                    'Thêm đề/ải mới',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              : null,
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đăng xuất Admin', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Bạn có muốn đăng xuất khỏi trang quản trị không?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Ở lại')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 0: TỔNG QUAN & BÁO CÁO HỆ THỐNG (KPIs & ANALYTICS)
  // ─────────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // Trạng thái AI Model
        _buildAiStatusCard(),
        const SizedBox(height: 16),

        // Grid 4 thẻ KPI
        const Text(
          'Chỉ số Hoạt động Hệ thống (KPIs)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.30,
          children: [
            _buildKpiCard(
              title: 'Từ vựng AI',
              value: '$_totalMappings từ',
              subtitle: '80+ nhãn COCO chuẩn ZIM',
              icon: Icons.menu_book_rounded,
              color: Colors.indigo,
            ),
            _buildKpiCard(
              title: 'Người dùng',
              value: '$_totalUsers TK',
              subtitle: 'Phân quyền RBAC',
              icon: Icons.people_alt_rounded,
              color: Colors.blue,
            ),
            _buildKpiCard(
              title: 'Học viên',
              value: '$_totalLearners HV',
              subtitle: 'Đang luyện thi',
              icon: Icons.school_rounded,
              color: Colors.teal,
            ),
            _buildKpiCard(
              title: 'Sổ tay đã lưu',
              value: '$_totalSavedNotebook từ',
              subtitle: 'Học viên tương tác',
              icon: Icons.bookmark_added_rounded,
              color: Colors.amber[800]!,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Phân bố từ vựng theo Band điểm
        _buildBandDistributionCard(),
        const SizedBox(height: 20),

        // Phím tắt thao tác nhanh
        const Text(
          'Thao tác Quản trị Nhanh',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.add_circle_outline_rounded,
                title: 'Thêm nhãn AI',
                color: AppColors.primary,
                onTap: _showAddMapping,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Thêm tài khoản',
                color: Colors.teal,
                onTap: _showAddUser,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildQuickActionButton(
          icon: Icons.settings_backup_restore_rounded,
          title: 'Khôi phục 82 nhãn IELTS gốc (Default Seeding)',
          color: Colors.orange[800]!,
          onTap: _resetDefaultMappings,
        ),
      ],
    );
  }

  Widget _buildAiStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sensors_rounded, color: Colors.greenAccent, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Vision Pipeline: YOLOv8n TFLite',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Letterbox 640x640 • Cross-Class NMS • On-Device',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ONLINE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildAiStatItem('Mô hình', 'yolov8n_float32.tflite'),
              const SizedBox(width: 8),
              _buildAiStatItem('Bộ nhãn', '80 COCO Objects'),
              const SizedBox(width: 8),
              _buildAiStatItem('Độ trễ', '< 35ms Offline'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAiStatItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBandDistributionCard() {
    final total = _totalMappings == 0 ? 1 : _totalMappings;
    final b70 = _bandDistribution['7.0'] ?? 0;
    final b75 = _bandDistribution['7.5'] ?? 0;
    final b80 = _bandDistribution['8.0'] ?? 0;
    final b85 = _bandDistribution['8.5'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Phân bố Từ vựng theo Band IELTS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tổng: $_totalMappings nhãn',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBandBar('Band 7.0', b70, total, Colors.blue),
          const SizedBox(height: 8),
          _buildBandBar('Band 7.5', b75, total, Colors.teal),
          const SizedBox(height: 8),
          _buildBandBar('Band 8.0', b80, total, const Color(0xFF10B981)),
          const SizedBox(height: 8),
          _buildBandBar('Band 8.5', b85, total, Colors.amber[800]!),
        ],
      ),
    );
  }

  Widget _buildBandBar(String label, int count, int total, Color color) {
    final double percent = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(
              '$count từ (${(percent * 100).toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: Colors.grey[100],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: KHO TỪ VỰNG AI (OBJECT MAPPINGS MANAGEMENT - 82 NHÃN)
  // ─────────────────────────────────────────────────────────────

  Widget _buildMappingsTab() {
    return Column(
      children: [
        // Thanh tìm kiếm & lọc Band
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm theo nhãn COCO, từ học thuật, nghĩa TV...',
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _bandOptions.map((band) {
                          final isSelected = _selectedBandFilter == band;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text(
                                band,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                              backgroundColor: Colors.grey[100],
                              selectedColor: AppColors.primary,
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected ? AppColors.primary : Colors.grey[300]!,
                                ),
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedBandFilter = band;
                                  _applyFilter();
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_filteredMappings.length}/${_allMappings.length} từ',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Danh sách từ vựng
        Expanded(
          child: _filteredMappings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 54, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Không tìm thấy nhãn từ vựng phù hợp',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: _filteredMappings.length,
                  itemBuilder: (ctx, index) {
                    final item = _filteredMappings[index];
                    return _buildMappingItemCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMappingItemCard(ObjectMappingModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Band badge + COCO Label chip + TTS + Edit + Delete (Chống tràn pixel)
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Band badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Band ${item.bandScore}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // COCO Label với Flexible và TextOverflow.ellipsis để không bao giờ bị tràn
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueGrey[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.tag_rounded, size: 12, color: Colors.blueGrey),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Action Buttons với kích thước gọn gàng
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 20),
                      tooltip: 'Nghe phát âm',
                      onPressed: () {
                        final wordToSpeak = item.academicWord.contains('/')
                            ? item.academicWord.split('/').first.trim()
                            : item.academicWord;
                        _flutterTts.speak(wordToSpeak);
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 21),
                      tooltip: 'Chỉnh sửa từ vựng',
                      onPressed: () => _showEditMapping(item),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 19),
                      tooltip: 'Xóa nhãn',
                      onPressed: () => _deleteMapping(item),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Academic Target Word
            Text(
              item.academicWord,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 2),

            // IPA + Common Word (với Flexible chống tràn)
            Row(
              children: [
                Flexible(
                  child: Text(
                    item.ipa,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                if (item.commonWord.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '(${item.commonWord})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Nghĩa tiếng Việt
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🇻🇳 ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Text(
                    item.vietnameseMeaning,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD61C2C),
                    ),
                  ),
                ),
              ],
            ),

            // Collocations & Idioms snippet (nếu có)
            if (item.collocations.isNotEmpty || item.idioms.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.collocations.isNotEmpty)
                      Text(
                        'Collocations: ${item.collocations.take(2).join("; ")}',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (item.idioms.isNotEmpty)
                      Text(
                        'Idiom: ${item.idioms}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3: QUẢN TRỊ 4 KỸ NĂNG & 5 ẢI (SKILLS & 5 STAGES MANAGEMENT)
  // ─────────────────────────────────────────────────────────────

  Widget _buildSkillsTab() {
    // Lọc bài học theo từ khóa tìm kiếm và ải
    final query = _skillSearchController.text.trim().toLowerCase();
    final filtered = _skillLessons.where((lesson) {
      final title = (lesson['title'] as String? ?? '').toLowerCase();
      final topic = (lesson['category_or_topic'] as String? ?? '').toLowerCase();
      final stage = (lesson['stage_number'] as num?)?.toInt() ?? 1;

      final matchesQuery = query.isEmpty || title.contains(query) || topic.contains(query);
      final matchesStage = _selectedStageFilter == null || stage == _selectedStageFilter;

      return matchesQuery && matchesStage;
    }).toList();

    // Sắp xếp theo số ải tăng dần
    filtered.sort((a, b) {
      final sA = (a['stage_number'] as num?)?.toInt() ?? 1;
      final sB = (b['stage_number'] as num?)?.toInt() ?? 1;
      return sA.compareTo(sB);
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // 1. Header & Actions Bar
        Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.military_tech_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quản lý Đề thi & 5 Ải Vượt bài IELTS',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Toàn quyền Thêm/Sửa/Xóa và Nạp đề thi hàng loạt từ file cho 4 kỹ năng:',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Action Buttons
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showImportSkillDialog,
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: const Text('Import File Đề Thi (.json/.xlsx)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddSkillLesson,
                      icon: const Icon(Icons.add_task_rounded, color: Colors.white, size: 18),
                      label: const Text('Thêm Ải / Đề thi Mới'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 2. Chuyển đổi 4 Kỹ năng (Skill Tabs)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSkillPill('reading', '📖 Reading', Icons.menu_book_rounded),
              const SizedBox(width: 8),
              _buildSkillPill('listening', '🎧 Listening', Icons.headphones_rounded),
              const SizedBox(width: 8),
              _buildSkillPill('writing', '✍️ Writing', Icons.edit_note_rounded),
              const SizedBox(width: 8),
              _buildSkillPill('speaking', '🗣️ Speaking', Icons.record_voice_over_rounded),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Search Bar & Bộ lọc Ải (Stage 1 -> 5)
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _skillSearchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo tiêu đề hoặc chủ đề...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _skillSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _skillSearchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Filter chips cho các Ải
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const Text('Lọc theo ải: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Tất cả'),
                selected: _selectedStageFilter == null,
                onSelected: (val) => setState(() => _selectedStageFilter = null),
              ),
              ...List.generate(
                _skillLessons
                    .map((l) => (l['stage_number'] as num?)?.toInt() ?? 1)
                    .fold(5, (prev, curr) => curr > prev ? curr : prev),
                (i) => i + 1,
              ).map((stg) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('Ải $stg'),
                    selected: _selectedStageFilter == stg,
                    onSelected: (val) => setState(() => _selectedStageFilter = val ? stg : null),
                  ),
                );
              }),

            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Danh sách các bài thi / ải
        if (_isLoadingSkills) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ] else if (filtered.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.layers_clear_rounded, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 10),
                Text(
                  'Chưa có bài thi nào cho ${_selectedSkill.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bạn có thể bấm "Thêm Ải / Đề thi Mới" hoặc "Import File Đề Thi" để bắt đầu.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else ...[
          ...filtered.map((lesson) => _buildSkillLessonCard(lesson)),
        ],
      ],
    );
  }

  Widget _buildSkillPill(String skillKey, String label, IconData icon) {
    final isSelected = _selectedSkill == skillKey;

    return InkWell(
      onTap: () {
        if (_selectedSkill != skillKey) {
          setState(() {
            _selectedSkill = skillKey;
            _selectedStageFilter = null;
          });
          _loadSkillLessons();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillLessonCard(Map<String, dynamic> lesson) {
    final stageNum = (lesson['stage_number'] as num?)?.toInt() ?? 1;
    final title = lesson['title'] as String? ?? 'Chưa đặt tiêu đề';
    final topic = lesson['category_or_topic'] as String? ?? 'General';
    final diffLabel = lesson['difficulty_label'] as String? ?? 'Ải $stageNum';
    final targetBand = lesson['target_band'] ?? lesson['band_score_target'] ?? '7.0';
    final passCond = lesson['pass_condition'] as Map<String, dynamic>? ?? {};
    final passReq = lesson['pass_score_required'];

    String passText = '';
    if (_selectedSkill == 'reading' || _selectedSkill == 'listening') {
      final minC = passCond['min_correct'] ?? passReq ?? 2;
      passText = 'Đúng tối thiểu: $minC câu để qua ải';
    } else if (_selectedSkill == 'writing') {
      final minW = passCond['min_words'] ?? 150;
      final minB = passCond['min_band'] ?? 6.0;
      passText = 'Tối thiểu: $minW từ (Band >= $minB)';
    } else {
      final minB = passCond['min_band'] ?? 6.0;
      passText = 'Band trung bình >= $minB để qua ải';
    }

    final content = lesson['content_json'] as Map<String, dynamic>? ?? {};
    String detailSummary = '';
    if (_selectedSkill == 'reading' || _selectedSkill == 'listening') {
      final qList = content['questions'] as List<dynamic>? ?? [];
      detailSummary = 'Tổng số: ${qList.length} câu hỏi trắc nghiệm';
    } else if (_selectedSkill == 'writing') {
      final taskType = content['taskType'] as String? ?? 'Task 2';
      detailSummary = 'Dạng bài: $taskType • Có bài văn mẫu Band 8.0+';
    } else {
      detailSummary = 'Gồm câu hỏi Part 1 & Đề bài Part 2 Cue Card';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Badges & Actions (Chống tràn pixel)
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Stage Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ẢI $stageNum',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Target Band Badge
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber[700]!.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 14, color: Colors.amber[800]),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  'Target Band $targetBand',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.amber[900],
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Action buttons (Edit & Delete)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                      tooltip: 'Chỉnh sửa bài thi',
                      onPressed: () => _showEditSkillLesson(lesson),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      tooltip: 'Xóa bài thi',
                      onPressed: () => _deleteSkillLesson(lesson),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title & Difficulty
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.5,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$diffLabel • Chủ đề: $topic',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),

            // Pass condition chip & details
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      passText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  Text(
                    detailSummary,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 4: QUẢN TRỊ TÀI KHOẢN (USER RBAC MANAGEMENT)
  // ─────────────────────────────────────────────────────────────

  Widget _buildUsersTab() {
    final currentUser = context.read<AuthProvider>().currentUser;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Người dùng Hệ thống',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  Text(
                    'Tổng cộng: ${_users.length} tài khoản',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _showAddUser,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Thêm mới', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Danh sách tài khoản
        ..._users.map((u) {
          final isCurrent = u.id == currentUser?.id;
          final isAdmin = u.role == 'admin';

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isCurrent ? AppColors.primary.withValues(alpha: 0.5) : Colors.grey[200]!,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isAdmin ? Colors.amber[100] : Colors.blue[50],
                    child: Icon(
                      isAdmin ? Icons.security_rounded : Icons.person_rounded,
                      color: isAdmin ? Colors.amber[900] : Colors.blue[700],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                u.username,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'HIỆN TẠI',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tạo lúc: ${u.createdAt.length >= 10 ? u.createdAt.substring(0, 10) : u.createdAt}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAdmin ? Colors.purple[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isAdmin ? Colors.purple[200]! : Colors.green[200]!,
                      ),
                    ),
                    child: Text(
                      u.role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isAdmin ? Colors.purple[700] : Colors.green[700],
                      ),
                    ),
                  ),
                  if (!isCurrent) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 22),
                      tooltip: 'Xóa tài khoản',
                      onPressed: () => _deleteUser(u),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
