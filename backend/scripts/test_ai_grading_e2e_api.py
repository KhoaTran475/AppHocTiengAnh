import os
import sys
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from app.main import app
from app.db.session import SessionLocal
from app.models.user import User
from app.core.security import create_access_token


def test_api_e2e():
    print("=" * 60)
    print("🌐 KIỂM THỬ END-TO-END CÁC ENDPOINT ADMIN AI GRADING")
    print("=" * 60)

    db = SessionLocal()
    admin_user = db.query(User).filter(User.role == "admin").first()
    learner_user = db.query(User).filter(User.role == "learner").first()
    assert admin_user is not None, "Cần ít nhất 1 tài khoản admin"
    assert learner_user is not None, "Cần ít nhất 1 tài khoản learner"

    admin_token = create_access_token(admin_user.username, role="admin")
    learner_token = create_access_token(learner_user.username, role="learner")
    db.close()

    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    learner_headers = {"Authorization": f"Bearer {learner_token}"}

    client = TestClient(app)

    # 1. Learner gọi đặt câu Từ Vựng -> sinh log
    print("\n1. Learner gọi /vocabulary/learning/evaluate-sentence...")
    vocab_resp = client.post(
        "/api/v1/vocabulary/learning/evaluate-sentence",
        json={
            "word": "collaborate",
            "level": 2,
            "user_sentence": "We need to collaborate closely with the research team to achieve success.",
        },
        headers=learner_headers,
    )
    assert vocab_resp.status_code == 200, f"Lỗi evaluate-sentence: {vocab_resp.text}"
    v_data = vocab_resp.json()
    print(f"   ✅ Chấm câu thành công: Score={v_data.get('score')}, Band={v_data.get('estimated_band')}")

    # 2. Learner gọi giải thích Reading / Listening
    print("\n2. Learner gọi /skills/explain (Reading)...")
    explain_resp = client.post(
        "/api/v1/skills/explain",
        json={
            "lesson_id": "r1",
            "question_id": "1",
            "user_choice": "True",
        },
        headers=learner_headers,
    )
    assert explain_resp.status_code == 200, f"Lỗi explain: {explain_resp.text}"
    exp_data = explain_resp.json()
    print(f"   ✅ AI Explain thành công: is_correct={exp_data.get('is_correct')}, from_cache={exp_data.get('from_cache')}")

    # 3. Learner gọi lần 2 -> Cache hit
    print("\n3. Learner gọi /skills/explain lần 2 (Kiểm tra Cache)...")
    explain_cache_resp = client.post(
        "/api/v1/skills/explain",
        json={
            "lesson_id": "r1",
            "question_id": "1",
            "user_choice": "True",
        },
        headers=learner_headers,
    )
    assert explain_cache_resp.status_code == 200
    assert explain_cache_resp.json().get("from_cache") is True
    print("   ✅ Xác nhận log ghi nhận Cache hit thành công!")

    # 4. Kiểm tra phân quyền: Learner gọi Admin API -> Phải bị từ chối 403
    print("\n4. Kiểm tra RBAC: Learner truy cập /admin/ai-grading/logs...")
    forbidden_resp = client.get("/api/v1/admin/ai-grading/logs", headers=learner_headers)
    assert forbidden_resp.status_code == 403, f"Learner không được phép truy cập, status={forbidden_resp.status_code}"
    print("   ✅ RBAC bảo mật hoạt động chuẩn xác (403 Forbidden)")

    # 5. Admin gọi /admin/ai-grading/stats
    print("\n5. Admin truy cập /admin/ai-grading/stats...")
    stats_resp = client.get("/api/v1/admin/ai-grading/stats", headers=admin_headers)
    assert stats_resp.status_code == 200
    st = stats_resp.json()
    print(f"   ✅ Stats: Total={st['total_requests']}, Vocab={st['feature_counts'].get('vocab_sentence')}, Reading={st['feature_counts'].get('reading_explain')}")

    # 6. Admin gọi /admin/ai-grading/logs
    print("\n6. Admin truy cập /admin/ai-grading/logs...")
    logs_resp = client.get("/api/v1/admin/ai-grading/logs?page=1&page_size=10", headers=admin_headers)
    assert logs_resp.status_code == 200
    logs_data = logs_resp.json()
    assert logs_data["total"] >= 3
    print(f"   ✅ Lấy danh sách thành công: Tổng {logs_data['total']} bản ghi")

    first_log_id = logs_data["items"][0]["id"]

    # 7. Admin xem chi tiết 1 log
    print(f"\n7. Admin xem chi tiết log ID={first_log_id}...")
    detail_resp = client.get(f"/api/v1/admin/ai-grading/logs/{first_log_id}", headers=admin_headers)
    assert detail_resp.status_code == 200
    det = detail_resp.json()
    print(f"   ✅ Chi tiết hợp lệ: Feature={det['feature']}, Input preview={str(det['input_text'])[:40]}...")

    # 8. Admin xuất CSV
    print("\n8. Admin gọi xuất CSV /admin/ai-grading/export-csv...")
    csv_resp = client.get("/api/v1/admin/ai-grading/export-csv", headers=admin_headers)
    assert csv_resp.status_code == 200
    assert "text/csv" in csv_resp.headers.get("content-type", "")
    print(f"   ✅ Tải file CSV thành công: Size={len(csv_resp.content)} bytes")

    # 9. Admin xóa 1 log
    print(f"\n9. Admin xóa log ID={first_log_id}...")
    del_resp = client.delete(f"/api/v1/admin/ai-grading/logs/{first_log_id}", headers=admin_headers)
    assert del_resp.status_code == 200
    print("   ✅ Xóa log thành công!")

    print("\n" + "=" * 60)
    print("🎉 TẤT CẢ TEST API ENDPOINTS END-TO-END ĐỀU THÀNH CÔNG 100%!")
    print("=" * 60)


if __name__ == "__main__":
    test_api_e2e()
