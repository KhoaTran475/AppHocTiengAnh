import sys
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_stage2_chart_crud():
    print("=== [TEST GIAI ĐOẠN 2] ADMIN WEB & QUẢN LÝ BIỂU ĐỒ TASK 1 ===")

    # 1. Đăng nhập Admin
    login_res = client.post("/api/v1/auth/login", json={"username": "admin", "password": "password123"})
    assert login_res.status_code == 200, f"Login thất bại: {login_res.text}"
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("✓ 1. Đăng nhập Admin thành công.")

    # 2. Tạo bài học Task 1 mới với Biểu đồ Số liệu Động (Bar Chart)
    new_bar_lesson = {
        "skill_type": "writing",
        "stage_number": 6,
        "title": "Smartphone Adoption in Southeast Asia (2018 - 2024)",
        "category_or_topic": "Technology",
        "difficulty_label": "Ải 6: Thử thách mới",
        "target_band": 7.5,
        "band_score_target": "7.5",
        "pass_condition": {"min_words": 150, "min_band": 6.5},
        "pass_score_required": 150,
        "content_json": {
            "taskType": "Task 1",
            "prompt": "The bar chart compares the penetration rate of smartphones across Vietnam, Thailand, and Indonesia between 2018 and 2024. Summarise the main features.",
            "minWordCount": 150,
            "suggestedTimeMinutes": 20,
            "keyOutline": ["Introduction", "Overview", "Body 1", "Body 2"],
            "sampleEssay": "The bar chart delineates the proportion of smartphone ownership...",
            "academicVocabulary": ["penetration rate", "exponential surge"],
            "chart_data": {
                "type": "bar",
                "title": "Smartphone Adoption in Southeast Asia",
                "unit": "%",
                "categories": ["2018", "2020", "2022", "2024"],
                "series": [
                    {"name": "Vietnam", "color": "#1E3A8A", "values": [55.0, 68.0, 80.0, 89.0]},
                    {"name": "Thailand", "color": "#059669", "values": [60.0, 72.0, 82.0, 91.0]},
                    {"name": "Indonesia", "color": "#D97706", "values": [45.0, 58.0, 71.0, 84.0]}
                ]
            }
        }
    }

    create_res = client.post("/api/v1/admin/skills/lessons", headers=headers, json=new_bar_lesson)
    assert create_res.status_code in (200, 201), f"Tạo bài viết Task 1 Bar Chart thất bại: {create_res.status_code} - {create_res.text}"
    created_id = create_res.json()["id"]
    print(f"✓ 2. Tạo thành công bài viết Task 1 Bar Chart (ID: {created_id}) với 3 chuỗi số liệu.")

    # 3. Tạo bài học Task 1 với Ảnh Đề Thi Supabase Storage
    new_image_lesson = {
        "skill_type": "writing",
        "stage_number": 7,
        "title": "Cambridge IELTS 18 Test 1: Task 1 Map",
        "category_or_topic": "Urban Planning",
        "difficulty_label": "Ải 7: Đề thi thật",
        "target_band": 8.0,
        "band_score_target": "8.0",
        "pass_condition": {"min_words": 150, "min_band": 7.0},
        "pass_score_required": 150,
        "content_json": {
            "taskType": "Task 1",
            "prompt": "The plans below show the site of an airport in 1995 and how it looks now.",
            "minWordCount": 150,
            "suggestedTimeMinutes": 20,
            "keyOutline": ["Intro", "Overview", "Development in Terminal", "Runway expansion"],
            "sampleEssay": "The diagrams illustrate the layout changes of a city airport...",
            "academicVocabulary": ["modernization", "infrastructure redeveloped"],
            "chart_data": {
                "type": "image",
                "image_url": "https://tcbcmzfdidcwblvfmckb.supabase.co/storage/v1/object/public/ielts-assets/charts/sample_map.png"
            }
        }
    }

    create_img_res = client.post("/api/v1/admin/skills/lessons", headers=headers, json=new_image_lesson)
    assert create_img_res.status_code in (200, 201), f"Tạo bài viết Task 1 Image thất bại: {create_img_res.text}"
    img_created_id = create_img_res.json()["id"]
    print(f"✓ 3. Tạo thành công bài viết Task 1 dạng Ảnh Supabase (ID: {img_created_id}).")

    # 4. Kiểm tra API công khai cho Học viên (/api/v1/skills/writing/lessons)
    get_res = client.get("/api/v1/skills/writing/lessons")
    assert get_res.status_code == 200
    all_lessons = get_res.json()
    assert len(all_lessons) >= 2

    # Kiểm tra bài học Task 1 vừa tạo có chart_data đầy đủ
    created_match = next((l for l in all_lessons if l["id"] == created_id), None)
    assert created_match is not None, f"Không tìm thấy bài vừa tạo {created_id}"
    created_chart = created_match["content_json"].get("chart_data")
    assert created_chart is not None and created_chart["type"] == "bar"
    assert len(created_chart["series"]) == 3
    assert created_chart["categories"] == ["2018", "2020", "2022", "2024"]

    # Kiểm tra bài học Task 1 dạng Ảnh vừa tạo
    img_match = next((l for l in all_lessons if l["id"] == img_created_id), None)
    assert img_match is not None, f"Không tìm thấy bài vừa tạo {img_created_id}"
    img_chart = img_match["content_json"].get("chart_data")
    assert img_chart is not None and img_chart["type"] == "image"
    assert "sample_map.png" in img_chart["image_url"]

    print("✓ 4. API Học viên (/skills/writing/lessons) trả về cấu trúc chart_data đầy đủ và chuẩn xác.")

    # 5. Dọn dẹp bài test
    client.delete(f"/api/v1/admin/skills/lessons/{created_id}", headers=headers)
    client.delete(f"/api/v1/admin/skills/lessons/{img_created_id}", headers=headers)
    print("✓ 5. Dọn dẹp các bài học thử nghiệm thành công.")

    print("\n🎉 HOÀN THÀNH TOÀN DIỆN KIỂM THỬ GIAI ĐOẠN 2!\n")

if __name__ == "__main__":
    with TestClient(app) as client:
        test_stage2_chart_crud()

