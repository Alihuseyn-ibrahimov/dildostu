"""Gutenberg mətn strukturunu yoxlamaq üçün müvəqqəti skript."""
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / ".tools"
TOOLS.mkdir(exist_ok=True)

for gid in (22065, 36805):
    url = f"https://www.gutenberg.org/cache/epub/{gid}/pg{gid}.txt"
    dest = TOOLS / f"gutenberg_{gid}.txt"
    if not dest.exists():
        print("downloading", gid)
        urllib.request.urlretrieve(url, dest)
    text = dest.read_text(encoding="utf-8", errors="replace")
    print(f"\n=== {gid} ({len(text)} chars) ===")
    start = text.find("*** START")
    chunk = text[start : start + 5000] if start >= 0 else text[:5000]
    for i, ln in enumerate(chunk.splitlines()[:70]):
        print(f"{i:3}: {ln[:110]}")
