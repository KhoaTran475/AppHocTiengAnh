import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Dịch vụ quản lý tiến độ "Vượt ải" (Gamified Level Progression) phân hệ IELTS Listening.
/// Hỗ trợ lưu trữ theo từng tài khoản (userId) trong SharedPreferences.
class ListeningProgressService {
  static const String _keyUnlockedStagePrefix = 'listening_unlocked_stage_';
  static const String _keyBestScorePrefix = 'listening_best_score_';
  static const String _keyStarsPrefix = 'listening_stars_';

  /// Lấy số Ải cao nhất đã được mở khóa (mặc định = 1)
  static Future<int> getHighestUnlockedStage(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyUnlockedStagePrefix$userId') ?? 1;
  }

  /// Kiểm tra xem một Ải cụ thể đã được mở khóa chưa
  static Future<bool> isStageUnlocked(int userId, int stageNumber) async {
    if (stageNumber <= 1) return true; // Ải 1 luôn mở
    final highest = await getHighestUnlockedStage(userId);
    return stageNumber <= highest;
  }

  /// Lấy điểm số cao nhất của một Ải
  static Future<int> getStageBestScore(int userId, int stageNumber) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyBestScorePrefix${userId}_stage_$stageNumber') ?? 0;
  }

  /// Lấy số sao đã đạt được ở Ải (0 đến 3 sao)
  static Future<int> getStageStars(int userId, int stageNumber) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyStarsPrefix${userId}_stage_$stageNumber') ?? 0;
  }

  /// Tính toán số sao dựa trên điểm số và tổng số câu
  static int calculateStars(int score, int totalQuestions, int passScoreRequired) {
    if (score < passScoreRequired) return 0;
    if (score == totalQuestions) return 3; // Đúng 100% -> 3 sao
    if (score >= totalQuestions - 1) return 2; // Gần tối đa -> 2 sao
    return 1; // Vừa đủ qua ải -> 1 sao
  }

  /// Ghi nhận kết quả làm bài & Tự động mở khóa ải tiếp theo nếu đủ điểm
  /// Trả về true nếu lần này mở khóa thành công một Ải mới!
  static Future<bool> recordStageResult({
    required int userId,
    required int stageNumber,
    required int score,
    required int totalQuestions,
    required int passScoreRequired,
    required int totalStagesAvailable,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final isPassed = score >= passScoreRequired;

    // 1. Cập nhật điểm cao nhất
    final oldBest = await getStageBestScore(userId, stageNumber);
    if (score > oldBest) {
      await prefs.setInt('$_keyBestScorePrefix${userId}_stage_$stageNumber', score);
    }

    // 2. Cập nhật số sao cao nhất
    final stars = calculateStars(score, totalQuestions, passScoreRequired);
    final oldStars = await getStageStars(userId, stageNumber);
    if (stars > oldStars) {
      await prefs.setInt('$_keyStarsPrefix${userId}_stage_$stageNumber', stars);
    }

    // 3. Nếu vượt ải thành công, kiểm tra mở khóa ải tiếp theo
    bool newlyUnlocked = false;
    if (isPassed && stageNumber < totalStagesAvailable) {
      final currentHighest = await getHighestUnlockedStage(userId);
      if (stageNumber >= currentHighest) {
        final nextStage = min(stageNumber + 1, totalStagesAvailable);
        await prefs.setInt('$_keyUnlockedStagePrefix$userId', nextStage);
        newlyUnlocked = true;
      }
    }

    return newlyUnlocked;
  }

  /// Đặt lại tiến độ (hỗ trợ kiểm thử hoặc bắt đầu lại hành trình)
  static Future<void> resetProgress(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyUnlockedStagePrefix$userId');
    for (int i = 1; i <= 10; i++) {
      await prefs.remove('$_keyBestScorePrefix${userId}_stage_$i');
      await prefs.remove('$_keyStarsPrefix${userId}_stage_$i');
    }
  }
}
