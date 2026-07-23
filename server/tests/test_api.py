import json

import pytest
from fastapi.testclient import TestClient

from dildostu_server.app import (
    app,
    get_chat_completers,
    get_completers,
    get_release_store,
    get_routine_store,
)
from dildostu_server.release_store import ReleaseStore
from dildostu_server.routine_store import RoutineStore


def _word_json(word="coffee", pack_id=None):
    obj = {
        "word": word,
        "translation_az": "qəhvə",
        "ipa": "/ˈkɒfi/",
        "example": "I would like a coffee.",
        "example_az": "Mən qəhvə istəyirəm.",
        "ai_line": "İndi kafedəsən!",
        "level": 1,
    }
    if pack_id:
        obj["pack_id"] = pack_id
    return obj


class Counter:
    def __init__(self, response):
        self.response = response
        self.calls = 0

    def __call__(self, system, user):
        self.calls += 1
        return self.response


def override(completers):
    app.dependency_overrides[get_completers] = lambda: completers
    return TestClient(app)


@pytest.fixture(autouse=True)
def _clean_state():
    """Hər testdən sonra override və keşi təmizlə (class metodları daxil)."""
    yield
    app.dependency_overrides.clear()
    app.state.cache.clear()


PROFILE = {
    "wake_hour": 8, "sleep_hour": 23, "purpose": "travel",
    "level": "beginner", "interests": [],
}


class TestGenerateEndpoint:
    def test_success(self):
        client = override({"groq": Counter(json.dumps(_word_json()))})
        r = client.post("/generate", json={
            "profile": PROFILE,
            "context": {"pack_id": "cafe", "hour": 9},
        })
        assert r.status_code == 200
        body = r.json()
        assert body["word"] == "coffee"
        assert body["pack_id"] == "cafe"

    def test_ai_failure_returns_502(self):
        def failing(s, u):
            raise RuntimeError("limit")
        client = override({"groq": failing, "claude": failing})
        r = client.post("/generate", json={
            "profile": PROFILE,
            "context": {"pack_id": "cafe", "hour": 9},
        })
        assert r.status_code == 502

    def test_cache_avoids_second_ai_call(self):
        counter = Counter(json.dumps(_word_json()))
        client = override({"groq": counter})
        payload = {"profile": PROFILE, "context": {"pack_id": "cafe", "hour": 9}}
        client.post("/generate", json=payload)
        client.post("/generate", json=payload)
        assert counter.calls == 1  # ikinci keşdən gəldi

    def test_different_mode_not_cached_together(self):
        counter = Counter(json.dumps(_word_json()))
        client = override({"groq": counter, "claude": counter})
        base = {"profile": PROFILE, "context": {"pack_id": "cafe", "hour": 9}}
        client.post("/generate", json={**base, "mode": "normal"})
        client.post("/generate", json={**base, "mode": "simpler"})
        assert counter.calls == 2


class TestDayPlanEndpoint:
    def test_success(self):
        payload = {"messages": [
            _word_json("good morning", "morning"),
            _word_json("coffee", "cafe"),
        ]}
        client = override({"groq": Counter(json.dumps(payload))})
        r = client.post("/day-plan", json={
            "profile": PROFILE, "date": "2026-07-22",
            "pack_ids": ["morning", "cafe"],
        })
        assert r.status_code == 200
        body = r.json()
        assert len(body["messages"]) == 2
        assert body["messages"][0]["pack_id"] == "morning"

    def test_failure_returns_502(self):
        def failing(s, u):
            raise RuntimeError("x")
        client = override({"groq": failing, "claude": failing})
        r = client.post("/day-plan", json={
            "profile": PROFILE, "date": "2026-07-22", "pack_ids": ["morning"],
        })
        assert r.status_code == 502


def override_chat(chat_completers):
    app.dependency_overrides[get_chat_completers] = lambda: chat_completers
    return TestClient(app)


