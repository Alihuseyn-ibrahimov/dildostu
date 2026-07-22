import pytest

from dildostu_server.providers import AllProvidersFailed, complete_with_fallback


def test_first_provider_used_when_ok():
    calls = []
    completers = {
        "groq": lambda s, u: calls.append("groq") or "groq-cavab",
        "claude": lambda s, u: calls.append("claude") or "claude-cavab",
    }
    out = complete_with_fallback("sys", "usr", ["groq", "claude"], completers)
    assert out == "groq-cavab"
    assert calls == ["groq"]  # claude çağırılmadı


def test_falls_back_when_first_fails():
    def failing(s, u):
        raise RuntimeError("429 limit")

    completers = {
        "groq": failing,
        "claude": lambda s, u: "claude-cavab",
    }
    out = complete_with_fallback("sys", "usr", ["groq", "claude"], completers)
    assert out == "claude-cavab"


def test_raises_when_all_fail():
    def failing(s, u):
        raise RuntimeError("xəta")

    completers = {"groq": failing, "claude": failing}
    with pytest.raises(AllProvidersFailed):
        complete_with_fallback("sys", "usr", ["groq", "claude"], completers)


def test_skips_missing_provider():
    # order-da olan amma completers-də olmayan provayder ötürülür
    completers = {"claude": lambda s, u: "claude-cavab"}
    out = complete_with_fallback("sys", "usr", ["groq", "claude"], completers)
    assert out == "claude-cavab"
