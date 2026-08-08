"""Rutin nümunələrini tez-tez gedilən yerlərə (geofence namizədləri) qruplaşdırır.

Təmiz funksiyalar — heç bir I/O yoxdur, `routine_store.py`-dən gələn nümunə
siyahısı üzərində işləyir (bax spec: docs/superpowers/specs/
2026-07-23-dildostu-routine-faza3-design.md, Alt-mərhələ 3b).
"""

from __future__ import annotations

import math
from collections import Counter
from datetime import datetime

_EARTH_RADIUS_M = 6_371_000.0
# Azərbaycan sabit UTC+4-dür (2016-dan yay vaxtı yoxdur). Nümunə vaxtları
# serverdə UTC saxlanır, gün hissəsi isə istifadəçinin yerli saatına görə
# hesablanmalıdır.
_LOCAL_UTC_OFFSET_HOURS = 4


def haversine_distance_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """İki koordinat arası məsafə (metr)."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)
    a = (
        math.sin(d_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    )
    return 2 * _EARTH_RADIUS_M * math.asin(math.sqrt(a))


def _hour_window(ts: str) -> str:
    """Gün hissəsi (informativ metadata — bildiriş göndərmə şərti deyil).

    `ts` serverdə UTC saxlanır, istifadəçilər isə Azərbaycandadır — ona görə
    YERLİ vaxta çevrilir. Əvvəllər UTC saatı birbaşa işlədilirdi və yerli
    səhər 07:00 (03:00 UTC) "night" kimi qeyd olunurdu.
    Azərbaycan 2016-dan yay vaxtı tətbiq etmir, sabit UTC+4.
    """
    try:
        hour = (datetime.fromisoformat(ts).hour + _LOCAL_UTC_OFFSET_HOURS) % 24
    except ValueError:
        return "unknown"
    if 6 <= hour < 12:
        return "morning"
    if 12 <= hour < 17:
        return "afternoon"
    if 17 <= hour < 22:
        return "evening"
    return "night"


def cluster_places(
    samples: list[dict],
    *,
    radius_m: float = 100.0,
    min_count: int = 3,
) -> list[dict]:
    """Yaxın nümunələri (≤`radius_m`) qruplaşdırır; ≥`min_count` təkrarlanan
    qrupları qaytarır (say azalan sırada).

    Hər qrup: {center_lat, center_lng, radius, pack_id, label, hour_window,
    count}. `pack_id`/`label` qrupdakı ən çox rast gəlinən dəyərdir (pack_id
    yoxdursa place_type işlədilir).
    """
    clusters: list[dict] = []

    for sample in samples:
        lat, lng = sample["lat"], sample["lng"]
        pack_id = sample.get("pack_id") or sample["place_type"]
        placed = False
        for cluster in clusters:
            center_lat = cluster["_lat_sum"] / cluster["count"]
            center_lng = cluster["_lng_sum"] / cluster["count"]
            if haversine_distance_m(center_lat, center_lng, lat, lng) <= radius_m:
                cluster["_lat_sum"] += lat
                cluster["_lng_sum"] += lng
                cluster["count"] += 1
                cluster["_pack_ids"][pack_id] += 1
                cluster["_hours"][_hour_window(sample["ts"])] += 1
                cluster["_points"].append((lat, lng))
                placed = True
                break
        if not placed:
            clusters.append(
                {
                    "_lat_sum": lat,
                    "_lng_sum": lng,
                    "count": 1,
                    "_pack_ids": Counter({pack_id: 1}),
                    "_hours": Counter({_hour_window(sample["ts"]): 1}),
                    "_points": [(lat, lng)],
                }
            )

    result = []
    for cluster in clusters:
        if cluster["count"] < min_count:
            continue
        center_lat = cluster["_lat_sum"] / cluster["count"]
        center_lng = cluster["_lng_sum"] / cluster["count"]
        spread = max(
            haversine_distance_m(center_lat, center_lng, p[0], p[1])
            for p in cluster["_points"]
        )
        pack_id = cluster["_pack_ids"].most_common(1)[0][0]
        result.append(
            {
                "center_lat": center_lat,
                "center_lng": center_lng,
                "radius": max(100.0, round(spread + 30, 1)),
                "pack_id": pack_id,
                "label": pack_id,
                "hour_window": cluster["_hours"].most_common(1)[0][0],
                "count": cluster["count"],
            }
        )

    result.sort(key=lambda g: -g["count"])
    return result
