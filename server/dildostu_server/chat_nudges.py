"""Proaktiv chat bildirişləri — səhər/nahar/axşam slotları (AI-siz).

App hər gün 08:00, 13:00 və 22:00-da planlaşdırır. Mətnlər günün
ordinalına görə fərqli şablondan seçilir (hər gün bir az fərqli).
"""

from __future__ import annotations

from datetime import date, datetime, timezone

from .models import ChatNudgeItem, UserProfile

PACK_TITLES_AZ: dict[str, str] = {
    "morning": "Səhər",
    "greetings": "Salamlaşma",
    "cafe": "Kafedə",
    "restaurant": "Restoranda",
    "market": "Marketdə",
    "airport": "Aeroportda",
    "hotel": "Oteldə",
    "transport": "Nəqliyyatda",
    "pharmacy": "Aptekdə",
    "evening": "Axşam",
}

LANG_LABELS_AZ: dict[str, str] = {
    "en": "ingilis",
    "ru": "rus",
    "es": "ispan",
    "it": "italyan",
}

# (body, quick_prompt) — {lang} və {place} placeholder-ları doldurulur.
MORNING_TEMPLATES: list[tuple[str, str]] = [
    (
        "Sabahın xeyir! ☀️ Gəl 5 dəqiqəni ayır — bu günü {lang} ilə faydalı başlayaq.",
        "Bu gün üçün 3 faydalı söz",
    ),
    (
        "Günaydın! 🌅 5 dəqiqəlik mini dərs — günə enerjili başla.",
        "Sabah salamlaşması necə deyilir?",
    ),
    (
        "Sabahın xeyir! LachinGo burada — 5 dəqiqə ayır, {lang} sözləri ilə günə start ver.",
        "Günə enerjili başlamaq üçün 3 ifadə",
    ),
    (
        "Yeni gün, yeni sözlər! ☀️ 5 dəqiqəni ayır — birlikdə faydalı başlayaq.",
        "Bu gün üçün 3 faydalı söz",
    ),
    (
        "Sabahın xeyir! Günün ilk 5 dəqiqəsini {lang} öyrənməyə ayırmaq istəyirsən?",
        "Sabah rutini üçün 3 ifadə",
    ),
    (
        "Günaydın! ☕ 5 dəqiqə kifayətdir — bu günü {lang} ilə güclü başlat.",
        "Bu gün üçün 3 faydalı söz",
    ),
    (
        "Sabahın xeyir! ✈️ Səyahətə hazırlaş — 5 dəqiqəlik {lang} ilə günə başla.",
        "Aeroportda check-in necə deyilir?",
    ),
]

LUNCH_TEMPLATES: list[tuple[str, str]] = [
    (
        "Nahar fasiləsindəsən? 🍽️ Gəl bu vaxtı dəyərləndirək — 5 dəqiqəlik {lang} sual-cavab.",
        "Restoranda sifariş necə verilir?",
    ),
    (
        "Fasilə vaxtı! ☕ 5 dəqiqəni ayır — nahar arasında {lang} öyrən.",
        "Nahar menyusunda nə demək olar?",
    ),
    (
        "Nahar fasiləsi ideal vaxtdır! Gəl birlikdə 5 dəqiqə {lang} danışaq.",
        "Bu gün üçün 3 faydalı söz",
    ),
    (
        "Fasilədəsən? 🥗 Bu 5 dəqiqəni boş keçirmə — gəl praktik edək.",
        "Kafedə çay sifarişi necə deyilir?",
    ),
    (
        "Nahar vaxtı! 🍽️ Gəl sual-cavab edək — fasiləni faydalı keçir.",
        "Bu gün üçün 3 faydalı söz",
    ),
    (
        "{place} qalmışdıq — nahar fasiləsində davam edək! 5 dəqiqə kifayətdir.",
        "{place} üçün praktik ifadələr",
    ),
    (
        "Gün ortası! 🌤️ Nahar fasiləsində {lang} sözləri ilə özünü yüngülləşdir.",
        "Restoranda hesab necə istənilir?",
    ),
]

