import json
from pathlib import Path

m = json.loads(Path("audiobooks_out/manifest.json").read_text(encoding="utf-8"))
book = next(b for b in m["books"] if b["book_id"] == "harrison")
print("chapters", len(book["chapters"]))
for ch in book["chapters"]:
    w = len(ch["text"].split())
    print(f"{ch['chapter_id'][:40]:40} {w:5}w  {ch['title_en'][:55]}")
