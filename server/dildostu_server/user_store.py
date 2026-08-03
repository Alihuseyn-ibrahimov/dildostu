"""İstifadəçi hesablarının SQLite saxlanması (Faza 1.1).

`routine_store.py` ilə eyni pattern: `sqlite3` standart kitabxana, tək worker
(bax deploy), qısa əməliyyatlar. Şifrə YALNIZ hash kimi saxlanır — bu modul
hash-ləməni özü etmir (bax `auth.py`), yalnız verilən dəyəri yazır.
"""

from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone


class DuplicateEmail(Exception):
    """Bu e-poçt artıq qeydiyyatdadır."""


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _normalize_email(email: str) -> str:
    """E-poçt registrə həssas olmamalıdır (Ali@X.com == ali@x.com)."""
    return email.strip().lower()


class UserStore:
    def __init__(self, path: str = "users.db") -> None:
        self._conn = sqlite3.connect(path, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._init_schema()

    def _init_schema(self) -> None:
        self._conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                email         TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                created_at    TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS user_profiles (
                user_id    INTEGER PRIMARY KEY,
                profile    TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        )
        self._conn.commit()

    def create(self, email: str, password_hash: str) -> dict:
        normalized = _normalize_email(email)
        try:
            cur = self._conn.execute(
                "INSERT INTO users (email, password_hash, created_at) "
                "VALUES (?, ?, ?)",
                (normalized, password_hash, _utc_now_iso()),
            )
            self._conn.commit()
        except sqlite3.IntegrityError as exc:
            raise DuplicateEmail(normalized) from exc
        return self.get_by_id(cur.lastrowid)

    def get_by_email(self, email: str) -> dict | None:
        cur = self._conn.execute(
            "SELECT id, email, password_hash, created_at FROM users "
            "WHERE email = ?",
            (_normalize_email(email),),
        )
        row = cur.fetchone()
        return dict(row) if row else None

    def get_by_id(self, user_id: int) -> dict | None:
        cur = self._conn.execute(
            "SELECT id, email, password_hash, created_at FROM users WHERE id = ?",
            (user_id,),
        )
        row = cur.fetchone()
        return dict(row) if row else None

    def delete(self, user_id: int) -> None:
        """Hesabı və ona bağlı profili silir (Play "hesab silmə" tələbi)."""
        self._conn.execute("DELETE FROM users WHERE id = ?", (user_id,))
        self._conn.execute(
            "DELETE FROM user_profiles WHERE user_id = ?", (user_id,)
        )
        self._conn.commit()

    def get_profile(self, user_id: int) -> dict | None:
        cur = self._conn.execute(
            "SELECT profile FROM user_profiles WHERE user_id = ?", (user_id,)
        )
        row = cur.fetchone()
        return json.loads(row["profile"]) if row else None

    def save_profile(self, user_id: int, profile: dict) -> None:
        self._conn.execute(
            "INSERT INTO user_profiles (user_id, profile, updated_at) "
            "VALUES (?, ?, ?) "
            "ON CONFLICT(user_id) DO UPDATE SET profile = excluded.profile, "
            "updated_at = excluded.updated_at",
            (user_id, json.dumps(profile, ensure_ascii=False), _utc_now_iso()),
        )
        self._conn.commit()
