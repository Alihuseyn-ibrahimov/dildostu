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

# Dəstəklənən öyrənilən dillər — kod → İngilis dilində ad (prompt üçün).
# Yeni dil əlavə etmək üçün buraya bir sətir kifayətdir.
LANGUAGES: dict[str, str] = {
    "en": "English", "ru": "Russian", "es": "Spanish", "it": "Italian",
}

TARGET_LANG = "en"  # geriyə uyğunluq üçün saxlanır (mövcud importlar)
UI_LANG = "az"
TARGET_LANG_NAME = "English"  # geriyə uyğunluq üçün saxlanır
UI_LANG_NAME = "Azerbaijani"
SYSTEM_PROMPT = "You output only valid JSON. No commentary."
WORDS_PER_PACK = 12

# Hər dilin öz alt-qovluğu (bax pubspec.yaml — Flutter asset bəyanı
# rekursiv deyil, hər qovluq ayrıca sətir tələb edir).
PACKS_ROOT_DIR = Path(__file__).resolve().parents[2] / "app" / "assets" / "packs"


# Skript xəbərdarlığı — modellər (xüsusən Groq/Llama) dil adı verilsə də
# tərcüməni LATIN HƏRFLƏRLƏ transliterasiya edə bilir (məs. "kofe" yerinə
# "кофе") və ya başqa dilin sözünü qarışdıra bilir ("kak mucho" kimi rus+
# ispan qarışığı). 2026-08-04-də real generasiyada tutuldu — hər dil üçün
# açıq skript təlimatı MƏCBURİDİR.
_SCRIPT_NOTE = {
    "en": "Use standard English spelling.",
    "ru": (
        "Write EVERY Russian word/example in CYRILLIC SCRIPT (е.g. привет, "
        "кофе) — NEVER romanize/transliterate into Latin letters, and never "
        "mix in words from any other language."
    ),
    "es": "Use standard Spanish spelling, including accents (á, é, í, ó, ú, ñ).",
    "it": "Use standard Italian spelling, including accents (à, è, ì, ò, ù).",
}


def build_prompt(
    category: Category, n_words: int = WORDS_PER_PACK, lang: str = "en"
) -> str:
    """Modelə situasiyaya uyğun söz siyahısı sifariş edən prompt qur."""
    lang_name = LANGUAGES[lang]
    script_note = _SCRIPT_NOTE.get(lang, "")
    return (
        f"You are helping build a travel language-learning app for "
        f"{UI_LANG_NAME} speakers who are learning {lang_name}.\n\n"
        f"Situation / category: \"{category.title_az}\" — {category.context_hint}\n\n"
        f"Produce exactly {n_words} of the most useful {lang_name} words or "
        f"short phrases a traveller would really need in this situation.\n\n"
        "For each item provide:\n"
        f"- \"word\": the {lang_name} word or short phrase (lowercase unless a proper noun)\n"
        f"- \"translation_az\": a natural {UI_LANG_NAME} translation\n"
        "- \"ipa\": IPA pronunciation in slashes, e.g. /rɪˈsiːt/\n"
        f"- \"example\": one short natural {lang_name} sentence using the word\n"
        f"- \"example_az\": the {UI_LANG_NAME} translation of that sentence\n"
        f"- \"level\": difficulty from {LEVEL_MIN} (very common) to {LEVEL_MAX} (advanced)\n\n"
        f"Rules: no duplicate words. Keep phrases short and practical. {script_note} "
        "Example sentences must start with a capital letter and end with proper "
        "punctuation (. or ?). "
        "Azerbaijani must use correct spelling (ə, ı, ö, ü, ğ, ç, ş).\n\n"
        'Return ONLY a JSON object of the form {"words": [ ... ]} with no extra text.'
    )


def parse_response(text: str, category: Category, lang: str = "en") -> dict:
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
        "target_lang": lang,
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


def generate_pack(
    category: Category,
    completer=None,
    n_words: int = WORDS_PER_PACK,
    lang: str = "en",
) -> dict:
    """Bir kateqoriya üçün paketi AI-dan al və doğrulanmış dict qaytar.

    `completer` — providers.get_completer()-dən gələn (system, user)->text
    çağırışı; testdə mock ötürülür.
    """
    completer = completer or get_completer()
    text = completer(SYSTEM_PROMPT, build_prompt(category, n_words, lang))
    return parse_response(text, category, lang)


def _write_pack(pack: dict, lang: str) -> Path:
    out_dir = PACKS_ROOT_DIR / lang
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{pack['pack_id']}.json"
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
    parser.add_argument("--lang", default="en", choices=sorted(LANGUAGES))
    args = parser.parse_args(argv)

    targets = [by_id(pid) for pid in args.pack_ids] if args.pack_ids else list(CATEGORIES)
    load_env()
    completer = get_completer()
    print(f"Provayder: {describe()}  |  Dil: {LANGUAGES[args.lang]} ({args.lang})")

    failures = 0
    for category in targets:
        try:
            pack = generate_pack(category, completer, args.words, args.lang)
            path = _write_pack(pack, args.lang)
            print(f"OK  {category.pack_id:12} {len(pack['words'])} söz → {args.lang}/{path.name}")
        except Exception as exc:  # noqa: BLE001 — toplu işdə birini uğursuzluq digərini dayandırmasın
            failures += 1
            print(f"XƏTA {category.pack_id:12} {exc}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
