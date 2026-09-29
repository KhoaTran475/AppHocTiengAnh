import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vocabulary_item_model.dart';
import '../../auth/providers/auth_provider.dart';
import 'camera_scan_screen.dart';
import 'vocabulary_notebook_screen.dart';

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
    if (user != null && user.id != null) {
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
            const Text(
              'Từ vựng vừa lưu gần đây',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            if (_recentWords.isNotEmpty)
              Text(
                'Mới nhất',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
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
          childAspectRatio: 2.2,
          children: [
            _buildSkillTile(Icons.headphones_rounded, 'Listening', 'Audio Player & Điền từ', Colors.blue),
            _buildSkillTile(Icons.chrome_reader_mode_rounded, 'Reading', 'Học thuật & Tra từ', Colors.green),
            _buildSkillTile(Icons.mic_rounded, 'Speaking', 'Chấm phát âm AI', Colors.orange),
            _buildSkillTile(Icons.edit_note_rounded, 'Writing', 'Soạn thảo & Đếm từ', Colors.teal),
          ],
        ),
      ],
    );
  }

  Widget _buildSkillTile(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab Thông tin cá nhân & Tài khoản (Profile)
class _LearnerProfileTab extends StatelessWidget {
  const _LearnerProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

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
          const SizedBox(height: 32),

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
          const SizedBox(height: 32),

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
