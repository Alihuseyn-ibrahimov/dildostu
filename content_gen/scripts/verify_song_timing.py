"""songs.json-dakı sinxron vaxtlarını yoxlayır (mənbədən təsdiq, UI-dan yox)."""

from __future__ import annotations

import io
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from dildostu_content.lyrics_align import line_words

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

SONGS = ROOT / "songs_out" / "songs.json"


def fmt(ms: int) -> str:
    return f"{ms // 60000}:{(ms % 60000) / 1000:05.2f}"


def main() -> None:
    data = json.loads(SONGS.read_text(encoding="utf-8-sig"))
    problems: list[str] = []

    for song in data["songs"]:
        print(f"\n=== {song['title']} ({song['youtube_id']}) ===")
        prev = -1
        matched = 0
        for line in song["lines"]:
            start = line.get("start_ms")
            if start is None:
                print(f"  --:--.--  {line['text']}  [sinxron YOX]")
                continue
            matched += 1
            words = line_words(line["text"])
            word_ms = line.get("word_ms") or []
            if len(words) != len(word_ms):
                problems.append(
                    f"{song['song_id']}/{line['line_id']}: "
                    f"{len(words)} soz, {len(word_ms)} vaxt"
                )
            if start < prev:
                problems.append(f"{song['song_id']}/{line['line_id']}: vaxt geriyə getdi")
            prev = start
            print(f"  {fmt(start)}  {line['text']}")

        print(f"  ({matched}/{len(song['lines'])} setr sinxron)")

    print("\n--- Yoxlama ---")
    if problems:
        for p in problems:
            print("XETA:", p)
        sys.exit(1)
    print("Sinxronlu setirlərdə vaxtlar artandır, soz sayi uyğundur.")


if __name__ == "__main__":
    main()
