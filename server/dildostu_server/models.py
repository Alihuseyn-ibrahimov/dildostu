"""DilDostu Live API modelləri (pydantic v2).

Bu modellər həm request/response validasiyasını (FastAPI), həm də AI çıxışının
sxem yoxlamasını təmin edir.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

Purpose = Literal["travel", "work", "general"]
Level = Literal["beginner", "intermediate"]
Mode = Literal["normal", "another_example", "simpler", "harder"]


class UserProfile(BaseModel):
    wake_hour: int = Field(ge=0, le=23)
    sleep_hour: int = Field(ge=0, le=23)
    purpose: Purpose
    level: Level
    interests: list[str] = Field(default_factory=list)


class Context(BaseModel):
    """ContextEngine-in aşkarladığı cari kontekst."""

    pack_id: str = Field(min_length=1)
    place: str | None = None
    hour: int = Field(ge=0, le=23)


class LiveMessage(BaseModel):
    """AI-nin yaratdığı bir fərdi mesaj (app-a gedən vahid)."""

    pack_id: str = Field(min_length=1)
    word: str = Field(min_length=1)
    translation_az: str = Field(min_length=1)
    ipa: str = Field(min_length=1)
    example: str = Field(min_length=1)
    example_az: str = Field(min_length=1)
    ai_line: str = Field(min_length=1)
    level: int = Field(ge=1, le=3)


class GenerateRequest(BaseModel):
    profile: UserProfile
    context: Context
    recent_words: list[str] = Field(default_factory=list)
    mode: Mode = "normal"


class DayPlanRequest(BaseModel):
    profile: UserProfile
    date: str = Field(min_length=1)
    pack_ids: list[str] = Field(min_length=1)


class DayPlanResponse(BaseModel):
    messages: list[LiveMessage]
    source: Literal["ai", "fallback"] = "ai"


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1)


class ChatRequest(BaseModel):
    profile: UserProfile
    messages: list[ChatMessage] = Field(min_length=1)
    context: Context | None = None


class ChatResponse(BaseModel):
    reply: str


class RoutineSampleRequest(BaseModel):
    """Cihazın göndərdiyi bir məkan nümunəsi (vaxt serverdə qoyulur)."""

    device_id: str = Field(min_length=1)
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    place_type: str = Field(min_length=1)
    pack_id: str | None = None


class PlaceResolveRequest(BaseModel):
    """App-ın göndərdiyi cari koordinat — server yaxın yeri tapır."""

    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)


class PlaceResolveResponse(BaseModel):
    """Tapılan yer və ona uyğun söz paketi."""

    pack_id: str = Field(min_length=1)
    name: str = ""
    category: str = ""


class PlaceSummary(BaseModel):
    """Bir məkan tipi üzrə aqreqat — "AI nəyi öyrənib" ekranı üçün."""

    place_type: str
    count: int
    last_seen: str  # ISO 8601 UTC
    pack_id: str | None = None


class RoutineSummaryResponse(BaseModel):
    places: list[PlaceSummary] = Field(default_factory=list)


class GeofenceZone(BaseModel):
    """Tez-tez gedilən yer — app bura çatanda avtomatik dərs bildirişi göstərir."""

    center_lat: float
    center_lng: float
    radius: float
    pack_id: str = Field(min_length=1)
    label: str
    hour_window: str
    count: int


class GeofencesResponse(BaseModel):
    geofences: list[GeofenceZone] = Field(default_factory=list)


class AppVersionInfo(BaseModel):
    """Serverdəki ən son buraxılış — app açılışda bunu özü ilə müqayisə edir."""

    version_code: int = Field(ge=1)
    version_name: str = Field(min_length=1)
    notes: str = ""
