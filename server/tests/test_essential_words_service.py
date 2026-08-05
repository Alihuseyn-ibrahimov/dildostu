"""Əsas lüğət (504 söz bankı) — /essential-words servis+endpoint."""

import json

import pytest
from fastapi.testclient import TestClient

from dildostu_server.app import app, get_completers
from dildostu_server.essential_words import words_for_level
from dildostu_server.models import UserProfile
from dildostu_server.service import LiveService, ServiceError


def _profile(level="beginner", target_lang="en"):
    return UserProfile(
        wake_hour=8, sleep_hour=23, purpose="travel", level=level, interests=[],
        target_lang=target_lang,
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


class TestLanguageEssentialWordsService:
    def test_returns_count_messages(self):
        service = LiveService(
            {"groq": lambda s, u: _response(["привет", "спасибо", "да"])},
            cache={},
        )
        messages = service.language_essential_words(
            _profile(target_lang="ru"), 3, []
        )
        assert len(messages) == 3
        assert all(m.pack_id == "essential" for m in messages)

    def test_not_cached_each_call_hits_ai(self):
        calls = []

        def completer(system, user):
            calls.append(1)
            return _response(["привет"])

        service = LiveService({"groq": completer}, cache={})
        service.language_essential_words(_profile(target_lang="ru"), 1, [])
        service.language_essential_words(_profile(target_lang="ru"), 1, [])
        assert len(calls) == 2

    def test_ai_failure_raises_service_error(self):
        def failing(s, u):
            raise RuntimeError("limit")

        service = LiveService({"groq": failing, "claude": failing}, cache={})
        with pytest.raises(ServiceError):
            service.language_essential_words(_profile(target_lang="ru"), 3, [])


class TestLanguageEssentialWordsEndpoint:
    def _client(self, completers):
        app.dependency_overrides[get_completers] = lambda: completers
        return TestClient(app)

    def teardown_method(self):
        app.dependency_overrides.clear()
        app.state.cache.clear()

    def test_non_english_returns_unbounded_total(self):
        client = self._client(
            {"groq": lambda s, u: _response(["привет", "спасибо", "да"])}
        )
        r = client.post("/essential-words", json={
            "profile": _profile(target_lang="ru").model_dump(),
            "offset": 0,
            "count": 3,
        })
        assert r.status_code == 200
        body = r.json()
        assert len(body["words"]) == 3
        assert body["total"] == -1
        assert body["next_offset"] == 3

    def test_next_offset_increments_without_wraparound(self):
        client = self._client({"groq": lambda s, u: _response(["привет"])})
        r = client.post("/essential-words", json={
            "profile": _profile(target_lang="ru").model_dump(),
            "offset": 500,
            "count": 12,
        })
        assert r.status_code == 200
        assert r.json()["next_offset"] == 512

    def test_exclude_words_forwarded(self):
        captured = {}

        def completer(system, user):
            captured["user"] = user
            return _response(["привет", "да", "нет"])

        client = self._client({"groq": completer})
        client.post("/essential-words", json={
            "profile": _profile(target_lang="ru").model_dump(),
            "offset": 0,
            "count": 3,
            "exclude_words": ["спасибо"],
        })
        assert "спасибо" in captured["user"]

    def test_ai_failure_502(self):
        def failing(s, u):
            raise RuntimeError("x")

        client = self._client({"groq": failing, "claude": failing})
        r = client.post("/essential-words", json={
            "profile": _profile(target_lang="ru").model_dump(),
            "offset": 0,
            "count": 12,
        })
        assert r.status_code == 502
