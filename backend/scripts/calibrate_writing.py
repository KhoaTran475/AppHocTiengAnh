import asyncio
import os
import sys
import time

# Cấu hình UTF-8 cho console Windows
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")

# Thêm đường dẫn backend vào sys.path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.db.session import SessionLocal
from app.models.skill import SkillLesson
from app.services.ai_grading_service import grade_writing_with_qwen


# ─────────────────────────────────────────────────────────────
# 3 BÀI VIẾT MẪU ĐỂ HIỆU CHUẨN ĐIỂM SỐ (TASK 1: INTERNET ACCESS)
# ─────────────────────────────────────────────────────────────

ESSAY_HIGH_BAND = """The line graph delineates the proportion of households possessing internet connectivity across metropolitan and rural districts over a ten-year span from 2015 to 2025.

Overall, it is manifest that both sectors experienced a noticeable upward trajectory throughout the examined timeline. Furthermore, while urban regions consistently registered higher connectivity rates, the disparity between the two categories narrowed considerably towards the end of the period.

In 2015, approximately 65% of urban dwellings were equipped with online access, compared to a modest 30% in rural vicinities. Over the subsequent five years, urban adoption surged steadily, surpassing 80% by 2020. Simultaneously, rural connectivity witnessed exponential growth, climbing to nearly 55% as telecommunication infrastructure expanded.

By 2025, internet penetration in cities plateaued at an impressive 92%. In contrast, rural areas continued their accelerated ascent to reach 78%, thereby significantly reducing the digital divide to merely 14 percentage points."""

ESSAY_MID_BAND = """The bar chart shows the percentage of households that have internet in cities and countryside from 2015 to 2025. 

Overall, internet access increased in both areas. Cities always had more internet than the countryside, but the difference became smaller at the end.

In 2015, about 65% of people in cities had internet, but only 30% of rural people had it. Over the next few years, city access grew to around 82% in 2020. At the same time, rural internet access also increased quickly to 55%.

By 2025, city internet reached 92%, which was the highest number. Rural areas also went up to 78%. In general, more and more people had internet access in their homes over the ten years."""

ESSAY_LOW_BAND = """The chart show internet in city and rural. Internet go up from 2015 to 2025. City have 65% in 2015 and then 92% in 2025. Rural have 30% and then 78%. City is bigger than rural. Many people use internet today for work and study."""


async def run_calibration():
    db = SessionLocal()
    try:
        lesson = db.query(SkillLesson).filter(SkillLesson.id == "w1").first()
        if not lesson:
            print("❌ Không tìm thấy bài học 'w1' trong cơ sở dữ liệu để chạy benchmark!")
            return

        print("=" * 80)
        print("🎯 BẮT ĐẦU HIỆU CHUẨN VÀ ĐO LƯỜNG CHẤM ĐIỂM IELTS WRITING (QWEN 2.5 7B)")
        print(f"Bài thi: {lesson.title} (Yêu cầu tối thiểu: {lesson.content_json.get('minWordCount', 120)} từ)")
        print("=" * 80)

        test_cases = [
            ("1. BÀI XUẤT SẮC (Target Band 8.0+)", ESSAY_HIGH_BAND, 7.5, 9.0),
            ("2. BÀI TRUNG BÌNH (Target Band 6.0 - 6.5)", ESSAY_MID_BAND, 5.5, 6.5),
            ("3. BÀI YẾU / THIẾU TỪ (Target Band 4.5 - 5.0)", ESSAY_LOW_BAND, 4.0, 5.5),
        ]

        results = []

        for title, essay_text, expected_min, expected_max in test_cases:
            word_count = len(essay_text.strip().split())
            print(f"\n📝 Đang chấm: {title} ({word_count} từ)...")

            t0 = time.time()
            res = await grade_writing_with_qwen(lesson, essay_text)
            latency = time.time() - t0

            band_score = float(res.get("band_score", 0.0))
            ai_used = res.get("ai_used", False)
            fb = res.get("writing_feedback", {})

            task_b = fb.get("task_response_band", 0.0)
            cc_b = fb.get("coherence_band", 0.0)
            lr_b = fb.get("lexical_band", 0.0)
            gr_b = fb.get("grammar_band", 0.0)
            errors = fb.get("errors", [])

            is_within_range = expected_min <= band_score <= expected_max

            results.append({
                "title": title,
                "words": word_count,
                "latency": latency,
                "overall_band": band_score,
                "task": task_b,
                "cc": cc_b,
                "lr": lr_b,
                "gr": gr_b,
                "errors_count": len(errors),
                "ai_used": ai_used,
                "is_within_range": is_within_range,
            })

            status_mark = "✅ HỢP LÝ" if is_within_range else "⚠️ CẦN LƯU Ý"
            print(f"   ⏱️ Thời gian: {latency:0.1f}s | Band: {band_score} | {status_mark}")
            print(f"   📊 4 Tiêu chí: Task={task_b} | CC={cc_b} | LR={lr_b} | GR={gr_b}")
            print(f"   🔍 Số lỗi đã xác thực quote: {len(errors)} lỗi")

        # In bảng tổng hợp
        print("\n" + "=" * 80)
        print("📊 BẢNG TỔNG HỢP HIỆU CHUẨN ĐIỂM SỐ (BENCHMARK RESULTS):")
        print("=" * 80)
        print(f"{'Mức bài viết':<40} | {'Từ':<4} | {'Độ trễ':<6} | {'Band':<5} | {'Task':<4} | {'CC':<4} | {'LR':<4} | {'GR':<4} | {'Lỗi':<4}")
        print("-" * 80)
        for r in results:
            print(f"{r['title']:<40} | {r['words']:<4} | {r['latency']:0.1f}s  | {r['overall_band']:<5} | {r['task']:<4} | {r['cc']:<4} | {r['lr']:<4} | {r['gr']:<4} | {r['errors_count']:<4}")
        print("-" * 80)

        # Kiểm tra tính phân tầng: High > Mid > Low
        bands = [r["overall_band"] for r in results]
        if bands[0] > bands[1] > bands[2]:
            print("🏆 KẾT LUẬN: ĐẠT CHUẨN (CALIBRATION PASSED)! Điểm số phân tầng hoàn hảo:")
            print(f"   Bài xuất sắc (Band {bands[0]}) > Bài trung bình (Band {bands[1]}) > Bài yếu (Band {bands[2]})")
        else:
            print(f"⚠️ Cảnh báo: Điểm số chưa phân tầng nghiêm ngặt: {bands}")
        print("=" * 80)

    finally:
        db.close()


if __name__ == "__main__":
    asyncio.run(run_calibration())

