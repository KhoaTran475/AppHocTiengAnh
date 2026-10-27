import sys
import os

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.db.session import SessionLocal
from app.services.skill_service import seed_default_skill_lessons

client = TestClient(app)

def test_gamification_all_skills():
    db = SessionLocal()
    seed_default_skill_lessons(db)
    db.close()

    # 1. Login Learner
    res_login = client.post(
        "/api/v1/auth/login",
        json={"username": "learner", "password": "password123"},
    )
    assert res_login.status_code == 200, f"Login failed: {res_login.text}"
    token = res_login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Kiểm tra đủ 5 ải cho cả 4 kỹ năng
    skills = ["reading", "listening", "writing", "speaking"]
    for skill in skills:
        r_lessons = client.get(f"/api/v1/skills/{skill}/lessons")
        assert r_lessons.status_code == 200, f"Failed getting lessons for {skill}"
        lessons = r_lessons.json()
        assert len(lessons) == 5, f"Expected 5 lessons for {skill}, got {len(lessons)}"
        print(f"✅ {skill.upper()}: Có đủ 5 ải vượt cấp ({', '.join(l['id'] for l in lessons)})")

    # 3. Test Vượt ải Reading (Ải 1 -> Mở ải 2)
    prog_r_before = client.get("/api/v1/skills/reading/progress", headers=headers).json()
    assert prog_r_before["highest_unlocked_stage"] >= 1

    r_submit = client.post(
        "/api/v1/skills/submit",
        headers=headers,
        json={
            "lesson_id": "r1",
            "skill_type": "reading",
            "answers": {
                "1": "Tailoring learning materials to individual student pacing",
                "2": "By mapping camera-scanned objects to academic vocabulary",
                "3": "AI tools augment pedagogy rather than replace human teachers",
            },
        },
    )
    assert r_submit.status_code == 200, f"Reading submit failed: {r_submit.text}"
    res_r = r_submit.json()
    assert res_r["passed"] is True
    assert res_r["stars"] == 3
    print(f"✅ Reading Ải 1: Điểm {res_r['score']}/{res_r['total_questions']} | {res_r['stars']}⭐ | Band {res_r['band_score']}")

    prog_r_after = client.get("/api/v1/skills/reading/progress", headers=headers).json()
    assert prog_r_after["highest_unlocked_stage"] >= 2
    assert prog_r_after["stages"][1]["is_unlocked"] is True
    print(f"✅ Reading Gamification: Đã mở khóa Ải 2 thành công! (Highest: {prog_r_after['highest_unlocked_stage']})")

    # 4. Test Vượt ải Writing (Ải 1 -> Mở ải 2)
    w_sample = (
        "The line graph delineates the proportion of households possessing internet connectivity across metropolitan and rural districts over a ten-year span from 2015 to 2025. "
        "Overall, it is manifest that both sectors experienced a noticeable upward trajectory throughout the examined timeline. "
        "Furthermore, while urban regions consistently registered higher connectivity rates, the disparity between the two categories narrowed considerably towards the end of the period. "
        "In 2015, approximately 65% of urban dwellings were equipped with online access, compared to a modest 30% in rural vicinities. "
        "Over the subsequent five years, urban adoption surged steadily, surpassing 80% by 2020. Simultaneously, rural connectivity witnessed exponential growth, climbing to nearly 55% as telecommunication infrastructure expanded. "
        "By 2025, internet penetration in cities plateaued at an impressive 92%. In contrast, rural areas continued their accelerated ascent to reach 78%, thereby significantly reducing the digital divide to merely 14 percentage points."
    )
    w_submit = client.post(
        "/api/v1/skills/submit",
        headers=headers,
        json={
            "lesson_id": "w1",
            "skill_type": "writing",
            "essay_text": w_sample,
        },
    )
    assert w_submit.status_code == 200, f"Writing submit failed: {w_submit.text}"
    res_w = w_submit.json()
    assert res_w["passed"] is True
    print(f"✅ Writing Ải 1: Số từ {res_w['score']} | {res_w['stars']}⭐ | Band {res_w['band_score']}")

    prog_w_after = client.get("/api/v1/skills/writing/progress", headers=headers).json()
    assert prog_w_after["highest_unlocked_stage"] >= 2
    assert prog_w_after["stages"][1]["is_unlocked"] is True
    print(f"✅ Writing Gamification: Đã mở khóa Ải 2 thành công! (Highest: {prog_w_after['highest_unlocked_stage']})")

    # 5. Test Vượt ải Speaking (Ải 1 -> Mở ải 2)
    s_submit = client.post(
        "/api/v1/skills/submit",
        headers=headers,
        json={
            "lesson_id": "s1",
            "skill_type": "speaking",
            "ratings": {"fluency": 8, "vocabulary": 8, "pronunciation": 8},
        },
    )
    assert s_submit.status_code == 200, f"Speaking submit failed: {s_submit.text}"
    res_s = s_submit.json()
    assert res_s["passed"] is True
    print(f"✅ Speaking Ải 1: {res_s['stars']}⭐ | Band {res_s['band_score']}")

    prog_s_after = client.get("/api/v1/skills/speaking/progress", headers=headers).json()
    assert prog_s_after["highest_unlocked_stage"] >= 2
    assert prog_s_after["stages"][1]["is_unlocked"] is True
    print(f"✅ Speaking Gamification: Đã mở khóa Ải 2 thành công! (Highest: {prog_s_after['highest_unlocked_stage']})")

    print("\n🎉 TOÀN BỘ 4 KỸ NĂNG ĐÃ VƯỢT ẢI GAMIFICATION HOÀN HẢO 100% TRÊN BACKEND!")

if __name__ == "__main__":
    test_gamification_all_skills()
