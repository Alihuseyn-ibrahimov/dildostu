"""Server manifestinə yeni kitab əlavə et — mövcud kitabları silmə."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "audiobooks_out"


def main() -> None:
    book_id = sys.argv[1] if len(sys.argv) > 1 else "harrison"
    local = json.loads((OUT / "manifest.json").read_text(encoding="utf-8-sig"))
    server_path = OUT / "server_manifest.json"
    if server_path.exists():
        merged = json.loads(server_path.read_text(encoding="utf-8-sig"))
    else:
        merged = {"version": 1, "books": []}

    new_book = next(b for b in local["books"] if b["book_id"] == book_id)
    merged["books"] = [b for b in merged["books"] if b["book_id"] != book_id] + [new_book]
    merged["version"] = local.get("version", 1)

    out_path = OUT / "manifest_deploy.json"
    out_path.write_text(json.dumps(merged, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"deploy manifest: {len(merged['books'])} kitab")
    for b in merged["books"]:
        print(f"  - {b['book_id']} ({b.get('lang','en')}, {b.get('level')}, {len(b['chapters'])} fəsil)")


if __name__ == "__main__":
    main()
