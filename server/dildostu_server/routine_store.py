"""Rutin nümunələrinin SQLite saxlanması.

Anonim `device_id` ilə açarlanır (PII yox). `sqlite3` standart kitabxanadır —
yeni asılılıq gətirmir. Test `:memory:` ilə, prod fayl yolu ilə işləyir.

Qeyd: `sqlite3.connect` standart olaraq tək thread-ə bağlıdır; gunicorn tək
worker (bax deploy) ilə işlədiyi üçün `check_same_thread=False` + qısa
əməliyyatlar kifayətdir.
"""

from __future__ import annotations

import sqlite3
from datetime import datetime, timezone


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class RoutineStore:
    def __init__(self, path: str = "routine.db") -> None:
        self._conn = sqlite3.connect(path, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._init_schema()

    def _init_schema(self) -> None:
        self._conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS routine_samples (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id  TEXT NOT NULL,
                ts         TEXT NOT NULL,
                lat        REAL NOT NULL,
                lng        REAL NOT NULL,
                place_type TEXT NOT NULL,
                pack_id    TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_routine_device_ts
                ON routine_samples (device_id, ts);
            """
        )
        self._conn.commit()

    def add(
        self,
        device_id: str,
        *,
        lat: float,
        lng: float,
        place_type: str,
        pack_id: str | None = None,
        ts: str | None = None,
    ) -> None:
        self._conn.execute(
            "INSERT INTO routine_samples "
            "(device_id, ts, lat, lng, place_type, pack_id) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (device_id, ts or _utc_now_iso(), lat, lng, place_type, pack_id),
        )
        self._conn.commit()

    def recent(self, device_id: str, *, limit: int = 100) -> list[dict]:
        cur = self._conn.execute(
            "SELECT device_id, ts, lat, lng, place_type, pack_id "
            "FROM routine_samples WHERE device_id = ? "
            "ORDER BY id DESC LIMIT ?",
            (device_id, limit),
        )
        return [dict(r) for r in cur.fetchall()]

    def place_summary(self, device_id: str) -> list[dict]:
        """Hər məkan tipi üzrə say + son görülmə, saya görə azalan sıra."""
        cur = self._conn.execute(
            "SELECT place_type, COUNT(*) AS count, MAX(ts) AS last_seen, "
            "MAX(pack_id) AS pack_id "
            "FROM routine_samples WHERE device_id = ? "
            "GROUP BY place_type ORDER BY count DESC, last_seen DESC",
            (device_id,),
        )
        return [dict(r) for r in cur.fetchall()]
