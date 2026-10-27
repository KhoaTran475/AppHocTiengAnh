import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/datasources/api_service.dart';
import '../../../data/models/vocabulary_item_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/face_scan_dialog.dart';
import 'camera_scan_screen.dart';
import 'vocabulary_notebook_screen.dart';
import 'reading_practice_screen.dart';
import 'listening_practice_screen.dart';
import 'speaking_practice_screen.dart';
import 'writing_practice_screen.dart';
import '../widgets/saved_vocabulary_detail_bottom_sheet.dart';

/// Khung giao diện chính (App Shell & Navigation) của Học viên (Learner).
/// Tích hợp BottomNavigationBar chuyển đổi linh hoạt giữa Trang chủ, Sổ tay từ vựng và Cá nhân.
class LearnerHomeScreen extends StatefulWidget {
  const LearnerHomeScreen({super.key});

  @override
  State<LearnerHomeScreen> createState() => _LearnerHomeScreenState();
}

class _LearnerHomeScreenState extends State<LearnerHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _LearnerDashboardTab(),
          VocabularyNotebookScreen(),
          _LearnerProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: Colors.white,
        elevation: 4,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded, color: AppColors.primary),
            label: 'Sổ tay từ',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Cá nhân',
          ),
        ],
      ),
      floatingActionButton: _currentIndex != 1
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScanScreen()),
                );
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text(
                'QUÉT AI',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
              ),
            )
          : null,
    );
  }
}

/// Tab Trang chủ học tập (Dashboard)
class _LearnerDashboardTab extends StatefulWidget {
  const _LearnerDashboardTab();

  @override
  State<_LearnerDashboardTab> createState() => _LearnerDashboardTabState();
}

class _LearnerDashboardTabState extends State<_LearnerDashboardTab> {
  int _savedWordsCount = 0;
  List<VocabularyItemModel> _recentWords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      try {
        final words = await ApiService.instance.getNotebookItems();
        if (mounted) {
          setState(() {
            _savedWordsCount = words.length;
            _recentWords = words.take(3).toList();
            _isLoading = false;
          });
          return;
        }
      } catch (_) {}

