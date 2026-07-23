"""RoutineStore (SQLite) — nümunə saxlama + aqreqat testləri."""

from dildostu_server.routine_store import RoutineStore


def _store() -> RoutineStore:
    # :memory: — hər test təmiz başlayır.
    return RoutineStore(":memory:")


class TestAddAndRecent:
    def test_add_then_recent_returns_it(self):
        s = _store()
        s.add("dev1", lat=40.37, lng=49.83, place_type="cafe", pack_id="cafe")
        rows = s.recent("dev1", limit=10)
        assert len(rows) == 1
        assert rows[0]["place_type"] == "cafe"
        assert rows[0]["lat"] == 40.37
        assert rows[0]["ts"]  # server vaxt qoyur

    def test_recent_is_scoped_by_device(self):
        s = _store()
        s.add("dev1", lat=1.0, lng=1.0, place_type="cafe")
        s.add("dev2", lat=2.0, lng=2.0, place_type="market")
        assert len(s.recent("dev1", limit=10)) == 1
        assert s.recent("dev1", limit=10)[0]["place_type"] == "cafe"

    def test_recent_newest_first_and_limited(self):
        s = _store()
        for i in range(5):
            s.add("dev1", lat=float(i), lng=0.0, place_type=f"p{i}")
        rows = s.recent("dev1", limit=3)
        assert len(rows) == 3
        # ən yeni əvvəldə (p4 sonuncu əlavə edildi)
        assert rows[0]["place_type"] == "p4"


class TestPlaceSummary:
    def test_empty_device_returns_empty(self):
        s = _store()
        assert s.place_summary("nobody") == []

    def test_aggregates_by_place_type(self):
        s = _store()
        s.add("dev1", lat=1.0, lng=1.0, place_type="cafe", pack_id="cafe")
        s.add("dev1", lat=1.0, lng=1.0, place_type="cafe", pack_id="cafe")
        s.add("dev1", lat=2.0, lng=2.0, place_type="market", pack_id="market")
        summary = {r["place_type"]: r for r in s.place_summary("dev1")}
        assert summary["cafe"]["count"] == 2
        assert summary["market"]["count"] == 1
        assert summary["cafe"]["pack_id"] == "cafe"
        assert summary["cafe"]["last_seen"]

    def test_summary_sorted_by_count_desc(self):
        s = _store()
        s.add("dev1", lat=1.0, lng=1.0, place_type="rare")
        for _ in range(3):
            s.add("dev1", lat=2.0, lng=2.0, place_type="common")
        rows = s.place_summary("dev1")
        assert rows[0]["place_type"] == "common"
        assert rows[0]["count"] == 3
