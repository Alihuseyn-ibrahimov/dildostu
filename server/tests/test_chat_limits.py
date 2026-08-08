"""Gündəlik söhbət limiti — kvota qoruması (bax `chat_limits.py`)."""

from datetime import datetime, timedelta, timezone

from dildostu_server.chat_limits import (
    DEFAULT_DAILY_MESSAGE_LIMIT,
    check_quota,
    daily_message_limit,
    quota_message,
)
from dildostu_server.memory_store import MemoryStore


def _store() -> MemoryStore:
    return MemoryStore(":memory:")


class TestDailyLimitConfig:
    def test_default_when_env_missing(self, monkeypatch):
        monkeypatch.delenv("CHAT_DAILY_LIMIT", raising=False)
        assert daily_message_limit() == DEFAULT_DAILY_MESSAGE_LIMIT

    def test_env_override(self, monkeypatch):
        monkeypatch.setenv("CHAT_DAILY_LIMIT", "5")
        assert daily_message_limit() == 5

    def test_invalid_env_falls_back(self, monkeypatch):
        monkeypatch.setenv("CHAT_DAILY_LIMIT", "abc")
        assert daily_message_limit() == DEFAULT_DAILY_MESSAGE_LIMIT

    def test_zero_or_negative_falls_back(self, monkeypatch):
        monkeypatch.setenv("CHAT_DAILY_LIMIT", "0")
        assert daily_message_limit() == DEFAULT_DAILY_MESSAGE_LIMIT


class TestCheckQuota:
    def test_no_messages_not_exceeded(self, monkeypatch):
        monkeypatch.setenv("CHAT_DAILY_LIMIT", "3")
        status = check_quota(_store(), 1)
        assert status.used == 0
        assert status.remaining == 3
        assert not status.exceeded

    def test_counts_only_user_messages(self, monkeypatch):
        monkeypatch.setenv("CHAT_DAILY_LIMIT", "3")
        s = _store()
        s.add_message(1, "user", "salam")
        s.add_message(1, "assistant", "cavab")
        assert check_quota(s, 1).used == 1

    def test_exceeded_when_limit_reached(self, monkeypatch):
        monkeypatch.setenv("CHAT_DAILY_LIMIT", "2")
        s = _store()
        s.add_message(1, "user", "bir")
        s.add_message(1, "user", "iki")
        status = check_quota(s, 1)
        assert status.exceeded
        assert status.remaining == 0

    def test_scoped_per_user(self, monkeypatch):
        monkeypatch.setenv("CHAT_DAILY_LIMIT", "1")
        s = _store()
        s.add_message(1, "user", "salam")
        assert check_quota(s, 1).exceeded
        assert not check_quota(s, 2).exceeded

    def test_old_messages_outside_window_not_counted(self, monkeypatch):
        monkeypatch.setenv("CHAT_DAILY_LIMIT", "1")
        s = _store()
        s.add_message(1, "user", "köhnə")
        # 25 saat sonrakı ana baxsaq köhnə mesaj pəncərədən çıxır.
        future = datetime.now(timezone.utc) + timedelta(hours=25)
        assert not check_quota(s, 1, now=future).exceeded


class TestQuotaMessage:
    def test_message_is_azerbaijani_and_mentions_limit(self, monkeypatch):
        monkeypatch.setenv("CHAT_DAILY_LIMIT", "7")
        text = quota_message(check_quota(_store(), 1))
        assert "limit" in text.lower()
        assert "7" in text
