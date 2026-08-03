"""Səsli kitablar — hazır MP3 və manifest faylları (server TTS İŞLƏTMİR).

Audio bir dəfəlik yerli kompüterdə yaradılır (bax
`content_gen/scripts/build_audiobook.py`) və `scp` ilə bura köçürülür.
Səbəb: VPS-də cəmi ~115 MB əlçatan RAM var — orada TTS işlətmək serveri
söndürər.

`releases/` kimi, bu qovluq da kod deploy-undan AYRIDIR.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

# Yalnız kiçik hərf, rəqəm və tire. Bu, `slugify`-ın çıxışı ilə eynidir və
# path traversal-ı (`..`, `/`, `\`) tamamilə bağlayır.
_SAFE_ID = re.compile(r"^[a-z0-9-]+$")


class AudiobookStore:
    def __init__(self, audiobooks_dir: str = "audiobooks") -> None:
        self._dir = Path(audiobooks_dir)

    def manifest(self) -> dict | None:
        """`manifest.json`-u oxuyur; yoxdursa `None` (heç bir kitab yoxdur)."""
        path = self._dir / "manifest.json"
        if not path.exists():
            return None
        # utf-8-sig: Windows tərəfdə yaradılan fayl BOM-lu ola bilər.
        return json.loads(path.read_text(encoding="utf-8-sig"))

    def chapter_path(self, book_id: str, chapter_id: str) -> Path | None:
        """Fəslin MP3 yolu; id-lər təhlükəsiz deyilsə və ya fayl yoxdursa `None`.

        Ad yoxlaması `resolve()`-dan ƏVVƏL edilir — şübhəli girişi heç vaxt
        fayl sisteminə buraxmırıq.
        """
        if not _SAFE_ID.match(book_id) or not _SAFE_ID.match(chapter_id):
            return None
        path = self._dir / book_id / f"{chapter_id}.mp3"
        return path if path.is_file() else None
