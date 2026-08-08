"""Bir mahnının sətir-sətir uyğunlaşma nəticəsini göstərir (diaqnostika aləti).

İstifadə: .venv/Scripts/python scripts/debug_align.py <song_id>
"""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from dildostu_content.lyrics_align import align_lines  # noqa: E402

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")


def main() -> None:
    song_id = sys.argv[1]
    data = json.loads((ROOT / "songs_out" / "songs.json").read_text(encoding="utf-8-sig"))
    song = next(s for s in data["songs"] if s["song_id"] == song_id)
    payload = json.loads(
        (ROOT / "songs_out" / f"_words_{song['youtube_id']}.json").read_text(encoding="utf-8")
    )
    timings = align_lines(
        [ln["text"] for ln in song["lines"]], payload["words"], payload.get("duration_ms")
    )
    for line, t in zip(song["lines"], timings, strict=True):
        mark = f"{t['start_ms'] / 1000:8.2f}" if t["matched"] else "    YOX "
        print(f"{line['line_id']:>4} {mark}  {line['text']}")


if __name__ == "__main__":
    main()
