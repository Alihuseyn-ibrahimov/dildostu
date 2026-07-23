"""DilDostu Live FastAPI tətbiqi — /generate, /day-plan, /health."""

from __future__ import annotations

from fastapi import Depends, FastAPI, HTTPException, Response
from fastapi.responses import FileResponse

import os

from .models import (
    AppVersionInfo,
    ChatRequest,
    ChatResponse,
    DayPlanRequest,
    DayPlanResponse,
    GenerateRequest,
    LiveMessage,
    RoutineSampleRequest,
    RoutineSummaryResponse,
)
from .providers import (
    ChatCompleter,
    Completer,
    build_chat_completers,
    build_completers,
)
from .release_store import ReleaseStore
from .routine_store import RoutineStore
from .service import LiveService, ServiceError, run_chat

app = FastAPI(title="DilDostu Live")
app.state.cache = {}
# Rutin nümunələri üçün davamlı SQLite (WorkingDirectory: /opt/dildostu/server).
app.state.routine_store = RoutineStore(
    os.environ.get("ROUTINE_DB_PATH", "routine.db")
)
# APK buraxılışları — kod deploy-undan ayrı qovluq (bax release_store.py).
app.state.release_store = ReleaseStore(
    os.environ.get("RELEASES_DIR", "releases")
)


def get_completers() -> dict[str, Completer]:
    """Provayder completer-ləri (test-də override olunur)."""
    return build_completers()


def get_chat_completers() -> dict[str, ChatCompleter]:
    """Söhbət (çoxnövbəli) completer-ləri (test-də override olunur)."""
    return build_chat_completers()


def get_routine_store() -> RoutineStore:
    """Rutin SQLite store (test-də :memory: ilə override olunur)."""
    return app.state.routine_store


def get_release_store() -> ReleaseStore:
    """Buraxılış store (test-də tmp_path ilə override olunur)."""
    return app.state.release_store


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


@app.post("/routine/sample")
def routine_sample(
    req: RoutineSampleRequest,
    store: RoutineStore = Depends(get_routine_store),
) -> dict:
    """Cihazdan gələn məkan nümunəsini saxlayır (vaxt serverdə UTC)."""
    store.add(
        req.device_id,
        lat=req.lat,
        lng=req.lng,
        place_type=req.place_type,
        pack_id=req.pack_id,
    )
    return {"ok": True}


@app.get("/routine/summary/{device_id}", response_model=RoutineSummaryResponse)
def routine_summary(
    device_id: str,
    store: RoutineStore = Depends(get_routine_store),
) -> RoutineSummaryResponse:
    """"AI nəyi öyrənib" — məkan tipləri üzrə aqreqat."""
    return RoutineSummaryResponse(places=store.place_summary(device_id))


# Buraxılış cavabları keşlənməməlidir — Cloudflare/proxy köhnə APK/versiya
# verməsin (yeni buraxılış dərhal görünsün).
_NO_STORE = {"Cache-Control": "no-store, no-cache, must-revalidate"}


@app.get("/app/version", response_model=AppVersionInfo)
def app_version(
    response: Response,
    store: ReleaseStore = Depends(get_release_store),
) -> AppVersionInfo:
    """App açılışda bunu öz versiyası ilə müqayisə edir."""
    response.headers.update(_NO_STORE)
    info = store.version_info()
    if info is None:
        raise HTTPException(status_code=404, detail="Buraxılış yoxdur")
    return AppVersionInfo(**info)


@app.get("/app/latest.apk")
def app_latest_apk(
    store: ReleaseStore = Depends(get_release_store),
) -> FileResponse:
    path = store.apk_path()
    if path is None:
        raise HTTPException(status_code=404, detail="APK yoxdur")
    return FileResponse(
        path,
        media_type="application/vnd.android.package-archive",
        filename="dildostu-update.apk",
        headers=_NO_STORE,
    )
