"""Foursquare Places kateqoriyalarını DilDostu söz paketinə çevirir.

Foursquare hər yerə bir və ya bir neçə kateqoriya verir (məs. "Coffee Shop",
"Shopping Mall"). Biz kateqoriya ADINDAKI açar sözə görə paketə uyğunlaşdırırıq
— bu, konkret kateqoriya ID-lərini əzbərləməkdən daha davamlıdır (taksonomiya
dəyişsə də ad sabit qalır).

Uyğun paket tapılmasa `None` qaytarır (ContextEngine vaxt qaydasına düşür).
"""

from __future__ import annotations

import re

# Sıra ƏHƏMİYYƏTLİDİR — ən spesifik qayda əvvəl yoxlanır. Məsələn "Coffee Shop"
# həm "coffee" (cafe), həm "shop" (market) açarını daşıyır; cafe qaydası market-dən
# əvvəl olduğu üçün düzgün "cafe" seçilir.
_RULES: list[tuple[tuple[str, ...], str]] = [
    (("airport",), "airport"),
    (("pharmacy", "drugstore", "chemist"), "pharmacy"),
    (
        ("hotel", "hostel", "motel", "resort", "bed and breakfast", "guest house"),
        "hotel",
    ),
    (
        (
            "café", "cafe", "coffee", "tea room", "teahouse", "bakery",
            "bubble tea", "patisserie", "pastry", "dessert", "ice cream",
            "juice bar", "smoothie", "donut", "creperie",
        ),
        "cafe",
    ),
    (
        (
            "restaurant", "diner", "steakhouse", "pizzeria", "bistro", "eatery",
            "fast food", "food court", "bbq", "burger", "kebab", "bar", "pub",
            "brewery", "taverna", "food truck", "snack", "canteen", "grill",
            "pizza", "sushi", "noodle", "ramen", "seafood", "sandwich",
            "salad", "breakfast", "brunch", "buffet", "dining", "cafeteria",
            "wings", "taqueria", "shawarma", "dumpling",
        ),
        "restaurant",
    ),
    (
        (
            "mall", "supermarket", "grocery", "market", "shopping", "store",
            "shop", "boutique", "retail", "bazaar", "convenience", "deli",
            "grocer", "butcher", "greengrocer", "kiosk", "newsstand",
            "liquor", "wine", "florist", "optic", "hardware",
        ),
        "market",
    ),
    (
        (
            "bus", "train", "metro", "subway", "transit", "rail", "station",
            "platform", "tram", "transport", "ferry", "taxi", "terminal",
            "harbor", "harbour", "seaport", "funicular", "cable car",
        ),
        "transport",
    ),
]


def _pattern(keyword: str) -> re.Pattern[str]:
    r"""Açar sözü SÖZ SƏRHƏDİ ilə uyğunlaşdıran şablon (`\bkeyword s?\b`).

    Sadə `in` yoxlaması yalan uyğunluqlar verirdi: "Barbershop" içində "bar"
    görünürdü (→ restaurant), "Sports Club" içində "port" (→ transport).
    Sonda `s?` cəm formanı tutur — Foursquare `plural_name` göndərir
    ("Cafés", "Hotels").
    """
    return re.compile(rf"\b{re.escape(keyword)}s?\b", re.IGNORECASE)


_COMPILED: list[tuple[tuple[re.Pattern[str], ...], str]] = [
    (tuple(_pattern(k) for k in keywords), pack_id) for keywords, pack_id in _RULES
]


def pack_id_for_foursquare(categories: list[dict]) -> str | None:
    """Foursquare kateqoriya siyahısından DilDostu paketini tap.

    `categories` — Foursquare cavabındakı `categories` massivi; hər element
    ən azı `name` (və ya `short_name`) daşıyır. Uyğunluq registrə həssas deyil.
    """
    names: list[str] = []
    for cat in categories:
        for key in ("name", "short_name", "plural_name"):
            value = cat.get(key)
            if isinstance(value, str) and value:
                names.append(value)

    for patterns, pack_id in _COMPILED:
        for name in names:
            if any(pattern.search(name) for pattern in patterns):
                return pack_id
    return None
