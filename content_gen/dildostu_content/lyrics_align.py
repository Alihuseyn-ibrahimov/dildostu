"""ASR söz vaxtlarını manifest sətirlərinə bağlayır — REAL sinxron mənbəyi.

Hər sətir AYRI uyğunlaşdırılır (təkrarlanan mahnılarda düzgün təkrar seçilir).
Uyğunluq kifayət qədər yüksək deyilsə sətir vaxtsız qalır — yanlış vaxt
yox, heç vurğulanmır.
"""

from __future__ import annotations

import re
import unicodedata
from difflib import SequenceMatcher

WORD_RE = re.compile(r"[A-Za-zÀ-ÿ']+")

# Sətri "tapıldı" saymaq üçün minimal oxşarlıq (2/4 söz ≈ 0.5).
_MIN_SCORE = 0.50
# Sətir daxilində lövbərsiz söz üçün ehtiyat addım (ms).
_INTRA_LINE_MS = 350


def normalize(word: str) -> str:
    """Kiçik hərf + diakritikasız + yalnız hərflər (ASR ilə müqayisə üçün)."""
    decomposed = unicodedata.normalize("NFD", word.lower())
    stripped = "".join(c for c in decomposed if unicodedata.category(c) != "Mn")
    return "".join(c for c in stripped if c.isalpha())


def line_words(text: str) -> list[str]:
    return WORD_RE.findall(text)


def _normalized_line(text: str) -> list[str]:
    return [n for n in (normalize(w) for w in line_words(text)) if n]


def _fill_intra_line(word_ms: list[int | None]) -> list[int]:
    """Sətir daxilində bilinməyən sözləri eyni sətirdəki lövbərlər arasında doldurur."""
    if not word_ms:
        return []
    known = [i for i, t in enumerate(word_ms) if t is not None]
    if not known:
        return []

    filled = list(word_ms)
    first = known[0]
    for i in range(first):
        filled[i] = filled[first] - (first - i) * _INTRA_LINE_MS

    for idx in range(len(known) - 1):
        a, b = known[idx], known[idx + 1]
        t_a, t_b = filled[a], filled[b]
        if b - a <= 1:
            continue
        span = t_b - t_a
        for k in range(1, b - a):
            filled[a + k] = t_a + round(span * k / (b - a))

    last = known[-1]
    for i in range(last + 1, len(filled)):
        filled[i] = filled[last] + (i - last) * _INTRA_LINE_MS

    for i in range(1, len(filled)):
        if filled[i] < filled[i - 1]:
            filled[i] = filled[i - 1]
    return [max(0, int(t)) for t in filled]


def _match_line(
    words: list[str],
    asr_norm: list[str],
    asr_words: list[dict],
    min_asr_idx: int,
) -> tuple[float, int, int, list[int]]:
    """Bir sətir üçün ən yaxşı ASR parçasını tapır."""
    if not words:
        return 0.0, min_asr_idx, min_asr_idx, []

    candidates: list[tuple[float, int, int]] = []
    n = len(words)
    for start in range(min_asr_idx, len(asr_norm)):
        for width in range(max(1, n - 1), n + 3):
            chunk = asr_norm[start : start + width]
            if not chunk:
                continue
            score = SequenceMatcher(None, words, chunk, autojunk=False).ratio()
            if score >= _MIN_SCORE:
                candidates.append((score, start, start + len(chunk)))

    if not candidates:
        return 0.0, min_asr_idx, min_asr_idx, []

    top = max(c[0] for c in candidates)
    # Yaxın skorlarda (≤0.20) videoda daha tez gələn təkrarı seç.
    close = [c for c in candidates if c[0] >= top - 0.20]
    best_score, best_start, best_end = min(close, key=lambda c: c[1])

    chunk = asr_norm[best_start:best_end]
    matcher = SequenceMatcher(None, words, chunk, autojunk=False)
    raw: list[int | None] = [None] * n
    last_asr_idx = best_start - 1
    for block in matcher.get_matching_blocks():
        for k in range(block.size):
            lyric_idx = block.a + k
            asr_idx = best_start + block.b + k
            raw[lyric_idx] = round(asr_words[asr_idx]["start"] * 1000)
            # q, y, de kimi qısa sözlər hər yerdə görünür — kursoru onlarla irəli itirmə.
            if len(words[lyric_idx]) >= 3:
                last_asr_idx = max(last_asr_idx, asr_idx)

    # Növbəti sətir yalnız GERÇƏK uyğun sözlərdən sonra axtarılır (l4 arriba udmasın).
    next_idx = last_asr_idx + 1 if last_asr_idx >= best_start else best_end
    return best_score, best_start, next_idx, _fill_intra_line(raw)


def align_lines(
    lines: list[str],
    asr_words: list[dict],
    duration_ms: int | None = None,
) -> list[dict]:
    """Hər sətir üçün `{start_ms, end_ms, word_ms, matched}` qaytarır.

    Uyğunlaşmayan sətirdə `start_ms`/`word_ms` `None` — app onu vurğulamır.
    """
    asr_norm = [normalize(w["word"]) for w in asr_words]
    last_asr_end = round(asr_words[-1]["end"] * 1000) if asr_words else 0
    cap = duration_ms if duration_ms is not None else last_asr_end

    results: list[dict] = []
    min_asr_idx = 0

    for text in lines:
        words = _normalized_line(text)
        if not words:
            results.append(
                {"start_ms": None, "end_ms": None, "word_ms": None, "matched": False}
            )
            continue

        score, start_idx, end_idx, word_ms = _match_line(
            words, asr_norm, asr_words, min_asr_idx
        )
        if not word_ms:
            results.append(
                {"start_ms": None, "end_ms": None, "word_ms": None, "matched": False}
            )
            continue

        word_ms = [min(t, cap) for t in word_ms]
        start_ms = word_ms[0]
        min_asr_idx = max(min_asr_idx, end_idx)
        results.append(
            {
                "start_ms": start_ms,
                "end_ms": 0,
                "word_ms": word_ms,
                "matched": True,
            }
        )

    for idx, item in enumerate(results):
        if not item["matched"]:
            continue
        nxt = next((r for r in results[idx + 1 :] if r["matched"]), None)
        if nxt is not None:
            item["end_ms"] = max(item["start_ms"], nxt["start_ms"])
        else:
            item["end_ms"] = max(item["start_ms"], last_asr_end)

    return results
