"""Çat cavabı zənciri — RunnablePassthrough tipli addım-addım pipeline.

LangChain asılılığı yoxdur; hər addım state dict-i qəbul edib genişləndirir
və növbətiyə ötürür (bax `lesson19` RunnablePassthrough.assign naxışı).

Addımlar: validate → load (DB) → build messages → call AI → parse marker
→ persist → return.
"""

from __future__ import annotations

import logging
import re
import time
from typing import Any, Callable

from .memory_store import MemoryStore
from .models import ChatRequest
from .prompts import build_chat_system, chat_preferred_providers
from .providers import (
    AllProvidersFailed,
    ChatCompleter,
    chat_with_fallback_detail,
)

logger = logging.getLogger("dildostu.chat")

# AI-ya göndərilən tarixçə limiti — app `ChatClient._maxHistory` ilə eyni.
AI_HISTORY_LIMIT = 12

_MEMORY_MARKER = re.compile(r"\n?\[\[YADDA:\s*(.+?)\s*\]\]\s*$", re.DOTALL)

Step = Callable[[dict[str, Any]], dict[str, Any]]


class ChatPipelineError(Exception):
    """Pipeline addımında xəta — `service.run_chat` bunu ServiceError-a çevirir."""


def _step_validate(state: dict[str, Any]) -> dict[str, Any]:
    req: ChatRequest = state["req"]
    if not req.messages:
        raise ChatPipelineError("Mesaj siyahısı boş ola bilməz")
    last = req.messages[-1]
    if last.role != "user":
        raise ChatPipelineError("Son mesaj istifadəçidən olmalıdır")
    state["user_content"] = last.content
    return state


def _step_load(state: dict[str, Any]) -> dict[str, Any]:
    """DB-dən faktları və son mesajları yükləyir (server müəllimdir)."""
    memory: MemoryStore = state["memory"]
    user_id: int = state["user_id"]
    state["facts"] = memory.recent_facts(user_id)
    state["stored"] = memory.recent_messages(user_id, limit=AI_HISTORY_LIMIT)
    return state


def _merge_ai_messages(
    stored: list[dict],
    client_messages: list,
    user_content: str,
) -> list[dict[str, str]]:
    """DB tarixçəsi ilə client mesajlarını birləşdirir.

    DB boşdursa client-ə etibar edir (sessiya daxili). DB doludursa və client
    onun davamıdırsa client-i götürür; əks halda DB + yeni istifadəçi mesajı.
    """
    stored_pairs = [(m["role"], m["content"]) for m in stored]
    client_pairs = [(m.role, m.content) for m in client_messages]

    if not stored_pairs:
        messages = [{"role": r, "content": c} for r, c in client_pairs]
    elif (
        len(client_pairs) >= len(stored_pairs)
        and client_pairs[: len(stored_pairs)] == stored_pairs
    ):
        messages = [{"role": r, "content": c} for r, c in client_pairs]
    else:
        messages = [{"role": m["role"], "content": m["content"]} for m in stored]
        if (
            not messages
            or messages[-1]["role"] != "user"
            or messages[-1]["content"] != user_content
        ):
            messages.append({"role": "user", "content": user_content})

    if len(messages) > AI_HISTORY_LIMIT:
        messages = messages[-AI_HISTORY_LIMIT:]
    return messages


def _step_build_messages(state: dict[str, Any]) -> dict[str, Any]:
    """Saxlanmış + client tarixçəsi + yeni istifadəçi mesajı → AI konteksti."""
    state["ai_messages"] = _merge_ai_messages(
        state["stored"],
        state["req"].messages,
        state["user_content"],
    )
    return state


def _step_call_ai(state: dict[str, Any]) -> dict[str, Any]:
    req: ChatRequest = state["req"]
    system = build_chat_system(req.profile, req.context, state["facts"])
    started = time.monotonic()
    try:
        reply, provider, errors = chat_with_fallback_detail(
            system,
            state["ai_messages"],
            chat_preferred_providers(),
            state["chat_completers"],
        )
    except AllProvidersFailed as exc:
        logger.error(
            "chat_failed user=%s latency_ms=%d error=%s",
            state["user_id"],
            int((time.monotonic() - started) * 1000),
            exc,
        )
        raise ChatPipelineError(str(exc)) from exc

    state["raw_reply"] = reply
    state["provider"] = provider
    state["latency_ms"] = int((time.monotonic() - started) * 1000)
    if errors:
        logger.warning("chat_fallback user=%s skipped=%s", state["user_id"], errors)
    return state


def _step_parse_marker(state: dict[str, Any]) -> dict[str, Any]:
    raw: str = state["raw_reply"]
    match = _MEMORY_MARKER.search(raw)
    state["reply"] = raw
    state["new_facts"] = []
    if match:
        state["reply"] = raw[: match.start()].rstrip()
        state["new_facts"] = [
            fact.strip() for fact in match.group(1).split("|") if fact.strip()
        ]
    return state


def _step_persist(state: dict[str, Any]) -> dict[str, Any]:
    """Uğurlu cavabdan sonra istifadəçi + köməkçi mesajlarını DB-yə yazır."""
    memory: MemoryStore = state["memory"]
    user_id: int = state["user_id"]
    user_content: str = state["user_content"]
    reply: str = state["reply"]
    stored: list[dict] = state["stored"]

    already_saved = (
        stored
        and stored[-1]["role"] == "user"
        and stored[-1]["content"] == user_content
    )
    if not already_saved:
        memory.add_message(user_id, "user", user_content)
    memory.add_message(user_id, "assistant", reply)
    saved_facts = sum(1 for fact in state["new_facts"] if memory.add_fact(user_id, fact))

    logger.info(
        "chat_ok user=%s provider=%s latency_ms=%s turns=%d reply_chars=%d "
        "new_facts=%d",
        user_id,
        state.get("provider", "?"),
        state.get("latency_ms", -1),
        len(state.get("ai_messages", ())),
        len(reply),
        saved_facts,
    )
    return state


_PIPELINE: tuple[Step, ...] = (
    _step_validate,
    _step_load,
    _step_build_messages,
    _step_call_ai,
    _step_parse_marker,
    _step_persist,
)


def run_chat_pipeline(
    req: ChatRequest,
    chat_completers: dict[str, ChatCompleter],
    memory: MemoryStore,
    user_id: int,
) -> str:
    """RunnablePassthrough tipli zəncir: state dict addım-addım genişlənir."""
    state: dict[str, Any] = {
        "req": req,
        "chat_completers": chat_completers,
        "memory": memory,
        "user_id": user_id,
    }
    for step in _PIPELINE:
        state = step(state)
    return state["reply"]
