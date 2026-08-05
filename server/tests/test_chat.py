import pytest

from dildostu_server.memory_store import MemoryStore
from dildostu_server.models import ChatMessage, ChatRequest, Context, UserProfile
from dildostu_server.prompts import build_chat_system, chat_preferred_providers
from dildostu_server.providers import (
    AllProvidersFailed,
    build_chat_completers,
    chat_with_fallback,
)
from dildostu_server.service import ServiceError, run_chat


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


class TestRunChat:
    """2026-08-04 — yaddaş inteqrasiyası: marker parse/strip/saxlama."""

    def _req(self):
        return ChatRequest(
            profile=profile(),
            messages=[ChatMessage(role="user", content="salam")],
        )

    def test_marker_stripped_and_fact_saved(self):
        memory = MemoryStore(":memory:")
        completers = {
            "claude": lambda s, m: "Salam Elvin![[YADDA: Adı Elvin]]",
        }
        reply = run_chat(self._req(), completers, memory, user_id=1)
        assert reply == "Salam Elvin!"
        assert memory.recent_facts(1) == ["Adı Elvin"]

    def test_multiple_facts_split_on_pipe(self):
        memory = MemoryStore(":memory:")
        completers = {
            "claude": lambda s, m: "ok[[YADDA: Adı Vüqar | İdmanla maraqlanır]]",
        }
        run_chat(self._req(), completers, memory, user_id=1)
        assert memory.recent_facts(1) == ["Adı Vüqar", "İdmanla maraqlanır"]

    def test_no_marker_reply_unchanged_no_fact_saved(self):
        memory = MemoryStore(":memory:")
        completers = {"claude": lambda s, m: "Sadəcə cavab, marker yoxdur."}
        reply = run_chat(self._req(), completers, memory, user_id=1)
        assert reply == "Sadəcə cavab, marker yoxdur."
        assert memory.recent_facts(1) == []

    def test_reply_and_user_message_saved_to_history(self):
        memory = MemoryStore(":memory:")
        completers = {"claude": lambda s, m: "cavab"}
        run_chat(self._req(), completers, memory, user_id=1)
        messages = memory.recent_messages(1)
        assert [m["role"] for m in messages] == ["user", "assistant"]
        assert messages[0]["content"] == "salam"
        assert messages[1]["content"] == "cavab"

    def test_known_facts_passed_into_system_prompt(self):
        memory = MemoryStore(":memory:")
        memory.add_fact(1, "Adı Elvin")
        captured = {}

        def cap(system, messages):
            captured["system"] = system
            return "ok"

        run_chat(self._req(), {"claude": cap}, memory, user_id=1)
        assert "Adı Elvin" in captured["system"]

    def test_all_providers_fail_raises_service_error_no_history_saved(self):
        memory = MemoryStore(":memory:")

        def fail(s, m):
            raise RuntimeError("x")

        with pytest.raises(ServiceError):
            run_chat(self._req(), {"claude": fail}, memory, user_id=1)
        assert memory.recent_messages(1) == []
