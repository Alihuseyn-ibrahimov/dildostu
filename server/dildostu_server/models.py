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
