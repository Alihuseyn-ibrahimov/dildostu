"""ASR söz vaxtlarını oxunaqlı vaxt xətti kimi çap edir (sətir qurmaq üçün alət).

İstifadə: .venv/Scripts/python scripts/dump_asr.py <youtube_id> [--gap 1.0]

Sözlər arasında `--gap` saniyədən böyük fasilə olanda yeni sətir başlanır —
videonun faktiki sətir strukturunu görmək üçün.
"""

from __future__ import annotations

import argparse
import io
import json
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("youtube_id")
    parser.add_argument("--gap", type=float, default=1.0)
    args = parser.parse_args()

    path = ROOT / "songs_out" / f"_words_{args.youtube_id}.json"
    payload = json.loads(path.read_text(encoding="utf-8"))
    words = payload["words"]
    print(f"# {args.youtube_id}: {len(words)} soz, {payload['duration_ms']} ms")

    chunk: list[dict] = []
    prev_end = None
    for w in words:
        if prev_end is not None and w["start"] - prev_end > args.gap and chunk:
            _flush(chunk, w["start"] - prev_end)
            chunk = []
        chunk.append(w)
        prev_end = w["end"]
    if chunk:
        _flush(chunk, 0.0)


def _flush(chunk: list[dict], gap_after: float) -> None:
    text = " ".join(w["word"] for w in chunk)
    print(f"[{chunk[0]['start']:7.2f} - {chunk[-1]['end']:7.2f}]  {text}")
    if gap_after > 3.0:
        print(f"   ... {gap_after:.1f}s FASILE ...")


if __name__ == "__main__":
    main()
