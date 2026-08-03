"""RoutineStore (SQLite) — nümunə saxlama + aqreqat testləri.

Faza 2 (03.08.2026): nümunələr artıq anonim `device_id` yerinə `user_id`
üzrə açarlanır. `device_id` sütunu qalır (cihazı tanımaq + köhnə anonim
nümunələri hesaba bağlamaq üçün).
"""

import sqlite3

from dildostu_server.routine_store import RoutineStore


def _store() -> RoutineStore:
    # :memory: — hər test təmiz başlayır.
    return RoutineStore(":memory:")


def _add(store, user_id, **kw):
    kw.setdefault("lat", 1.0)
    kw.setdefault("lng", 1.0)
    kw.setdefault("place_type", "cafe")
    kw.setdefault("device_id", "dev1")
    store.add(user_id, **kw)


class TestAddAndRecent:
    def test_add_then_recent_returns_it(self):
        s = _store()
        s.add(1, device_id="dev1", lat=40.37, lng=49.83,
              place_type="cafe", pack_id="cafe")
        rows = s.recent(1, limit=10)
        assert len(rows) == 1
        assert rows[0]["place_type"] == "cafe"
        assert rows[0]["lat"] == 40.37
        assert rows[0]["ts"]  # server vaxt qoyur

    def test_recent_is_scoped_by_user(self):
        s = _store()
        _add(s, 1, place_type="cafe")
        _add(s, 2, place_type="market")
        rows = s.recent(1, limit=10)
        assert len(rows) == 1
        assert rows[0]["place_type"] == "cafe"

    def test_recent_newest_first_and_limited(self):
        s = _store()
        for i in range(5):
            _add(s, 1, lat=float(i), place_type=f"p{i}")
        rows = s.recent(1, limit=3)
        assert len(rows) == 3
        assert rows[0]["place_type"] == "p4"

    def test_unknown_user_returns_empty(self):
        assert _store().recent(999, limit=10) == []


class TestPlaceSummary:
    def test_empty_user_returns_empty(self):
        assert _store().place_summary(999) == []

    def test_aggregates_by_place_type(self):
        s = _store()
        _add(s, 1, place_type="cafe", pack_id="cafe")
        _add(s, 1, place_type="cafe", pack_id="cafe")
        _add(s, 1, place_type="market", pack_id="market")
        summary = {r["place_type"]: r for r in s.place_summary(1)}
        assert summary["cafe"]["count"] == 2
        assert summary["market"]["count"] == 1
        assert summary["cafe"]["pack_id"] == "cafe"
        assert summary["cafe"]["last_seen"]

    def test_summary_sorted_by_count_desc(self):
        s = _store()
        _add(s, 1, place_type="rare")
        for _ in range(3):
            _add(s, 1, place_type="common")
        rows = s.place_summary(1)
        assert rows[0]["place_type"] == "common"
        assert rows[0]["count"] == 3

    def test_summary_does_not_leak_between_users(self):
        s = _store()
        _add(s, 1, place_type="cafe")
        _add(s, 2, place_type="market")
        assert [r["place_type"] for r in s.place_summary(1)] == ["cafe"]


class TestClaimDevice:
    """Hesabdan əvvəl toplanmış anonim nümunələr hesaba bağlanır."""

    def test_claims_orphan_rows(self):
        s = _store()
        s.add(None, device_id="devX", lat=1.0, lng=1.0, place_type="cafe")
        claimed = s.claim_device(7, "devX")
        assert claimed == 1
        assert len(s.recent(7, limit=10)) == 1

    def test_does_not_steal_other_users_rows(self):
        s = _store()
        _add(s, 5, device_id="devX", place_type="cafe")
        assert s.claim_device(7, "devX") == 0
        assert s.recent(7, limit=10) == []
        assert len(s.recent(5, limit=10)) == 1

    def test_unknown_device_claims_nothing(self):
        assert _store().claim_device(7, "yoxdur") == 0


class TestMigration:
    def test_adds_user_id_column_to_old_table(self, tmp_path):
        """Faza 2-dən əvvəlki baza (user_id sütunu yox) açıla bilməlidir."""
        path = str(tmp_path / "old.db")
        conn = sqlite3.connect(path)
        conn.executescript(
            """
            CREATE TABLE routine_samples (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id  TEXT NOT NULL,
                ts         TEXT NOT NULL,
                lat        REAL NOT NULL,
                lng        REAL NOT NULL,
                place_type TEXT NOT NULL,
                pack_id    TEXT
            );
            INSERT INTO routine_samples (device_id, ts, lat, lng, place_type)
            VALUES ('devOld', '2026-08-01T10:00:00+00:00', 1.0, 1.0, 'cafe');
            """
        )
        conn.commit()
        conn.close()

        store = RoutineStore(path)  # miqrasiya burada olmalıdır
        # Köhnə sətir itməyib və sahibsizdir — hesab açanda tələb oluna bilər.
        assert store.claim_device(3, "devOld") == 1
        assert len(store.recent(3, limit=10)) == 1
