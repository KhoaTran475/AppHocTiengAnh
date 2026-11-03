import os
import sys

os.environ["DATABASE_URL"] = "sqlite:///./ielts_vision_backend.db"

if sys.stdout.encoding != "utf-8":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from fastapi import FastAPI
from fastapi.testclient import TestClient
from app.db.session import engine, Base, SessionLocal
import app.models  # noqa: F401
from app.api.v1.endpoints import vocab_learning
from app.services.ollama_vocab_service import seed_default_vocab_learning

Base.metadata.create_all(bind=engine)
_db = SessionLocal()
try:
    seed_default_vocab_learning(_db)
finally:
    _db.close()

test_app = FastAPI()
test_app.include_router(vocab_learning.router, prefix="/api/v1/vocabulary/learning")


def run_phase3_tests():
    print("=" * 70)
    print("🚀 KIỂM THỬ PHA 2 & PHA 3: API HỌC TỪ VỰNG 5 CẤP ĐỘ & OLLAMA QWEN 2.5")
    print("=" * 70)

    with TestClient(test_app) as client:
        # 1. Kiểm tra trạng thái Ollama Qwen 2.5
        r_status = client.get("/api/v1/vocabulary/learning/status")
        assert r_status.status_code == 200, f"Status failed: {r_status.text}"
        st_data = r_status.json()
        print(
            f"[1/6] GET /status -> HTTP 200 | Configured: {st_data['configured_model']} | "
            f"Resolved: {st_data['resolved_model']} | Online: {st_data['online']}"
        )

        # 2. Lấy lộ trình 5 cấp độ (Basic -> Advanced)
        r_levels = client.get("/api/v1/vocabulary/learning/levels")
        assert r_levels.status_code == 200, f"Levels failed: {r_levels.text}"
        roadmap = r_levels.json()
        print(
            f"[2/6] GET /levels -> HTTP 200 | Tổng số thẻ từ hệ thống: {roadmap['total_cards_in_system']} | "
            f"Số cấp độ: {len(roadmap['levels'])}"
        )
        assert len(roadmap["levels"]) == 5
        assert roadmap["total_cards_in_system"] >= 30

        # 3. Lấy danh sách thẻ từ vựng ở Level 1 (Cơ bản) & Level 5 (Bậc thầy)
        r_cards_1 = client.get("/api/v1/vocabulary/learning/cards?level=1")
        assert r_cards_1.status_code == 200
        cards_1 = r_cards_1.json()
        first_card = cards_1[0]
        print(
            f"[3/6] GET /cards?level=1 -> {len(cards_1)} thẻ | Ví dụ thang từ: "
            f"Basic '{first_card['basic_word']}' -> Inter '{first_card['intermediate_word']}' -> Adv '{first_card['advanced_word']}'"
        )

        # 4. Cập nhật mức độ ghi nhớ từ (SRS Mastery)
        r_mastery = client.post(
            "/api/v1/vocabulary/learning/mastery",
            json={"card_id": first_card["id"], "mastery_level": 3},
        )
        assert r_mastery.status_code == 200
        m_data = r_mastery.json()
        print(
            f"[4/6] POST /mastery -> HTTP 200 | Card ID={m_data['card_id']} -> "
            f"Mastery={m_data['mastery_level']} ({m_data['message']})"
        )

        # 5. Chấm điểm câu học viên với Qwen 2.5 (hoặc Fallback thông minh)
        r_eval = client.post(
            "/api/v1/vocabulary/learning/evaluate-sentence",
            json={
                "word": "mitigate",
                "level": 3,
                "user_sentence": "Governments should plant more trees to mitigate the negative effects of climate change.",
            },
        )
        assert r_eval.status_code == 200
        ev_data = r_eval.json()
        print(
            f"[5/6] POST /evaluate-sentence -> HTTP 200 | Score: {ev_data['score']}/100 | "
            f"Band: {ev_data['estimated_band']} | Model: {ev_data['model_used']}"
        )

        # 6. Tạo đề Quiz & Nộp bài vượt cấp Level 1 -> Mở khóa Level 2
        r_quiz = client.post(
            "/api/v1/vocabulary/learning/quiz",
            json={"level": 1, "question_count": 4, "use_ai_qwen": False},
        )
        assert r_quiz.status_code == 200
        q_data = r_quiz.json()
        assert len(q_data["questions"]) == 4

        r_submit = client.post(
            "/api/v1/vocabulary/learning/submit-quiz",
            json={
                "level": 1,
                "score": 4,
                "total_questions": 4,
                "mastered_card_ids": [first_card["id"]],
            },
        )
        assert r_submit.status_code == 200
        sub_data = r_submit.json()
        print(
            f"[6/6] POST /quiz & /submit-quiz -> HTTP 200 | Passed: {sub_data['passed']} | "
            f"Stars: {sub_data['stars_earned']}⭐ | Highest Unlocked Level: {sub_data['highest_unlocked_level']}"
        )
        assert sub_data["passed"] is True
        assert sub_data["stars_earned"] == 3
        assert sub_data["highest_unlocked_level"] >= 2

    print("=" * 70)
    print("🎉 HOÀN THÀNH KIỂM THỬ PHA 2 & PHA 3 THÀNH CÔNG 100%!")
    print("=" * 70)


if __name__ == "__main__":
    run_phase3_tests()
