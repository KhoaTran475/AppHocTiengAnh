import io
import sys
sys.stdout.reconfigure(encoding='utf-8')
from PIL import Image
from fastapi.testclient import TestClient
from app.main import app

with TestClient(app) as client:
    print("=== 1. ĐĂNG NHẬP LẤY TOKEN ===")
    r_admin = client.post("/api/v1/auth/login", json={"username": "admin", "password": "password123"})
    assert r_admin.status_code == 200
    admin_token = r_admin.json()["access_token"]

    r_learner = client.post("/api/v1/auth/login", json={"username": "learner", "password": "password123"})
    assert r_learner.status_code == 200
    learner_token = r_learner.json()["access_token"]
    print("Đăng nhập Admin & Learner thành công!")

    print("\n=== 2. TEST KHO TỪ VỰNG OBJECT_MAPPINGS ===")
    r = client.get("/api/v1/vocabulary/mappings")
    assert r.status_code == 200
    mappings = r.json()
    print(f"Tổng số từ vựng nạp vào: {len(mappings)} từ")
    assert len(mappings) >= 80

    # Lấy chi tiết nhãn 'person'
    r_person = client.get("/api/v1/vocabulary/mappings/person")
    assert r_person.status_code == 200
    p_data = r_person.json()
    print("Nhãn 'person':", p_data["academic_word"], "| IPA:", p_data["ipa"], "| Nghĩa:", p_data["vietnamese_meaning"])
    assert p_data["label"] == "person"

    # Lọc theo Band điểm
    r_band8 = client.get("/api/v1/vocabulary/mappings?band=Band 8.0")
    assert r_band8.status_code == 200
    print(f"Số từ vựng Band 8.0: {len(r_band8.json())} từ")

    print("\n=== 3. TEST TỪ ĐIỂN TẠI CHỖ (TAP-TO-TRANSLATE) ===")
    r_lookup = client.get("/api/v1/vocabulary/lookup?word=intelligence")
    assert r_lookup.status_code == 200
    lookup_data = r_lookup.json()
    print("Tra cứu 'intelligence':", lookup_data["word"], lookup_data["ipa"], "-", lookup_data["vietnamese_meaning"])
    assert lookup_data["band_score"] == "7.5"

    print("\n=== 4. TEST SỔ TAY TỪ VỰNG (VOCABULARY NOTEBOOK) ===")
    # Học viên lưu từ vào sổ tay
    item_payload = {
        "label": "person",
        "word": p_data["academic_word"],
        "ipa": p_data["ipa"],
        "translation": p_data["vietnamese_meaning"],
        "example": p_data["speaking_part1_example"],
        "example_translation": p_data["speaking_part1_translation"],
        "band_score": p_data["band_score"],
        "collocations": "; ".join(p_data["collocations"] or []),
        "idioms": p_data["idioms"],
    }
    r_save = client.post(
        "/api/v1/notebook/",
        json=item_payload,
        headers={"Authorization": f"Bearer {learner_token}"},
    )
    assert r_save.status_code == 201
    saved_item = r_save.json()
    print(f"Lưu vào sổ tay thành công (ID: {saved_item['id']}, Từ: {saved_item['word']})")

    # Kiểm tra xem từ đã lưu chưa
    r_check = client.get(
        "/api/v1/notebook/check?label=person",
        headers={"Authorization": f"Bearer {learner_token}"},
    )
    assert r_check.status_code == 200
    assert r_check.json()["saved"] is True
    print("Kiểm tra trạng thái isSaved:", r_check.json())

    # Lấy danh sách sổ tay của học viên
    r_list = client.get("/api/v1/notebook/", headers={"Authorization": f"Bearer {learner_token}"})
    assert r_list.status_code == 200
    notebook_items = r_list.json()
    print(f"Số từ trong sổ tay của Learner: {len(notebook_items)}")
    assert len(notebook_items) >= 1

    # Xóa từ khỏi sổ tay
    r_del = client.delete(
        f"/api/v1/notebook/{saved_item['id']}",
        headers={"Authorization": f"Bearer {learner_token}"},
    )
    assert r_del.status_code == 200
    print("Xóa từ khỏi sổ tay thành công:", r_del.json()["message"])

    print("\n=== 5. TEST AI VISION INFERENCE (YOLOv8n) ===")
    # Tạo một ảnh RGB mẫu trong bộ nhớ để test inference
    img = Image.new("RGB", (640, 640), color=(73, 109, 137))
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format="JPEG")
    img_bytes = img_byte_arr.getvalue()

    r_detect = client.post(
        "/api/v1/vision/detect",
        files={"file": ("test_image.jpg", img_bytes, "image/jpeg")},
    )
    assert r_detect.status_code == 200
    detect_res = r_detect.json()
    print("AI Vision Inference thành công!")
    print(f"Số lượng vật thể nhận diện trong ảnh test: {detect_res['total_detected']}")
    print("Cấu trúc kết quả trả về:", list(detect_res.keys()))

    print("\n========================================================")
    print("🎉 TẤT CẢ TEST PHASE 3 THÀNH CÔNG 100%! AI VISION & VOCABULARY HOÀN CHỈNH!")
    print("========================================================")
