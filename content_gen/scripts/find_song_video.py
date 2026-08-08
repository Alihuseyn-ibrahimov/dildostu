"""YouTube-da mahnı namizədləri axtarır və metadata çap edir (bir dəfəlik alət).

AI heç vaxt video ID uydurmamalıdır (bax `dildostu_content/songs.py`) — bu alət
hər namizədi yt-dlp ilə YOXLAYIR: başlıq, ifaçı, uzunluq, embed statusu.

İstifadə:
    .venv/Scripts/python scripts/find_song_video.py --search "La Cucaracha infantil"
    .venv/Scripts/python scripts/find_song_video.py --check <youtube_id> [...]
"""

from __future__ import annotations

import argparse
import io
import sys

import yt_dlp

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# JS runtime olmadan imza açılmır — imzasız URL verən klientləri sına.
_EXTRACTOR_ARGS = {"youtube": {"player_client": ["android_vr", "ios", "android", "web"]}}


def search(query: str, limit: int) -> None:
    opts = {"quiet": True, "skip_download": True, "extract_flat": True}
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(f"ytsearch{limit}:{query}", download=False)
    for entry in info.get("entries") or []:
        dur = entry.get("duration")
        print(
            f"{entry.get('id')}  {int(dur) if dur else '?':>4}s  "
            f"{entry.get('title')}  [{entry.get('uploader')}]"
        )


def check(video_id: str) -> None:
    opts = {"quiet": True, "skip_download": True, "extractor_args": _EXTRACTOR_ARGS}
    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(
                f"https://www.youtube.com/watch?v={video_id}", download=False
            )
    except Exception as exc:  # noqa: BLE001 — namizəd yoxlanışıdır, sadəcə bildir
        print(f"{video_id}: XETA — {exc}")
        return

    print(
        f"{video_id}\n"
        f"  basliq   : {info.get('title')}\n"
        f"  kanal    : {info.get('uploader')}\n"
        f"  uzunluq  : {info.get('duration')} s\n"
        f"  embed    : {'HAYIR' if info.get('playable_in_embed') is False else 'ola biler'}\n"
        f"  bax sayi : {info.get('view_count')}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--search")
    parser.add_argument("--limit", type=int, default=8)
    parser.add_argument("--check", nargs="*", default=[])
    args = parser.parse_args()

    if args.search:
        search(args.search, args.limit)
    for vid in args.check:
        check(vid)


if __name__ == "__main__":
    main()
