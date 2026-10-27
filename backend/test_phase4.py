import sys
sys.stdout.reconfigure(encoding='utf-8')
from fastapi.testclient import TestClient
from app.main import app

with TestClient(app) as client:
    print("=== 1. ĐĂNG NHẬP LEARNER ===")
    r_login = client.post("/api/v1/auth/login", json={"username": "learner", "password": "password123"})
    assert r_login.status_code == 200
    token = r_login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("Đăng nhập học viên thành công!")

    print("\n=== 2. KIỂM TRA DANH SÁCH BÀI HỌC 4 KỸ NĂNG ===")
    # Reading
    r_reading = client.get("/api/v1/skills/reading/lessons")
    assert r_reading.status_code == 200
    reading_lessons = r_reading.json()
    print(f"Reading: Có {len(reading_lessons)} bài đọc ({', '.join(l['id'] for l in reading_lessons)})")
    assert len(reading_lessons) >= 2

    # Listening
    r_listening = client.get("/api/v1/skills/listening/lessons")
    assert r_listening.status_code == 200
    listening_lessons = r_listening.json()
    print(f"Listening: Có {len(listening_lessons)} ải vượt cấp ({', '.join(l['difficulty_label'] for l in listening_lessons)})")
    assert len(listening_lessons) == 5

    # Speaking
    r_speaking = client.get("/api/v1/skills/speaking/lessons")
    assert r_speaking.status_code == 200
    speaking_lessons = r_speaking.json()
    print(f"Speaking: Có {len(speaking_lessons)} bài luyện nói ({speaking_lessons[0]['title']})")
    assert len(speaking_lessons) >= 1

    # Writing
    r_writing = client.get("/api/v1/skills/writing/lessons")
    assert r_writing.status_code == 200
    writing_lessons = r_writing.json()
    print(f"Writing: Có {len(writing_lessons)} đề bài viết ({writing_lessons[0]['title']})")
    assert len(writing_lessons) >= 1

    print("\n=== 3. TEST CHẤM ĐIỂM READING ===")
    # Nộp đúng 3/3 câu của bài r1
    submit_r = client.post(
        "/api/v1/skills/submit",
        json={
            "lesson_id": "r1",
            "skill_type": "reading",
            "answers": {
                "1": "Tailoring learning materials to individual student pacing",
                "2": "By mapping camera-scanned objects to academic vocabulary",
                "3": "AI tools augment pedagogy rather than replace human teachers"
            }
        },
        headers=headers,
    )
    assert submit_r.status_code == 200
    res_r = submit_r.json()
    print("Kết quả Reading:", f"Điểm: {res_r['score']}/{res_r['total_questions']} | Band: {res_r['band_score']} | Feedback: {res_r['feedback']}")
    assert res_r["score"] == 3
    assert res_r["band_score"] == "8.5+"

    print("\n=== 4. TEST CHẤM ĐIỂM LISTENING & MỞ KHÓA ẢI GAMIFICATION ===")
    # Ban đầu kiểm tra tiến độ ải
    r_prog_before = client.get("/api/v1/skills/listening/progress", headers=headers)
    assert r_prog_before.status_code == 200
    print("Tiến độ trước khi làm ải 1:", f"Ải cao nhất: {r_prog_before.json()['highest_unlocked_stage']}")

    # Nộp bài Ải 1 (l1) đạt 3/3 câu
    submit_l = client.post(
        "/api/v1/skills/submit",
        json={
            "lesson_id": "l1",
            "skill_type": "listening",
            "answers": {
                "1": "Senior Academic Coordinator",
                "2": "8:00 AM to 10:00 PM",
                "3": "University ID card"
            }
        },
        headers=headers,
    )
    assert submit_l.status_code == 200
    res_l = submit_l.json()
    print("Kết quả Listening Ải 1:", f"Điểm: {res_l['score']}/{res_l['total_questions']} | Đạt: {res_l['passed']} | Sao: {res_l['stars']}⭐ | Band: {res_l['band_score']}")
    assert res_l["passed"] is True
    assert res_l["stars"] == 3

    # Kiểm tra tiến độ sau khi hoàn thành ải 1: Ải 2 phải được mở khóa!
    r_prog_after = client.get("/api/v1/skills/listening/progress", headers=headers)
    assert r_prog_after.status_code == 200
    stages = r_prog_after.json()["stages"]
    print(f"Tiến độ sau ải 1: Ải 1 có {stages[0]['stars']} sao, Ải 2 đã mở khóa: {stages[1]['is_unlocked']}")
    assert stages[1]["is_unlocked"] is True

    print("\n=== 5. TEST CHẤM ĐIỂM WRITING ===")
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
    submit_w = client.post(
        "/api/v1/skills/submit",
        json={
            "lesson_id": "w1",
            "skill_type": "writing",
            "essay_text": sample_text
        },
        headers=headers,
    )
    assert submit_w.status_code == 200
    res_w = submit_w.json()
    print("Kết quả Writing:", f"Số từ: {res_w['score']} | Band: {res_w['band_score']} | Feedback: {res_w['feedback']}")
    assert float(res_w["band_score"]) >= 7.5

    print("\n=== 6. TEST ĐÁNH GIÁ SPEAKING ===")
    submit_s = client.post(
        "/api/v1/skills/submit",
        json={
            "lesson_id": "s1",
            "skill_type": "speaking",
            "ratings": {"fluency": 8, "vocabulary": 8, "pronunciation": 8}
        },
        headers=headers,
    )
    assert submit_s.status_code == 200
    res_s = submit_s.json()
    print("Kết quả Speaking:", f"Band: {res_s['band_score']} | Feedback: {res_s['feedback']}")
    assert res_s["band_score"] == "8.0"

    print("\n=== 7. TEST TRUY VẤN LỊCH SỬ THI PRACTICE_HISTORY ===")
    r_hist = client.get("/api/v1/skills/history", headers=headers)
    assert r_hist.status_code == 200
    history_items = r_hist.json()
    print(f"Tổng số bài thi trong lịch sử: {len(history_items)} bài")
    assert len(history_items) >= 4
    for h in history_items:
        print(f" - [{h['skill_type'].upper()}] {h['lesson_title']} -> Band {h['band_score']} (Lúc: {h['created_at']})")

    print("\n========================================================")
    print("🎉 TẤT CẢ TEST PHASE 4 THÀNH CÔNG 100%! 4 KỸ NĂNG IELTS HOÀN HẢO!")
    print("========================================================")
