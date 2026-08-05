"""Səsli kitab qurucusu — Gutenberg mətni → Piper TTS → MP3 + manifest.

Bir dəfəlik/oflayn alət: SERVERDƏ İŞLƏMİR (VPS-də cəmi ~115 MB əlçatan RAM
var). Nəticə `scp` ilə serverə köçürülür.

İşlətmə (content_gen qovluğundan):
    .venv/Scripts/python scripts/build_audiobook.py --book aesop --limit 20
    .venv/Scripts/python scripts/build_audiobook.py --book aesop        # hamısı

Piper binarı və səs modeli (~85 MB) repoya girmir — ilk çağırışda
`.tools/`-a yüklənir.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dildostu_content.audiobooks import (  # noqa: E402
    BOOKS,
    after_last_marker,
    build_manifest,
    drop_non_narrative,
    humanize_title,
    split_chapters,
    strip_gutenberg_wrapper,
)

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / ".tools"
PIPER_ZIP_URL = (
    "https://github.com/rhasspy/piper/releases/download/2023.11.14-2/"
    "piper_windows_amd64.zip"
)

# Dilə görə defolt Piper səsi (hər dildən BİR, mövcud İngilis pipeline-ı ilə
# eyni qərar strukturu). Yeni dil əlavə etmək üçün buraya bir sətir kifayətdir
# — model adı `huggingface.co/rhasspy/piper-voices` reposunun yol quruluşuna
# uyğun olmalıdır (bax VOICES.md).
VOICES: dict[str, str] = {
    "en": "en/en_US/lessac/medium/en_US-lessac-medium",
    "ru": "ru/ru_RU/irina/medium/ru_RU-irina-medium",
}


def _voice_urls(lang: str) -> tuple[str, str]:
    """(model_url, voice_filename) — lang üçün Piper model + JSON konfiqi."""
    path = VOICES[lang]
    name = path.rsplit("/", 1)[-1] + ".onnx"
    base = f"https://huggingface.co/rhasspy/piper-voices/resolve/main/{path}.onnx"
    return base, name

# Dil öyrənənlər üçün bir qədər yavaş və cümlələr arası fasiləli.
LENGTH_SCALE = "1.05"
SENTENCE_SILENCE = "0.4"
MP3_BITRATE = "64k"


def _download(url: str, dest: Path) -> None:
    if dest.exists():
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"  yüklənir: {dest.name} …")
    urllib.request.urlretrieve(url, dest)


def ensure_piper(lang: str = "en") -> tuple[Path, Path]:
    """Piper binarını və (dilə uyğun) səs modelini təmin edir → (piper.exe, model)."""
    exe = TOOLS / "piper" / "piper.exe"
    if not exe.exists():
        zip_path = TOOLS / "piper_windows_amd64.zip"
        _download(PIPER_ZIP_URL, zip_path)
        print("  açılır: piper …")
        with zipfile.ZipFile(zip_path) as z:
            z.extractall(TOOLS)
    voice_base, voice_name = _voice_urls(lang)
    model = TOOLS / voice_name
    _download(voice_base, model)
    _download(voice_base + ".json", TOOLS / (voice_name + ".json"))
    if not exe.exists():
        raise SystemExit(f"XƏTA: piper tapılmadı: {exe}")
    return exe, model


def fetch_book_text(gutenberg_id: int) -> str:
    """Gutenberg mətnini gətirir (yerli keşlə — təkrar yükləmə olmasın)."""
    cache = TOOLS / f"gutenberg_{gutenberg_id}.txt"
    if not cache.exists():
        url = f"https://www.gutenberg.org/cache/epub/{gutenberg_id}/pg{gutenberg_id}.txt"
        _download(url, cache)
    return cache.read_text(encoding="utf-8")


def probe_duration(path: Path) -> float:
    """MP3-ün REAL uzunluğu (saniyə) — təxmin edilmir, fayldan ölçülür."""
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
        capture_output=True, text=True, check=True,
    )
    return round(float(out.stdout.strip()), 1)


def synth_all(exe: Path, model: Path, jobs: list[tuple[str, str]], wav_dir: Path) -> None:
    """Bütün fəsilləri BİR piper prosesində yaradır (model bir dəfə yüklənir)."""
    wav_dir.mkdir(parents=True, exist_ok=True)
    lines = [
        json.dumps({"text": text, "output_file": str(wav_dir / f"{cid}.wav")})
        for cid, text in jobs
    ]
    proc = subprocess.run(
        [str(exe), "-m", str(model), "--json-input", "--quiet",
         "--length_scale", LENGTH_SCALE, "--sentence_silence", SENTENCE_SILENCE],
        input="\n".join(lines) + "\n", text=True, encoding="utf-8",
        capture_output=True,
    )
    if proc.returncode != 0:
        raise SystemExit(f"XƏTA: piper uğursuz oldu:\n{proc.stderr[-2000:]}")


def to_mp3(wav: Path, mp3: Path) -> None:
    mp3.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
         "-codec:a", "libmp3lame", "-b:a", MP3_BITRATE, "-ac", "1", str(mp3)],
        check=True,
    )


def main() -> None:
    ap = argparse.ArgumentParser(description="Səsli kitab qur (Gutenberg → MP3)")
    ap.add_argument("--book", default="aesop", choices=sorted(BOOKS))
    ap.add_argument("--limit", type=int, default=0, help="yalnız ilk N fəsil (0 = hamısı)")
    ap.add_argument("--out", default=str(ROOT / "audiobooks_out"))
    args = ap.parse_args()

    meta = BOOKS[args.book]
    lang = meta.get("lang", "en")
    out_dir = Path(args.out)
    audio_dir = out_dir / args.book
    wav_dir = TOOLS / "wav" / args.book

    print(f"=== {meta['title_az']} ({args.book}, {lang}) ===")
    exe, model = ensure_piper(lang)

    raw = fetch_book_text(meta["gutenberg_id"])
    body = after_last_marker(strip_gutenberg_wrapper(raw), meta["body_marker"])
    chapters = drop_non_narrative(split_chapters(body), min_words=meta["min_words"])
    if args.limit:
        chapters = chapters[: args.limit]
    if not chapters:
        raise SystemExit("XƏTA: heç bir fəsil tapılmadı — bölücü qaydasını yoxla.")
    print(f"  fəsil: {len(chapters)}")

    # Səsləndirmədə başlıq da oxunur (səsli kitab hissi üçün).
    jobs = [
        (c.chapter_id, f"{humanize_title(c.title_en)}.\n\n{c.text}")
        for c in chapters
    ]
    print("  səsləndirilir (Piper) …")
    synth_all(exe, model, jobs, wav_dir)

    print("  MP3-ə çevrilir (ffmpeg) …")
    measured: dict[str, tuple[float, int]] = {}
    for c in chapters:
        wav = wav_dir / f"{c.chapter_id}.wav"
        if not wav.exists():
            raise SystemExit(f"XƏTA: WAV yaranmayıb: {wav}")
        mp3 = audio_dir / f"{c.chapter_id}.mp3"
        to_mp3(wav, mp3)
        measured[c.chapter_id] = (probe_duration(mp3), mp3.stat().st_size)

    manifest = build_manifest(
        book_id=args.book,
        title_en=meta["title_en"],
        title_az=meta["title_az"],
        author=meta["author"],
        source=meta["source"],
        level=meta["level"],
        chapters=chapters,
        measured=measured,
        lang=lang,
    )
    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    total_sec = sum(d for d, _ in measured.values())
    total_mb = sum(s for _, s in measured.values()) / 1024 / 1024
    print(f"\n=== HAZIR ===")
    print(f"  {len(chapters)} fəsil | {total_sec/60:.1f} dəq | {total_mb:.1f} MB")
    print(f"  {manifest_path}")
    print(f"  {audio_dir}")


if __name__ == "__main__":
    main()
