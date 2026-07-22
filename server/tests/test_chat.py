import pytest

from dildostu_server.models import ChatMessage, Context, UserProfile
from dildostu_server.prompts import build_chat_system, chat_preferred_providers
from dildostu_server.providers import (
    AllProvidersFailed,
    build_chat_completers,
    chat_with_fallback,
)


class TestBuildChatCompleters:
    def test_callable_without_keys(self, monkeypatch):
        # Açar yoxdursa boş dict qaytarmalı — NameError/istisna ATMAMALI.
        # .env-in açarları geri yükləməməsi üçün load_dotenv neytrallaşdırılır.
        monkeypatch.setattr("dildostu_server.providers.load_dotenv", lambda *a, **k: None)
        monkeypatch.delenv("GROQ_API_KEY", raising=False)
        monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
        assert build_chat_completers() == {}

    def test_builds_groq_when_key_present(self, monkeypatch):
        monkeypatch.setattr("dildostu_server.providers.load_dotenv", lambda *a, **k: None)
        monkeypatch.setenv("GROQ_API_KEY", "test-key")
        monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
        assert "groq" in build_chat_completers()


def profile():
    return UserProfile(
        wake_hour=8, sleep_hour=23, purpose="travel", level="beginner",
        interests=["yemək"],
    )


class TestChatSystem:
    def test_mentions_level_and_persona(self):
        s = build_chat_system(profile(), None)
        assert "beginner" in s.lower() or "başlanğıc" in s.lower()
        # Azərbaycanca müəllim personası
        assert "azərbaycan" in s.lower() or "azerbaijani" in s.lower()

    def test_includes_context_when_given(self):
        s = build_chat_system(profile(), Context(pack_id="cafe", hour=9))
        assert "cafe" in s.lower()


class TestChatRouting:
    def test_chat_prefers_claude(self):
        assert chat_preferred_providers()[0] == "claude"
        assert "groq" in chat_preferred_providers()


class TestChatFallback:
    def _msgs(self):
        return [{"role": "user", "content": "salam"}]

    def test_uses_first_ok(self):
        calls = []
        completers = {
            "claude": lambda s, m: calls.append("claude") or "salam cavab",
            "groq": lambda s, m: calls.append("groq") or "groq cavab",
        }
        out = chat_with_fallback("sys", self._msgs(), ["claude", "groq"], completers)
        assert out == "salam cavab"
        assert calls == ["claude"]

    def test_falls_back(self):
        def fail(s, m):
            raise RuntimeError("x")
        completers = {"claude": fail, "groq": lambda s, m: "groq cavab"}
        out = chat_with_fallback("sys", self._msgs(), ["claude", "groq"], completers)
        assert out == "groq cavab"

    def test_all_fail_raises(self):
        def fail(s, m):
            raise RuntimeError("x")
        with pytest.raises(AllProvidersFailed):
            chat_with_fallback("sys", self._msgs(), ["claude", "groq"],
                               {"claude": fail, "groq": fail})

    def test_messages_passed_through(self):
        captured = {}
        def cap(s, m):
            captured["msgs"] = m
            return "ok"
        chat_with_fallback("sys", self._msgs(), ["groq"], {"groq": cap})
        assert captured["msgs"] == self._msgs()
