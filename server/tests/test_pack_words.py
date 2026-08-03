"""Paket söz siyahısı — /pack-words (söz siyahısı ekranı üçün)."""

import json

import pytest
from fastapi.testclient import TestClient

from dildostu_server.app import app, get_completers
from dildostu_server.models import UserProfile
from dildostu_server.prompts import build_pack_words_prompt
from dildostu_server.service import LiveService, ServiceError


def _profile(level="beginner"):
    return UserProfile(
        wake_hour=8, sleep_hour=23, purpose="travel", level=level, interests=[]
    )


def _word(word="coffee"):
    return {
        "word": word,
        "translation_az": "qəhvə",
        "ipa": "/ˈkɒfi/",
        "example": "I would like a coffee.",
        "example_az": "Mən qəhvə istəyirəm.",
        "ai_line": "Kafedəsən!",
        "level": 1,
    }


def _response(count):
    return json.dumps({"messages": [_word(f"w{i}") for i in range(count)]})


class TestPackWordsPrompt:
    def test_includes_pack_and_count(self):
        _, user = build_pack_words_prompt(_profile(), "airport", 8)
        assert "airport" in user
        assert "8" in user

    def test_carries_level_rules(self):
        _, user = build_pack_words_prompt(_profile("advanced"), "airport", 8)
        assert "idiom" in user.lower()

    def test_asks_for_messages_array(self):
        _, user = build_pack_words_prompt(_profile(), "cafe", 5)
        assert "messages" in user

    def test_forbids_repeats(self):
        _, user = build_pack_words_prompt(_profile(), "cafe", 5)
        assert "təkrar" in user.lower()


class TestPackWordsService:
    def test_returns_requested_count(self):
        service = LiveService({"groq": lambda s, u: _response(6)}, cache={})
        words = service.pack_words(_profile(), "cafe", 6)
        assert len(words) == 6
        assert all(w.pack_id == "cafe" for w in words)

    def test_cached_by_pack_and_level(self):
        calls = []

        def completer(system, user):
            calls.append(1)
            return _response(3)

        cache = {}
        service = LiveService({"groq": completer}, cache=cache)
        service.pack_words(_profile(), "cafe", 3)
        service.pack_words(_profile(), "cafe", 3)
        assert len(calls) == 1  # ikinci keşdən gəldi

    def test_different_level_not_shared(self):
        calls = []

        def completer(system, user):
            calls.append(1)
            return _response(3)

        service = LiveService({"groq": completer}, cache={})
        service.pack_words(_profile("beginner"), "cafe", 3)
        service.pack_words(_profile("advanced"), "cafe", 3)
        assert len(calls) == 2

    def test_ai_failure_raises_service_error(self):
        def failing(s, u):
            raise RuntimeError("limit")

        service = LiveService({"groq": failing, "claude": failing}, cache={})
        with pytest.raises(ServiceError):
            service.pack_words(_profile(), "cafe", 3)


class TestPackWordsEndpoint:
    def _client(self, completers):
        app.dependency_overrides[get_completers] = lambda: completers
        return TestClient(app)

    def teardown_method(self):
        app.dependency_overrides.clear()
        app.state.cache.clear()

    def test_success(self):
        client = self._client({"groq": lambda s, u: _response(4)})
        r = client.post("/pack-words", json={
            "profile": _profile().model_dump(),
            "pack_id": "airport",
            "count": 4,
        })
        assert r.status_code == 200
        words = r.json()["words"]
        assert len(words) == 4
        assert words[0]["pack_id"] == "airport"

    def test_ai_failure_502(self):
        def failing(s, u):
            raise RuntimeError("x")

        client = self._client({"groq": failing, "claude": failing})
        r = client.post("/pack-words", json={
            "profile": _profile().model_dump(),
            "pack_id": "airport",
            "count": 4,
        })
        assert r.status_code == 502

    def test_count_out_of_range_422(self):
        client = self._client({"groq": lambda s, u: _response(4)})
        r = client.post("/pack-words", json={
            "profile": _profile().model_dump(),
            "pack_id": "airport",
            "count": 99,
        })
        assert r.status_code == 422
