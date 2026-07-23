"""Tətbiq buraxılışları (APK + versiya) — kod deploy-undan ayrı qovluqda.

`releases/` kodun tar+scp deploy-u ilə ÜZƏRİNƏ YAZILMIR — ayrıca scp ilə
yenilənir (bax `deploy/publish_release.ps1`). Bu, kod push tezliyi ilə APK
buraxılış tezliyini ayırır.
"""

from __future__ import annotations

import json
from pathlib import Path


class ReleaseStore:
    def __init__(self, releases_dir: str = "releases") -> None:
        self._dir = Path(releases_dir)

    def version_info(self) -> dict | None:
        """`version.json`-u oxuyur; yoxdursa `None` (heç bir buraxılış yoxdur)."""
        path = self._dir / "version.json"
        if not path.exists():
            return None
        # utf-8-sig: Windows PowerShell `Set-Content -Encoding utf8` BOM əlavə
        # edir; bu, BOM-lu və BOM-suz faylların ikisini də düzgün oxuyur.
        return json.loads(path.read_text(encoding="utf-8-sig"))

    def apk_path(self) -> Path | None:
        path = self._dir / "latest.apk"
        return path if path.exists() else None
