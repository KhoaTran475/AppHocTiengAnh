import sys
sys.stdout.reconfigure(encoding="utf-8")
import io
import base64
from PIL import Image
from fastapi.testclient import TestClient

sys.path.append("backend")
from app.main import app
from app.db.session import SessionLocal
from app.models.user import User
from app.core.security import get_password_hash, create_access_token

client = TestClient(app)
db = SessionLocal()

test_uname = "__test_e2e_face_user__"
test_pwd = "password123"
created_user = None

try:
    # 0. Dọn dẹp user cũ nếu có
    db.query(User).filter(User.username == test_uname).delete()
    db.commit()

    created_user = User(
        username=test_uname,
        hashed_password=get_password_hash(test_pwd),
        role="learner",
        is_face_auth_enabled=False
    )
    db.add(created_user)
    db.commit()
    db.refresh(created_user)

    auth_token = create_access_token(subject=test_uname, role="learner")
    auth_headers = {"Authorization": f"Bearer {auth_token}"}

    # Tạo ảnh mẫu
    img1 = Image.new("RGB", (160, 160), color=(140, 95, 75))
    b1 = io.BytesIO()
    img1.save(b1, format="JPEG")
    b64_face1 = "data:image/jpeg;base64," + base64.b64encode(b1.getvalue()).decode("utf-8")

    # Ảnh người khác
    img2 = Image.new("RGB", (160, 160), color=(30, 200, 220))
    b2 = io.BytesIO()
    img2.save(b2, format="JPEG")
    b64_face2 = "data:image/jpeg;base64," + base64.b64encode(b2.getvalue()).decode("utf-8")

    print("=== TEST 1: GET /api/v1/auth/face/nonce ===")
    r = client.get("/api/v1/auth/face/nonce")
    assert r.status_code == 200
    nonce1 = r.json()["nonce"]
    print(f"Nonce received: {nonce1[:10]}... (expires_in={r.json()['expires_in']})")

    print("\n=== TEST 2: POST /api/v1/auth/face/register với Nonce sai ===")
    r_bad = client.post("/api/v1/auth/face/register", headers=auth_headers, json={
        "nonce": "invalid_nonce_12345678",
        "image_base64": b64_face1,
    })
    assert r_bad.status_code == 400
    print(f"Chặn Nonce sai thành công: {r_bad.status_code} - {r_bad.json()['detail']}")

    print("\n=== TEST 3: POST /api/v1/auth/face/register Hợp lệ ===")
    r_reg = client.post("/api/v1/auth/face/register", headers=auth_headers, json={
        "nonce": nonce1,
        "image_base64": b64_face1,
    })
    assert r_reg.status_code == 200
    assert r_reg.json()["is_face_auth_enabled"] is True
    print(f"Đăng ký FaceID thành công: {r_reg.json()}")

    print("\n=== TEST 4: Thử đăng ký lại với nonce cũ (Replay) ===")
    r_rep = client.post("/api/v1/auth/face/register", headers=auth_headers, json={
        "nonce": nonce1,
        "image_base64": b64_face1,
    })
    assert r_rep.status_code == 400
    print(f"Chống Replay thành công: {r_rep.status_code} - {r_rep.json()['detail']}")

    print("\n=== TEST 5: GET /api/v1/auth/face/status ===")
    r_stat = client.get("/api/v1/auth/face/status", headers=auth_headers)
    assert r_stat.status_code == 200
    assert r_stat.json()["is_face_auth_enabled"] is True
    print(f"Status: {r_stat.json()}")

    print("\n=== TEST 6a: POST /api/v1/auth/face/login (Ngưỡng 0.70-0.79 -> 422 Cảnh báo ánh sáng/góc) ===")
    r_nonce_login1 = client.get("/api/v1/auth/face/nonce")
    nonce_login1 = r_nonce_login1.json()["nonce"]
    r_login_low = client.post("/api/v1/auth/face/login", json={
        "nonce": nonce_login1,
        "image_base64": b64_face2,
        "username_hint": test_uname
    })
    assert r_login_low.status_code == 422
    print(f"Báo lỗi ánh sáng/góc thành công: {r_login_low.status_code} - {r_login_low.json()['detail']}")

    print("\n=== TEST 6b: POST /api/v1/auth/face/login (User không tồn tại hoặc không khớp -> 401) ===")
    r_nonce_login1b = client.get("/api/v1/auth/face/nonce")
    nonce_login1b = r_nonce_login1b.json()["nonce"]
    r_login_fail = client.post("/api/v1/auth/face/login", json={
        "nonce": nonce_login1b,
        "image_base64": b64_face2,
        "username_hint": "non_existent_user_999"
    })
    assert r_login_fail.status_code == 401
    print(f"Từ chối không khớp thành công: {r_login_fail.status_code} - {r_login_fail.json()['detail']}")

    print("\n=== TEST 7: POST /api/v1/auth/face/login (Chính chủ -> 200 + JWT Token) ===")
    r_nonce_login2 = client.get("/api/v1/auth/face/nonce")
    nonce_login2 = r_nonce_login2.json()["nonce"]
    r_login_ok = client.post("/api/v1/auth/face/login", json={
        "nonce": nonce_login2,
        "image_base64": b64_face1,
        "username_hint": test_uname
    })
    assert r_login_ok.status_code == 200
    data = r_login_ok.json()
    assert "access_token" in data
    assert data["user"]["username"] == test_uname
    print(f"Đăng nhập FaceID 1:1 thành công! Token: {data['access_token'][:15]}... (Score={data['similarity_score']})")

    print("\n=== TEST 8: POST /api/v1/auth/face/login 1:N (Không cần hint username) ===")
    r_nonce_login3 = client.get("/api/v1/auth/face/nonce")
    nonce_login3 = r_nonce_login3.json()["nonce"]
    r_login_1n = client.post("/api/v1/auth/face/login", json={
        "nonce": nonce_login3,
        "image_base64": b64_face1,
    })
    assert r_login_1n.status_code == 200
    data_1n = r_login_1n.json()
    assert data_1n["user"]["username"] == test_uname
    print(f"Đăng nhập FaceID 1:N thành công! Nhận diện đúng user: {data_1n['user']['username']} (Score={data_1n['similarity_score']})")

    print("\n=== TEST 9: DELETE /api/v1/auth/face ===")
    r_del = client.delete("/api/v1/auth/face", headers=auth_headers)
    assert r_del.status_code == 200
    assert r_del.json()["is_face_auth_enabled"] is False
    print(f"Hủy FaceID thành công: {r_del.json()}")

    print("\n=== TEST 10: Xác nhận lại trạng thái sau khi hủy ===")
    r_stat_after = client.get("/api/v1/auth/face/status", headers=auth_headers)
    assert r_stat_after.json()["is_face_auth_enabled"] is False
    print("Trạng thái đã cập nhật tắt FaceID!")

finally:
    if created_user:
        db.delete(created_user)
        db.commit()
    db.close()

print("\nTẤT CẢ 10 BÀI TEST E2E API ENDPOINTS ĐÃ THÀNH CÔNG 100%!")
