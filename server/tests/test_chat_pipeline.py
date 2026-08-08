"""chat_pipeline.py — RunnablePassthrough zəncir testləri."""

import pytest

from dildostu_server.chat_pipeline import (
    ChatPipelineError,
    _merge_ai_messages,
    _step_build_messages,
    _step_load,
    _step_persist,
    _step_validate,
    run_chat_pipeline,
)
from dildostu_server.memory_store import MemoryStore
from dildostu_server.models import ChatMessage, ChatRequest, UserProfile


def _profile():
    return UserProfile(
        wake_hour=8, sleep_hour=23, purpose="travel", level="beginner",
        interests=[],
    )


def _req(content: str = "salam"):
    return ChatRequest(
        profile=_profile(),
        messages=[ChatMessage(role="user", content=content)],
    )


class TestPipelineSteps:
    def test_validate_requires_user_message(self):
        bad = ChatRequest(
            profile=_profile(),
            messages=[ChatMessage(role="assistant", content="x")],
        )
        with pytest.raises(ChatPipelineError, match="istifadəçidən"):
            _step_validate({"req": bad})

    def test_load_reads_from_memory(self):
        memory = MemoryStore(":memory:")
        memory.add_message(1, "user", "salam")
        state = {"memory": memory, "user_id": 1}
        out = _step_load(state)
        assert out["stored"][0]["content"] == "salam"

    def test_build_messages_merges_stored_and_new(self):
        state = {
            "stored": [{"role": "user", "content": "a"}],
            "user_content": "b",
        }
        out = _step_build_messages({**state, "req": _req("b")})
        assert out["ai_messages"] == [
            {"role": "user", "content": "a"},
            {"role": "user", "content": "b"},
        ]

    def test_merge_uses_client_when_db_empty(self):
        from dildostu_server.models import ChatMessage

        msgs = _merge_ai_messages(
            [],
            [
                ChatMessage(role="user", content="salam"),
                ChatMessage(role="assistant", content="salam!"),
                ChatMessage(role="user", content="çay?"),
            ],
            "çay?",
        )
        assert len(msgs) == 3

    def test_merge_prefers_db_when_client_sends_only_new(self):
        stored = [
            {"role": "user", "content": "Adım Elvindir"},
            {"role": "assistant", "content": "Salam Elvin!"},
        ]
        msgs = _merge_ai_messages(
            stored,
            [ChatMessage(role="user", content="Adımı xatırlayırsan?")],
            "Adımı xatırlayırsan?",
        )
        assert msgs == [
            {"role": "user", "content": "Adım Elvindir"},
            {"role": "assistant", "content": "Salam Elvin!"},
            {"role": "user", "content": "Adımı xatırlayırsan?"},
        ]

    def test_persist_skips_duplicate_user_message(self):
        memory = MemoryStore(":memory:")
        memory.add_message(1, "user", "salam")
        state = {
            "memory": memory,
            "user_id": 1,
            "user_content": "salam",
            "reply": "cavab",
            "stored": [{"role": "user", "content": "salam"}],
            "new_facts": [],
        }
        _step_persist(state)
        msgs = memory.recent_messages(1)
        assert [m["role"] for m in msgs] == ["user", "assistant"]
        assert msgs[0]["content"] == "salam"
        assert msgs[1]["content"] == "cavab"


class TestRunChatPipeline:
    def test_end_to_end_persists_reply(self):
        memory = MemoryStore(":memory:")
        reply = run_chat_pipeline(
            _req("necəsən?"),
            {"claude": lambda s, m: "Yaxşıyam!"},
            memory,
            user_id=1,
        )
        assert reply == "Yaxşıyam!"
        assert memory.recent_messages(1)[-1]["content"] == "Yaxşıyam!"
