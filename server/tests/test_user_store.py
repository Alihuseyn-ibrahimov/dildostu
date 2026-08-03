import pytest

from dildostu_server.user_store import DuplicateEmail, UserStore


def _store():
    return UserStore(":memory:")


class TestCreateUser:
    def test_creates_and_returns_user(self):
        store = _store()
        user = store.create("ali@example.com", "hash123")
        assert user["id"] >= 1
        assert user["email"] == "ali@example.com"
        assert "created_at" in user

    def test_email_normalized_to_lowercase(self):
        store = _store()
        store.create("Ali@Example.COM", "h")
        assert store.get_by_email("ali@example.com") is not None

    def test_duplicate_email_rejected(self):
        store = _store()
        store.create("ali@example.com", "h")
        with pytest.raises(DuplicateEmail):
            store.create("ali@example.com", "h2")

    def test_duplicate_check_is_case_insensitive(self):
        store = _store()
        store.create("ali@example.com", "h")
        with pytest.raises(DuplicateEmail):
            store.create("ALI@EXAMPLE.COM", "h2")


class TestLookup:
    def test_get_by_email_returns_hash(self):
        store = _store()
        store.create("ali@example.com", "secret-hash")
        row = store.get_by_email("ali@example.com")
        assert row["password_hash"] == "secret-hash"

    def test_get_by_email_case_insensitive(self):
        store = _store()
        store.create("ali@example.com", "h")
        assert store.get_by_email("ALI@example.com") is not None

    def test_unknown_email_returns_none(self):
        assert _store().get_by_email("yox@example.com") is None

    def test_get_by_id(self):
        store = _store()
        created = store.create("ali@example.com", "h")
        assert store.get_by_id(created["id"])["email"] == "ali@example.com"

    def test_unknown_id_returns_none(self):
        assert _store().get_by_id(9999) is None


class TestDelete:
    def test_delete_removes_user(self):
        store = _store()
        user = store.create("ali@example.com", "h")
        store.delete(user["id"])
        assert store.get_by_id(user["id"]) is None

    def test_delete_unknown_id_is_silent(self):
        _store().delete(9999)  # atmamalı

    def test_email_reusable_after_delete(self):
        store = _store()
        user = store.create("ali@example.com", "h")
        store.delete(user["id"])
        assert store.create("ali@example.com", "h2")["id"] >= 1


class TestProfile:
    def test_profile_none_by_default(self):
        store = _store()
        user = store.create("ali@example.com", "h")
        assert store.get_profile(user["id"]) is None

    def test_save_and_read_profile(self):
        store = _store()
        user = store.create("ali@example.com", "h")
        profile = {
            "wake_hour": 7, "sleep_hour": 22, "purpose": "work",
            "level": "advanced", "interests": ["idman"],
        }
        store.save_profile(user["id"], profile)
        assert store.get_profile(user["id"]) == profile

    def test_save_profile_overwrites(self):
        store = _store()
        user = store.create("ali@example.com", "h")
        store.save_profile(user["id"], {"level": "beginner"})
        store.save_profile(user["id"], {"level": "advanced"})
        assert store.get_profile(user["id"])["level"] == "advanced"

    def test_delete_user_removes_profile(self):
        store = _store()
        user = store.create("ali@example.com", "h")
        store.save_profile(user["id"], {"level": "beginner"})
        store.delete(user["id"])
        assert store.get_profile(user["id"]) is None
