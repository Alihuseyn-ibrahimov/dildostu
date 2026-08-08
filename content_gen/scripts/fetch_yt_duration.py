"""YouTube video müddətini səhifədən oxuyur (tək dəfəlik alət)."""
import re
import sys

import httpx

for vid in sys.argv[1:]:
    r = httpx.get(f"https://www.youtube.com/watch?v={vid}", timeout=20, follow_redirects=True)
    m = re.search(r'"lengthSeconds":"(\d+)"', r.text)
    print(vid, m.group(1) if m else "NA")
