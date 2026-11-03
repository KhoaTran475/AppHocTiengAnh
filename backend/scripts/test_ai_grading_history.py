import os
import sys
import uuid
import asyncio

# Đặt đường dẫn để import app
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from app.db.session import SessionLocal, Base, engine
from app.models.ai_grading_log import AiGradingLog
from app.models.user import User
from app.models.skill import SkillLesson, PracticeHistory, WritingFeedback
from app.services.ai_grading_log_service import (
    log_ai_grading,
    get_ai_grading_logs,
    get_ai_grading_log_detail,
    get_ai_grading_stats,
    delete_ai_grading_log,
    bulk_delete_ai_grading_logs,
    export_ai_grading_logs_csv,
)


def run_tests():
    print("=" * 60)
    print("🚀 BẮT ĐẦU KIỂM THỬ HỆ THỐNG LỊCH SỬ CHẤM ĐIỂM AI QWEN")
    print("=" * 60)

    db = SessionLocal()
    try:
        # Đảm bảo bảng tồn tại
        Base.metadata.create_all(bind=engine)

        admin = db.query(User).filter(User.role == "admin").first()
        learner = db.query(User).filter(User.role == "learner").first()
        admin_name = admin.username if admin else "admin"
        learner_name = learner.username if learner else "learner"
        learner_uuid = uuid.uuid4()

        # 1. Test ghi log Writing Grading
        print("\n1. Ghi log IELTS Writing Grading...")
        essay = (
            "The given chart illustrates the consumption of renewable energy across multiple sectors over a 20-year period. "
            "Overall, it is evident that wind and solar power experienced a dramatic escalation, whereas fossil fuel reliance decreased steadily."
        )
        w_log = log_ai_grading(
            db=db,
            feature="writing_grading",
            skill_type="writing",
            user_id=learner_uuid,
            username=learner_name,
            lesson_id="w1",
            lesson_title="IELTS Writing Task 1: Renewable Energy Trends",
            input_text=essay,
            input_word_count=len(essay.split()),
            band_score="7.0",
            score_numeric=7.0,
            is_correct=True,
            result_json={
                "overall_band": "7.0",
                "task_response_band": 7.0,
                "task_response_comment": "Covered all key trends clearly with specific overview.",
                "coherence_band": 7.0,
                "coherence_comment": "Logical sequencing of paragraphs.",
                "lexical_band": 7.5,
                "lexical_comment": "Rich academic vocabulary such as 'dramatic escalation'.",
                "grammar_band": 6.5,
                "grammar_comment": "Good range of complex structures.",
                "errors": [
                    {"quote": "reliance decreased steadily", "fix": "reliance decreased steadily.", "explain_vi": "Cần lưu ý dấu câu."}
                ],
                "strengths": ["Clear overview paragraph", "Good lexical variety"],
                "improvements": ["Enhance paragraph transitions"],
                "improved_paragraph": "A more advanced version exhibiting Band 8.5 structures...",
            },
            model_name="qwen2.5:7b",
            ai_used=True,
            from_cache=False,
            status="success",
            latency_ms=4200,
            prompt_tokens=450,
            completion_tokens=280,
        )
        assert w_log is not None, "Log Writing không được tạo!"
        print(f"   ✅ Đã ghi log Writing: ID={w_log.id}, Band={w_log.band_score}, Latency={w_log.latency_ms}ms")

        # 2. Test ghi log Reading Explanation
        print("\n2. Ghi log IELTS Reading Explanation...")
        r_log = log_ai_grading(
            db=db,
            feature="reading_explain",
            skill_type="reading",
            user_id=learner_uuid,
            username=learner_name,
            lesson_id="r1",
            lesson_title="IELTS Reading: Artificial Intelligence in Modern Healthcare",
            question_id="1",
            input_text="True",
            is_correct=True,
            result_json={
                "explanation_vi": "Đoạn A nêu rõ trí tuệ nhân tạo cải thiện độ chính xác chẩn đoán lâm sàng.",
                "why_correct": "Dẫn chứng trong bài: 'AI systems enhance diagnostic precision'.",
                "why_trap": "Phương án False bóp méo thông tin về tỷ lệ chẩn đoán sai.",
                "strategy_tips": "Tìm từ đồng nghĩa 'enhance' = 'improve'.",
                "key_vocabulary": [{"word": "precision", "meaning": "độ chính xác", "paraphrase_with": "accuracy"}],
            },
            model_name="qwen2.5:7b",
            ai_used=True,
            from_cache=False,
            status="success",
            latency_ms=2100,
        )
        assert r_log is not None, "Log Reading không được tạo!"
        print(f"   ✅ Đã ghi log Reading Explain: ID={r_log.id}, IsCorrect={r_log.is_correct}")

        # 3. Test ghi log Reading Explanation (Cache Hit)
        print("\n3. Ghi log Reading Explanation (Cache hit)...")
        r_cache_log = log_ai_grading(
            db=db,
            feature="reading_explain",
            skill_type="reading",
            user_id=learner_uuid,
            username=learner_name,
            lesson_id="r1",
            lesson_title="IELTS Reading: Artificial Intelligence in Modern Healthcare",
            question_id="1",
            input_text="True",
            is_correct=True,
            result_json=r_log.result_json,
            model_name="qwen2.5:7b",
            ai_used=True,
            from_cache=True,
            status="success",
            latency_ms=0,
        )
        assert r_cache_log is not None and r_cache_log.from_cache is True
        print(f"   ✅ Đã ghi log Cache hit: ID={r_cache_log.id}, from_cache={r_cache_log.from_cache}")

        # 4. Test ghi log Vocab Sentence Lab
        print("\n4. Ghi log Vocabulary Sentence Lab...")
        v_log = log_ai_grading(
            db=db,
            feature="vocab_sentence",
            skill_type="vocabulary",
            user_id=learner_uuid,
            username=learner_name,
            vocab_word="escalate",
            vocab_level=3,
            input_text="Tensions between the two factions began to escalate rapidly.",
            band_score="7.5",
            score_numeric=85.0,
            is_correct=True,
            result_json={
                "score": 85,
                "estimated_band": "7.5",
                "corrected_sentence": "Tensions between the two factions began to escalate rapidly.",
                "feedback_vi": "Bạn đã sử dụng từ 'escalate' rất tự nhiên trong ngữ cảnh xung đột.",
                "upgraded_basic": "The conflict became more serious quickly.",
                "upgraded_intermediate": "Tensions between the two factions began to escalate rapidly.",
                "upgraded_advanced": "Geopolitical friction between both factions escalated at an unprecedented pace.",
                "key_collocations_used": ["tensions escalate", "escalate rapidly"],
            },
            model_name="qwen2.5:7b",
            ai_used=True,
            from_cache=False,
            status="success",
            latency_ms=3100,
        )
        assert v_log is not None, "Log Vocab không được tạo!"
        print(f"   ✅ Đã ghi log Vocab Sentence: ID={v_log.id}, Word={v_log.vocab_word}, Score={v_log.score_numeric}")

        # 5. Test Thống kê Stats
        print("\n5. Kiểm tra hàm thống kê get_ai_grading_stats()...")
        stats = get_ai_grading_stats(db)
        print(f"   Tổng request: {stats['total_requests']}")
        print(f"   Phân bổ feature: {stats['feature_counts']}")
        print(f"   Trạng thái: {stats['status_counts']}")
        print(f"   Độ trễ trung bình: {stats['avg_latency_ms']} ms")
        print(f"   Cache hits: {stats['cache_hits']} ({stats['cache_hit_rate']}%)")
        print(f"   Writing Band TB: {stats['writing_avg_band']}")
        print(f"   Vocab Score TB: {stats['vocab_avg_score']}")
        assert stats["total_requests"] >= 4, "Tổng request phải >= 4"

        # 6. Test Lọc và phân trang
        print("\n6. Kiểm tra hàm get_ai_grading_logs() với các bộ lọc...")
        # Lọc Writing
        writing_list = get_ai_grading_logs(db, feature="writing_grading")
        assert writing_list["total"] >= 1, "Bộ lọc writing_grading phải trả về kết quả"
        print(f"   ✅ Lọc writing_grading: {writing_list['total']} bản ghi")

        # Lọc Từ vựng
        vocab_list = get_ai_grading_logs(db, feature="vocab_sentence")
        assert vocab_list["total"] >= 1, "Bộ lọc vocab_sentence phải trả về kết quả"
        print(f"   ✅ Lọc vocab_sentence: {vocab_list['total']} bản ghi")

        # Tìm kiếm từ khóa "escalate"
        search_res = get_ai_grading_logs(db, search="escalate")
        assert search_res["total"] >= 1, "Tìm kiếm 'escalate' phải thấy kết quả"
        print(f"   ✅ Tìm kiếm 'escalate': {search_res['total']} bản ghi")

        # 7. Test xem chi tiết
        print("\n7. Kiểm tra hàm get_ai_grading_log_detail()...")
        detail = get_ai_grading_log_detail(db, str(w_log.id))
        assert detail is not None, "Chi tiết log Writing phải tồn tại"
        assert detail["result_json"]["overall_band"] == "7.0"
        print(f"   ✅ Lấy chi tiết log ID={w_log.id} thành công!")

        # 8. Test Xuất CSV
        print("\n8. Kiểm tra hàm export_ai_grading_logs_csv()...")
        csv_text = export_ai_grading_logs_csv(db)
        assert csv_text.startswith("\ufeffID,Thời gian"), "CSV phải có UTF-8 BOM và đúng header"
        assert "escalate" in csv_text or "renewable" in csv_text
        print(f"   ✅ Xuất CSV thành công! Chiều dài: {len(csv_text)} ký tự")

        # 9. Test Xóa đơn và Xóa hàng loạt
        print("\n9. Kiểm tra hàm xóa log...")
        del_single = delete_ai_grading_log(db, str(r_cache_log.id))
        assert del_single is True, "Xóa đơn lẻ phải thành công"
        print("   ✅ Xóa đơn lẻ thành công!")

        bulk_del_count = bulk_delete_ai_grading_logs(db, [str(w_log.id), str(r_log.id), str(v_log.id)])
        assert bulk_del_count == 3, f"Phải xóa được 3 bản ghi, thực tế: {bulk_del_count}"
        print(f"   ✅ Xóa hàng loạt {bulk_del_count} bản ghi thành công!")

        print("\n" + "=" * 60)
        print("🎉 TẤT CẢ CÁC BÀI TEST SERVICE & REPOSITORY ĐỀU PASS 100%!")
        print("=" * 60)

    finally:
        db.close()


if __name__ == "__main__":
    run_tests()
