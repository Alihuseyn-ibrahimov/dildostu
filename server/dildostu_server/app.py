"""DilDostu Live FastAPI tətbiqi — /generate, /day-plan, /health."""

from __future__ import annotations

from pathlib import Path

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException, Response
from fastapi.responses import FileResponse, HTMLResponse

import os

from .auth import (
    InvalidToken,
    create_token,
    hash_password,
    token_secret,
    verify_password,
    verify_token,
)
from .essential_words import words_for_level
from .models import (
    AppVersionInfo,
    AuthResponse,
    ChatHistoryResponse,
    ChatRequest,
    ChatResponse,
    DayPlanRequest,
    DayPlanResponse,
    EssentialWordsRequest,
    EssentialWordsResponse,
    GenerateRequest,
    GeofencesResponse,
    LiveMessage,
    LoginRequest,
    PackWordsRequest,
    PackWordsResponse,
    PlaceResolveRequest,
    PlaceResolveResponse,
    ProfileResponse,
    ProfileUpdateRequest,
    RegisterRequest,
    RoutineClaimRequest,
    RoutineSampleRequest,
    RoutineSummaryResponse,
    UserInfo,
    WordLookupRequest,
    WordLookupResponse,
)
from .audiobook_store import AudiobookStore
from .memory_store import MemoryStore
from .place_lookup import PlaceLookup, PlaceLookupError
from .routine_clustering import cluster_places
from .providers import (
    ChatCompleter,
    Completer,
    build_chat_completers,
    build_completers,
)
from .release_store import ReleaseStore
from .routine_store import RoutineStore
from .service import LiveService, ServiceError, run_chat
from .static_pages import delete_account_html, privacy_policy_html
from .user_store import DuplicateEmail, UserStore

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
# Foursquare açarı serverdə (.env) — koordinatı yaxın yerə çevirmək üçün.
load_dotenv(Path(__file__).resolve().parents[1] / ".env")
app.state.place_lookup = PlaceLookup(os.environ.get("FOURSQUARE_API_KEY", ""))
# İstifadəçi hesabları (Faza 1) — routine.db-dən ayrı fayl.
app.state.user_store = UserStore(os.environ.get("USERS_DB_PATH", "users.db"))
# Səsli kitablar — hazır MP3-lər, kod deploy-undan ayrı qovluq.
app.state.audiobook_store = AudiobookStore(
    os.environ.get("AUDIOBOOKS_DIR", "audiobooks")
)
# Çat tarixçəsi + öyrənilən faktlar — routine.db-dən ayrı fayl.
app.state.memory_store = MemoryStore(os.environ.get("MEMORY_DB_PATH", "memory.db"))


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


def get_audiobook_store() -> AudiobookStore:
    """Səsli kitab store (test-də tmp_path ilə override olunur)."""
    return app.state.audiobook_store


def get_place_lookup() -> PlaceLookup:
    """Foursquare yer axtarışı (test-də saxta client ilə override olunur)."""
    return app.state.place_lookup


def get_user_store() -> UserStore:
    """İstifadəçi hesabları store-u (test-də :memory: ilə override olunur)."""
    return app.state.user_store


def get_memory_store() -> MemoryStore:
    """Çat yaddaşı store-u (test-də :memory: ilə override olunur)."""
    return app.state.memory_store


def get_token_secret() -> str:
    """JWT imzalama açarı (test-də sabit açarla override olunur)."""
    return token_secret()


# Başlıq avtomatik `WWW-Authenticate` ilə — standart 401 davranışı.
_UNAUTHORIZED = HTTPException(
    status_code=401,
    detail="Giriş tələb olunur",
    headers={"WWW-Authenticate": "Bearer"},
)


