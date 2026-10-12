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


# --- Groq modeli (llama-3.3-70b-versatile Groq-dan çıxarılıb → 404 model_not_found) ---

class _FakeGroq:
    """groq modulunun əvəzi: create() çağırışının arqumentlərini saxlayır."""

    def __init__(self):
        self.calls = []
        fake = self

        class _Completions:
            def create(self, **kw):
                fake.calls.append(kw)
                msg = type("M", (), {"content": "{}"})()
                return type("R", (), {"choices": [type("C", (), {"message": msg})()]})()

        class Groq:
            def __init__(self, api_key):
                self.chat = type("Chat", (), {"completions": _Completions()})()

        self.Groq = Groq


def _fake_groq(monkeypatch):
    import sys

    fake = _FakeGroq()
    monkeypatch.setitem(sys.modules, "groq", fake)
    monkeypatch.setenv("GROQ_API_KEY", "test")
    return fake


def test_default_groq_model_is_not_retired_llama():
    from dildostu_server import providers

    assert "llama-3.3-70b-versatile" not in providers.DEFAULT_GROQ_MODEL
    assert providers.DEFAULT_GROQ_MODEL == "openai/gpt-oss-120b"


def test_reasoning_model_gets_low_effort_via_extra_body(monkeypatch):
    # extra_body: köhnə groq SDK-sı da qəbul edir (yeni kwarg TypeError verib səssizcə Claude-a keçərdi)
    from dildostu_server import providers

    fake = _fake_groq(monkeypatch)
    providers._groq_completer("openai/gpt-oss-120b")("sys", "usr")
    providers._groq_chat_completer("openai/gpt-oss-120b")("sys", [{"role": "user", "content": "x"}])
    assert all(c["extra_body"] == {"reasoning_effort": "low"} for c in fake.calls)
    assert fake.calls[0]["response_format"] == {"type": "json_object"}


def test_non_reasoning_model_gets_no_reasoning_param(monkeypatch):
    from dildostu_server import providers

    fake = _fake_groq(monkeypatch)
    providers._groq_completer("llama-3.1-8b-instant")("sys", "usr")
    assert "extra_body" not in fake.calls[0]
