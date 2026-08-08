"""MemoryStore (SQLite) — çat tarixçəsi + fakt saxlama testləri."""

from dildostu_server.memory_store import MemoryStore


def _store() -> MemoryStore:
    # :memory: — hər test təmiz başlayır.
    return MemoryStore(":memory:")


class TestMessages:
    def test_add_then_recent_returns_it(self):
        s = _store()
        s.add_message(1, "user", "salam")
        rows = s.recent_messages(1)
        assert len(rows) == 1
        assert rows[0]["role"] == "user"
        assert rows[0]["content"] == "salam"
        assert rows[0]["created_at"]

    def test_messages_scoped_by_user(self):
        s = _store()
        s.add_message(1, "user", "salam")
        s.add_message(2, "user", "hola")
        assert [m["content"] for m in s.recent_messages(1)] == ["salam"]
        assert [m["content"] for m in s.recent_messages(2)] == ["hola"]

    def test_messages_returned_in_chronological_order(self):
        s = _store()
        s.add_message(1, "user", "birinci")
        s.add_message(1, "assistant", "ikinci")
        s.add_message(1, "user", "üçüncü")
        contents = [m["content"] for m in s.recent_messages(1)]
        assert contents == ["birinci", "ikinci", "üçüncü"]

    def test_limit_keeps_most_recent_in_order(self):
        s = _store()
        for i in range(5):
            s.add_message(1, "user", f"mesaj{i}")
        contents = [m["content"] for m in s.recent_messages(1, limit=3)]
        assert contents == ["mesaj2", "mesaj3", "mesaj4"]

    def test_no_messages_returns_empty(self):
        assert _store().recent_messages(1) == []


class TestFacts:
    def test_add_then_recent_returns_it(self):
        s = _store()
        s.add_fact(1, "Adı Elvin")
        assert s.recent_facts(1) == ["Adı Elvin"]

    def test_facts_scoped_by_user(self):
        s = _store()
        s.add_fact(1, "fakt1")
        s.add_fact(2, "fakt2")
        assert s.recent_facts(1) == ["fakt1"]
        assert s.recent_facts(2) == ["fakt2"]

    def test_facts_returned_in_chronological_order(self):
        s = _store()
        s.add_fact(1, "birinci")
        s.add_fact(1, "ikinci")
        assert s.recent_facts(1) == ["birinci", "ikinci"]

    def test_limit_keeps_most_recent_in_order(self):
        s = _store()
        for i in range(25):
            s.add_fact(1, f"fakt{i}")
        facts = s.recent_facts(1, limit=20)
        assert len(facts) == 20
        assert facts[0] == "fakt5"
        assert facts[-1] == "fakt24"

    def test_no_facts_returns_empty(self):
        assert _store().recent_facts(1) == []

    def test_duplicate_fact_not_inserted(self):
        s = _store()
        assert s.add_fact(1, "Hobbi: foto") is True
        assert s.add_fact(1, "hobbi: foto") is False
        assert s.recent_facts(1) == ["Hobbi: foto"]

    def test_default_limit_is_forty(self):
        s = _store()
        for i in range(45):
            s.add_fact(1, f"fakt{i}")
        facts = s.recent_facts(1)
        assert len(facts) == 40
        assert facts[0] == "fakt5"
        assert facts[-1] == "fakt44"


class TestDeleteUserData:
    def test_deletes_messages_and_facts(self):
        s = _store()
        s.add_message(1, "user", "salam")
        s.add_fact(1, "Adı Elvin")
        s.delete_user_data(1)
        assert s.recent_messages(1) == []
        assert s.recent_facts(1) == []

    def test_does_not_touch_other_users(self):
        s = _store()
        s.add_message(1, "user", "salam")
        s.add_fact(1, "fakt1")
        s.add_message(2, "user", "hola")
        s.add_fact(2, "fakt2")
        s.delete_user_data(1)
        assert s.recent_messages(2) != []
        assert s.recent_facts(2) != []
