"""AI provayder qatı — prompt-u mətnə çevirən `completer` qaytarır.

Keyfiyyət sırası ilə avtomatik seçim: Anthropic (Claude) → Groq → OpenAI.
Provayderi `GEN_PROVIDER`, modeli `GEN_MODEL` env ilə override etmək olar.
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
    "openai": "gpt-4o-mini",
}


def load_env() -> None:
    load_dotenv(_ENV_PATH)


def _pick_provider() -> str:
    explicit = os.environ.get("GEN_PROVIDER")
    if explicit:
        return explicit.lower()
    if os.environ.get("ANTHROPIC_API_KEY"):
        return "anthropic"
    if os.environ.get("GROQ_API_KEY"):
        return "groq"
    if os.environ.get("OPENAI_API_KEY"):
        return "openai"
    raise SystemExit(
        "Heç bir API açarı tapılmadı. content_gen/.env faylına "
        "ANTHROPIC_API_KEY (tövsiyə), GROQ_API_KEY və ya OPENAI_API_KEY əlavə edin."
    )


def describe() -> str:
    provider = _pick_provider()
    model = os.environ.get("GEN_MODEL", DEFAULT_MODELS[provider])
    return f"{provider} / {model}"


def get_completer() -> Completer:
    """Mövcud açara görə uyğun provayderin completer-ini qur."""
    load_env()
    provider = _pick_provider()
    model = os.environ.get("GEN_MODEL", DEFAULT_MODELS.get(provider, ""))
    if provider == "anthropic":
        return _anthropic_completer(model)
    if provider == "groq":
        return _groq_completer(model)
    if provider == "openai":
        return _openai_completer(model)
    raise SystemExit(f"Naməlum provayder: {provider}")


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