class TestChatEndpoint:
    def test_success(self):
        client = override_chat({"claude": lambda s, m: "Salam! Necə kömək edim?"})
        r = client.post("/chat", json={
            "profile": PROFILE,
            "messages": [{"role": "user", "content": "salam"}],
        })
        assert r.status_code == 200
        assert r.json()["reply"] == "Salam! Necə kömək edim?"

    def test_history_passed_to_ai(self):
        captured = {}
        def cap(s, m):
            captured["m"] = m
            return "ok"
        client = override_chat({"claude": cap})
        client.post("/chat", json={
            "profile": PROFILE,
            "messages": [
                {"role": "user", "content": "salam"},
                {"role": "assistant", "content": "salam!"},
                {"role": "user", "content": "çayı necə deyim?"},
            ],
        })
        assert len(captured["m"]) == 3
        assert captured["m"][-1]["content"] == "çayı necə deyim?"

    def test_empty_messages_422(self):
        client = override_chat({"claude": lambda s, m: "x"})
        r = client.post("/chat", json={"profile": PROFILE, "messages": []})
        assert r.status_code == 422

    def test_ai_failure_502(self):
        def fail(s, m):
            raise RuntimeError("x")
        client = override_chat({"claude": fail, "groq": fail})
        r = client.post("/chat", json={
            "profile": PROFILE,
            "messages": [{"role": "user", "content": "salam"}],
        })
        assert r.status_code == 502


def override_routine(store):
    app.dependency_overrides[get_routine_store] = lambda: store
    return TestClient(app)


class TestRoutineSampleEndpoint:
    def test_sample_stored(self):
        store = RoutineStore(":memory:")
        client = override_routine(store)
        r = client.post("/routine/sample", json={
            "device_id": "dev1", "lat": 40.37, "lng": 49.83,
            "place_type": "cafe", "pack_id": "cafe",
        })
        assert r.status_code == 200
        assert r.json()["ok"] is True
        assert store.recent("dev1")[0]["place_type"] == "cafe"

    def test_invalid_lat_422(self):
        client = override_routine(RoutineStore(":memory:"))
        r = client.post("/routine/sample", json={
            "device_id": "dev1", "lat": 999, "lng": 0, "place_type": "cafe",
        })
        assert r.status_code == 422


class TestRoutineSummaryEndpoint:
    def test_summary_returns_aggregate(self):
        store = RoutineStore(":memory:")
        store.add("dev1", lat=1.0, lng=1.0, place_type="cafe", pack_id="cafe")
        store.add("dev1", lat=1.0, lng=1.0, place_type="cafe", pack_id="cafe")
        client = override_routine(store)
        r = client.get("/routine/summary/dev1")
        assert r.status_code == 200
        places = r.json()["places"]
        assert places[0]["place_type"] == "cafe"
        assert places[0]["count"] == 2

    def test_unknown_device_empty(self):
        client = override_routine(RoutineStore(":memory:"))
        r = client.get("/routine/summary/nobody")
        assert r.status_code == 200
        assert r.json()["places"] == []


def override_release(store):
    app.dependency_overrides[get_release_store] = lambda: store
    return TestClient(app)


class TestAppVersionEndpoint:
    def test_no_release_404(self, tmp_path):
        client = override_release(ReleaseStore(str(tmp_path)))
        assert client.get("/app/version").status_code == 404

    def test_returns_version_info(self, tmp_path):
        (tmp_path / "version.json").write_text(
            '{"version_code": 3, "version_name": "1.0.0+3", "notes": "test"}',
            encoding="utf-8",
        )
        client = override_release(ReleaseStore(str(tmp_path)))
        r = client.get("/app/version")
        assert r.status_code == 200
        assert r.json()["version_code"] == 3
        assert "no-store" in r.headers["cache-control"]


class TestAppLatestApkEndpoint:
    def test_no_apk_404(self, tmp_path):
        client = override_release(ReleaseStore(str(tmp_path)))
        assert client.get("/app/latest.apk").status_code == 404

    def test_serves_apk_bytes(self, tmp_path):
        (tmp_path / "latest.apk").write_bytes(b"fake-apk-bytes")
        client = override_release(ReleaseStore(str(tmp_path)))
        r = client.get("/app/latest.apk")
        assert r.status_code == 200
        assert r.content == b"fake-apk-bytes"
        assert r.headers["content-type"] == "application/vnd.android.package-archive"
        assert "no-store" in r.headers["cache-control"]


def test_health():
    client = override({})
    assert client.get("/health").status_code == 200
