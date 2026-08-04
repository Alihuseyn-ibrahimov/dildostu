"""AI mətn cavabını LiveMessage-lərə çevirən parser (təmiz, testlənən)."""

from __future__ import annotations

import json
import re

from pydantic import ValidationError

from .models import Context, LiveMessage, WordLookupResponse


def _extract_json(text: str):
    """Sərbəst mətndən ilk JSON obyektini çıxarıb yüklə."""
    fenced = re.search(r"```(?:json)?\s*(.+?)```", text, re.DOTALL)
    candidate = fenced.group(1) if fenced else text
    start = candidate.find("{")
    end = candidate.rfind("}")
    if start == -1 or end <= start:
        raise ValueError("Cavabda JSON tapılmadı")
    try:
        return json.loads(candidate[start : end + 1])
    except json.JSONDecodeError as exc:
        raise ValueError(f"JSON parse xətası: {exc}") from exc


def parse_generate_response(text: str, context: Context) -> LiveMessage:
    """/generate cavabını LiveMessage-ə çevir (pack_id kontekstdən)."""
    obj = _extract_json(text)
    obj["pack_id"] = context.pack_id
    try:
        return LiveMessage(**obj)
    except ValidationError as exc:
        raise ValueError(f"LiveMessage sxem xətası: {exc}") from exc


def parse_word_lookup_response(text: str, word: str) -> WordLookupResponse:
    """Söz axtarışı cavabını çevir (word AI-nin cavabına yox, sorğuya görə)."""
    obj = _extract_json(text)
    obj["word"] = word
    try:
        return WordLookupResponse(**obj)
    except ValidationError as exc:
        raise ValueError(f"WordLookup sxem xətası: {exc}") from exc


def parse_dayplan_response(text: str, pack_ids: list[str]) -> list[LiveMessage]:
    """/day-plan cavabını LiveMessage siyahısına çevir.

    pack_id verilməyibsə, verilmiş sıraya görə doldurulur.
    """
    obj = _extract_json(text)
    raw = obj.get("messages")
    if not isinstance(raw, list) or not raw:
        raise ValueError("day-plan cavabında 'messages' massivi yoxdur")

    messages: list[LiveMessage] = []
    for i, item in enumerate(raw):
        if not isinstance(item, dict):
            raise ValueError(f"messages[{i}] obyekt deyil")
        if not item.get("pack_id") and i < len(pack_ids):
            item["pack_id"] = pack_ids[i]
        try:
            messages.append(LiveMessage(**item))
        except ValidationError as exc:
            raise ValueError(f"messages[{i}] sxem xətası: {exc}") from exc
    return messages
