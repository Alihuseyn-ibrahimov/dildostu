"""DilDostu MVP kateqoriyaları — hər biri bir söz paketinə çevrilir.

`context_hint` yalnız AI-a situasiyanı izah etmək üçündür (prompt-a düşür),
app-a düşən JSON-a girmir. `pack_id` app tərəfdə asset faylının adıdır.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Category:
    pack_id: str
    title_az: str
    context_hint: str


CATEGORIES: tuple[Category, ...] = (
    Category(
        "morning",
        "Səhər rutini",
        "Waking up, morning greetings, breakfast, getting ready for the day.",
    ),
    Category(
        "greetings",
        "Salamlaşma və tanışlıq",
        "Meeting people, introductions, polite small talk, saying goodbye.",
    ),
    Category(
        "cafe",
        "Kafedə",
        "Ordering coffee/tea, asking for the bill, simple café interactions.",
    ),
    Category(
        "restaurant",
        "Restoranda",
        "Reserving a table, ordering a meal, dietary needs, paying at a restaurant.",
    ),
    Category(
        "market",
        "Marketdə / alış-veriş",
        "Grocery shopping, asking prices, quantities, checkout at a shop.",
    ),
    Category(
        "airport",
        "Hava limanında",
        "Check-in, boarding, security, gates, baggage, flight delays.",
    ),
    Category(
        "hotel",
        "Oteldə",
        "Checking in/out, room requests, hotel amenities, asking for help.",
    ),
    Category(
        "transport",
        "Nəqliyyat",
        "Taxi, bus, metro, buying tickets, asking for directions.",
    ),
    Category(
        "pharmacy",
        "Aptekdə",
        "Buying medicine, describing symptoms, dosage, basic health needs.",
    ),
    Category(
        "evening",
        "Axşam / günün sonu",
        "Evening routine, relaxing, dinner, going to sleep, reflecting on the day.",
    ),
)


def by_id(pack_id: str) -> Category:
    for category in CATEGORIES:
        if category.pack_id == pack_id:
            return category
    raise KeyError(f"Naməlum kateqoriya: {pack_id!r}")
