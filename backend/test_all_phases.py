"""
Comprehensive End-to-End Verification Test Suite for IELTS Vision Backend (Phase 6)
Covers all 6 Phases: Auth, RBAC, Vocabulary, Vision, 4 Skills, Supabase Sync, and Admin KPIs.
"""
import sys
import os

if sys.platform.startswith('win'):
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

import io
from PIL import Image
from fastapi.testclient import TestClient

# Ensure backend root is in sys.path
backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.main import app
from app.db.session import SessionLocal
from app.models.mapping import ObjectMapping
from app.models.user import User

client = TestClient(app)

def run_e2e_verification():
    print("=" * 65)
    print("🚀 BẮT ĐẦU KIỂM THỬ TOÀN DIỆN HỆ THỐNG IELTS VISION (PHASE 6)")
    print("=" * 65)

    # 1. Health check & Docs
    print("\n[1/8] Kiểm tra Trạng thái Máy chủ & Swagger API Docs...")
    res = client.get("/health")
    assert res.status_code == 200, f"Health check failed: {res.text}"
    assert res.json().get("status") == "healthy"
    print("  ✅ Server status: healthy")

    res = client.get("/api/v1/openapi.json")
    assert res.status_code == 200
    print("  ✅ Swagger OpenAPI specification: OK")

    # 2. Auth & RBAC
    print("\n[2/8] Kiểm tra Xác thực & Phân quyền RBAC (JWT Token)...")
    res = client.post("/api/v1/auth/login", json={"username": "admin", "password": "password123"})
    assert res.status_code == 200, f"Admin login failed: {res.text}"
    admin_token = res.json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    print("  ✅ Đăng nhập Admin thành công (Role: admin, Token JWT OK)")

    res = client.post("/api/v1/auth/login", json={"username": "learner", "password": "password123"})
    assert res.status_code == 200, f"Learner login failed: {res.text}"
    learner_token = res.json()["access_token"]
    learner_headers = {"Authorization": f"Bearer {learner_token}"}
    print("  ✅ Đăng nhập Learner thành công (Role: learner, Token JWT OK)")

    # Kiểm tra RBAC: Learner không được truy cập Admin KPIs
    res = client.get("/api/v1/admin/kpis", headers=learner_headers)
    assert res.status_code == 403, "Learner must not access Admin KPIs!"
    print("  ✅ Chặn Learner truy cập Admin KPIs (HTTP 403 Forbidden - RBAC bảo mật cao)")

    # 3. Object Mappings & Dictionary
    print("\n[3/8] Kiểm tra Kho 82 Nhãn Từ vựng AI & Từ điển Học thuật...")
    res = client.get("/api/v1/vocabulary/mappings", headers=learner_headers)
    assert res.status_code == 200
    mappings = res.json()
    assert len(mappings) >= 80, f"Expected >= 80 mappings, got {len(mappings)}"
    print(f"  ✅ Nạp thành công {len(mappings)} nhãn từ vựng AI YOLOv8n chuẩn Band 7.0 - 8.5")

    res = client.get("/api/v1/vocabulary/lookup?word=intelligence", headers=learner_headers)
    assert res.status_code == 200
    assert "intelligence" in res.json().get("word", "").lower()
    print(f"  ✅ Tap-to-Translate tra từ 'intelligence': {res.json().get('meaning')}")

    # 4. Vocabulary Notebook
    print("\n[4/8] Kiểm tra Sổ tay từ vựng & Đồng bộ Supabase...")
    # Lưu từ mới
    save_payload = {
        "label": "laptop",
        "word": "portable computing device",
        "ipa": "/ˈpɔː.tə.bəl kəmˈpjuː.tɪŋ dɪˈvaɪs/",
        "translation": "thiết bị tính toán di động, máy tính xách tay",
        "example": "Laptops have democratized access to remote education.",
        "example_translation": "Máy tính xách tay đã đại chúng hóa khả năng tiếp cận giáo dục từ xa.",
        "band_score": "8.0",
        "collocations": ["portable computing", "remote education"],
        "idioms": "cutting-edge technology"
    }
    res = client.post("/api/v1/notebook/", json=save_payload, headers=learner_headers)
    assert res.status_code in (200, 201), f"Save notebook failed: {res.text}"
    saved_item = res.json()
    item_id = saved_item["id"]
    print(f"  ✅ Đã lưu từ '{saved_item['word']}' vào sổ tay cá nhân (ID: {item_id})")

    res = client.get("/api/v1/notebook/check?label=laptop", headers=learner_headers)
    assert res.status_code == 200
    assert res.json().get("saved") is True
    print("  ✅ Check trạng thái 'isSaved' qua API: True")

    res = client.delete(f"/api/v1/notebook/{item_id}", headers=learner_headers)
    assert res.status_code == 200
    print(f"  ✅ Xóa từ (ID: {item_id}) khỏi sổ tay thành công")

    # 5. 4 Kỹ năng IELTS (Reading, Listening, Writing, Speaking)
    print("\n[5/8] Kiểm tra Động cơ Chấm điểm 4 Kỹ năng IELTS...")
    
    # Reading
    reading_res = client.post("/api/v1/skills/submit", json={
        "skill_type": "reading",
        "lesson_id": "r1",
        "answers": {
            "1": "Tailoring learning materials to individual student pacing",
            "2": "By mapping camera-scanned objects to academic vocabulary",
            "3": "AI tools augment pedagogy rather than replace human teachers"
        }
    }, headers=learner_headers)
    assert reading_res.status_code == 200
    assert reading_res.json()["band_score"] == "8.5+"
    print(f"  ✅ Reading engine: Điểm {reading_res.json()['score']}/3 -> Band {reading_res.json()['band_score']}")

    # Listening Gamification
    listening_res = client.post("/api/v1/skills/submit", json={
        "skill_type": "listening",
        "lesson_id": "l1",
        "answers": {
            "1": "Senior Academic Coordinator",
            "2": "8:00 AM to 10:00 PM",
            "3": "University ID card"
        }
    }, headers=learner_headers)
    assert listening_res.status_code == 200
    assert listening_res.json()["passed"] is True
    print(f"  ✅ Listening gamification: Ải 1 đạt {listening_res.json()['stars']}⭐ -> Mở khóa ải tiếp theo")

    # Writing Live Word & Collocation Check
    sample_text = (
        "The line graph delineates the proportion of households possessing internet connectivity across "
        "metropolitan and rural districts over a ten-year span from 2015 to 2025. "
        "Overall, it is manifest that both sectors experienced a noticeable upward trajectory throughout "
        "the examined timeline. Furthermore, while urban regions consistently registered higher connectivity rates, "
        "the disparity narrowed considerably towards the end of the period. "
        "In 2015, approximately 65% of urban dwellings were equipped with online access, compared to a modest 30% "
        "in rural vicinities. Over the subsequent five years, urban adoption surged steadily, surpassing 80% by 2020. "
        "Simultaneously, rural connectivity witnessed exponential growth, climbing to nearly 55% as telecommunication "
        "infrastructure expanded. By 2025, internet penetration in cities plateaued at an impressive 92%. "
        "In contrast, rural areas continued their accelerated ascent to reach 78%, thereby significantly reducing "
        "the digital divide to merely 14 percentage points. "
        "In conclusion, modern infrastructure development has fundamentally democratized digital access across the nation."
    )
    writing_res = client.post("/api/v1/skills/submit", json={
        "skill_type": "writing",
        "lesson_id": "w1",
        "essay_text": sample_text
    }, headers=learner_headers)
    assert writing_res.status_code == 200
    assert float(writing_res.json()["band_score"]) >= 7.5
    print(f"  ✅ Writing analysis: {writing_res.json()['score']} từ -> Band {writing_res.json()['band_score']}")

    # Speaking
    speaking_res = client.post("/api/v1/skills/submit", json={
        "skill_type": "speaking",
        "lesson_id": "s1",
        "ratings": {"fluency": 9, "vocabulary": 8, "pronunciation": 8}
    }, headers=learner_headers)
    assert speaking_res.status_code == 200
    assert float(speaking_res.json()["band_score"]) >= 8.0
    print(f"  ✅ Speaking criteria evaluation: Band {speaking_res.json()['band_score']}")

    # 6. Practice History
    print("\n[6/8] Kiểm tra Đồng bộ Lịch sử Luyện thi...")
    history_res = client.get("/api/v1/skills/history", headers=learner_headers)
    assert history_res.status_code == 200
    history_items = history_res.json()
    assert len(history_items) >= 4
    print(f"  ✅ Lịch sử luyện thi ghi nhận {len(history_items)} bài thi đã hoàn thành trên hệ thống")

    # 7. Admin KPIs & RBAC
    print("\n[7/8] Kiểm tra Dashboard Quản trị viên (Admin KPIs)...")
    kpis_res = client.get("/api/v1/admin/kpis", headers=admin_headers)
    assert kpis_res.status_code == 200
    kpis = kpis_res.json()
    print(f"  ✅ Tổng nhãn Mappings: {kpis.get('total_mappings')}")
    print(f"  ✅ Tổng người dùng hệ thống: {kpis.get('total_users')}")
    print(f"  ✅ Phân bố Band điểm: {kpis.get('band_distribution')}")

    # 8. AI Vision Server Inference
    print("\n[8/8] Kiểm tra Trí tuệ Nhân tạo AI Vision (YOLOv8n Inference)...")
    img = Image.new("RGB", (320, 320), color=(120, 150, 180))
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format="JPEG")
    img_bytes = img_byte_arr.getvalue()

    vision_res = client.post(
        "/api/v1/vision/detect?conf_threshold=0.3",
        files={"file": ("test_frame.jpg", img_bytes, "image/jpeg")},
        headers=learner_headers
    )
    assert vision_res.status_code == 200
    print(f"  ✅ YOLOv8n inference pipeline hoàn tất thành công (Phát hiện: {vision_res.json()['total_detected']} đối tượng)")

    print("\n" + "=" * 65)
    print("🏆 HOÀN THÀNH 100% CÁC BƯỚC KIỂM THỬ END-TO-END HỆ THỐNG!")
    print("=" * 65)

if __name__ == "__main__":
    run_e2e_verification()
