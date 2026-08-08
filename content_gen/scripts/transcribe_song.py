"""Mahnı videosunun səsini yükləyib real söz vaxtlarını çıxarır (bir dəfəlik alət).

İstifadə: .venv/Scripts/python scripts/transcribe_song.py <youtube_id> [dil_kodu] [--model medium]

Nəticə: konsola JSON (hər sözün başlanğıc/son vaxtı, saniyə) çap edir.
Audio faylı müvəqqəti qovluqda saxlanır, sonra silinir — repoya girmir.

`--hotwords` mahnının açar sözlərini modelə ipucu kimi verir. Musiqi üstündən
oxunan sözlərdə Whisper asanlıqla səhv eşidir ("bamba"→"banda",
"marinero"→"maninero"); ipucu bunları xeyli azaldır. `condition_on_previous_text`
söndürülü olduğu üçün ipucu HƏR seqmentə tətbiq olunur.
"""
from __future__ import annotations

import argparse
import json
import wave
from pathlib import Path

import yt_dlp
from faster_whisper import WhisperModel


def download_audio(video_id: str, out_dir: Path) -> Path:
    url = f"https://www.youtube.com/watch?v={video_id}"
    out_template = str(out_dir / f"{video_id}.%(ext)s")
    opts = {
        "format": "bestaudio/best",
        "outtmpl": out_template,
        "quiet": True,
        "postprocessors": [
            {"key": "FFmpegExtractAudio", "preferredcodec": "wav"}
        ],
        # JS runtime olmadan imza açılmır — imzasız URL verən klientləri sına.
        "extractor_args": {
            "youtube": {"player_client": ["android_vr", "ios", "android", "web"]}
        },
    }
    with yt_dlp.YoutubeDL(opts) as ydl:
        ydl.download([url])
    wav_path = out_dir / f"{video_id}.wav"
    if not wav_path.exists():
        candidates = list(out_dir.glob(f"{video_id}.*"))
        raise FileNotFoundError(f"audio tapılmadı: {candidates}")
    return wav_path


def transcribe(
    wav_path: Path,
    language: str | None,
    model_size: str = "small",
    hotwords: str | None = None,
    vad_filter: bool = False,
) -> list[dict]:
    model = WhisperModel(model_size, device="cpu", compute_type="int8")
    segments, _info = model.transcribe(
        str(wav_path),
        language=language,
        word_timestamps=True,
        vad_filter=vad_filter,
        condition_on_previous_text=False,
        hotwords=hotwords,
    )
    words = []
    for seg in segments:
        for w in seg.words or []:
            words.append({"word": w.word.strip(), "start": w.start, "end": w.end})
    return words


def main() -> None:
    parser = argparse.ArgumentParser(description="YouTube mahnısından söz-səviyyəli vaxtlar")
    parser.add_argument("youtube_id")
    parser.add_argument("language", nargs="?", default=None)
    parser.add_argument(
        "--model",
        default="small",
        help="faster-whisper model ölçüsü (small/medium/large-v3); default: small",
    )
    parser.add_argument(
        "--hotwords",
        default=None,
        help="mahnının açar sözləri (ASR-i düzgün orfoqrafiyaya yönəldir)",
    )
    parser.add_argument(
        "--vad",
        action="store_true",
        help="Silero VAD ilə səssiz hissələri kəs. DİQQƏT: musiqi üstündən "
        "oxunan mahnılarda VAD bütün səsi 'nitq deyil' sayıb SIFIR söz qaytara "
        "bilər (Un elefante-də belə oldu) — ona görə default sönülüdür",
    )
    args = parser.parse_args()
    video_id = args.youtube_id
    language = args.language

    cache_dir = Path(__file__).resolve().parents[1] / "songs_out" / "_audio_cache"
    cache_dir.mkdir(parents=True, exist_ok=True)
    wav_path = cache_dir / f"{video_id}.wav"
    if not wav_path.exists():
        download_audio(video_id, cache_dir)
    words = transcribe(wav_path, language, args.model, args.hotwords, args.vad)

    with wave.open(str(wav_path)) as wav:
        duration_ms = round(1000 * wav.getnframes() / wav.getframerate())

    payload = {"duration_ms": duration_ms, "words": words}
    out_path = Path(__file__).resolve().parents[1] / "songs_out" / f"_words_{video_id}.json"
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{len(words)} soz, {duration_ms} ms video: {out_path}")


if __name__ == "__main__":
    main()
