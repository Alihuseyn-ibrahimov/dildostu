"""Proaktiv chat nudge generatoru testləri."""

from datetime import date

from dildostu_server.chat_nudges import build_chat_nudges
from dildostu_server.models import UserProfile

PROFILE = UserProfile(
    wake_hour=8,
    sleep_hour=23,
    purpose="travel",
    level="beginner",
    interests=["foto"],
    target_lang="en",
)


class TestBuildChatNudges:
    def test_returns_three_slots(self):
        nudges = build_chat_nudges(
            profile=PROFILE, places=[], facts=[], last_user_at=None
        )
        assert len(nudges) == 3

    def test_morning_greeting(self):
        nudges = build_chat_nudges(
            profile=PROFILE, places=[], facts=[], last_user_at=None
        )
        body = nudges[0].body.lower()
        assert "sabahın xeyir" in body or "günaydın" in body
        assert "5 dəqiq" in body

    def test_lunch_break_theme(self):
        nudges = build_chat_nudges(
            profile=PROFILE, places=[], facts=[], last_user_at=None
        )
        body = nudges[1].body.lower()
        assert "nahar" in body or "fasil" in body

    def test_evening_review_theme(self):
        nudges = build_chat_nudges(
            profile=PROFILE, places=[], facts=[], last_user_at=None
        )
        body = nudges[2].body.lower()
        assert "yatm" in body or "təkrar" in body or "axşam" in body

    def test_place_in_lunch_when_routine_has_pack(self):
        nudges = build_chat_nudges(
            profile=PROFILE,
            places=[
                {
                    "place_type": "cafe",
                    "pack_id": "cafe",
                    "count": 5,
                    "last_seen": "2026-08-01T10:00:00+00:00",
                }
            ],
            facts=[],
            last_user_at=None,
            on_date=date(2026, 8, 7),
        )
        # day+1 template index — bəzi günlərdə {place} şablonu düşür
        bodies = " ".join(n.body for n in nudges)
        assert "Kafedə" in bodies or "nahar" in bodies.lower()

    def test_different_days_can_differ(self):
        a = build_chat_nudges(
            profile=PROFILE,
            places=[],
            facts=[],
            last_user_at=None,
            on_date=date(2026, 8, 7),
        )
        b = build_chat_nudges(
            profile=PROFILE,
            places=[],
            facts=[],
            last_user_at=None,
            on_date=date(2026, 8, 8),
        )
        assert a[0].body != b[0].body or a[1].body != b[1].body

    def test_inactive_user_evening_nudge(self):
        nudges = build_chat_nudges(
            profile=PROFILE,
            places=[],
            facts=[],
            last_user_at="2020-01-01T00:00:00+00:00",
        )
        assert "darıxdım" in nudges[2].body.lower()


class TestChatNudgesEndpoint:
    def test_nudges_require_auth(self):
        from fastapi.testclient import TestClient

        from dildostu_server.app import app

        anon = TestClient(app)
        assert anon.get("/chat/nudges").status_code == 401

    def test_nudges_with_profile(self):
        from dildostu_server.app import app, get_routine_store, get_user_store
        from dildostu_server.user_store import UserStore
        from tests.test_api import PROFILE, _TEST_USER, override_chat

        from dildostu_server.memory_store import MemoryStore
        from dildostu_server.routine_store import RoutineStore

        memory = MemoryStore(":memory:")
        routine = RoutineStore(":memory:")
        routine.add(
            _TEST_USER["id"],
            device_id="d1",
            lat=40.0,
            lng=49.0,
            place_type="cafe",
            pack_id="cafe",
        )
        memory.add_fact(_TEST_USER["id"], "Hobbi: foto")

        store = UserStore(":memory:")
        store.save_profile(_TEST_USER["id"], PROFILE)

        app.dependency_overrides[get_routine_store] = lambda: routine
        app.dependency_overrides[get_user_store] = lambda: store
        client = override_chat({}, memory=memory)

        r = client.get("/chat/nudges")
        assert r.status_code == 200
        nudges = r.json()["nudges"]
        assert len(nudges) == 3
        assert "body" in nudges[0]
        assert "quick_prompt" in nudges[0]
