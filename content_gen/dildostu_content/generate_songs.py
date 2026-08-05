"""Musiqi bölməsi üçün mahnı generatoru — İKİ ADDIMLI, insan-in-the-loop.

İşlətmə (content_gen qovluğundan)::

    # 1) AI mahnı TƏKLİF edir (YouTube ID YOXDUR):
    GROQ_API_KEY=... python -m dildostu_content.generate_songs suggest --lang en
        → songs_source/en.suggested.json

    # 2) İnsan hər təklif üçün YouTube linkini əlavə edib
    #    songs_source/en.json-a köçürür (əl ilə, kod xaricində).

    # 3) AI təsdiqlənmiş mahnı üçün tam sözlər + tərcümə doldurur:
    GROQ_API_KEY=... python -m dildostu_content.generate_songs fill-lyrics --lang en
        → songs_out/songs.json

Çıxış formatı və hüquqi qeyd üçün bax:
docs/superpowers/specs/2026-08-05-dildostu-music-section-design.md
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .audiobooks import slugify
from .generate import LANGUAGES, UI_LANG_NAME
from .providers import describe, get_completer, load_env
from .songs import (
    Song,
    SongCandidate,
    SongLine,
    build_lyrics_prompt,
    build_suggest_prompt,
    parse_lyrics_response,
    parse_suggest_response,
    validate_confirmed_songs,
)

SYSTEM_PROMPT = "You output only valid JSON. No commentary."
PER_LEVEL_DEFAULT = 3

SOURCE_DIR = Path(__file__).resolve().parents[1] / "songs_source"
OUT_DIR = Path(__file__).resolve().parents[1] / "songs_out"


def _reconfigure_utf8() -> None:
    # Windows konsolu standart cp1252-dir; AZ hərfləri çıxara bilmək üçün.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError):
            pass


def _cmd_suggest(args: argparse.Namespace) -> int:
    lang_name = LANGUAGES[args.lang]
    completer = get_completer()
    print(f"Provayder: {describe()}  |  Dil: {lang_name} ({args.lang})")

    prompt = build_suggest_prompt(lang_name, args.per_level)
    text = completer(SYSTEM_PROMPT, prompt)
    try:
        candidates = parse_suggest_response(text)
    except ValueError as exc:
        print(f"XƏTA: {exc}", file=sys.stderr)
        return 1

    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    out_path = SOURCE_DIR / f"{args.lang}.suggested.json"
    payload = [
        {"title": c.title, "artist": c.artist, "level": c.level, "youtube_id": ""}
        for c in candidates
    ]
    out_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"OK  {len(candidates)} mahnı təklifi → {out_path.name}")
    print(
        "Növbəti addım: hər mahnı üçün \"youtube_id\" sahəsini doldurub "
        f"{args.lang}.json adı ilə saxla (bax generate_songs.py modul qeydi)."
    )
    return 0


def _load_confirmed(path: Path) -> list[dict]:
    items = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(items, list):
        raise ValueError(f"{path}: siyahı gözlənilirdi")
    validate_confirmed_songs(items)
    return items


def _cmd_fill_lyrics(args: argparse.Namespace) -> int:
    lang_name = LANGUAGES[args.lang]
    source_path = Path(args.source) if args.source else SOURCE_DIR / f"{args.lang}.json"
    if not source_path.exists():
        print(
            f"XƏTA: {source_path} tapılmadı — əvvəlcə \"suggest\" işlədib "
            "YouTube linklərini təsdiqlə.",
            file=sys.stderr,
        )
        return 1

    try:
        confirmed = _load_confirmed(source_path)
    except ValueError as exc:
        print(f"XƏTA: {exc}", file=sys.stderr)
        return 1

    completer = get_completer()
    print(f"Provayder: {describe()}  |  Dil: {lang_name} ({args.lang})")

    # Əvvəlki qaçışdan uğurlu mahnılar varsa saxla — kvota tükənəndə
    # (bax 2026-08-05 tapıntısı) təkrar işlədəndə onları YENİDƏN
    # generasiya edib kvota israf etməyək, yalnız çatışmayanları tamamla.
    out_path = OUT_DIR / "songs.json"
    existing_ids: set[str] = set()
    songs: list[Song] = []
    if out_path.exists():
        prev = json.loads(out_path.read_text(encoding="utf-8-sig"))
        for s in prev.get("songs", []):
            songs.append(
                Song(
                    song_id=s["song_id"],
                    title=s["title"],
                    artist=s["artist"],
                    youtube_id=s["youtube_id"],
                    level=s["level"],
                    lang=s["lang"],
                    lines=tuple(
                        SongLine(l["line_id"], l["text"], l["translation_az"])
                        for l in s["lines"]
                    ),
                )
            )
            existing_ids.add(s["song_id"])
        if existing_ids:
            print(f"  {len(existing_ids)} mahnı əvvəlki qaçışdan saxlanılır (təkrar sorğu yox)")

    failures = 0
    for item in confirmed:
        title, artist = item["title"], item["artist"]
        song_id = slugify(f"{artist}-{title}")
        if song_id in existing_ids:
            continue
        try:
            prompt = build_lyrics_prompt(title, artist, lang_name, UI_LANG_NAME)
            text = completer(SYSTEM_PROMPT, prompt)
            song = parse_lyrics_response(
                text,
                song_id=song_id,
                title=title,
                artist=artist,
                youtube_id=item["youtube_id"],
                level=item["level"],
                lang=args.lang,
            )
            songs.append(song)
            print(f"OK  {song_id:30} {len(song.lines)} sətir")
        except Exception as exc:  # noqa: BLE001 — toplu işdə biri digərini dayandırmasın
            failures += 1
            print(f"XƏTA {song_id:30} {exc}", file=sys.stderr)

    manifest = {
        "version": 1,
        "songs": [
            {
                "song_id": s.song_id,
                "title": s.title,
                "artist": s.artist,
                "youtube_id": s.youtube_id,
                "level": s.level,
                "lang": s.lang,
                "lines": [
                    {"line_id": l.line_id, "text": l.text, "translation_az": l.translation_az}
                    for l in s.lines
                ],
            }
            for s in songs
        ],
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"HAZIR: {len(songs)} mahnı → {out_path}")
    return 1 if failures else 0


def main(argv: list[str] | None = None) -> int:
    _reconfigure_utf8()
    load_env()

    parser = argparse.ArgumentParser(description="DilDostu mahnı generatoru")
    sub = parser.add_subparsers(dest="command", required=True)

    p_suggest = sub.add_parser("suggest", help="AI mahnı təklif edir (YouTube ID yoxdur)")
    p_suggest.add_argument("--lang", default="en", choices=sorted(LANGUAGES))
    p_suggest.add_argument("--per-level", type=int, default=PER_LEVEL_DEFAULT)
    p_suggest.set_defaults(func=_cmd_suggest)

    p_fill = sub.add_parser(
        "fill-lyrics", help="Təsdiqlənmiş mahnı üçün sözlər+tərcümə doldurur"
    )
    p_fill.add_argument("--lang", default="en", choices=sorted(LANGUAGES))
    p_fill.add_argument(
        "--source", default=None, help="Defolt: songs_source/<lang>.json"
    )
    p_fill.set_defaults(func=_cmd_fill_lyrics)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