EVENING_TEMPLATES: list[tuple[str, str]] = [
    (
        "Yatmamış — gəl bu gün öyrəndiklərimizi təkrar edək 🌙",
        "Bu gün öyrəndiklərimi təkrar et",
    ),
    (
        "Günün sonu! 🌙 Yatmadan əvvəl 5 dəqiqəlik {lang} təkrarı edək.",
        "Axşam üçün 3 faydalı söz",
    ),
    (
        "Axşam saatı — öyrəndiklərimizi birlikdə xatırlayaq? 📚",
        "Bu günün qısa xülasəsi",
    ),
    (
        "Yatmadan əvvəl qısa təkrar — bu gün nə öyrənmişik? 🌙",
        "Bu gün öyrəndiklərimi təkrar et",
    ),
    (
        "Günü yaxşı bitirək! 🌙 5 dəqiqəlik {lang} təkrarı — yatmadan əvvəl.",
        "Axşam üçün 3 faydalı söz",
    ),
    (
        "Axşamın xeyir! 🌙 Gəl bu gün öyrəndiklərimizi bir daha təkrar edək.",
        "Bu gün öyrəndiklərimi təkrar et",
    ),
    (
        "Yatma vaxtı yaxındır — 5 dəqiqə ayır, {lang} sözlərini möhkəmləndir.",
        "Bu günün qısa xülasəsi",
    ),
]


def _place_title(pack_id: str | None, place_type: str) -> str:
    if pack_id and pack_id in PACK_TITLES_AZ:
        return PACK_TITLES_AZ[pack_id]
    if pack_id:
        return pack_id
    return place_type


def _top_place(places: list[dict]) -> str | None:
    for place in places:
        pack_id = place.get("pack_id")
        if pack_id:
            return _place_title(pack_id, str(place.get("place_type", pack_id)))
    return None


def _days_since(iso: str) -> float | None:
    try:
        ts = datetime.fromisoformat(iso.replace("Z", "+00:00"))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        return (datetime.now(timezone.utc) - ts).total_seconds() / 86400
    except (TypeError, ValueError):
        return None


def _pick(
    templates: list[tuple[str, str]], day: int, *, lang: str, place: str | None
) -> ChatNudgeItem:
    body_tpl, prompt_tpl = templates[day % len(templates)]
    place_text = place or "Son dəfə öyrəndiyimiz yerdə"
    body = body_tpl.format(lang=lang, place=place_text)
    prompt = prompt_tpl.format(lang=lang, place=place_text)
    return ChatNudgeItem(body=body, quick_prompt=prompt)


def build_chat_nudges(
    *,
    profile: UserProfile,
    places: list[dict],
    facts: list[str],
    last_user_at: str | None,
    on_date: date | None = None,
) -> list[ChatNudgeItem]:
    """Sıra: səhər (08:00), nahar (13:00), axşam (22:00)."""
    day = (on_date or date.today()).toordinal()
    lang = LANG_LABELS_AZ.get(profile.target_lang, "ingilis")
    place = _top_place(places)

    morning = _pick(MORNING_TEMPLATES, day, lang=lang, place=place)
    if profile.purpose == "travel" and day % 3 == 0:
        morning = ChatNudgeItem(
            body=(
                f"Sabahın xeyir! ✈️ Səyahətə hazırlaş — 5 dəqiqəlik {lang} "
                "ilə günə faydalı başla."
            ),
            quick_prompt="Aeroportda check-in necə deyilir?",
        )

    lunch = _pick(LUNCH_TEMPLATES, day + 1, lang=lang, place=place)

    evening = _pick(EVENING_TEMPLATES, day + 2, lang=lang, place=place)
    if last_user_at:
        inactive = _days_since(last_user_at)
        if inactive is not None and inactive >= 2:
            evening = ChatNudgeItem(
                body=(
                    "Səni darıxdım! 🌙 Yatmamış qısa təkrar edək — "
                    f"5 dəqiqəlik {lang} kifayətdir."
                ),
                quick_prompt="Bu gün öyrəndiklərimi təkrar et",
            )
    elif facts:
        fact = facts[-1].strip()
        if len(fact) > 60:
            fact = fact[:57] + "..."
        evening = ChatNudgeItem(
            body=f"Axşamın xeyir! 🌙 {fact} — gəl bu gün öyrəndiklərimizi təkrar edək.",
            quick_prompt="Bu günün qısa xülasəsi",
        )

    return [morning, lunch, evening]
