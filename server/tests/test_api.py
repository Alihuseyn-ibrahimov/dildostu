import json

import pytest
from fastapi.testclient import TestClient

from dildostu_server.app import (
    app,
    get_chat_completers,
    get_completers,
    get_current_user,
    get_memory_store,
    get_place_lookup,
    get_release_store,
    get_routine_store,
)
from dildostu_server.memory_store import MemoryStore
from dildostu_server.place_lookup import (
    PlaceLookup,
    PlaceLookupError,
    PlaceQuotaExceeded,
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

# Faza 2: bir çox endpoint token tələb edir. Testlərdə auth-u sabit
# istifadəçi ilə əvəz edirik (auth məntiqi ayrıca test_auth_api.py-də yoxlanır).
_TEST_USER = {"id": 1, "email": "test@example.com", "created_at": "2026-08-03T00:00:00+00:00"}


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


def override_chat(chat_completers, *, memory=None, user=None):
    mem = memory or MemoryStore(":memory:")
    app.dependency_overrides[get_chat_completers] = lambda: chat_completers
    app.dependency_overrides[get_current_user] = lambda: user or _TEST_USER
    app.dependency_overrides[get_memory_store] = lambda: mem
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

    def test_requires_auth(self):
        app.dependency_overrides[get_chat_completers] = lambda: {
            "claude": lambda s, m: "x"
        }
        app.dependency_overrides[get_memory_store] = lambda: MemoryStore(":memory:")
        r = TestClient(app).post("/chat", json={
            "profile": PROFILE,
            "messages": [{"role": "user", "content": "salam"}],
        })
        assert r.status_code == 401

    def test_reply_and_facts_persisted_to_memory(self):
        memory = MemoryStore(":memory:")
        client = override_chat(
            {"claude": lambda s, m: "Salam Elvin![[YADDA: Adı Elvin]]"},
            memory=memory,
        )
        r = client.post("/chat", json={
            "profile": PROFILE,
            "messages": [{"role": "user", "content": "Adım Elvindir"}],
        })
        assert r.json()["reply"] == "Salam Elvin!"
        assert memory.recent_facts(1) == ["Adı Elvin"]
        assert [m["role"] for m in memory.recent_messages(1)] == ["user", "assistant"]


class TestChatHistoryEndpoint:
    def test_returns_own_history(self):
        memory = MemoryStore(":memory:")
        memory.add_message(1, "user", "salam")
        memory.add_message(1, "assistant", "salam!")
        client = override_chat({}, memory=memory)
        r = client.get("/chat/history")
        assert r.status_code == 200
        messages = r.json()["messages"]
        assert [m["content"] for m in messages] == ["salam", "salam!"]

    def test_does_not_leak_other_users_history(self):
        memory = MemoryStore(":memory:")
        memory.add_message(2, "user", "başqasının mesajı")
        client = override_chat({}, memory=memory)  # user id=1
        r = client.get("/chat/history")
        assert r.json()["messages"] == []

    def test_new_user_empty(self):
        client = override_chat({}, memory=MemoryStore(":memory:"))
        r = client.get("/chat/history")
        assert r.json()["messages"] == []

    def test_requires_auth(self):
        app.dependency_overrides[get_memory_store] = lambda: MemoryStore(":memory:")
        r = TestClient(app).get("/chat/history")
        assert r.status_code == 401


class TestChatQuota:
    """2026-08-06 — gündəlik limit AI çağırışından əvvəl yoxlanır."""

    def test_over_limit_returns_429_without_calling_ai(self, monkeypatch):
        monkeypatch.setenv("CHAT_DAILY_LIMIT", "1")
        memory = MemoryStore(":memory:")
        memory.add_message(1, "user", "əvvəlki")
        calls = []
        client = override_chat(
            {"claude": lambda s, m: calls.append(1) or "cavab"}, memory=memory
        )
        r = client.post("/chat", json={
            "profile": PROFILE,
            "messages": [{"role": "user", "content": "salam"}],
        })
        assert r.status_code == 429
        assert calls == []

    def test_under_limit_passes(self, monkeypatch):
        monkeypatch.setenv("CHAT_DAILY_LIMIT", "5")
        client = override_chat(
            {"claude": lambda s, m: "cavab"}, memory=MemoryStore(":memory:")
        )
        r = client.post("/chat", json={
            "profile": PROFILE,
            "messages": [{"role": "user", "content": "salam"}],
        })
        assert r.status_code == 200

    def test_quota_endpoint_reports_remaining(self, monkeypatch):
        monkeypatch.setenv("CHAT_DAILY_LIMIT", "10")
        memory = MemoryStore(":memory:")
        memory.add_message(1, "user", "bir")
        client = override_chat({}, memory=memory)
        body = client.get("/chat/quota").json()
        assert body == {"used": 1, "limit": 10, "remaining": 9}


class TestChatDataManagement:
    """2026-08-06 — istifadəçi öz datasını idarə edir (şəffaflıq)."""

    def test_delete_history_keeps_portrait(self):
        memory = MemoryStore(":memory:")
        memory.add_message(1, "user", "salam")
        memory.add_fact(1, "Ad: Elvin")
        client = override_chat({}, memory=memory)

        assert client.delete("/chat/history").status_code == 200
        assert memory.recent_messages(1) == []
        assert memory.recent_facts(1) == ["Ad: Elvin"]

    def test_portrait_returns_facts(self):
        memory = MemoryStore(":memory:")
        memory.add_fact(1, "Hobbi: foto")
        client = override_chat({}, memory=memory)
        assert client.get("/chat/portrait").json()["facts"] == ["Hobbi: foto"]

    def test_delete_portrait_keeps_history(self):
        memory = MemoryStore(":memory:")
        memory.add_message(1, "user", "salam")
        memory.add_fact(1, "Hobbi: foto")
        client = override_chat({}, memory=memory)

        assert client.delete("/chat/portrait").status_code == 200
        assert memory.recent_facts(1) == []
        assert len(memory.recent_messages(1)) == 1

    def test_portrait_scoped_per_user(self):
        memory = MemoryStore(":memory:")
        memory.add_fact(2, "başqasının faktı")
        client = override_chat({}, memory=memory)  # user id=1
        assert client.get("/chat/portrait").json()["facts"] == []

    def test_endpoints_require_auth(self):
        app.dependency_overrides[get_memory_store] = lambda: MemoryStore(":memory:")
        anon = TestClient(app)
        assert anon.get("/chat/portrait").status_code == 401
        assert anon.delete("/chat/portrait").status_code == 401
        assert anon.delete("/chat/history").status_code == 401
        assert anon.get("/chat/quota").status_code == 401
        assert anon.get("/chat/nudges").status_code == 401


def override_routine(store, user=None):
    app.dependency_overrides[get_routine_store] = lambda: store
    app.dependency_overrides[get_current_user] = lambda: user or _TEST_USER
    return TestClient(app)


def _sample(store, user_id, **kw):
    kw.setdefault("device_id", "dev1")
    kw.setdefault("lat", 1.0)
    kw.setdefault("lng", 1.0)
    kw.setdefault("place_type", "cafe")
    store.add(user_id, **kw)


class TestRoutineSampleEndpoint:
    def test_sample_stored_against_current_user(self):
        store = RoutineStore(":memory:")
        client = override_routine(store)
        r = client.post("/routine/sample", json={
            "device_id": "dev1", "lat": 40.37, "lng": 49.83,
            "place_type": "cafe", "pack_id": "cafe",
        })
        assert r.status_code == 200
        assert r.json()["ok"] is True
        assert store.recent(1)[0]["place_type"] == "cafe"

    def test_invalid_lat_422(self):
        client = override_routine(RoutineStore(":memory:"))
        r = client.post("/routine/sample", json={
            "device_id": "dev1", "lat": 999, "lng": 0, "place_type": "cafe",
        })
        assert r.status_code == 422

    def test_requires_auth(self):
        app.dependency_overrides[get_routine_store] = lambda: RoutineStore(":memory:")
        r = TestClient(app).post("/routine/sample", json={
            "device_id": "dev1", "lat": 40.0, "lng": 49.0, "place_type": "cafe",
        })
        assert r.status_code == 401


class TestRoutineSummaryEndpoint:
    def test_summary_returns_aggregate(self):
        store = RoutineStore(":memory:")
        _sample(store, 1, pack_id="cafe")
        _sample(store, 1, pack_id="cafe")
        client = override_routine(store)
        r = client.get("/routine/summary")
        assert r.status_code == 200
        places = r.json()["places"]
        assert places[0]["place_type"] == "cafe"
        assert places[0]["count"] == 2

    def test_new_user_empty(self):
        client = override_routine(RoutineStore(":memory:"))
        r = client.get("/routine/summary")
        assert r.status_code == 200
        assert r.json()["places"] == []

    def test_does_not_leak_other_users_data(self):
        store = RoutineStore(":memory:")
        _sample(store, 2, place_type="market")  # başqa istifadəçi
        client = override_routine(store)  # user id=1
        assert client.get("/routine/summary").json()["places"] == []

    def test_requires_auth(self):
        app.dependency_overrides[get_routine_store] = lambda: RoutineStore(":memory:")
        assert TestClient(app).get("/routine/summary").status_code == 401


class TestRoutineClaimEndpoint:
    def test_claims_anonymous_samples(self):
        store = RoutineStore(":memory:")
        store.add(None, device_id="devX", lat=1.0, lng=1.0, place_type="cafe")
        client = override_routine(store)
        r = client.post("/routine/claim", json={"device_id": "devX"})
        assert r.status_code == 200
        assert r.json()["claimed"] == 1
        assert len(store.recent(1)) == 1

    def test_cannot_claim_other_users_samples(self):
        store = RoutineStore(":memory:")
        _sample(store, 2, device_id="devX")
        client = override_routine(store)
        assert client.post("/routine/claim", json={"device_id": "devX"}).json()["claimed"] == 0

    def test_requires_auth(self):
        app.dependency_overrides[get_routine_store] = lambda: RoutineStore(":memory:")
        r = TestClient(app).post("/routine/claim", json={"device_id": "d"})
        assert r.status_code == 401


class _StubLookup:
    """PlaceLookup əvəzinə — resolve() sabit nəticə və ya istisna verir."""

    def __init__(self, result=None, error=None):
        self._result = result
        self._error = error
        # `/health` bu iki sahəni oxuyur (provayder vəziyyəti).
        self.configured = True
        self.quota_exhausted = False

    def resolve(self, lat, lng, radius=200):
        if self._error is not None:
            raise self._error
        return self._result


def override_place(lookup):
    app.dependency_overrides[get_place_lookup] = lambda: lookup
    app.dependency_overrides[get_current_user] = lambda: _TEST_USER
    return TestClient(app)


class TestPlaceResolveEndpoint:
    def test_resolves_to_pack(self):
        client = override_place(_StubLookup(
            {"name": "28 Mall", "category": "Shopping Mall", "pack_id": "market"}))
        r = client.post("/place/resolve", json={"lat": 40.37, "lng": 49.83})
        assert r.status_code == 200
        assert r.json()["pack_id"] == "market"
        assert r.json()["name"] == "28 Mall"

    def test_no_place_nearby_404(self):
        client = override_place(_StubLookup(None))
        r = client.post("/place/resolve", json={"lat": 40.0, "lng": 49.0})
        assert r.status_code == 404

    def test_unmapped_category_returns_place_without_pack(self):
        """2026-08-07 — əvvəllər 404 idi, yer məlumatı tamamilə itirdi.

        İndi 200 qaytarılır: `pack_id=None`, amma ad/kateqoriya gəlir ki, UI
        "Bura tanınmadı — City Hall" göstərə bilsin. Köhnə app-lar boş
        `pack_id`-ni artıq "tapılmadı" kimi oxuduğu üçün geriyə uyğundur.
        """
        client = override_place(_StubLookup(
            {"name": "City Hall", "category": "Government", "pack_id": None}))
        r = client.post("/place/resolve", json={"lat": 40.0, "lng": 49.0})
        assert r.status_code == 200
        assert r.json()["pack_id"] is None
        assert r.json()["name"] == "City Hall"

    def test_distance_passed_through(self):
        client = override_place(_StubLookup({
            "name": "Kofe Evi", "category": "Café", "pack_id": "cafe",
            "distance_m": 27,
        }))
        r = client.post("/place/resolve", json={"lat": 40.0, "lng": 49.0})
        assert r.json()["distance_m"] == 27

    def test_missing_key_503(self):
        client = override_place(_StubLookup(error=PlaceLookupError("açar yoxdur")))
        r = client.post("/place/resolve", json={"lat": 40.0, "lng": 49.0})
        assert r.status_code == 503

    def test_invalid_coords_422(self):
        client = override_place(_StubLookup(None))
        r = client.post("/place/resolve", json={"lat": 999, "lng": 0})
        assert r.status_code == 422

    def test_requires_auth(self):
        app.dependency_overrides[get_place_lookup] = lambda: _StubLookup(None)
        r = TestClient(app).post("/place/resolve", json={"lat": 40.0, "lng": 49.0})
        assert r.status_code == 401


class TestRoutineGeofencesEndpoint:
    def test_returns_frequent_places(self):
        store = RoutineStore(":memory:")
        for _ in range(4):
            _sample(store, 1, lat=40.370, lng=49.830, pack_id="cafe")
        client = override_routine(store)
        r = client.get("/routine/geofences")
        assert r.status_code == 200
        zones = r.json()["geofences"]
        assert len(zones) == 1
        assert zones[0]["pack_id"] == "cafe"
        assert zones[0]["count"] == 4

    def test_below_threshold_empty(self):
        store = RoutineStore(":memory:")
        _sample(store, 1, lat=40.370, lng=49.830, pack_id="cafe")
        client = override_routine(store)
        r = client.get("/routine/geofences")
        assert r.status_code == 200
        assert r.json()["geofences"] == []

    def test_new_user_empty(self):
        client = override_routine(RoutineStore(":memory:"))
        r = client.get("/routine/geofences")
        assert r.status_code == 200
        assert r.json()["geofences"] == []

    def test_requires_auth(self):
        app.dependency_overrides[get_routine_store] = lambda: RoutineStore(":memory:")
        assert TestClient(app).get("/routine/geofences").status_code == 401


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


class TestHealthPlaceProvider:
    """2026-08-07 — Foursquare krediti bitmiş vəziyyəti görünən etmək.

    Əvvəllər bu hal yalnız istifadəçinin "yer tapılmır" şikayətindən bilinirdi.
    """

    def test_reports_ok_when_provider_healthy(self):
        client = override_place(_StubLookup(
            {"name": "Kafe", "category": "Café", "pack_id": "cafe"}))
        assert client.get("/health").json()["place_provider"] == "ok"

    def test_reports_quota_exhausted(self):
        lookup = _StubLookup(None)
        lookup.quota_exhausted = True
        client = override_place(lookup)
        assert client.get("/health").json()["place_provider"] == "quota_exhausted"

    def test_reports_unconfigured_when_no_key(self):
        lookup = _StubLookup(None)
        lookup.configured = False
        client = override_place(lookup)
        assert client.get("/health").json()["place_provider"] == "unconfigured"

    def test_place_resolve_quota_error_sends_retry_after(self):
        client = override_place(
            _StubLookup(error=PlaceQuotaExceeded("kredit bitib")))
        r = client.post("/place/resolve", json={"lat": 40.0, "lng": 49.0})
        assert r.status_code == 503
        assert r.headers["Retry-After"] == "900"
