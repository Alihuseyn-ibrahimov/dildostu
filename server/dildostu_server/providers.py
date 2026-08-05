"""AI provayder qatı — Groq/Claude completer-ləri və fallback məntiqi.

`complete_with_fallback` təmiz məntiqdir (mock completer ilə test olunur);
faktiki şəbəkə completer-ləri `build_completers()`-dədir.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Callable

from dotenv import load_dotenv

Completer = Callable[[str, str], str]  # (system, user) -> text
ChatCompleter = Callable[[str, list], str]  # (system, messages) -> text

GROQ_MODEL = os.environ.get("GROQ_MODEL", "llama-3.3-70b-versatile")
CLAUDE_MODEL = os.environ.get("CLAUDE_MODEL", "claude-sonnet-5")
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")

_ENV_PATH = Path(__file__).resolve().parents[1] / ".env"


class AllProvidersFailed(Exception):
    """Sıradakı bütün provayderlər uğursuz oldu."""


def complete_with_fallback(
    system: str,
    user: str,
    order: list[str],
    completers: dict[str, Completer],
) -> str:
    """`order` sırası ilə provayderləri sına; ilk uğurlu cavabı qaytar.

    Provayder yoxdursa və ya istisna atarsa növbətiyə keç. Hamısı uğursuzsa
    AllProvidersFailed at.
    """
    errors: list[str] = []
    for name in order:
        completer = completers.get(name)
        if completer is None:
            continue
        try:
            return completer(system, user)
        except Exception as exc:  # noqa: BLE001 — fallback üçün geniş tutuş
            errors.append(f"{name}: {exc}")
    raise AllProvidersFailed("; ".join(errors) or "provayder yoxdur")


def chat_with_fallback(
    system: str,
    messages: list,
    order: list[str],
    completers: dict[str, ChatCompleter],
) -> str:
    """Çoxnövbəli söhbət üçün fallback — `order` sırası ilə provayderləri sına."""
    errors: list[str] = []
    for name in order:
        completer = completers.get(name)
        if completer is None:
            continue
        try:
            return completer(system, messages)
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{name}: {exc}")
    raise AllProvidersFailed("; ".join(errors) or "provayder yoxdur")


def build_chat_completers() -> dict[str, ChatCompleter]:
    """Söhbət (messages massivi) üçün Groq/Claude/Gemini completer-ləri."""
    load_dotenv(_ENV_PATH)
    completers: dict[str, ChatCompleter] = {}
    if os.environ.get("GROQ_API_KEY"):
        completers["groq"] = _groq_chat_completer(GROQ_MODEL)
    if os.environ.get("ANTHROPIC_API_KEY"):
        completers["claude"] = _claude_chat_completer(CLAUDE_MODEL)
    if os.environ.get("GEMINI_API_KEY"):
        completers["gemini"] = _gemini_chat_completer(GEMINI_MODEL)
    return completers


def _groq_chat_completer(model: str) -> ChatCompleter:
    import groq

    client = groq.Groq(api_key=os.environ["GROQ_API_KEY"])

    def complete(system: str, messages: list) -> str:
        resp = client.chat.completions.create(
            model=model,
            temperature=0.6,
            messages=[{"role": "system", "content": system}, *messages],
        )
        return resp.choices[0].message.content

    return complete


def _claude_chat_completer(model: str) -> ChatCompleter:
    import anthropic

    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

    def complete(system: str, messages: list) -> str:
        resp = client.messages.create(
            model=model,
            max_tokens=1024,
            temperature=0.6,
            system=system,
            messages=messages,
        )
        return "".join(b.text for b in resp.content if b.type == "text")

    return complete


def _gemini_chat_completer(model: str) -> ChatCompleter:
    from google import genai
    from google.genai import types

    client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])

    def complete(system: str, messages: list) -> str:
        # Gemini-nin "contents" formatı fərqlidir: "assistant" yox "model"
        # rolu gözlənilir, "content" sahəsi yox "parts" massivi.
        contents = [
            {
                "role": "model" if m["role"] == "assistant" else m["role"],
                "parts": [{"text": m["content"]}],
            }
            for m in messages
        ]
        resp = client.models.generate_content(
            model=model,
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=system, temperature=0.6
            ),
        )
        return resp.text

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
                temperature=0.5,
                response_mime_type="application/json",
            ),
        )
        return resp.text

    return complete


def build_completers() -> dict[str, Completer]:
    """Mövcud API açarlarına görə Groq/Claude/Gemini completer-lərini qur (şəbəkə)."""
    load_dotenv(_ENV_PATH)
    completers: dict[str, Completer] = {}
    if os.environ.get("GROQ_API_KEY"):
        completers["groq"] = _groq_completer(GROQ_MODEL)
    if os.environ.get("ANTHROPIC_API_KEY"):
        completers["claude"] = _claude_completer(CLAUDE_MODEL)
    if os.environ.get("GEMINI_API_KEY"):
        completers["gemini"] = _gemini_completer(GEMINI_MODEL)
    return completers


def _groq_completer(model: str) -> Completer:
    import groq

    client = groq.Groq(api_key=os.environ["GROQ_API_KEY"])

    def complete(system: str, user: str) -> str:
        resp = client.chat.completions.create(
            model=model,
            temperature=0.5,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
        )
        return resp.choices[0].message.content

    return complete


def _claude_completer(model: str) -> Completer:
    import anthropic

    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

    def complete(system: str, user: str) -> str:
        resp = client.messages.create(
            model=model,
            max_tokens=2048,
            temperature=0.5,
            system=system,
            messages=[{"role": "user", "content": user}],
        )
        return "".join(b.text for b in resp.content if b.type == "text")

    return complete
