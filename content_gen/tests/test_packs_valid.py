"""Generasiya olunmuş bütün paket fayllarının sxemə uyğunluğunu yoxlayır.

Bu test app-a düşən əsl JSON-lar üzərində işləyir — bir paket korlanarsa
və ya əl ilə düzəliş sxemi pozarsa, dərhal tutulur.
"""

import json
from pathlib import Path

import pytest

from dildostu_content.categories import CATEGORIES
from dildostu_content.schema import validate_pack

PACKS_DIR = Path(__file__).resolve().parents[2] / "app" / "assets" / "packs"


def _pack_files():
    return sorted(PACKS_DIR.glob("*.json"))


def test_all_categories_have_a_pack():
    have = {p.stem for p in _pack_files()}
    expected = {c.pack_id for c in CATEGORIES}
    assert expected <= have, f"Çatışmayan paketlər: {expected - have}"


@pytest.mark.parametrize("path", _pack_files(), ids=lambda p: p.stem)
def test_pack_file_valid(path):
    pack = json.loads(path.read_text(encoding="utf-8"))
    validate_pack(pack)
    assert pack["pack_id"] == path.stem
    assert len(pack["words"]) >= 8
