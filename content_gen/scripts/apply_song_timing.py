"""songs.json-a REAL sinxron vaxtlarını yazır (ASR word timestamps əsasında).

Əvvəlcə hər mahnı üçün transkripsiya lazımdır:

    .venv/Scripts/python scripts/transcribe_song.py <youtube_id> <dil>

o, `songs_out/_words_<youtube_id>.json` yaradır. Uyğunlaşmayan sətirlərdə
vaxt sahələri yazılmır — app onları vurğulamır.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from dildostu_content.lyrics_align import align_lines

SONGS = ROOT / "songs_out" / "songs.json"
WORDS_DIR = ROOT / "songs_out"

_OBSOLETE_KEYS = ("intro_ms", "cycle_duration_ms", "sync_lead_ms")
_TIMING_KEYS = ("start_ms", "end_ms", "word_ms")


def _words_path(youtube_id: str) -> Path:
    return WORDS_DIR / f"_words_{youtube_id}.json"


def apply_timing(song: dict) -> tuple[dict, bool]:
    path = _words_path(song["youtube_id"])
    if not path.exists():
        return song, False

    payload = json.loads(path.read_text(encoding="utf-8"))
    timings = align_lines(
        [ln["text"] for ln in song["lines"]],
        payload["words"],
        duration_ms=payload.get("duration_ms"),
    )

    song = {k: v for k, v in song.items() if k not in _OBSOLETE_KEYS}
    new_lines = []
    matched = 0
    for line, t in zip(song["lines"], timings, strict=True):
        base = {k: v for k, v in line.items() if k not in _TIMING_KEYS}
        if t.get("matched") and t.get("start_ms") is not None:
            base["start_ms"] = t["start_ms"]
            base["end_ms"] = t["end_ms"]
            base["word_ms"] = t["word_ms"]
            matched += 1
        new_lines.append(base)
    song["lines"] = new_lines
    return song, matched > 0


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else SONGS
    data = json.loads(out.read_text(encoding="utf-8-sig"))

    songs = []
    for song in data["songs"]:
        updated, ok = apply_timing(song)
        songs.append(updated)
        n = sum(1 for ln in updated["lines"] if "start_ms" in ln)
        total = len(updated["lines"])
        status = f"{n}/{total} setr sinxron" if ok else "vaxt fayli YOXDUR"
        print(f"  {song['song_id']}: {status}")

    data["songs"] = songs
    out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Yazildi: {out}")


if __name__ == "__main__":
    main()
