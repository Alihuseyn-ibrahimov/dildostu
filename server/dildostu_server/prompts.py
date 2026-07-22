"""Prompt qurma və provayder yönləndirmə — təmiz funksiyalar (şəbəkəsiz).

AI çağırışları ayrı `providers.py`-dədir; buradakı hər şey unit test olunur.
"""

from __future__ import annotations

from .models import Context, Mode, UserProfile

_PURPOSE_AZ = {
    "travel": "səyahət üçün",
    "work": "iş üçün",
    "general": "ümumi məqsədlə",
}

_MODE_INSTRUCTION = {
    "normal": "Situasiyaya uyğun faydalı bir söz/ifadə seç.",
    "another_example": "Eyni kontekstdə FƏRQLİ, yeni bir söz/ifadə seç.",
    "simpler": "Daha SADƏ, başlanğıc səviyyəsinə uyğun söz və nümunə seç.",
    "harder": "Daha ÇƏTİN, irəli səviyyəyə uyğun söz və nümunə seç.",
}

_SYSTEM = "You output only valid JSON. No commentary."

_WORD_FIELDS_DESC = (
    '- "word": İngilis söz/qısa ifadə (kiçik hərflə, xüsusi ad istisna)\n'
    '- "translation_az": təbii Azərbaycan tərcüməsi (düzgün ə,ı,ö,ü,ğ,ç,ş)\n'
    '- "ipa": IPA transkripsiya, məs. /rɪˈsiːt/\n'
    '- "example": qısa təbii İngilis cümlə (böyük hərf + . və ya ?)\n'
    '- "example_az": həmin cümlənin Azərbaycan tərcüməsi\n'
    '- "ai_line": istifadəçiyə dostcasına, motivasiyalı bir Azərbaycan cümləsi '
    "(kontekstə uyğun, məs. \"İndi kafedəsən — kofe sifarişini məşq edək!\")\n"
    '- "level": çətinlik 1 (çox adi) - 3 (irəli)'
)


def preferred_providers(mode: Mode) -> list[str]:
    """Mode-a görə provayder sırası: adi → Groq (ucuz); fərdi → Claude (keyfiyyət).

    Hər ikisində fallback var (biri uğursuz olsa digəri).
    """
    if mode == "normal":
        return ["groq", "claude"]
    return ["claude", "groq"]


def _profile_line(profile: UserProfile) -> str:
    interests = ", ".join(profile.interests) if profile.interests else "yoxdur"
    return (
        f"İstifadəçi profili: səviyyə={profile.level} (beginner/intermediate), "
        f"məqsəd={profile.purpose} ({_PURPOSE_AZ[profile.purpose]}), "
        f"maraqlar: {interests}."
    )


def build_generate_prompt(
    profile: UserProfile,
    context: Context,
    mode: Mode,
    recent_words: list[str],
) -> tuple[str, str]:
    """Bir fərdi mesaj üçün (system, user) prompt qur."""
    place = f" (məkan: {context.place})" if context.place else ""
    exclude = (
        f"\nBu sözləri TƏKRAR ETMƏ (artıq öyrədilib): {', '.join(recent_words)}."
        if recent_words
        else ""
    )
    user = (
        f"Sən Azərbaycanca danışan istifadəçiyə İngilis dili öyrədən dostcasına "
        f"AI köməkçisən.\n{_profile_line(profile)}\n"
        f"Cari kontekst: '{context.pack_id}'{place}, saat {context.hour}.\n"
        f"{_MODE_INSTRUCTION[mode]}{exclude}\n\n"
        f"Hər sahə üçün:\n{_WORD_FIELDS_DESC}\n\n"
        'Yalnız bu formada JSON obyekti qaytar: '
        '{"word":..., "translation_az":..., "ipa":..., "example":..., '
        '"example_az":..., "ai_line":..., "level":...}'
    )
    return _SYSTEM, user


def chat_preferred_providers() -> list[str]:
    """Söhbət üçün provayder sırası: Claude (keyfiyyət) → Groq (fallback)."""
    return ["claude", "groq"]


def build_chat_system(profile: UserProfile, context: Context | None) -> str:
    """Söhbət üçün system prompt — Azərbaycanca İngilis dili müəllimi personası."""
    ctx = ""
    if context is not None:
        ctx = (
            f"\nİstifadəçi hazırda '{context.pack_id}' kontekstindədir "
            f"(saat {context.hour}) — cavablarını buna uyğunlaşdıra bilərsən."
        )
    return (
        "Sən DilDostu-san — Azərbaycanca danışan istifadəçiyə İngilis dili "
        "öyrədən dostcasına, səbirli AI müəllim. Həmişə AZƏRBAYCANCA cavab ver "
        "(İngilis söz/ifadələri nümunə kimi ver). Cavabların qısa, praktik və "
        "cəsarətləndirici olsun. İstifadəçi soruşanda tələffüz, nümunə cümlə və "
        "sadə izah ver.\n"
        f"İstifadəçi səviyyəsi: {profile.level} (beginner/intermediate); "
        f"məqsəd: {profile.purpose}.{ctx}"
    )


def build_dayplan_prompt(
    profile: UserProfile,
    pack_ids: list[str],
    date: str,
) -> tuple[str, str]:
    """Günün mesaj dəsti üçün (system, user) prompt qur (batch)."""
    user = (
        f"Sən Azərbaycanca danışan istifadəçiyə İngilis dili öyrədən dostcasına "
        f"AI köməkçisən.\n{_profile_line(profile)}\n"
        f"Tarix: {date}. Aşağıdakı kontekstlərin HƏR BİRİ üçün bir söz/ifadə seç "
        f"(sıra ilə): {', '.join(pack_ids)}.\n\n"
        f"Hər element üçün sahələr:\n{_WORD_FIELDS_DESC}\n"
        '- "pack_id": həmin kontekstin id-si\n\n'
        'Yalnız bu formada JSON qaytar: {"messages": [ {pack_id, word, '
        'translation_az, ipa, example, example_az, ai_line, level}, ... ]} '
        f"— dəqiq {len(pack_ids)} element, verilmiş sıra ilə."
    )
    return _SYSTEM, user
