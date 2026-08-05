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
        "splitter": "generic",
    },
    # Samaniego — Ezop-un tərcüməsi DEYİL, əsl İSPAN dilində yazılmış
    # klassik təmsillər (1781) — ispan məktəblərində Ezop qədər tanınır,
    # dil öyrənənlər üçün pedaqoji cəhətdən ideal paralel.
    "samaniego": {
        "gutenberg_id": 55206,
        "title_en": "Fables (Samaniego)",
        "title_az": "Samaniego Təmsilləri",
        "author": "Félix María Samaniego (1781)",
        "source": "Project Gutenberg #55206 — ictimai domen",
        "level": "intermediate",  # 18-ci əsr şeir dili, nəsr Aesop-dan çətindir
        "body_marker": "LIBRO PRIMERO",
        "min_words": 15,  # təmsillər qısa şeirdir, Aesop-un nəsr həddi uyğun deyil
        "lang": "es",
        "splitter": "fabulas",
        # "LIBRO PRIMERO" kitabın SONUNDAKI səhifəli indeksdə də təkrarlanır —
        # bizə BİRİNCİ (əsl başlanğıc) keçid lazımdır, sonuncu yox.
        "marker_occurrence": "first",
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


def after_first_marker(text: str, marker: str) -> str:
    """`marker` sətrinin BİRİNCİ keçidindən sonrakı hissəni qaytarır.

    `after_last_marker`-in əksi — Samaniego "Fábulas" nəşrində "LIBRO
    PRIMERO" gövdənin başında BİR dəfə, kitabın SONUNDAKI indeksdə isə
    TƏKRAR keçir (səhifə nömrəli siyahı) — `rfind` indeksə düşərdi.
    """
    idx = text.find(marker)
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


def dedupe_chapter_ids(chapters: list[Chapter]) -> list[Chapter]:
    """Eyni `chapter_id`-li fəsilləri `-2`, `-3`, ... ilə fərqləndirir.

    Mp3 fayl adı = `chapter_id` (bax `build_audiobook.py`) — iki fəslin
    başlığı slugify-dən sonra üst-üstə düşsə (məs. Samaniego-da iki fərqli
    kitabda eyni "El Asno y el Caballo." adlı fabl, 2026-08-05-də tapıldı),
    ikincisi diskdə birincinin faylını SİLİB ƏVƏZ EDİR — səssiz məlumat
    itkisi. Bu yalnız disk/keş açarı üçündür, `title_en` toxunulmaz qalır.
    """
    seen: dict[str, int] = {}
    result: list[Chapter] = []
    for chapter in chapters:
        base = chapter.chapter_id
        seen[base] = seen.get(base, 0) + 1
        occurrence = seen[base]
        chapter_id = base if occurrence == 1 else f"{base}-{occurrence}"
        result.append(
            Chapter(chapter_id=chapter_id, title_en=chapter.title_en, text=chapter.text)
        )
    return result


def clean_text(text: str) -> str:
    """Səsləndirilməyə hazır mətn: naşir markerlərini atır, boşluqları səliqəyə salır.

    `[Illustration: ...]` kimi markerlər qalsa TTS onları UCADAN OXUYUR —
    dinləyici "illustration the fox and the grapes" eşidər. `[imagen]`
    (İspan mənbələrində) və `[12]` kimi qeyd/footnote istinadları (Samaniego
    "Fábulas" nəşrində hər səhifədə onlarla var) eyni səbəbdən silinir.
    """
    # Çoxsətirli də ola bilər, ona görə DOTALL.
    cleaned = re.sub(r"\[Illustration:.*?\]", "", text, flags=re.DOTALL)
    cleaned = re.sub(r"\[imagen\]", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\[\d+\]", "", cleaned)
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
    return dedupe_chapter_ids(chapters)


# "FÁBULA PRIMERA", "FÁBULA II", "FÁBULA III" — Samaniego nəşrinin fəsil
# markeri. İngilis Aesop-dan fərqli olaraq başlığın özü (məs. "La Cigarra y
# la Hormiga") BÖYÜK HƏRFLƏ deyil, adi cümlə kimi yazılıb — `is_title_line`
# bura uyğun gəlmir, ayrıca funksiya lazımdır.
_FABULA_HEADING = re.compile(r"^FÁBULA\b")
# Fabllardan SONRA gələn qeydlər (footnote mətnləri) + nəşriyyat elanı bloku
# — kəsilməsə son fablın gövdəsinə qarışar (bax content_gen/CLAUDE.md-dəki
# tapıntı, 2026-08-05).
_NOTES_APPENDIX_MARKER = "\nNOTAS:"


def split_fabulas(body: str) -> list[Chapter]:
    """Samaniego "Fábulas" formatını bölür: `FÁBULA N` başlığından sonra
    (şəkil markerini keçib) gələn İLK QEYRI-BOŞ sətir fablın öz adıdır.
    """
    body = body.split(_NOTES_APPENDIX_MARKER)[0]
    lines = body.splitlines()
    chapters: list[Chapter] = []
    i, n = 0, len(lines)
    while i < n:
        if not _FABULA_HEADING.match(lines[i].strip()):
            i += 1
            continue
        i += 1
        while i < n and (not lines[i].strip() or lines[i].strip().lower() == "[imagen]"):
            i += 1
        if i >= n:
            break
        title = lines[i].strip()
        i += 1
        body_lines: list[str] = []
        while i < n and not _FABULA_HEADING.match(lines[i].strip()) and not lines[
            i
        ].strip().startswith("LIBRO "):
            body_lines.append(lines[i])
            i += 1
        text = clean_text("\n".join(body_lines))
        if text:
            chapters.append(Chapter(chapter_id=slugify(title), title_en=title, text=text))
    return dedupe_chapter_ids(chapters)


def humanize_title(title: str) -> str:
    """'THE FOX AND THE GRAPES' → 'The Fox and the Grapes' (oxunaqlı).

    YALNIZ tam BÖYÜK HƏRFLİ başlıqlara tətbiq edilməlidir (Aesop mənbəyi
    belədir) — artıq düzgün yazılmış başlıq (Samaniego: "La Cigarra y la
    Hormiga") buradan keçsə İngilis kiçik-söz siyahısı Ispan sözlərini
    tanımayıb səhv böyük hərflə yazardı ("La Cigarra Y La Hormiga").
    """
    if title != title.upper():
        return title
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
