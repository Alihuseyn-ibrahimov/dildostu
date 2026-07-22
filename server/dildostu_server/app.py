"""DilDostu Live FastAPI tətbiqi — /generate, /day-plan, /health."""

from __future__ import annotations

from fastapi import Depends, FastAPI, HTTPException

from .models import (
    ChatRequest,
    ChatResponse,
    DayPlanRequest,
    DayPlanResponse,
    GenerateRequest,
    LiveMessage,
)
from .providers import (
    ChatCompleter,
    Completer,
    build_chat_completers,
    build_completers,
)
from .service import LiveService, ServiceError, run_chat

app = FastAPI(title="DilDostu Live")
app.state.cache = {}


def get_completers() -> dict[str, Completer]:
    """Provayder completer-ləri (test-də override olunur)."""
    return build_completers()


def get_chat_completers() -> dict[str, ChatCompleter]:
    """Söhbət (çoxnövbəli) completer-ləri (test-də override olunur)."""
    return build_chat_completers()


def _service(completers: dict[str, Completer]) -> LiveService:
    return LiveService(completers, cache=app.state.cache)


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/generate", response_model=LiveMessage)
def generate(
    req: GenerateRequest,
    completers: dict[str, Completer] = Depends(get_completers),
) -> LiveMessage:
    try:
        return _service(completers).generate(req)
    except ServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc))


@app.post("/day-plan", response_model=DayPlanResponse)
def day_plan(
    req: DayPlanRequest,
    completers: dict[str, Completer] = Depends(get_completers),
) -> DayPlanResponse:
    try:
        return _service(completers).day_plan(req)
    except ServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc))


@app.post("/chat", response_model=ChatResponse)
def chat(
    req: ChatRequest,
    chat_completers: dict[str, ChatCompleter] = Depends(get_chat_completers),
) -> ChatResponse:
    try:
        return ChatResponse(reply=run_chat(req, chat_completers))
    except ServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc))
