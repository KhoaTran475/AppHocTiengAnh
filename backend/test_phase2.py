import sys
sys.stdout.reconfigure(encoding='utf-8')
from fastapi.testclient import TestClient
from app.main import app

with TestClient(app) as client:
    print("=== 1. TEST ROOT & HEALTH ===")
    r = client.get("/")
    print("Root:", r.status_code, r.json().get("project"))
    assert r.status_code == 200

    r = client.get("/health")
    print("Health:", r.status_code, r.json().get("supabase", {}).get("status"))
    assert r.status_code == 200

    print("\n=== 2. TEST LOGIN ADMIN ===")
    r = client.post("/api/v1/auth/login", json={"username": "admin", "password": "password123"})
    print("Admin Login:", r.status_code, r.json().get("user"))
    assert r.status_code == 200
    admin_token = r.json()["access_token"]
    assert r.json()["user"]["role"] == "admin"

    print("\n=== 3. TEST LOGIN LEARNER ===")
    r = client.post("/api/v1/auth/login", json={"username": "learner", "password": "password123"})
    print("Learner Login:", r.status_code, r.json().get("user"))
    assert r.status_code == 200
    learner_token = r.json()["access_token"]
    assert r.json()["user"]["role"] == "learner"

    print("\n=== 4. TEST LOGIN WRONG PASSWORD ===")
    r = client.post("/api/v1/auth/login", json={"username": "admin", "password": "wrongpassword"})
    print("Wrong Login Status:", r.status_code, "Detail:", r.json().get("detail"))
    assert r.status_code == 401

    print("\n=== 5. TEST GET /ME ===")
    r = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {admin_token}"})
    print("Admin Me:", r.status_code, r.json().get("username"), r.json().get("role"))
    assert r.status_code == 200
    assert r.json()["username"] == "admin"

    print("\n=== 6. TEST RBAC (ADMIN ONLY ENDPOINTS) ===")
    # Learner tries to access admin endpoint -> 403 Forbidden
    r = client.get("/api/v1/users/", headers={"Authorization": f"Bearer {learner_token}"})
    print("Learner accessing /users/ -> Expected 403:", r.status_code, r.json().get("detail"))
    assert r.status_code == 403

    # Admin accesses admin endpoint -> 200 OK
    r = client.get("/api/v1/users/", headers={"Authorization": f"Bearer {admin_token}"})
    print("Admin accessing /users/ -> Expected 200:", r.status_code, f"Total users in DB: {len(r.json())}")
    assert r.status_code == 200

    # Admin accesses KPIs -> 200 OK
    r = client.get("/api/v1/admin/kpis", headers={"Authorization": f"Bearer {admin_token}"})
    print("Admin accessing /admin/kpis -> Expected 200:", r.status_code, r.json())
    assert r.status_code == 200

    print("\n=== 7. TEST REGISTER NEW USER ===")
    test_uname = "testuser_fastapi_1"
    r = client.post("/api/v1/auth/register", json={
        "username": test_uname,
        "password": "mypassword123",
        "role": "learner"
    })
    print("Register new user status:", r.status_code, r.json().get("user"))
    assert r.status_code in [201, 400]

    print("\n========================================================")
    print("🎉 TẤT CẢ TEST PHASE 2 THÀNH CÔNG 100%! AUTH & RBAC HOÀN HẢO!")
    print("========================================================")