def get_current_user(
    authorization: str | None = Header(default=None),
    store: UserStore = Depends(get_user_store),
    secret: str = Depends(get_token_secret),
) -> dict:
    """`Authorization: Bearer <token>` başlığından cari istifadəçini tapır.

    Token yoxdursa/etibarsızdırsa və ya istifadəçi silinibsə 401.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise _UNAUTHORIZED
    token = authorization[7:].strip()
    try:
        user_id = verify_token(token, secret=secret)
    except InvalidToken:
        raise _UNAUTHORIZED

    user = store.get_by_id(user_id)
    if user is None:
        # Hesab silinib, amma token hələ ömrünü başa vurmayıb.
        raise _UNAUTHORIZED
    return user


def _user_info(user: dict) -> UserInfo:
    """DB sətrindən cavab modeli — `password_hash` qəsdən daxil edilmir."""
    return UserInfo(
        id=user["id"], email=user["email"], created_at=user["created_at"]
    )


def _service(completers: dict[str, Completer]) -> LiveService:
    return LiveService(completers, cache=app.state.cache)


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/privacy", response_class=HTMLResponse)
def privacy_policy() -> str:
    """Google Play Store siyahısı üçün məcburi məxfilik siyasəti."""
    return privacy_policy_html()


@app.get("/delete-account", response_class=HTMLResponse)
def delete_account_page() -> str:
    """Google Play "data deletion" tələbi — tətbiqsiz də hesab silmə yolu."""
    return delete_account_html()


@app.post("/auth/register", response_model=AuthResponse, status_code=201)
def auth_register(
    req: RegisterRequest,
    store: UserStore = Depends(get_user_store),
    secret: str = Depends(get_token_secret),
) -> AuthResponse:
    try:
        user = store.create(req.email, hash_password(req.password))
    except DuplicateEmail:
        raise HTTPException(status_code=409, detail="Bu e-poçt artıq qeydiyyatdadır")
    return AuthResponse(
        token=create_token(user["id"], secret=secret), user=_user_info(user)
    )


@app.post("/auth/login", response_model=AuthResponse)
def auth_login(
    req: LoginRequest,
    store: UserStore = Depends(get_user_store),
    secret: str = Depends(get_token_secret),
) -> AuthResponse:
    user = store.get_by_email(req.email)
    # Naməlum e-poçt və səhv şifrə EYNİ cavabı verir — hansı e-poçtların
    # qeydiyyatda olduğunu üzə çıxarmamaq üçün.
    if user is None or not verify_password(req.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="E-poçt və ya şifrə səhvdir")
    return AuthResponse(
        token=create_token(user["id"], secret=secret), user=_user_info(user)
    )


@app.get("/auth/me", response_model=UserInfo)
def auth_me(user: dict = Depends(get_current_user)) -> UserInfo:
    return _user_info(user)


@app.delete("/auth/me", status_code=204)
def auth_delete_me(
    user: dict = Depends(get_current_user),
    store: UserStore = Depends(get_user_store),
    routine: RoutineStore = Depends(get_routine_store),
    memory: MemoryStore = Depends(get_memory_store),
) -> Response:
    """Hesabı və ona bağlı BÜTÜN datanı silir (Google Play tələbi).

    Rutin nümunələri (məkan tarixçəsi) və çat yaddaşı (tarixçə + faktlar)
    da silinir — hesab silinəndə geridə heç bir şəxsi data qalmamalıdır.
    """
    routine.delete_user_data(user["id"])
    memory.delete_user_data(user["id"])
    store.delete(user["id"])
    return Response(status_code=204)


@app.get("/profile", response_model=ProfileResponse)
def get_profile(
    user: dict = Depends(get_current_user),
    store: UserStore = Depends(get_user_store),
) -> ProfileResponse:
    """İstifadəçinin serverdə saxlanan profili (səviyyə, məqsəd, maraqlar)."""
    saved = store.get_profile(user["id"])
    return ProfileResponse(profile=saved)


@app.put("/profile", response_model=ProfileResponse)
def put_profile(
    req: ProfileUpdateRequest,
    user: dict = Depends(get_current_user),
    store: UserStore = Depends(get_user_store),
) -> ProfileResponse:
    store.save_profile(user["id"], req.profile.model_dump())
    return ProfileResponse(profile=req.profile)


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


@app.post("/pack-words", response_model=PackWordsResponse)
def pack_words(
    req: PackWordsRequest,
    completers: dict[str, Completer] = Depends(get_completers),
) -> PackWordsResponse:
    """Söz siyahısı ekranı üçün — paketin sözləri istifadəçi səviyyəsində."""
    try:
        words = _service(completers).pack_words(req.profile, req.pack_id, req.count)
    except ServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc))
    return PackWordsResponse(words=words, source="ai")


@app.post("/essential-words", response_model=EssentialWordsResponse)
def essential_words(
    req: EssentialWordsRequest,
    completers: dict[str, Completer] = Depends(get_completers),
) -> EssentialWordsResponse:
    """Əsas lüğət.

    `target_lang == "en"` — 504 sabit söz bankı (Barron's), səviyyəyə uyğun
    növbəti dəst. `offset` dövr edir (dövrə bir dəfə tam banka görə) — son
    sözdən sonra yenidən əvvələ qayıdır ki, "növbəti dəst" düyməsi heç vaxt
    boş qalmasın.

    Digər dillər — sabit bank yoxdur, AI hər çağırışda təzə dəst seçir.
    `total=-1` "sonsuz axın" mənasını verir (app bunu sayğacı gizlətmək
    üçün oxuyur), `next_offset` sadəcə artır (dövriyyə yoxdur).
    """
    if req.profile.target_lang != "en":
        try:
            words = _service(completers).language_essential_words(
                req.profile, req.count, req.exclude_words
            )
        except ServiceError as exc:
            raise HTTPException(status_code=502, detail=str(exc))
        return EssentialWordsResponse(
            words=words, total=-1, next_offset=req.offset + req.count
        )

    pool = words_for_level(req.profile.level)
    total = len(pool)
    if total == 0:
        raise HTTPException(status_code=404, detail="Bu səviyyə üçün söz yoxdur")
    start = req.offset % total
    end = start + req.count
    batch = pool[start:end] if end <= total else pool[start:] + pool[: end - total]
    try:
        words = _service(completers).essential_words(req.profile, batch)
    except ServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc))
    return EssentialWordsResponse(
        words=words, total=total, next_offset=(start + req.count) % total
    )


@app.post("/word-lookup", response_model=WordLookupResponse)
def word_lookup(
    req: WordLookupRequest,
    completers: dict[str, Completer] = Depends(get_completers),
) -> WordLookupResponse:
    """Səsli kitabda toxunulan sözün tərcümə+IPA-sı (Faza 3)."""
    try:
        return _service(completers).word_lookup(req.word, req.context)
    except ServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc))


@app.post("/chat", response_model=ChatResponse)
def chat(
    req: ChatRequest,
    user: dict = Depends(get_current_user),
    chat_completers: dict[str, ChatCompleter] = Depends(get_chat_completers),
    memory: MemoryStore = Depends(get_memory_store),
) -> ChatResponse:
    try:
        return ChatResponse(
            reply=run_chat(req, chat_completers, memory, user["id"])
        )
    except ServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc))


@app.get("/chat/history", response_model=ChatHistoryResponse)
def chat_history(
    user: dict = Depends(get_current_user),
    memory: MemoryStore = Depends(get_memory_store),
) -> ChatHistoryResponse:
    """İstifadəçinin saxlanmış çat tarixçəsi — ekran açılanda göstərilir."""
    return ChatHistoryResponse(messages=memory.recent_messages(user["id"]))


@app.post("/routine/sample")
def routine_sample(
    req: RoutineSampleRequest,
    user: dict = Depends(get_current_user),
    store: RoutineStore = Depends(get_routine_store),
) -> dict:
    """Cihazdan gələn məkan nümunəsini saxlayır (vaxt serverdə UTC)."""
    store.add(
        user["id"],
        device_id=req.device_id,
        lat=req.lat,
        lng=req.lng,
        place_type=req.place_type,
        pack_id=req.pack_id,
    )
    return {"ok": True}


@app.post("/routine/claim")
def routine_claim(
    req: RoutineClaimRequest,
    user: dict = Depends(get_current_user),
    store: RoutineStore = Depends(get_routine_store),
) -> dict:
    """Hesabdan əvvəl bu cihazda toplanmış anonim nümunələri hesaba bağlayır."""
    return {"claimed": store.claim_device(user["id"], req.device_id)}


@app.post("/place/resolve", response_model=PlaceResolveResponse)
def place_resolve(
    req: PlaceResolveRequest,
    user: dict = Depends(get_current_user),
    lookup: PlaceLookup = Depends(get_place_lookup),
) -> PlaceResolveResponse:
    """Koordinatı yaxınlıqdakı yerə və söz paketinə çevirir (Foursquare)."""
    try:
        result = lookup.resolve(req.lat, req.lng)
    except PlaceLookupError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    if result is None or not result.get("pack_id"):
        raise HTTPException(status_code=404, detail="Yaxınlıqda tanınan yer yoxdur")
    return PlaceResolveResponse(
        pack_id=result["pack_id"],
        name=result.get("name", ""),
        category=result.get("category", ""),
    )


@app.get("/routine/summary", response_model=RoutineSummaryResponse)
def routine_summary(
    user: dict = Depends(get_current_user),
    store: RoutineStore = Depends(get_routine_store),
) -> RoutineSummaryResponse:
    """"AI nəyi öyrənib" — məkan tipləri üzrə aqreqat.

    Faza 2: `device_id` URL-dən çıxarıldı — əvvəl istənilən şəxs başqasının
    `device_id`-sini bilsə onun məkan aqreqatını oxuya bilirdi.
    """
    return RoutineSummaryResponse(places=store.place_summary(user["id"]))


# Android geofence limitinə uyğun tavan (bax spec: Faza 3b).
_MAX_GEOFENCES = 20


@app.get("/routine/geofences", response_model=GeofencesResponse)
def routine_geofences(
    user: dict = Depends(get_current_user),
    store: RoutineStore = Depends(get_routine_store),
) -> GeofencesResponse:
    """Tez-tez gedilən yerlər — app bunları qeyd edib çatanda bildiriş göstərir."""
    samples = store.recent(user["id"], limit=1000)
    zones = cluster_places(samples)[:_MAX_GEOFENCES]
    return GeofencesResponse(geofences=zones)


# Səsli kitab audiosu DƏYİŞMƏZDİR (yeni məzmun = yeni chapter_id), ona görə
# uzun müddət keşlənir — hər dinləmədə origin-ə getməsin (trafik + gecikmə).
# Bu, APK-nın `_NO_STORE`-undan QƏSDƏN fərqlidir, səhv salma.
_AUDIO_CACHE = {"Cache-Control": "public, max-age=31536000, immutable"}


@app.get("/audiobooks")
def audiobooks_manifest(
    store: AudiobookStore = Depends(get_audiobook_store),
) -> dict:
    """Kitab/fəsil siyahısı — app bunu keşləyib offline da göstərir."""
    manifest = store.manifest()
    if manifest is None:
        raise HTTPException(status_code=404, detail="Səsli kitab yoxdur")
    return manifest


@app.get("/audiobooks/{book_id}/{chapter_id}.mp3")
def audiobook_chapter(
    book_id: str,
    chapter_id: str,
    store: AudiobookStore = Depends(get_audiobook_store),
) -> FileResponse:
    """Fəslin MP3-ü. Range sorğuları dəstəklənir (sürüşdürmə üçün)."""
    path = store.chapter_path(book_id, chapter_id)
    if path is None:
        raise HTTPException(status_code=404, detail="Fəsil tapılmadı")
    return FileResponse(path, media_type="audio/mpeg", headers=_AUDIO_CACHE)


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
