"""Musiqi bölməsi — hazır `songs.json` manifesti (server audio SAXLAMIR).

Audiobook-dan fərqli: mahnının səsi YouTube-dan gəlir (app-da embed olunur),
bizdə heç bir mp3 yoxdur — ona görə `AudiobookStore.chapter_path`-ın
qarşılığı yoxdur, yalnız manifest oxunur.

Manifest bir dəfəlik yerli kompüterdə yaradılır (bax
`content_gen/dildostu_content/generate_songs.py`) və `scp` ilə bura
köçürülür — audiobook manifest deploy pattern-i ilə eyni.
"""

from __future__ import annotations

import json
from pathlib import Path


class MusicStore:
    def __init__(self, music_dir: str = "music") -> None:
        self._dir = Path(music_dir)

    def manifest(self) -> dict | None:
        """`songs.json`-u oxuyur; yoxdursa `None` (heç bir mahnı yoxdur)."""
        path = self._dir / "songs.json"
        if not path.exists():
            return None
        # utf-8-sig: Windows tərəfdə yaradılan fayl BOM-lu ola bilər.
        return json.loads(path.read_text(encoding="utf-8-sig"))
