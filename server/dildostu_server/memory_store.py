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

    def last_user_message_at(self, user_id: int) -> str | None:
        """Son istifadəçi mesajının UTC ISO vaxtı (nudge fərdiləşdirməsi üçün)."""
        cur = self._conn.execute(
            "SELECT created_at FROM chat_messages "
            "WHERE user_id = ? AND role = 'user' ORDER BY id DESC LIMIT 1",
            (user_id,),
        )
        row = cur.fetchone()
        return row["created_at"] if row else None

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

    def count_messages_since(
        self, user_id: int, since_iso: str, *, role: str = "user"
    ) -> int:
        """`since_iso`-dan sonra həmin roldan neçə mesaj var (kvota sayğacı).

        `created_at` ISO-8601 UTC olduğu üçün sətir müqayisəsi xronolojidir.
        """
        cur = self._conn.execute(
            "SELECT COUNT(*) AS n FROM chat_messages "
            "WHERE user_id = ? AND role = ? AND created_at >= ?",
            (user_id, role, since_iso),
        )
        return int(cur.fetchone()["n"])

    def delete_messages(self, user_id: int) -> None:
        """Yalnız söhbət tarixçəsini silir — portret (faktlar) qalır."""
        self._conn.execute("DELETE FROM chat_messages WHERE user_id = ?", (user_id,))
        self._conn.commit()

    def delete_facts(self, user_id: int) -> None:
        """Yalnız portreti (faktları) silir — tarixçə qalır."""
        self._conn.execute("DELETE FROM user_facts WHERE user_id = ?", (user_id,))
        self._conn.commit()

    def add_fact(self, user_id: int, fact: str) -> bool:
        """Yeni fakt əlavə edir. Eyni mətn (kiçik/böyük hərfsiz) artıq
        varsa təkrar yazmır — `True` yalnız yeni əlavə olunanda."""
        cleaned = fact.strip()
        if not cleaned:
            return False
        cur = self._conn.execute(
            "SELECT 1 FROM user_facts WHERE user_id = ? "
            "AND lower(fact) = lower(?) LIMIT 1",
            (user_id, cleaned),
        )
        if cur.fetchone() is not None:
            return False
        self._conn.execute(
            "INSERT INTO user_facts (user_id, fact, created_at) VALUES (?, ?, ?)",
            (user_id, cleaned, _utc_now_iso()),
        )
        self._conn.commit()
        return True

    def recent_facts(self, user_id: int, *, limit: int = 40) -> list[str]:
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
