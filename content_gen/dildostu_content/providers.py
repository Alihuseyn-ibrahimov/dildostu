"""AI provayder qatı — prompt-u mətnə çevirən `completer` qaytarır.

Keyfiyyət sırası ilə avtomatik seçim: Anthropic (Claude) → Groq → Gemini →
OpenAI. Mövcud açarı olan HAMISI zəncirə düşür — bir provayder kvota/rate
limit xətası atsa (məs. Groq-un 100K TPD limiti, bax dildostu/CLAUDE.md),
completer avtomatik növbətiyə keçir, generasiya dayanmır.
Provayderi `GEN_PROVIDER`, modeli `GEN_MODEL` env ilə override etmək olar
(bu halda YALNIZ o provayder işlənir, fallback yoxdur).
Bütün açarlar `.env` faylından (content_gen kökü) yüklənir.

Bu qat şəbəkəyə toxunur, ona görə testlərdə mock completer ötürülür;
generatorun bütün məntiqi (prompt/parse) təmiz funksiyalardadır.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Callable

from dotenv import load_dotenv

Completer = Callable[[str, str], str]  # (system, user_prompt) -> text

_ENV_PATH = Path(__file__).resolve().parents[1] / ".env"

# Hər provayder üçün standart model (env GEN_MODEL üstün gəlir).
DEFAULT_MODELS = {
    "anthropic": "claude-sonnet-5",
    "groq": "llama-3.3-70b-versatile",
    "gemini": "gemini-2.5-flash",
    "openai": "gpt-4o-mini",
}

# Avtomatik fallback zənciri sırası (keyfiyyət/qiymətə görə).
_FALLBACK_ORDER = ["anthropic", "groq", "gemini", "openai"]

_ENV_KEYS = {
    "anthropic": "ANTHROPIC_API_KEY",
    "groq": "GROQ_API_KEY",
    "gemini": "GEMINI_API_KEY",
    "openai": "OPENAI_API_KEY",
}


def load_env() -> None:
    load_dotenv(_ENV_PATH)


def _available_providers() -> list[str]:
    explicit = os.environ.get("GEN_PROVIDER")
    if explicit:
        return [explicit.lower()]
    available = [p for p in _FALLBACK_ORDER if os.environ.get(_ENV_KEYS[p])]
    if not available:
        raise SystemExit(
            "Heç bir API açarı tapılmadı. content_gen/.env faylına "
            "ANTHROPIC_API_KEY (tövsiyə), GROQ_API_KEY, GEMINI_API_KEY və ya "
            "OPENAI_API_KEY əlavə edin."
        )
    return available


def _pick_provider() -> str:
    return _available_providers()[0]


def describe() -> str:
    providers = _available_providers()
    parts = [f"{p}/{os.environ.get('GEN_MODEL', DEFAULT_MODELS[p])}" for p in providers]
    return " → ".join(parts)


def _build_completer(provider: str) -> Completer:
    model = os.environ.get("GEN_MODEL", DEFAULT_MODELS.get(provider, ""))
    if provider == "anthropic":
        return _anthropic_completer(model)
    if provider == "groq":
        return _groq_completer(model)
    if provider == "gemini":
        return _gemini_completer(model)
    if provider == "openai":
        return _openai_completer(model)
    raise SystemExit(f"Naməlum provayder: {provider}")


def get_completer() -> Completer:
    """Mövcud açarlara görə fallback zənciri quran completer qaytarır.

    Zəncirdəki hər provayder növbə ilə sınanır; biri istisna atsa (rate
    limit, şəbəkə xətası və s.) avtomatik növbətiyə keçilir. Hamısı
    uğursuz olsa sonuncu xəta yenidən atılır.
    """
    load_env()
    providers = _available_providers()
    completers = [(p, _build_completer(p)) for p in providers]

    def complete(system: str, user: str) -> str:
        last_exc: Exception | None = None
        for name, completer in completers:
            try:
                return completer(system, user)
            except Exception as exc:  # noqa: BLE001 — fallback üçün geniş tutuş
                last_exc = exc
                if len(completers) > 1:
                    print(f"  [{name} uğursuz, növbətiyə keçir: {exc}]")
        assert last_exc is not None
        raise last_exc

    return complete


def _anthropic_completer(model: str) -> Completer:
    import anthropic

    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

    def complete(system: str, user: str) -> str:
        resp = client.messages.create(
            model=model,
            max_tokens=2048,
            temperature=0.4,
            system=system,
            messages=[{"role": "user", "content": user}],
        )
        return "".join(block.text for block in resp.content if block.type == "text")

    return complete


def _groq_completer(model: str) -> Completer:
    import groq

    client = groq.Groq(api_key=os.environ["GROQ_API_KEY"])

    def complete(system: str, user: str) -> str:
        resp = client.chat.completions.create(
            model=model,
            temperature=0.4,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        )
        return resp.choices[0].message.content

    return complete


def _gemini_completer(model: str) -> Completer:
    from google import genai
    from google.genai import types

    client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])

    def complete(system: str, user: str) -> str:
        resp = client.models.generate_content(
            model=model,
            contents=user,
            config=types.GenerateContentConfig(
                system_instruction=system,
                temperature=0.4,
                response_mime_type="application/json",
            ),
        )
        return resp.text

    return complete


def _openai_completer(model: str) -> Completer:
    import openai

    client = openai.OpenAI(api_key=os.environ["OPENAI_API_KEY"])

    def complete(system: str, user: str) -> str:
        resp = client.chat.completions.create(
            model=model,
            temperature=0.4,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        )
        return resp.choices[0].message.content

    return complete
