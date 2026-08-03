"""Auth endpoint-ləri: qeydiyyat, giriş, hesab məlumatı, hesab silmə."""

import pytest
from fastapi.testclient import TestClient

from dildostu_server.app import app, get_token_secret, get_user_store
from dildostu_server.user_store import UserStore

_SECRET = "test-secret-key-32-chars-minimum!!"

_PROFILE = {
    "wake_hour": 8, "sleep_hour": 23, "purpose": "travel",
    "level": "beginner", "interests": [],
}


@pytest.fixture
def client():
    store = UserStore(":memory:")
    app.dependency_overrides[get_user_store] = lambda: store
    app.dependency_overrides[get_token_secret] = lambda: _SECRET
    yield TestClient(app)
    app.dependency_overrides.clear()


def _register(client, email="ali@example.com", password="Parol1234"):
    return client.post("/auth/register", json={"email": email, "password": password})


class TestRegister:
    def test_returns_token_and_user(self, client):
        r = _register(client)
        assert r.status_code == 201
        body = r.json()
        assert body["token"]
        assert body["user"]["email"] == "ali@example.com"

    def test_password_hash_never_returned(self, client):
        r = _register(client)
        assert "password" not in str(r.json()).lower() or "password_hash" not in r.json()["user"]

    def test_duplicate_email_409(self, client):
        _register(client)
        assert _register(client).status_code == 409

    def test_duplicate_is_case_insensitive(self, client):
        _register(client, email="ali@example.com")
        assert _register(client, email="ALI@Example.com").status_code == 409

    def test_invalid_email_422(self, client):
        assert _register(client, email="bu-email-deyil").status_code == 422

    def test_short_password_422(self, client):
        assert _register(client, password="123").status_code == 422

    def test_token_works_immediately(self, client):
        token = _register(client).json()["token"]
        r = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200


class TestLogin:
    def test_correct_credentials_return_token(self, client):
        _register(client)
        r = client.post("/auth/login", json={
            "email": "ali@example.com", "password": "Parol1234",
        })
        assert r.status_code == 200
        assert r.json()["token"]

    def test_email_case_insensitive(self, client):
        _register(client)
        r = client.post("/auth/login", json={
            "email": "ALI@EXAMPLE.COM", "password": "Parol1234",
        })
        assert r.status_code == 200

    def test_wrong_password_401(self, client):
        _register(client)
        r = client.post("/auth/login", json={
            "email": "ali@example.com", "password": "SehvParol",
        })
        assert r.status_code == 401

    def test_unknown_email_401(self, client):
        r = client.post("/auth/login", json={
            "email": "yox@example.com", "password": "Parol1234",
        })
        assert r.status_code == 401

    def test_unknown_email_and_wrong_password_same_status(self, client):
        """İstifadəçi sayımının qarşısını alır — hər iki hal eyni cavab."""
        _register(client)
        wrong_pw = client.post("/auth/login", json={
            "email": "ali@example.com", "password": "Sehv",
        })
        no_user = client.post("/auth/login", json={
            "email": "yox@example.com", "password": "Sehv",
        })
        assert wrong_pw.status_code == no_user.status_code == 401
        assert wrong_pw.json()["detail"] == no_user.json()["detail"]


class TestMe:
    def test_returns_current_user(self, client):
        token = _register(client).json()["token"]
        r = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert r.json()["email"] == "ali@example.com"

    def test_missing_header_401(self, client):
        assert client.get("/auth/me").status_code == 401

    def test_garbage_token_401(self, client):
        r = client.get("/auth/me", headers={"Authorization": "Bearer zibil"})
        assert r.status_code == 401

    def test_wrong_scheme_401(self, client):
        r = client.get("/auth/me", headers={"Authorization": "Basic abc"})
        assert r.status_code == 401

    def test_token_of_deleted_user_401(self, client):
        token = _register(client).json()["token"]
        client.delete("/auth/me", headers={"Authorization": f"Bearer {token}"})
        r = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 401


class TestDeleteAccount:
    """Play Store hesab sistemi olan tətbiqlərdən hesab silməni TƏLƏB edir."""

    def test_deletes_account(self, client):
        token = _register(client).json()["token"]
        r = client.delete("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 204

    def test_email_reusable_after_delete(self, client):
        token = _register(client).json()["token"]
        client.delete("/auth/me", headers={"Authorization": f"Bearer {token}"})
        assert _register(client).status_code == 201

    def test_requires_auth(self, client):
        assert client.delete("/auth/me").status_code == 401


class TestProfileEndpoints:
    def test_profile_empty_by_default(self, client):
        token = _register(client).json()["token"]
        r = client.get("/profile", headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200
        assert r.json()["profile"] is None

    def test_save_and_read_profile(self, client):
        token = _register(client).json()["token"]
        headers = {"Authorization": f"Bearer {token}"}
        client.put("/profile", json={"profile": _PROFILE}, headers=headers)
        r = client.get("/profile", headers=headers)
        assert r.json()["profile"]["level"] == "beginner"

    def test_invalid_profile_422(self, client):
        token = _register(client).json()["token"]
        bad = {**_PROFILE, "level": "expert"}
        r = client.put("/profile", json={"profile": bad},
                       headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 422

    def test_requires_auth(self, client):
        assert client.get("/profile").status_code == 401

    def test_users_do_not_see_each_others_profile(self, client):
        token_a = _register(client, email="a@example.com").json()["token"]
        token_b = _register(client, email="b@example.com").json()["token"]
        client.put("/profile", json={"profile": _PROFILE},
                   headers={"Authorization": f"Bearer {token_a}"})
        r = client.get("/profile", headers={"Authorization": f"Bearer {token_b}"})
        assert r.json()["profile"] is None
