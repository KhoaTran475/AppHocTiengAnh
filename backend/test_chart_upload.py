import io
import sys
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8")
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_chart_upload_flow():
    print("=== [TEST GIAI ĐOẠN 1] BẢO MẬT & UPLOAD ẢNH BIỂU ĐỒ SUPABASE STORAGE ===")

    # 1. Đăng nhập Admin
    login_res = client.post("/api/v1/auth/login", json={"username": "admin", "password": "password123"})
    assert login_res.status_code == 200, f"Login admin thất bại: {login_res.text}"
    admin_token = login_res.json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    print("✓ 1. Đăng nhập Admin thành công.")

    # 2. Đăng nhập Learner (Kiểm tra RBAC: Learner không được phép upload)
    l_login = client.post("/api/v1/auth/login", json={"username": "learner", "password": "password123"})
    assert l_login.status_code == 200
    learner_token = l_login.json()["access_token"]
    learner_headers = {"Authorization": f"Bearer {learner_token}"}

    fake_img = io.BytesIO(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4")
    r_forbidden = client.post(
        "/api/v1/admin/skills/upload-chart",
        headers=learner_headers,
        files={"file": ("chart.png", fake_img, "image/png")}
    )
    assert r_forbidden.status_code == 403, f"Quyền RBAC thất bại: {r_forbidden.status_code}"
    print("✓ 2. Bảo mật RBAC: Học viên (Learner) bị chặn 403 khi cố upload ảnh.")

    # 3. Kiểm tra validate định dạng file (.pdf / .txt bị từ chối 400)
    fake_txt = io.BytesIO(b"Hello world, not an image")
    r_invalid_ext = client.post(
        "/api/v1/admin/skills/upload-chart",
        headers=admin_headers,
        files={"file": ("malicious.txt", fake_txt, "text/plain")}
    )
    assert r_invalid_ext.status_code == 400, f"Validate file extension thất bại: {r_invalid_ext.status_code}"
    print("✓ 3. Validate định dạng file: File .txt bị từ chối 400 thành công.")

    # 4. Kiểm tra validate kích thước file (> 5MB bị từ chối 400)
    oversized_data = io.BytesIO(b"0" * (5 * 1024 * 1024 + 100))
    r_oversized = client.post(
        "/api/v1/admin/skills/upload-chart",
        headers=admin_headers,
        files={"file": ("huge_chart.png", oversized_data, "image/png")}
    )
    assert r_oversized.status_code == 400, f"Validate size thất bại: {r_oversized.status_code}"
    print("✓ 4. Validate kích thước file: File > 5MB bị từ chối 400 thành công.")

    # 5. Tải file ảnh hợp lệ (.png)
    valid_png = io.BytesIO(b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\nIDATx\x9cc`\x00\x00\x00\x02\x00\x01H\xaf\xa4q\x00\x00\x00\x00IEND\xaeB`\x82")
    r_upload = client.post(
        "/api/v1/admin/skills/upload-chart",
        headers=admin_headers,
        files={"file": ("ielts_bar_chart.png", valid_png, "image/png")}
    )
    assert r_upload.status_code == 200, f"Upload thất bại: {r_upload.status_code} - {r_upload.text}"
    data = r_upload.json()
    assert data["success"] is True
    assert "url" in data and len(data["url"]) > 0
    print(f"✓ 5. Upload thành công! Nguồn: '{data['source']}', URL: {data['url']}")

    print("\n🎉 HOÀN THÀNH TOÀN DIỆN KIỂM THỬ GIAI ĐOẠN 1!\n")

if __name__ == "__main__":
    test_chart_upload_flow()
