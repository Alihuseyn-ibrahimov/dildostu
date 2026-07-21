"""Söz paketlərini Groq (Llama) ilə generasiya edən skript.

İşlətmə::

    GROQ_API_KEY=... python -m dildostu_content.generate            # bütün paketlər
    GROQ_API_KEY=... python -m dildostu_content.generate cafe hotel # seçilmişlər

Çıxış: ../app/assets/packs/<pack_id>.json (spec §3.1 formatında, doğrulanmış).

Şəbəkə çağırışı (`generate_pack`) nazik saxlanılır; bütün məntiq — prompt qurma
və cavab parsinqi — təmiz funksiyalardadır ki, şəbəkəsiz test oluna bilsin.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

from .categories import CATEGORIES, Category, by_id
from .providers import describe, get_completer, load_env
from .schema import LEVEL_MAX, LEVEL_MIN, validate_pack

TARGET_LANG = "en"
UI_LANG = "az"
TARGET_LANG_NAME = "English"
UI_LANG_NAME = "Azerbaijani"
SYSTEM_PROMPT = "You output only valid JSON. No commentary."
WORDS_PER_PACK = 12

PACKS_DIR = Path(__file__).resolve().parents[2] / "app" / "assets" / "packs"


def build_prompt(category: Category, n_words: int = WORDS_PER_PACK) -> str:
    """Modelə situasiyaya uyğun söz siyahısı sifariş edən prompt qur."""
    return (
        f"You are helping build a travel language-learning app for "
        f"{UI_LANG_NAME} speakers who are learning {TARGET_LANG_NAME}.\n\n"
        f"Situation / category: \"{category.title_az}\" — {category.context_hint}\n\n"
        f"Produce exactly {n_words} of the most useful {TARGET_LANG_NAME} words or "
        f"short phrases a traveller would really need in this situation.\n\n"
        "For each item provide:\n"
        f"- \"word\": the {TARGET_LANG_NAME} word or short phrase (lowercase unless a proper noun)\n"
        f"- \"translation_az\": a natural {UI_LANG_NAME} translation\n"
        "- \"ipa\": IPA pronunciation in slashes, e.g. /rɪˈsiːt/\n"
        f"- \"example\": one short natural {TARGET_LANG_NAME} sentence using the word\n"
        f"- \"example_az\": the {UI_LANG_NAME} translation of that sentence\n"
        f"- \"level\": difficulty from {LEVEL_MIN} (very common) to {LEVEL_MAX} (advanced)\n\n"
        "Rules: no duplicate words. Keep phrases short and practical. "
        "Example sentences must start with a capital letter and end with proper "
        "punctuation (. or ?). "
        "Azerbaijani must use correct spelling (ə, ı, ö, ü, ğ, ç, ş).\n\n"
        'Return ONLY a JSON object of the form {"words": [ ... ]} with no extra text.'
    )


def parse_response(text: str, category: Category) -> dict:
    """Model cavabından JSON çıxar, tam paketə çevir və doğrula.

    ```json fence-ləri, ətrafdakı mətn, həm {"words": [...]} obyekti, həm də
    birbaşa massiv formatları qəbul edilir. Uğursuz JSON → ValueError;
    sxem/semantik problem → ValidationError (schema modulundan).
    """
    payload = _extract_json(text)
    if isinstance(payload, dict):
        words = payload.get("words", payload)
    else:
        words = payload
    if not isinstance(words, list):
        raise ValueError(f"[{category.pack_id}] cavabda söz massivi tapılmadı")

    pack = {
        "pack_id": category.pack_id,
        "target_lang": TARGET_LANG,
        "ui_lang": UI_LANG,
        "title_az": category.title_az,
        "words": words,
    }
    validate_pack(pack)
    return pack


def _extract_json(text: str):
    """Sərbəst mətndən ilk JSON obyekt və ya massivini çıxarıb yüklə."""
    fenced = re.search(r"```(?:json)?\s*(.+?)```", text, re.DOTALL)
    candidate = fenced.group(1) if fenced else text

    start = _first_json_start(candidate)
    if start is None:
        raise ValueError("Cavabda JSON tapılmadı")
    closer = "}" if candidate[start] == "{" else "]"
    end = candidate.rfind(closer)
    if end == -1 or end < start:
        raise ValueError("Cavabda tam JSON tapılmadı")
    snippet = candidate[start : end + 1]
    try:
        return json.loads(snippet)
    except json.JSONDecodeError as exc:
        raise ValueError(f"JSON parse xətası: {exc}") from exc


def _first_json_start(text: str):
    positions = [p for p in (text.find("{"), text.find("[")) if p != -1]
    return min(positions) if positions else None


def generate_pack(category: Category, completer=None, n_words: int = WORDS_PER_PACK) -> dict:
    """Bir kateqoriya üçün paketi AI-dan al və doğrulanmış dict qaytar.

    `completer` — providers.get_completer()-dən gələn (system, user)->text
    çağırışı; testdə mock ötürülür.
    """
    completer = completer or get_completer()
    text = completer(SYSTEM_PROMPT, build_prompt(category, n_words))
    return parse_response(text, category)


def _write_pack(pack: dict) -> Path:
    PACKS_DIR.mkdir(parents=True, exist_ok=True)
    path = PACKS_DIR / f"{pack['pack_id']}.json"
    path.write_text(
        json.dumps(pack, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return path


def main(argv: list[str] | None = None) -> int:
    # Windows konsolu standart cp1252-dir; AZ hərfləri və oxları çıxara bilmək üçün.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError):
            pass

    parser = argparse.ArgumentParser(description="DilDostu söz paketi generatoru")
    parser.add_argument("pack_ids", nargs="*", help="Boş buraxsan hamısı generasiya olunur")
    parser.add_argument("--words", type=int, default=WORDS_PER_PACK)
    args = parser.parse_args(argv)

    targets = [by_id(pid) for pid in args.pack_ids] if args.pack_ids else list(CATEGORIES)
    load_env()
    completer = get_completer()
    print(f"Provayder: {describe()}")

    failures = 0
    for category in targets:
        try:
            pack = generate_pack(category, completer, args.words)
            path = _write_pack(pack)
            print(f"OK  {category.pack_id:12} {len(pack['words'])} söz → {path.name}")
        except Exception as exc:  # noqa: BLE001 — toplu işdə birini uğursuzluq digərini dayandırmasın
            failures += 1
            print(f"XƏTA {category.pack_id:12} {exc}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
