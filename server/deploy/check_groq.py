"""Groq-u birbaşa yoxla (fallback-sız): hansı model, cavab gəlirmi.

Serverdə: cd /opt/dildostu/server && .venv/bin/python deploy/check_groq.py
Açar dəyəri çap olunmur.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dildostu_server import providers  # noqa: E402

completers = providers.build_completers()
print("GROQ_MODEL:", providers.GROQ_MODEL)
if "groq" not in completers:
    print("XƏTA: GROQ_API_KEY yoxdur (.env)")
    sys.exit(2)
try:
    out = completers["groq"]("Reply with a JSON object only.", 'Return {"ok": true}')
except Exception as e:  # noqa: BLE001 — diaqnostika: xətanı olduğu kimi göstər
    print(f"UĞURSUZ: {type(e).__name__}: {str(e)[:300]}")
    sys.exit(1)
print("CAVAB:", out[:200])
