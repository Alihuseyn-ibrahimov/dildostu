"""Söz axtarışı — /word-lookup (səsli kitabda toxunulan sözün mənası)."""

import json

import pytest
from fastapi.testclient import TestClient

from dildostu_server.app import app, get_completers
from dildostu_server.service import LiveService, ServiceError


def _response(word="bank", translation="sahil", ipa="/bæŋk/"):
    return json.dumps({"translation_az": translation, "ipa": ipa})


class TestWordLookupService:
    def test_returns_lookup_result(self):
        service = LiveService({"groq": lambda s, u: _response()}, cache={})
        result = service.word_lookup("bank", "He sat by the river bank.")
        assert result.word == "bank"
        assert result.translation_az == "sahil"
        assert result.ipa == "/bæŋk/"

    def test_cached_by_word_case_insensitive(self):
        calls = []

        def completer(system, user):
            calls.append(1)
            return _response()

        cache = {}
        service = LiveService({"groq": completer}, cache=cache)
        service.word_lookup("Bank", "ctx1")
        service.word_lookup("bank", "ctx2")
        assert len(calls) == 1  # ikinci sorğu keşdən gəldi

    def test_different_words_not_shared(self):
        calls = []

        def completer(system, user):
            calls.append(1)
            return _response()

        service = LiveService({"groq": completer}, cache={})
        service.word_lookup("bank", "ctx")
        service.word_lookup("river", "ctx")
        assert len(calls) == 2

    def test_ai_failure_raises_service_error(self):
        def failing(s, u):
            raise RuntimeError("limit")

        service = LiveService({"groq": failing, "claude": failing}, cache={})
        with pytest.raises(ServiceError):
            service.word_lookup("bank", "ctx")

    def test_malformed_response_raises_service_error(self):
        service = LiveService({"groq": lambda s, u: "not json"}, cache={})
        with pytest.raises(ServiceError):
            service.word_lookup("bank", "ctx")


class TestWordLookupEndpoint:
    def _client(self, completers):
        app.dependency_overrides[get_completers] = lambda: completers
        return TestClient(app)

    def teardown_method(self):
        app.dependency_overrides.clear()
        app.state.cache.clear()

    def test_success(self):
        client = self._client({"groq": lambda s, u: _response()})
        r = client.post("/word-lookup", json={"word": "bank", "context": "river bank"})
        assert r.status_code == 200
        body = r.json()
        assert body["word"] == "bank"
        assert body["translation_az"] == "sahil"
        assert body["ipa"] == "/bæŋk/"

    def test_context_optional(self):
        client = self._client({"groq": lambda s, u: _response()})
        r = client.post("/word-lookup", json={"word": "bank"})
        assert r.status_code == 200

    def test_empty_word_422(self):
        client = self._client({"groq": lambda s, u: _response()})
        r = client.post("/word-lookup", json={"word": ""})
        assert r.status_code == 422

    def test_ai_failure_502(self):
        def failing(s, u):
            raise RuntimeError("x")

        client = self._client({"groq": failing, "claude": failing})
        r = client.post("/word-lookup", json={"word": "bank"})
        assert r.status_code == 502