      if (user.id != null) {
        final count = await DatabaseHelper.instance.getNotebookCountByUser(user.id!);
        final words = await DatabaseHelper.instance.getNotebookItemsByUser(user.id!);

        if (mounted) {
          setState(() {
            _savedWordsCount = count;
            _recentWords = words.take(3).toList();
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.language_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 10),
            const Text(
              'IELTS Vision',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
            onPressed: _loadStats,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded, color: Colors.grey),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Lời chào học viên ──
              Text(
                'Xin chào, ${user?.username ?? "Học viên"}! 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sẵn sàng nâng tầm vốn từ vựng IELTS hôm nay!',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 18),

              // ── Banner "Scan to Learn" điểm nhấn AI ──
              _buildAiScanBanner(context),
              const SizedBox(height: 20),

              // ── Thống kê tiến độ học tập ──
              _buildStatisticsRow(),
              const SizedBox(height: 24),

              // ── Từ vựng vừa lưu gần đây ──
              _buildRecentWordsSection(),
              const SizedBox(height: 24),

              // ── Lộ trình 4 Kỹ năng (Định hướng Cuối kỳ) ──
              _buildCoreSkillsSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// Banner điểm nhấn AI Camera Scan
  Widget _buildAiScanBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'AI ON-DEVICE VISION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.document_scanner_rounded, color: Colors.white70, size: 28),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Scan to Learn - Nhận diện AI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hướng camera vào các đồ vật quanh bạn để học ngay từ vựng IELTS Band 7.0 - 8.5 kèm Collocations & Speaking.',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CameraScanScreen()),
              ).then((_) => _loadStats());
            },
            icon: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
            label: const Text(
              'BẬT CAMERA QUÉT NGAY',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  /// Hàng thống kê KPI học tập
  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            title: 'Từ đã lưu',
            value: _isLoading ? '...' : '$_savedWordsCount',
            unit: 'từ vựng',
            icon: Icons.bookmark_added_rounded,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKpiCard(
            title: 'Kho từ AI',
            value: '82',
            unit: 'vật thể COCO',
            icon: Icons.psychology_rounded,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKpiCard(
            title: 'Mục tiêu',
            value: '7.5+',
            unit: 'IELTS Band',
            icon: Icons.military_tech_rounded,
            color: Colors.deepOrangeAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Mục từ vựng vừa lưu gần đây
  Widget _buildRecentWordsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Từ vựng vừa lưu gần đây',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_recentWords.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                'Mới nhất',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (_recentWords.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.grey[400]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bạn chưa lưu từ vựng nào. Hãy quét camera để thêm từ vào sổ tay!',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          )
        else
          ..._recentWords.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                elevation: 0.5,
                child: ListTile(
                  onTap: () {
                    SavedVocabularyDetailBottomSheet.show(context, item);
                  },
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bookmark_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    item.word,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    '🇻🇳 ${item.translation}',
                    style: const TextStyle(color: Color(0xFFD61C2C), fontSize: 13),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Band ${item.bandScore}',
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  /// Mục định hướng 4 Kỹ năng (Cuối kỳ)
  Widget _buildCoreSkillsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Luyện thi 4 Kỹ năng Chuẩn IELTS',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.0,
          children: [
            _buildSkillTile(
              Icons.headphones_rounded,
              'Listening',
              'Audio Player & Điền từ',
              Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ListeningPracticeScreen()),
                );
              },
            ),
            _buildSkillTile(
              Icons.chrome_reader_mode_rounded,
              'Reading',
              'Học thuật & Tra từ',
              Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReadingPracticeScreen()),
                );
              },
            ),
            _buildSkillTile(
              Icons.mic_rounded,
              'Speaking',
              'Chấm phát âm AI',
              Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SpeakingPracticeScreen()),
                );
              },
            ),
            _buildSkillTile(
              Icons.edit_note_rounded,
              'Writing',
              'Soạn thảo & Đếm từ',
              Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const WritingPracticeScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSkillTile(
    IconData icon,
    String title,
    String subtitle,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
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
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      subtitle,
                      style:
                          TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab Thông tin cá nhân & Tài khoản (Profile)
/// Tích hợp Quản lý Bảo mật Sinh trắc học FaceID (Đăng ký, Trạng thái, Hủy)
class _LearnerProfileTab extends StatefulWidget {
  const _LearnerProfileTab();

  @override
  State<_LearnerProfileTab> createState() => _LearnerProfileTabState();
}

class _LearnerProfileTabState extends State<_LearnerProfileTab> {
  bool _isActionLoading = false;

  /// Đăng ký FaceID cho tài khoản hiện tại:
  /// 1. Lấy mã Nonce thử thách từ Backend (60s).
  /// 2. Mở FaceScanDialog để quét khuôn mặt qua Camera trước.
  /// 3. Gửi ảnh Base64 và Nonce lên Backend để trích xuất và lưu vector 128 số float.
  Future<void> _registerFaceId() async {
    setState(() => _isActionLoading = true);

    try {
      // BƯỚC 1: Lấy mã Nonce thử thách
      final String nonce = await ApiService.instance.getFaceNonce();

      if (!mounted) return;

      // BƯỚC 2: Mở hộp thoại quét khuôn mặt FaceID
      final scanResult = await FaceScanDialog.show(
        context,
        mode: FaceScanMode.register,
        title: 'Đăng ký FaceID',
        subtitle: 'Giữ gương mặt trong khung tròn để ghi nhận',
      );

      if (scanResult == null) {
        if (mounted) setState(() => _isActionLoading = false);
        return;
      }

      if (!mounted) return;

      // BƯỚC 3: Gửi dữ liệu đăng ký khuôn mặt lên Backend
      final res = await ApiService.instance.registerFace(
        imageBase64: scanResult.imageBase64,
        nonce: nonce,
      );

      if (!mounted) return;

      // Cập nhật State trong AuthProvider
      context.read<AuthProvider>().updateFaceAuthStatus(
        isEnabled: true,
        registeredAt: res['registered_at']?.toString(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Kích hoạt FaceID thành công! Giờ đây bạn có thể đăng nhập bằng khuôn mặt.')),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  /// Hủy liên kết FaceID của tài khoản hiện tại:
  /// Hiển thị Hộp thoại xác nhận trước khi gọi Backend DELETE
  Future<void> _deleteFaceId() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Hủy liên kết FaceID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn hủy đăng nhập bằng khuôn mặt cho tài khoản này?\n\n'
          'Sau khi hủy, bạn sẽ cần đăng nhập bằng tên người dùng và mật khẩu thông thường.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('GIỮ LẠI'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('HỦY FACEID'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isActionLoading = true);

    try {
      await ApiService.instance.deleteFace();

      if (!mounted) return;

      context.read<AuthProvider>().updateFaceAuthStatus(isEnabled: false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Đã hủy liên kết FaceID thành công.'),
            ],
          ),
          backgroundColor: Colors.grey[850],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final bool isFaceEnabled = user?.isFaceAuthEnabled ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Hồ sơ Cá nhân',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar + Tên người dùng
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 64,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user?.username ?? 'Học viên',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Vai trò: ${user?.role.toUpperCase() ?? "LEARNER"}',
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Thông tin tài khoản
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined, color: AppColors.navy),
                  title: const Text('Mã học viên (User ID)'),
                  trailing: Text(
                    '#${user?.id ?? "N/A"}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.school_outlined, color: AppColors.navy),
                  title: Text('Mục tiêu học tập'),
                  trailing: Text(
                    'IELTS Band 7.5+',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- KHỐI BẢO MẬT SINH TRẮC HỌC FACEID ---
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isFaceEnabled ? Colors.green.withValues(alpha: 0.3) : Colors.grey[200]!,
                width: isFaceEnabled ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isFaceEnabled
                      ? Colors.green.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.02),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isFaceEnabled
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.face_retouching_natural_rounded,
                        color: isFaceEnabled ? Colors.green[700] : Colors.grey[700],
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bảo mật FaceID',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isFaceEnabled
                                ? 'Đã kích hoạt đăng nhập sinh trắc học'
                                : 'Chưa kích hoạt đăng nhập sinh trắc học',
                            style: TextStyle(
                              fontSize: 12,
                              color: isFaceEnabled ? Colors.green[700] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Badge trạng thái
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFaceEnabled
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isFaceEnabled ? 'ĐÃ BẬT' : 'CHƯA BẬT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isFaceEnabled ? Colors.green[800] : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Nút hành động: Đăng ký hoặc Hủy
                if (!isFaceEnabled) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isActionLoading ? null : _registerFaceId,
                      icon: _isActionLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add_a_photo_rounded, size: 20),
                      label: Text(
                        _isActionLoading ? 'ĐANG XỬ LÝ...' : 'ĐĂNG KÝ KHUÔN MẶT (FACEID)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isActionLoading ? null : _registerFaceId,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('CẬP NHẬT LẠI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.navy,
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isActionLoading ? null : _deleteFaceId,
                          icon: _isActionLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                                )
                              : const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          label: const Text(
                            'HỦY FACEID',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                            backgroundColor: Colors.red.withValues(alpha: 0.04),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Nút Đăng xuất
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<AuthProvider>().logout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('ĐĂNG XUẤT TÀI KHOẢN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.redAccent,
                elevation: 0,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
