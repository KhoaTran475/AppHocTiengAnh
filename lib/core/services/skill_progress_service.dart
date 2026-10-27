import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Dịch vụ quản lý tiến độ "Vượt ải" (Gamified Level Progression)
/// cho toàn bộ 4 kỹ năng IELTS: Reading, Listening, Writing, Speaking.
/// Hỗ trợ lưu trữ độc lập theo từng tài khoản (userId) và từng kỹ năng trong SharedPreferences.
class SkillProgressService {
  static String _unlockedKey(int userId, String skillType) =>
      'gamification_unlocked_${skillType}_$userId';

  static String _bestScoreKey(int userId, String skillType, int stageNumber) =>
      'gamification_score_${skillType}_${userId}_stage_$stageNumber';

  static String _starsKey(int userId, String skillType, int stageNumber) =>
      'gamification_stars_${skillType}_${userId}_stage_$stageNumber';

  /// Lấy số Ải cao nhất đã được mở khóa (mặc định = 1)
  static Future<int> getHighestUnlockedStage(int userId, String skillType) async {
    final prefs = await SharedPreferences.getInstance();
    final normSkill = skillType.toLowerCase();

    // Tương thích ngược với key cũ của listening
    if (normSkill == 'listening') {
      final oldVal = prefs.getInt('listening_unlocked_stage_$userId');
      if (oldVal != null && oldVal > 1) {
        return oldVal;
      }
    }

    return prefs.getInt(_unlockedKey(userId, normSkill)) ?? 1;
  }

  /// Kiểm tra xem một Ải cụ thể đã được mở khóa chưa
  static Future<bool> isStageUnlocked(int userId, String skillType, int stageNumber) async {
    if (stageNumber <= 1) return true; // Ải 1 luôn mở mặc định
    final highest = await getHighestUnlockedStage(userId, skillType);
    return stageNumber <= highest;
  }

  /// Lấy điểm số cao nhất của một Ải
  static Future<int> getStageBestScore(int userId, String skillType, int stageNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final normSkill = skillType.toLowerCase();

    if (normSkill == 'listening') {
      final oldVal = prefs.getInt('listening_best_score_${userId}_stage_$stageNumber');
      if (oldVal != null && oldVal > 0) return oldVal;
    }

    return prefs.getInt(_bestScoreKey(userId, normSkill, stageNumber)) ?? 0;
  }

  /// Lấy số sao đã đạt được ở Ải (0 đến 3 sao)
  static Future<int> getStageStars(int userId, String skillType, int stageNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final normSkill = skillType.toLowerCase();

    if (normSkill == 'listening') {
      final oldVal = prefs.getInt('listening_stars_${userId}_stage_$stageNumber');
      if (oldVal != null && oldVal > 0) return oldVal;
    }

    return prefs.getInt(_starsKey(userId, normSkill, stageNumber)) ?? 0;
  }

  /// Tính toán số sao dựa trên điểm số và tổng số câu / yêu cầu qua ải
  static int calculateStars(int score, int totalQuestions, int passScoreRequired) {
    if (score < passScoreRequired) return 0;
    if (score >= totalQuestions) return 3; // Đúng 100% -> 3 sao
    if (score >= totalQuestions - 1) return 2; // Gần tối đa -> 2 sao
    return 1; // Vừa đủ qua ải -> 1 sao
  }

  /// Ghi nhận kết quả làm bài & Tự động mở khóa ải tiếp theo nếu đủ điểm
  /// Trả về true nếu lần này mở khóa thành công một Ải mới!
  static Future<bool> recordStageResult({
    required int userId,
    required String skillType,
    required int stageNumber,
    required int score,
    required int totalQuestions,
    required int passScoreRequired,
    required int totalStagesAvailable,
    int? overrideStars,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normSkill = skillType.toLowerCase();
    final isPassed = score >= passScoreRequired;

    // 1. Cập nhật điểm cao nhất
    final oldBest = await getStageBestScore(userId, normSkill, stageNumber);
    if (score > oldBest) {
      await prefs.setInt(_bestScoreKey(userId, normSkill, stageNumber), score);
      if (normSkill == 'listening') {
        await prefs.setInt('listening_best_score_${userId}_stage_$stageNumber', score);
      }
    }

    // 2. Cập nhật số sao cao nhất
    final stars = overrideStars ?? calculateStars(score, totalQuestions, passScoreRequired);
    final oldStars = await getStageStars(userId, normSkill, stageNumber);
    if (stars > oldStars) {
      await prefs.setInt(_starsKey(userId, normSkill, stageNumber), stars);
      if (normSkill == 'listening') {
        await prefs.setInt('listening_stars_${userId}_stage_$stageNumber', stars);
      }
    }

    // 3. Nếu vượt ải thành công, tự động mở khóa ải tiếp theo
    bool newlyUnlocked = false;
    if (isPassed && stageNumber < totalStagesAvailable) {
      final currentHighest = await getHighestUnlockedStage(userId, normSkill);
      if (stageNumber >= currentHighest) {
        final nextStage = min(stageNumber + 1, totalStagesAvailable);
        await prefs.setInt(_unlockedKey(userId, normSkill), nextStage);
        if (normSkill == 'listening') {
          await prefs.setInt('listening_unlocked_stage_$userId', nextStage);
        }
        newlyUnlocked = true;
      }
    }

    return newlyUnlocked;
  }
}

/// Lớp chuyển tiếp tương thích ngược cho Listening
class ListeningProgressService {
  static Future<int> getHighestUnlockedStage(int userId) =>
      SkillProgressService.getHighestUnlockedStage(userId, 'listening');

  static Future<bool> isStageUnlocked(int userId, int stageNumber) =>
      SkillProgressService.isStageUnlocked(userId, 'listening', stageNumber);

  static Future<int> getStageBestScore(int userId, int stageNumber) =>
      SkillProgressService.getStageBestScore(userId, 'listening', stageNumber);

  static Future<int> getStageStars(int userId, int stageNumber) =>
      SkillProgressService.getStageStars(userId, 'listening', stageNumber);

  static int calculateStars(int score, int totalQuestions, int passScoreRequired) =>
      SkillProgressService.calculateStars(score, totalQuestions, passScoreRequired);

  static Future<bool> recordStageResult({
    required int userId,
    required int stageNumber,
    required int score,
    required int totalQuestions,
    required int passScoreRequired,
    required int totalStagesAvailable,
  }) =>
      SkillProgressService.recordStageResult(
        userId: userId,
        skillType: 'listening',
        stageNumber: stageNumber,
        score: score,
        totalQuestions: totalQuestions,
        passScoreRequired: passScoreRequired,
        totalStagesAvailable: totalStagesAvailable,
      );
}
