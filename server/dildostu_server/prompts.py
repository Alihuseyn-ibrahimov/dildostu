"""Prompt qurma və provayder yönləndirmə — təmiz funksiyalar (şəbəkəsiz).

AI çağırışları ayrı `providers.py`-dədir; buradakı hər şey unit test olunur.
"""

from __future__ import annotations

from .models import Context, Level, Mode, UserProfile

_PURPOSE_AZ = {
    "travel": "səyahət üçün",
    "work": "iş üçün",
    "general": "ümumi məqsədlə",
}

# Spec §2 — səviyyələrin konkret tərifi. AI-nin "çətin"i subyektiv seçməməsi
# üçün söz tipi, cümlə uzunluğu və qrammatika açıq yazılır.
_LEVEL_RULES: dict[str, str] = {
    "beginner": (
        "SƏVİYYƏ: Asan (beginner). Ən çox işlənən TƏK sözlər seç "
        "(gündəlik lüğətin ilk 500 sözü). Nümunə cümlə 4-6 sözdən ibarət, "
        "yalnız indiki zaman. Məcazi mənalı ifadələri və çoxsözlü feil "
        'birləşmələrini İŞLƏTMƏ. "level" sahəsi 1 olmalıdır.'
    ),
    "intermediate": (
        "SƏVİYYƏ: Orta (intermediate). İfadələr və frazalar seç (tək söz yox). "
        "Nümunə cümlə 6-10 sözdən ibarət; keçmiş və gələcək zaman, modal "
        "feillər (can/should/would) işlət. "
        '"level" sahəsi 2 olmalıdır.'
    ),
    "advanced": (
        "SƏVİYYƏ: Çətin (advanced). Phrasal verb, idiom və nüanslı sözlər seç. "
        "Nümunə cümlə 10-15 sözdən ibarət; şərt cümlələri (if/unless) və "
        "passiv quruluş işlət. "
        '"level" sahəsi 3 olmalıdır.'
    ),
}


def level_instruction(level: Level) -> str:
    """Səviyyə üçün AI təlimatı (spec §2 cədvəli).

    Naməlum səviyyə gəlsə orta səviyyəyə düşür — prompt qurma heç vaxt
    sınmamalıdır (pydantic onsuz da dəyəri doğrulayır).
    """
    return _LEVEL_RULES.get(level, _LEVEL_RULES["intermediate"])

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
    """Profil sətri + seçilmiş səviyyənin konkret qaydaları (spec §2)."""
    interests = ", ".join(profile.interests) if profile.interests else "yoxdur"
    return (
        f"İstifadəçi profili: məqsəd={profile.purpose} "
        f"({_PURPOSE_AZ[profile.purpose]}), maraqlar: {interests}.\n"
        f"{level_instruction(profile.level)}"
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


def build_pack_words_prompt(
    profile: UserProfile,
    pack_id: str,
    count: int,
) -> tuple[str, str]:
    """Bir paket üçün söz SİYAHISI (söz siyahısı ekranı) — (system, user)."""
    user = (
        f"Sən Azərbaycanca danışan istifadəçiyə İngilis dili öyrədən dostcasına "
        f"AI köməkçisən.\n{_profile_line(profile)}\n"
        f"'{pack_id}' kontekstində ən faydalı {count} söz/ifadə seç. "
        f"Sözlər bir-birini TƏKRAR ETMƏMƏLİ və eyni situasiyanın müxtəlif "
        f"tərəflərini əhatə etməlidir.\n\n"
        f"Hər element üçün sahələr:\n{_WORD_FIELDS_DESC}\n"
        f'- "pack_id": "{pack_id}"\n\n'
        'Yalnız bu formada JSON qaytar: {"messages": [ {pack_id, word, '
        'translation_az, ipa, example, example_az, ai_line, level}, ... ]} '
        f"— dəqiq {count} element."
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
        f"məqsəd: {profile.purpose}.{ctx}\n"
        f"{level_instruction(profile.level)}"
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
