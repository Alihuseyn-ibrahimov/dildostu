"""Canlı mesaj generasiyası servisi — prompt → completer → parser + keş.

Endpoint-dən ayrıdır ki, completer və keş inject oluna (test üçün mock).
"""

from __future__ import annotations

from .generator import parse_dayplan_response, parse_generate_response
from .models import (
    ChatRequest,
    DayPlanRequest,
    DayPlanResponse,
    GenerateRequest,
    LiveMessage,
)
from .prompts import (
    build_chat_system,
    build_dayplan_prompt,
    build_generate_prompt,
    chat_preferred_providers,
    preferred_providers,
)
from .providers import (
    AllProvidersFailed,
    ChatCompleter,
    Completer,
    chat_with_fallback,
    complete_with_fallback,
)


class ServiceError(Exception):
    """AI generasiyası uğursuz oldu (app statik fallback-a düşməli)."""


class LiveService:
    def __init__(self, completers: dict[str, Completer], cache: dict | None = None):
        self._completers = completers
        self._cache = cache if cache is not None else {}

    def generate(self, req: GenerateRequest) -> LiveMessage:
        key = (req.context.pack_id, req.profile.level, req.mode)
        if key in self._cache:
            return self._cache[key]

        system, user = build_generate_prompt(
            req.profile, req.context, req.mode, req.recent_words
        )
        try:
            text = complete_with_fallback(
                system, user, preferred_providers(req.mode), self._completers
            )
            message = parse_generate_response(text, req.context)
        except (AllProvidersFailed, ValueError) as exc:
            raise ServiceError(str(exc)) from exc

        self._cache[key] = message
        return message

    def day_plan(self, req: DayPlanRequest) -> DayPlanResponse:
        system, user = build_dayplan_prompt(req.profile, req.pack_ids, req.date)
        try:
            text = complete_with_fallback(
                system, user, preferred_providers("normal"), self._completers
            )
            messages = parse_dayplan_response(text, req.pack_ids)
        except (AllProvidersFailed, ValueError) as exc:
            raise ServiceError(str(exc)) from exc
        return DayPlanResponse(messages=messages, source="ai")


def run_chat(req: ChatRequest, chat_completers: dict[str, ChatCompleter]) -> str:
    """Söhbət cavabı yaradır (çoxnövbəli). AI uğursuzsa ServiceError."""
    system = build_chat_system(req.profile, req.context)
    messages = [{"role": m.role, "content": m.content} for m in req.messages]
    try:
        return chat_with_fallback(
            system, messages, chat_preferred_providers(), chat_completers
        )
    except AllProvidersFailed as exc:
        raise ServiceError(str(exc)) from exc
