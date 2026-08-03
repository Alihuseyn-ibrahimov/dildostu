"""Rutin nümunələrinin SQLite saxlanması.

Faza 2 (03.08.2026): nümunələr `user_id` üzrə açarlanır. `device_id` sütunu
saxlanılır — cihazı tanımaq və hesab yaranmazdan əvvəl toplanmış anonim
nümunələri hesaba bağlamaq (`claim_device`) üçün.

`sqlite3` standart kitabxanadır — yeni asılılıq gətirmir. Test `:memory:` ilə,
prod fayl yolu ilə işləyir.

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
        self._migrate()

    def _init_schema(self) -> None:
        self._conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS routine_samples (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id  TEXT NOT NULL,
                user_id    INTEGER,
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

    def _migrate(self) -> None:
        """Faza 2-dən əvvəl yaradılmış bazaya `user_id` sütununu əlavə edir.

        Köhnə sətirlərdə `user_id` NULL qalır (sahibsiz) — istifadəçi həmin
        cihazda hesab açanda `claim_device` ilə mənimsənilir.
        """
        columns = {
            row["name"]
            for row in self._conn.execute("PRAGMA table_info(routine_samples)")
        }
        if "user_id" not in columns:
            self._conn.execute(
                "ALTER TABLE routine_samples ADD COLUMN user_id INTEGER"
            )
        self._conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_routine_user_ts "
            "ON routine_samples (user_id, ts)"
        )
        self._conn.commit()

    def add(
        self,
        user_id: int | None,
        *,
        device_id: str,
        lat: float,
        lng: float,
        place_type: str,
        pack_id: str | None = None,
        ts: str | None = None,
    ) -> None:
        self._conn.execute(
            "INSERT INTO routine_samples "
            "(device_id, user_id, ts, lat, lng, place_type, pack_id) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            (
                device_id,
                user_id,
                ts or _utc_now_iso(),
                lat,
                lng,
                place_type,
                pack_id,
            ),
        )
        self._conn.commit()

    def recent(self, user_id: int, *, limit: int = 100) -> list[dict]:
        cur = self._conn.execute(
            "SELECT device_id, user_id, ts, lat, lng, place_type, pack_id "
            "FROM routine_samples WHERE user_id = ? "
            "ORDER BY id DESC LIMIT ?",
            (user_id, limit),
        )
        return [dict(r) for r in cur.fetchall()]

    def place_summary(self, user_id: int) -> list[dict]:
        """Hər məkan tipi üzrə say + son görülmə, saya görə azalan sıra."""
        cur = self._conn.execute(
            "SELECT place_type, COUNT(*) AS count, MAX(ts) AS last_seen, "
            "MAX(pack_id) AS pack_id "
            "FROM routine_samples WHERE user_id = ? "
            "GROUP BY place_type ORDER BY count DESC, last_seen DESC",
            (user_id,),
        )
        return [dict(r) for r in cur.fetchall()]

    def claim_device(self, user_id: int, device_id: str) -> int:
        """Cihazın SAHİBSİZ nümunələrini istifadəçiyə bağlayır.

        Yalnız `user_id IS NULL` olan sətirlərə toxunur — başqa istifadəçinin
        datası mənimsənilə bilməz. Bağlanan sətir sayını qaytarır.
        """
        cur = self._conn.execute(
            "UPDATE routine_samples SET user_id = ? "
            "WHERE device_id = ? AND user_id IS NULL",
            (user_id, device_id),
        )
        self._conn.commit()
        return cur.rowcount

    def delete_user_data(self, user_id: int) -> int:
        """İstifadəçinin bütün nümunələrini silir (hesab silmə axını)."""
        cur = self._conn.execute(
            "DELETE FROM routine_samples WHERE user_id = ?", (user_id,)
        )
        self._conn.commit()
        return cur.rowcount
