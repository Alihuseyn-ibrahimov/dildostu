"""Səsli kitab boru xətti — mətn hazırlama və manifest qurma.

Bura YALNIZ təmiz funksiyalar düşür (şəbəkə/fayl/TTS yoxdur) ki, tam test
oluna bilsin. Yükləmə, Piper və ffmpeg çağırışları `scripts/`-dədir.

Mənbə yalnız İCTİMAİ DOMEN mətnləridir (Project Gutenberg). Müəllif hüququ
qorunan kitabların mətni bura düşməməlidir — bax
docs/superpowers/specs/2026-08-04-audiobooks-design.md
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass

_GUTENBERG_START = "*** START OF THE PROJECT GUTENBERG"
_GUTENBERG_END = "*** END OF THE PROJECT GUTENBERG"

# Başlıq: girintisiz, ən azı bir hərf, bütün hərfləri BÖYÜK.
_HAS_LETTER = re.compile(r"[^\W\d_]", re.UNICODE)


@dataclass(frozen=True)
class Chapter:
    """Bir fəsil (təmsil/hekayə) — audio hələ yaradılmayıb."""

    chapter_id: str
    title_en: str
    text: str


# Dəstəklənən kitablar — HAMISI ictimai domen (Project Gutenberg).
# `body_marker`: gövdənin başladığı sətir (CONTENTS-dən sonrakı sonuncu keçid).
# `lang`: kitabın DİLİ (target_lang ilə uzlaşır) — manifestə düşür, app bunu
# `profile.targetLang`-a görə süzür (bax 2026-08-04-multilanguage-russian-design.md).
#
# Rus dili üçün (Krılovun təmsilləri) HƏLƏ giriş YOXDUR — araşdırma göstərdi
# ki, Gutenberg-in mövcud Krylov girişi (#73646) əslində FİNCƏ tərcümədir,
# rus dilində doğrulanmış ictimai domen mətn tapılmadı. Uydurma/yoxlanmamış
# ID əlavə etmək əvəzinə bu, ayrıca izləmə tapşırığına saxlanılıb — düzgün
# mənbə (məs. archive.org-dan başqa lisenziyalı mətn) tapılanda BOOKS-a
# `"krylov": {..., "lang": "ru", ...}` əlavə edib eyni pipeline-ı işlətmək
# kifayətdir (aşağıdakı `lang` sahəsi və `--lang` CLI arqumenti artıq hazırdır).
BOOKS: dict[str, dict] = {
    "aesop": {
        "gutenberg_id": 11339,
        "title_en": "Aesop's Fables",
        "title_az": "Ezop Təmsilləri",
        "author": "Aesop — V. S. Vernon Jones tərcüməsi (1912)",
        "source": "Project Gutenberg #11339 — ictimai domen",
        "level": "beginner",
        "body_marker": "ÆSOP'S FABLES",
        "min_words": 30,
        "lang": "en",
    },
}


def strip_gutenberg_wrapper(raw: str) -> str:
    """Gutenberg başlıq/lisenziya bloklarını atır.

    Marker tapılmasa mətni olduğu kimi qaytarır — səssizcə boş nəticə
    qaytarmaqdansa tam mətnlə davam etmək yaxşıdır.
    """
    text = raw
    start = text.find(_GUTENBERG_START)
    if start != -1:
        line_end = text.find("\n", start)
        if line_end != -1:
            text = text[line_end + 1 :]
    end = text.find(_GUTENBERG_END)
    if end != -1:
        text = text[:end]
    return text


def after_last_marker(text: str, marker: str) -> str:
    """`marker` sətrinin SONUNCU keçidindən sonrakı hissəni qaytarır.

    Kitabın adı həm titul səhifəsində, həm də CONTENTS-dən sonra gövdənin
    başında olur; bizə gövdə lazımdır, ona görə sonuncu keçid götürülür.
    """
    idx = text.rfind(marker)
    if idx == -1:
        return text
    line_end = text.find("\n", idx)
    return text if line_end == -1 else text[line_end + 1 :]


def is_title_line(line: str) -> bool:
    """Sətir fəsil başlığıdırmı (girintisiz, tamamı BÖYÜK hərf)."""
    if line != line.lstrip():  # girintili → əxlaq sətri və ya gövdə
        return False
    stripped = line.strip()
    if len(stripped) < 3 or not _HAS_LETTER.search(stripped):
        return False
    return stripped == stripped.upper()


# NFKD ASCII-foldinq yalnız Latın mənşəli hərflər üçün işləyir (Æ→AE,
# ə→e) — kiril hərflərinin ASCII dekompozisiyası yoxdur, `encode("ascii",
# "ignore")` onları tamamilə SİLƏR (boş slug). Rus (və gələcək kiril-əsaslı
# dillərin) başlıqları üçün transliterasiya cədvəli lazımdır.
_CYRILLIC_TRANSLIT = str.maketrans({
    "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e",
    "ж": "zh", "з": "z", "и": "i", "й": "i", "к": "k", "л": "l", "м": "m",
    "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
    "ф": "f", "х": "h", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "sch",
    "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya",
})


def slugify(title: str) -> str:
    """Başlığı təhlükəsiz id-yə çevirir: yalnız [a-z0-9-].

    Server path traversal-a qarşı məhz bu simvol dəstini gözləyir.
    """
    # Əvvəlcə kiril → Latın (aşağı hərflə, böyük/kiçik fərqi yoxdur burda).
    translit = title.lower().translate(_CYRILLIC_TRANSLIT)
    # Æ → AE, ə → e: ASCII-yə endirmək URL/fayl adı üçün vacibdir.
    folded = unicodedata.normalize("NFKD", translit)
    ascii_only = folded.encode("ascii", "ignore").decode("ascii")
    # Apostrof SİLİNİR, tire olmur: "miser's" → "misers" (miser-s yox).
    ascii_only = re.sub(r"['’]", "", ascii_only)
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", ascii_only).lower()
    return slug.strip("-")


def clean_text(text: str) -> str:
    """Səsləndirilməyə hazır mətn: naşir markerlərini atır, boşluqları səliqəyə salır.

    `[Illustration: ...]` kimi markerlər qalsa TTS onları UCADAN OXUYUR —
    dinləyici "illustration the fox and the grapes" eşidər.
    """
    # Çoxsətirli də ola bilər, ona görə DOTALL.
    cleaned = re.sub(r"\[Illustration:.*?\]", "", text, flags=re.DOTALL)
    # 3+ sətir sonu → abzas ayrıcı (2 sətir sonu qorunur).
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    # Sətir sonundakı boşluqlar.
    cleaned = re.sub(r"[ \t]+\n", "\n", cleaned)
    return cleaned.strip()


def drop_non_narrative(chapters: list[Chapter], *, min_words: int = 20) -> list[Chapter]:
    """Hekayə olmayan bölmələri atır (şəkil siyahısı, boş qalan başlıqlar).

    Gutenberg mətnlərinin sonunda "ILLUSTRATIONS" kimi siyahı bölmələri olur —
    onlar fəsil deyil və səsləndirilməməlidir.
    """
    return [c for c in chapters if len(c.text.split()) >= min_words]


def split_chapters(body: str) -> list[Chapter]:
    """Gövdəni BÖYÜK HƏRFLİ başlıq sətirlərinə görə fəsillərə bölür.

    Gövdəsi olmayan başlıq (CONTENTS qalığı, ardıcıl başlıqlar) atılır.
    """
    chapters: list[Chapter] = []
    title: str | None = None
    buffer: list[str] = []

    def flush() -> None:
        if title is None:
            return
        text = clean_text("\n".join(buffer))
        if not text:  # gövdəsiz başlıq — fəsil deyil
            return
        chapters.append(
            Chapter(chapter_id=slugify(title), title_en=title.strip(), text=text)
        )

    for line in body.splitlines():
        if is_title_line(line):
            flush()
            title = line.strip()
            buffer = []
        elif title is not None:
            buffer.append(line)
    flush()
    return chapters


def humanize_title(title: str) -> str:
    """'THE FOX AND THE GRAPES' → 'The Fox and the Grapes' (oxunaqlı)."""
    small = {"a", "an", "and", "the", "of", "or", "in", "on", "at", "to", "his",
             "her", "its", "that", "who", "with", "for", "but"}
    words = title.strip().lower().split()
    out: list[str] = []
    for i, w in enumerate(words):
        out.append(w if i != 0 and w in small else w.capitalize())
    return " ".join(out)


def build_manifest(
    *,
    book_id: str,
    title_en: str,
    title_az: str,
    author: str,
    source: str,
    level: str,
    chapters: list[Chapter],
    measured: dict[str, tuple[float, int]],
    lang: str = "en",
) -> dict:
    """App-ın `/audiobooks` cavabını qurur.

    `measured`: chapter_id → (uzunluq_saniyə, ölçü_bayt). Bu dəyərlər REAL
    MP3 faylından ölçülür (ffprobe) — təxmin edilmir. Ölçü yoxdursa KeyError
    atılır: səssizcə 0 yazsaq plyer sınıq fəsil göstərərdi.
    """
    chapter_entries = []
    for ch in chapters:
        duration, size = measured[ch.chapter_id]  # yoxdursa KeyError — qəsdən
        chapter_entries.append(
            {
                "chapter_id": ch.chapter_id,
                "title_en": humanize_title(ch.title_en),
                "duration_sec": duration,
                "size_bytes": size,
                "text": ch.text,
            }
        )
    return {
        "version": 1,
        "books": [
            {
                "book_id": book_id,
                "title_en": title_en,
                "title_az": title_az,
                "author": author,
                "source": source,
                "level": level,
                "lang": lang,
                "chapters": chapter_entries,
            }
        ],
    }
