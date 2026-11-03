import asyncio
import os
import sys
import time
from typing import List, Optional

# Cấu hình UTF-8 cho console Windows
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

# Thêm đường dẫn backend vào sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.db.session import SessionLocal
from app.models.skill import SkillLesson, AiExplanation
from app.services.ai_grading_service import generate_and_cache_ai_explanation


async def pregenerate_cache(skill_filter: Optional[str] = None, max_lessons: Optional[int] = None):
    """
    Sinh trước toàn bộ giải thích chi tiết cho các bài học Reading & Listening bằng Qwen 2.5 7B.
    Kết quả được lưu trực tiếp vào bảng ai_explanations trên Supabase PostgreSQL.
    """
    db = SessionLocal()
    try:
        query = db.query(SkillLesson).filter(SkillLesson.skill_type.in_(["reading", "listening"]))
        if skill_filter:
            query = query.filter(SkillLesson.skill_type == skill_filter.lower())
        
        lessons: List[SkillLesson] = query.order_by(SkillLesson.skill_type, SkillLesson.stage_number).all()
        if max_lessons:
            lessons = lessons[:max_lessons]

        print("=" * 70)
        print("🚀 BẮT ĐẦU SINH TRƯỚC BỘ NHỚ ĐỆM AI EXPLANATIONS (QWEN 2.5 7B)")
        print(f"Tổng số bài thi cần xử lý: {len(lessons)} bài")
        print("=" * 70)

        total_questions_processed = 0
        total_cache_hits = 0
        total_ai_generated = 0
        t_start_all = time.time()

        for lesson_idx, lesson in enumerate(lessons, 1):
            questions = lesson.content_json.get("questions", [])
            print(f"\n📖 [{lesson_idx}/{len(lessons)}] {lesson.skill_type.upper()} - {lesson.id}: {lesson.title} ({len(questions)} câu hỏi)")

            for q in questions:
                q_id = str(q.get("id"))
                correct_ans = q.get("correctAnswer", "")
                options = q.get("options", [])

                # Đảm bảo danh sách phương án bao gồm cả đáp án đúng
                all_choices = list(dict.fromkeys([correct_ans] + options))

                for choice in all_choices:
                    choice_str = str(choice).strip()
                    if not choice_str:
                        continue

                    total_questions_processed += 1

                    # Kiểm tra xem đã có trong cache chưa
                    exists = (
                        db.query(AiExplanation)
                        .filter(
                            AiExplanation.lesson_id == lesson.id,
                            AiExplanation.question_id == q_id,
                            AiExplanation.user_choice == choice_str,
                        )
                        .first()
                    )

                    if exists:
                        total_cache_hits += 1
                        print(f"  ⚡ [ĐÃ CÓ CACHE] Q{q_id} | Phương án: '{choice_str[:40]}...'")
                        continue

                    # Sinh mới bằng Qwen 2.5 7B
                    t0 = time.time()
                    try:
                        res = await generate_and_cache_ai_explanation(db, lesson, q_id, choice_str)
                        elapsed = time.time() - t0
                        total_ai_generated += 1
                        status = "✅" if res.get("ai_used") else "⚠️ (Fallback)"
                        print(f"  {status} [SINH MỚI AI ({elapsed:0.1f}s)] Q{q_id} | '{choice_str[:40]}...'")
                    except Exception as e:
                        print(f"  ❌ [LỖI] Q{q_id} | '{choice_str[:40]}...': {e}")

        total_elapsed = time.time() - t_start_all
        print("\n" + "=" * 70)
        print("🎉 HOÀN TẤT TIẾN TRÌNH SINH CACHE GIẢI THÍCH AI!")
        print(f"• Tổng số lượt lựa chọn đã duyệt: {total_questions_processed}")
        print(f"• Số bản ghi có sẵn trong Cache: {total_cache_hits}")
        print(f"• Số bản ghi vừa sinh mới qua Qwen 2.5 7B: {total_ai_generated}")
        print(f"• Tổng thời gian thực thi: {total_elapsed:0.1f} giây")
        print("=" * 70)

    finally:
        db.close()


if __name__ == "__main__":
    # Tham số dòng lệnh: python pregenerate_explanations.py [reading/listening] [max_lessons]
    skill_arg = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] not in ["all", "None"] else None
    limit_arg = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else None

    asyncio.run(pregenerate_cache(skill_filter=skill_arg, max_lessons=limit_arg))

