"""Söhbət üçün gündəlik istifadə limiti — AI kvotasının qorunması.

Groq pulsuz tier gündə 100K token verir (bax `dildostu/CLAUDE.md`). Bir
istifadəçi limitsiz yazsa bütün digərləri üçün servis dayanır (`429
tokens_exceeded` → endpoint 502). Bu modul hər istifadəçiyə gündəlik mesaj
tavanı qoyur; sayğac ayrıca cədvəl saxlamır, mövcud `chat_messages`-i
sayır (bir mənbə, sinxronizasiya problemi yoxdur).
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from .memory_store import MemoryStore

DEFAULT_DAILY_MESSAGE_LIMIT = 80


def daily_message_limit() -> int:
    """Gündəlik mesaj tavanı — `CHAT_DAILY_LIMIT` ilə override olunur.

    Yanlış/mənfi dəyər verilsə default-a düşür (servis sınmır).
    """
    raw = os.environ.get("CHAT_DAILY_LIMIT")
    if not raw:
        return DEFAULT_DAILY_MESSAGE_LIMIT
    try:
        value = int(raw)
    except ValueError:
        return DEFAULT_DAILY_MESSAGE_LIMIT
    return value if value > 0 else DEFAULT_DAILY_MESSAGE_LIMIT


@dataclass(frozen=True)
class QuotaStatus:
    used: int
    limit: int

    @property
    def remaining(self) -> int:
        return max(0, self.limit - self.used)

    @property
    def exceeded(self) -> bool:
        return self.used >= self.limit


def _window_start(now: datetime) -> str:
    """Son 24 saatın başlanğıcı (ISO UTC).

    Təqvim günü yox, sürüşən pəncərə: gecə yarısını gözləyən "limit sıfırlandı"
    kütləvi sorğu dalğası olmur.
    """
    return (now - timedelta(hours=24)).isoformat()


def check_quota(
    memory: MemoryStore, user_id: int, *, now: datetime | None = None
) -> QuotaStatus:
    """İstifadəçinin son 24 saatdakı mesaj sayını limitlə müqayisə edir."""
    moment = now or datetime.now(timezone.utc)
    used = memory.count_messages_since(user_id, _window_start(moment))
    return QuotaStatus(used=used, limit=daily_message_limit())


def quota_message(status: QuotaStatus) -> str:
    """İstifadəçiyə göstərilən Azərbaycanca limit mesajı."""
    return (
        f"Bu gün üçün söhbət limitin doldu ({status.limit} mesaj). "
        "Sabah yenidən yazışa bilərsən — bu arada paketlərdən söz öyrən "
        "və ya səsli kitab dinlə. ✈️"
    )
