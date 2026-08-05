"""AI çat yaddaşının SQLite saxlanması — xam tarixçə + çıxarılmış faktlar.

`routine_store.py` ilə eyni naxış: `sqlite3` standart kitabxana, tək worker
(bax deploy), qısa əməliyyatlar. Bax spec:
2026-08-04-chat-memory-design.md.
"""

from __future__ import annotations

import sqlite3
from datetime import datetime, timezone


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class MemoryStore:
    def __init__(self, path: str = "memory.db") -> None:
        self._conn = sqlite3.connect(path, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._init_schema()

    def _init_schema(self) -> None:
        self._conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS chat_messages (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id    INTEGER NOT NULL,
                role       TEXT NOT NULL,
                content    TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_chat_messages_user
                ON chat_messages (user_id, id);
            CREATE TABLE IF NOT EXISTS user_facts (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id    INTEGER NOT NULL,
                fact       TEXT NOT NULL,
                created_at TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_user_facts_user
                ON user_facts (user_id, id);
            """
        )
        self._conn.commit()

    def add_message(self, user_id: int, role: str, content: str) -> None:
        self._conn.execute(
            "INSERT INTO chat_messages (user_id, role, content, created_at) "
            "VALUES (?, ?, ?, ?)",
            (user_id, role, content, _utc_now_iso()),
        )
        self._conn.commit()

    def recent_messages(self, user_id: int, *, limit: int = 50) -> list[dict]:
        """Son `limit` mesajı XRONOLOJİ sırada (ən köhnədən ən yeniyə) qaytarır."""
        cur = self._conn.execute(
            "SELECT role, content, created_at FROM chat_messages "
            "WHERE user_id = ? ORDER BY id DESC LIMIT ?",
            (user_id, limit),
        )
        rows = [dict(r) for r in cur.fetchall()]
        rows.reverse()
        return rows

    def add_fact(self, user_id: int, fact: str) -> None:
        self._conn.execute(
            "INSERT INTO user_facts (user_id, fact, created_at) VALUES (?, ?, ?)",
            (user_id, fact, _utc_now_iso()),
        )
        self._conn.commit()

    def recent_facts(self, user_id: int, *, limit: int = 20) -> list[str]:
        """Son `limit` faktı XRONOLOJİ sırada qaytarır (prompt-a bu sıra ilə düşür)."""
        cur = self._conn.execute(
            "SELECT fact FROM user_facts WHERE user_id = ? "
            "ORDER BY id DESC LIMIT ?",
            (user_id, limit),
        )
        facts = [r["fact"] for r in cur.fetchall()]
        facts.reverse()
        return facts

    def delete_user_data(self, user_id: int) -> None:
        """İstifadəçinin bütün tarixçəsini və faktlarını silir (hesab silmə axını)."""
        self._conn.execute("DELETE FROM chat_messages WHERE user_id = ?", (user_id,))
        self._conn.execute("DELETE FROM user_facts WHERE user_id = ?", (user_id,))
        self._conn.commit()
