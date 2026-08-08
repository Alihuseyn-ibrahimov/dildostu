"""`songs_out/drafts/*.json` fayllarını `songs.json`-a birləşdirir.

Hər draft: tam bir mahnı obyekti (song_id, title, artist, youtube_id, level,
lang, lines). Eyni song_id varsa əvəz edir.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SONGS = ROOT / "songs_out" / "songs.json"
DRAFTS = ROOT / "songs_out" / "drafts"


def main() -> None:
    data = json.loads(SONGS.read_text(encoding="utf-8-sig"))
    by_id = {s["song_id"]: s for s in data["songs"]}

    paths = sorted(DRAFTS.glob("*.json"))
    if not paths:
        print("Draft yoxdur:", DRAFTS)
        sys.exit(1)

    for path in paths:
        song = json.loads(path.read_text(encoding="utf-8"))
        sid = song["song_id"]
        action = "yenilendi" if sid in by_id else "elave edildi"
        by_id[sid] = song
        print(f"  {sid}: {action}")

    data["songs"] = list(by_id.values())
    SONGS.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Yazildi: {SONGS} ({len(data['songs'])} mahnı)")


if __name__ == "__main__":
    main()
