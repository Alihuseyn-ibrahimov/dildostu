"""Musiqi bölməsi boru xətti — mahnı təklifi + lyrics/tərcümə qurma.

Bura YALNIZ təmiz funksiyalar düşür (şəbəkə yoxdur) ki, tam test oluna bilsin.
Şəbəkə çağırışı (`generate_songs.py`-də) `providers.get_completer()`-i
təkrar istifadə edir.

İKİ ADDIMLI, insan-in-the-loop axın (bax
docs/superpowers/specs/2026-08-05-dildostu-music-section-design.md):
1. `build_suggest_prompt` + `parse_suggest_response` — AI mahnı TƏKLİF edir
   (başlıq+ifaçı), YouTube ID YOXDUR — AI heç vaxt video ID uydurmamalıdır.
2. İnsan hər təklif üçün YouTube linkini təsdiqləyir (kod xaricində).
3. `build_lyrics_prompt` + `parse_lyrics_response` — təsdiqlənmiş mahnı üçün
   AI-dan tam sözlər + sətir-sətir AZ tərcümə istənilir.

Hüquqi qeyd: tam mahnı sözləri müəllif hüququ qorunan material ola bilər —
bax spec-dəki "Hüquqi qeyd" bölməsi (bilərəkdən qəbul edilmiş risk).
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from .generate import _extract_json

LEVELS: tuple[str, ...] = ("beginner", "intermediate", "advanced")

# YouTube video ID: sabit 11 simvol, [A-Za-z0-9_-].
_YOUTUBE_ID_RE = re.compile(r"^[A-Za-z0-9_-]{11}$")


@dataclass(frozen=True)
class SongCandidate:
    """AI-nin təklif etdiyi mahnı — YouTube ID YOXDUR, insan təsdiqi lazımdır."""

    title: str
    artist: str
    level: str


@dataclass(frozen=True)
class SongLine:
    line_id: str
    text: str
    translation_az: str


@dataclass(frozen=True)
class Song:
    song_id: str
    title: str
    artist: str
    youtube_id: str
    level: str
    lang: str
    lines: tuple[SongLine, ...]


def build_suggest_prompt(lang_name: str, per_level: int = 3) -> str:
    """Hər səviyyə üçün `per_level` tanınmış mahnı təklifi istəyən prompt.

    YouTube ID İSTƏNMİR — model bunu uydura bilər (real olmayan/səhv video),
    bax spec-dəki "insan-in-the-loop" qərarı.
    """
    return (
        f"Suggest {per_level} well-known, popular {lang_name} songs for each "
        f"of these language-learner levels: {', '.join(LEVELS)}.\n\n"
        "Level guidance:\n"
        "- beginner: very simple, repetitive lyrics, slow/clear diction, "
        "widely known (e.g. children's songs, simple pop choruses)\n"
        "- intermediate: normal pop/folk song vocabulary, moderate pace\n"
        "- advanced: rich vocabulary, idioms, faster or more complex lyrics\n\n"
        "For each song give the song title and the artist/performer name "
        "(so the song can be found on YouTube). Do NOT invent a YouTube "
        "video ID or URL — only title and artist.\n\n"
        'Return ONLY a JSON object of the form {"songs": [{"title": "...", '
        '"artist": "...", "level": "beginner"}, ...]} with no extra text.'
    )


def parse_suggest_response(text: str) -> list[SongCandidate]:
    """Model cavabından mahnı təklifləri massivini çıxarır və doğrulayır."""
    payload = _extract_json(text)
    songs = payload.get("songs", payload) if isinstance(payload, dict) else payload
    if not isinstance(songs, list):
        raise ValueError("cavabda mahnı massivi tapılmadı")

    candidates: list[SongCandidate] = []
    for item in songs:
        if not isinstance(item, dict):
            raise ValueError(f"gözlənilməyən element: {item!r}")
        title = item.get("title")
        artist = item.get("artist")
        level = item.get("level")
        if not title or not artist:
            raise ValueError(f"başlıq/ifaçı əskikdir: {item!r}")
        if level not in LEVELS:
            raise ValueError(f"naməlum səviyyə: {level!r}")
        candidates.append(SongCandidate(title=title, artist=artist, level=level))
    return candidates


def validate_confirmed_songs(items: list[dict]) -> None:
    """Faza 2-nin çıxışını (insan-təsdiqli mahnı siyahısı) yoxlayır.

    Hər elementdə düzgün formatlı `youtube_id` olmalıdır — bura AI-nin
    uydurduğu boş/səhv id keçməsin deyə (bax modul qeydi, insan-in-the-loop
    qərarı). Xəta halında ilk problemli elementi göstərən ValueError atır.
    """
    for item in items:
        yid = item.get("youtube_id", "")
        if not _YOUTUBE_ID_RE.match(yid):
            raise ValueError(
                f"{item.get('title')!r}: düzgün youtube_id yoxdur (əl ilə təsdiq lazımdır)"
            )


def build_lyrics_prompt(
    title: str, artist: str, lang_name: str, ui_lang_name: str = "Azerbaijani"
) -> str:
    """Təsdiqlənmiş mahnı üçün tam sözlər + sətir-sətir tərcümə istəyən prompt."""
    return (
        f'Give the full lyrics of the {lang_name} song "{title}" by {artist}, '
        "split into individual lines in their original order.\n\n"
        f"For each line provide:\n"
        '- "text": the original line, exactly as sung\n'
        f'- "translation_az": a natural {ui_lang_name} translation of that line\n\n'
        "Rules: preserve the song's real line breaks (do not merge lines). "
        "If you are not fully certain of the exact lyrics, give your best, "
        "most accurate recollection — do not pad with invented lines.\n\n"
        'Return ONLY a JSON object of the form {"lines": [{"text": "...", '
        '"translation_az": "..."}, ...]} with no extra text.'
    )


def parse_lyrics_response(
    text: str,
    *,
    song_id: str,
    title: str,
    artist: str,
    youtube_id: str,
    level: str,
    lang: str,
) -> Song:
    """Model cavabından tam `Song`-u qurur (lyrics + tərcümə)."""
    payload = _extract_json(text)
    lines_raw = payload.get("lines", payload) if isinstance(payload, dict) else payload
    if not isinstance(lines_raw, list) or not lines_raw:
        raise ValueError(f"[{song_id}] cavabda sətir massivi tapılmadı")

    lines: list[SongLine] = []
    for i, item in enumerate(lines_raw, start=1):
        if not isinstance(item, dict):
            raise ValueError(f"[{song_id}] gözlənilməyən sətir: {item!r}")
        line_text = item.get("text")
        translation = item.get("translation_az")
        if not line_text or not translation:
            raise ValueError(f"[{song_id}] sətir/tərcümə əskikdir: {item!r}")
        lines.append(SongLine(line_id=f"l{i}", text=line_text, translation_az=translation))

    if level not in LEVELS:
        raise ValueError(f"[{song_id}] naməlum səviyyə: {level!r}")

    return Song(
        song_id=song_id,
        title=title,
        artist=artist,
        youtube_id=youtube_id,
        level=level,
        lang=lang,
        lines=tuple(lines),
    )
