"""Əsas lüğət (504 söz bankı) — /essential-words servis+endpoint."""

import json

import pytest
from fastapi.testclient import TestClient

from dildostu_server.app import app, get_completers
from dildostu_server.essential_words import words_for_level
from dildostu_server.models import UserProfile
from dildostu_server.service import LiveService, ServiceError


def _profile(level="beginner"):
    return UserProfile(
        wake_hour=8, sleep_hour=23, purpose="travel", level=level, interests=[]
    )


def _word(word):
    return {
        "word": word,
        "translation_az": "sözün mənası",
        "ipa": "/wɜːd/",
        "example": f"This is {word}.",
        "example_az": "Bu nümunədir.",
        "ai_line": "Bu sözü öyrən!",
        "level": 1,
    }


def _response(words):
    return json.dumps({"messages": [_word(w) for w in words]})


class TestEssentialWordsService:
    def test_returns_message_per_word(self):
        words = ["abandon", "keen", "tact"]
        service = LiveService({"groq": lambda s, u: _response(words)}, cache={})
        messages = service.essential_words(_profile(), words)
        assert len(messages) == 3
        assert [m.word for m in messages] == words
        assert all(m.pack_id == "essential" for m in messages)

    def test_cached_by_words_and_level(self):
        calls = []

        def completer(system, user):
            calls.append(1)
            return _response(["abandon"])

        cache = {}
        service = LiveService({"groq": completer}, cache=cache)
        service.essential_words(_profile(), ["abandon"])
        service.essential_words(_profile(), ["abandon"])
        assert len(calls) == 1

    def test_different_level_not_shared(self):
        calls = []

        def completer(system, user):
            calls.append(1)
            return _response(["abandon"])

        service = LiveService({"groq": completer}, cache={})
        service.essential_words(_profile("beginner"), ["abandon"])
        service.essential_words(_profile("advanced"), ["abandon"])
        assert len(calls) == 2

    def test_ai_failure_raises_service_error(self):
        def failing(s, u):
            raise RuntimeError("limit")

        service = LiveService({"groq": failing, "claude": failing}, cache={})
        with pytest.raises(ServiceError):
            service.essential_words(_profile(), ["abandon"])


class TestEssentialWordsEndpoint:
    def _client(self, completers):
        app.dependency_overrides[get_completers] = lambda: completers
        return TestClient(app)

    def teardown_method(self):
        app.dependency_overrides.clear()
        app.state.cache.clear()

    def test_success_returns_first_batch(self):
        pool = words_for_level("beginner")
        client = self._client({"groq": lambda s, u: _response(pool[:12])})
        r = client.post("/essential-words", json={
            "profile": _profile().model_dump(),
            "offset": 0,
            "count": 12,
        })
        assert r.status_code == 200
        body = r.json()
        assert len(body["words"]) == 12
        assert body["total"] == 168
        assert body["next_offset"] == 12
        assert all(w["pack_id"] == "essential" for w in body["words"])

    def test_offset_wraps_around(self):
        pool = words_for_level("beginner")
        client = self._client({"groq": lambda s, u: _response(pool[:12])})
        r = client.post("/essential-words", json={
            "profile": _profile().model_dump(),
            "offset": 160,
            "count": 12,
        })
        assert r.status_code == 200
        assert r.json()["next_offset"] == 4  # 160+12=172, 172-168=4

    def test_ai_failure_502(self):
        def failing(s, u):
            raise RuntimeError("x")

        client = self._client({"groq": failing, "claude": failing})
        r = client.post("/essential-words", json={
            "profile": _profile().model_dump(),
            "offset": 0,
            "count": 12,
        })
        assert r.status_code == 502

    def test_count_out_of_range_422(self):
        client = self._client({"groq": lambda s, u: _response(["abandon"])})
        r = client.post("/essential-words", json={
            "profile": _profile().model_dump(),
            "offset": 0,
            "count": 99,
        })
        assert r.status_code == 422
