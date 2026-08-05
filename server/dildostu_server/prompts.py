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

# Öyrənilən dilin Azərbaycanca adı — promptlarda "İngilis dili öyrədən" kimi
# sərt mətnlərin əvəzinə işlədilir (bax spec: 2026-08-04-multilanguage-russian-design.md).
_LANGUAGE_NAMES_AZ: dict[str, str] = {
    "en": "İngilis",
    "ru": "Rus",
    "es": "İspan",
    "it": "İtalyan",
}


def language_name(target_lang: str) -> str:
    """Dil kodu → Azərbaycanca ad. Naməlum kod İngilisə düşür (heç vaxt sınmır)."""
    return _LANGUAGE_NAMES_AZ.get(target_lang, _LANGUAGE_NAMES_AZ["en"])


# Skript xəbərdarlığı — modellər (xüsusən Groq/Llama) dil adı verilsə də
# sözü LATIN HƏRFLƏRLƏ transliterasiya edə bilir (məs. "kofe" yerinə "кофе")
# və ya başqa dilin sözünü qarışdıra bilir. 2026-08-04-də content_gen
# generasiyasında real tutuldu ("kak mucho" — rus+ispan qarışığı) — hər dil
# üçün açıq skript təlimatı MƏCBURİDİR, təkcə dil adı kifayət etmir.
_SCRIPT_NOTE_AZ: dict[str, str] = {
    "en": "",
    "ru": (
        " Sözü/nümunəni HƏMİŞƏ KİRİL ƏLİFBASI ilə yaz (məs. привет, кофе) — "
        "HEÇ VAXT latın hərfləri ilə transliterasiya etmə və başqa dilin "
        "sözünü qarışdırma."
    ),
    "es": " Standart ispan yazılışını (á, é, í, ó, ú, ñ daxil) işlət.",
    "it": " Standart italyan yazılışını (à, è, ì, ò, ù daxil) işlət.",
}


def _script_note(target_lang: str) -> str:
    return _SCRIPT_NOTE_AZ.get(target_lang, "")

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


def _word_fields_desc(target_lang: str) -> str:
    lang_name = language_name(target_lang)
    return (
        f'- "word": {lang_name} söz/qısa ifadə (kiçik hərflə, xüsusi ad istisna).'
        f"{_script_note(target_lang)}\n"
        '- "translation_az": təbii Azərbaycan tərcüməsi (düzgün ə,ı,ö,ü,ğ,ç,ş)\n'
        '- "ipa": IPA transkripsiya, məs. /rɪˈsiːt/\n'
        f'- "example": qısa təbii {lang_name} cümlə (böyük hərf + . və ya ?)\n'
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


# Yumşaq yönləndirmə — kontekstə uyğun söz həmişə prioritetdir, bu yalnız
# bərabər şərtlərdə "sınaqdan keçmiş" ümumi sözə üstünlük vermək üçündür.
# 504 sözün tam siyahısını prompt-a yükləmirik (əksəriyyəti "cafe"/"airport"
# kimi konkret kontekstlərə uyğun gəlmir) — bax essential_words.py.
#
# YALNIZ İngilis üçün əlavə olunur (`_profile_line`-da) — Barron's 504
# kitabı yalnız İngiliscədir, digər dillərdə bu istinad mənasızdır.
_ESSENTIAL_NUDGE = (
    'Mümkün olduqda, "504 Essential Words" (Barron\'s) kimi sınaqdan keçmiş '
    "mənbələrdəki ən çox işlənən, gündəlik lüğətdən söz seç — amma bu, "
    "kontekstə uyğunluqdan vacib DEYİL: situasiyaya ən yaxşı uyğun gələn "
    "sözü seçməyə davam et."
)


def _intro_line(target_lang: str) -> str:
    """Bütün prompt-larda təkrarlanan giriş cümləsi, dilə görə parametrləşib."""
    return (
        f"Sən Azərbaycanca danışan istifadəçiyə {language_name(target_lang)} "
        "dili öyrədən dostcasına AI köməkçisən."
    )


def _profile_line(profile: UserProfile) -> str:
    """Profil sətri + seçilmiş səviyyənin konkret qaydaları (spec §2)."""
    interests = ", ".join(profile.interests) if profile.interests else "yoxdur"
    nudge = f"\n{_ESSENTIAL_NUDGE}" if profile.target_lang == "en" else ""
    return (
        f"İstifadəçi profili: məqsəd={profile.purpose} "
        f"({_PURPOSE_AZ[profile.purpose]}), maraqlar: {interests}.\n"
        f"{level_instruction(profile.level)}{nudge}"
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
        f"{_intro_line(profile.target_lang)}\n{_profile_line(profile)}\n"
        f"Cari kontekst: '{context.pack_id}'{place}, saat {context.hour}.\n"
        f"{_MODE_INSTRUCTION[mode]}{exclude}\n\n"
        f"Hər sahə üçün:\n{_word_fields_desc(profile.target_lang)}\n\n"
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
        f"{_intro_line(profile.target_lang)}\n{_profile_line(profile)}\n"
        f"'{pack_id}' kontekstində ən faydalı {count} söz/ifadə seç. "
        f"Sözlər bir-birini TƏKRAR ETMƏMƏLİ və eyni situasiyanın müxtəlif "
        f"tərəflərini əhatə etməlidir.\n\n"
        f"Hər element üçün sahələr:\n{_word_fields_desc(profile.target_lang)}\n"
        f'- "pack_id": "{pack_id}"\n\n'
        'Yalnız bu formada JSON qaytar: {"messages": [ {pack_id, word, '
        'translation_az, ipa, example, example_az, ai_line, level}, ... ]} '
        f"— dəqiq {count} element."
    )
    return _SYSTEM, user


def build_essential_words_prompt(
    profile: UserProfile,
    words: list[str],
) -> tuple[str, str]:
    """Sabit söz siyahısı (504 ümumi söz bankından, bax essential_words.py)
    üçün AZ tərcümə/IPA/nümunə yaradır — (system, user).

    Fərqi `build_pack_words_prompt`-dan: AI sözləri ÖZÜ seçmir, ona VERİLİR —
    yalnız pedaqoji "qabıq" (tərcümə, nümunə, ai_line) yaradır. Bu, kitabın
    sınaqdan keçmiş söz seçimini qoruyub saxlayır.
    """
    word_list = ", ".join(words)
    user = (
        f"{_intro_line(profile.target_lang)}\n{_profile_line(profile)}\n"
        f"Aşağıdakı {len(words)} sözün HƏR BİRİ üçün ayrıca element yarat "
        f"(sıra ilə, heç birini ƏVƏZ ETMƏ, dəyişdirmə, ötürmə): {word_list}\n\n"
        f"Hər element üçün sahələr:\n{_word_fields_desc(profile.target_lang)}\n\n"
        'Yalnız bu formada JSON qaytar: {"messages": [ {word, translation_az, '
        'ipa, example, example_az, ai_line, level}, ... ]} '
        f"— dəqiq {len(words)} element, verilmiş sözlərlə eyni sırada."
    )
    return _SYSTEM, user


def build_language_essential_words_prompt(
    profile: UserProfile,
    count: int,
    exclude_words: list[str],
) -> tuple[str, str]:
    """Barron's 504 bankı olmayan dillər üçün "Əsas lüğət" — AI-dan bu
    səviyyə üçün ən vacib gündəlik sözləri ÖZÜ seçməsini istəyir (fərqli
    olaraq `build_essential_words_prompt`-dan, hansı ki sözlər VERİLİR).

    Sabit bank yoxdur, ona görə səhifələmə "sonsuz axın"dır — `exclude_words`
    (client-in son gördüyü sözlər) təkrarçılığı azaldır, tam qarantiya vermir.
    """
    exclude = (
        f"\nBu sözləri TƏKRAR ETMƏ (artıq göstərilib): {', '.join(exclude_words)}."
        if exclude_words
        else ""
    )
    lang = language_name(profile.target_lang)
    user = (
        f"{_intro_line(profile.target_lang)}\n{_profile_line(profile)}\n"
        f"Bu səviyyə üçün ən vacib, ən çox işlənən {count} gündəlik {lang} "
        f"sözü/ifadəsi seç (kontekstdən asılı olmayan ümumi lüğət, "
        f"gündəlik həyatda tez-tez lazım olan sözlər).{exclude}\n\n"
        f"Hər element üçün sahələr:\n{_word_fields_desc(profile.target_lang)}\n\n"
        'Yalnız bu formada JSON qaytar: {"messages": [ {word, translation_az, '
        'ipa, example, example_az, ai_line, level}, ... ]} '
        f"— dəqiq {count} element."
    )
    return _SYSTEM, user


def build_word_lookup_prompt(word: str, context: str) -> tuple[str, str]:
    """Səsli kitab mətnində toxunulan bir sözün mənası — (system, user).

    Qəsdən YALNIZ tərcümə+IPA istənir (nümunə cümlə YOX) — sözün öz cümləsi
    artıq ekranda görünür (kitabın mətni), təkrar yaratmağa ehtiyac yoxdur.
    Bu, tokeni (və Groq günlük limitini) qənaətli saxlayır.
    """
    ctx_line = f'Cümlə: "{context}"\n' if context.strip() else ""
    user = (
        f'İngilis sözün bu kontekstdəki mənasına görə Azərbaycan tərcüməsini '
        f"və IPA transkripsiyasını ver.\n"
        f'Söz: "{word}"\n{ctx_line}\n'
        'Yalnız bu formada JSON qaytar: {"translation_az": "...", "ipa": "/.../"}'
    )
    return _SYSTEM, user


def chat_preferred_providers() -> list[str]:
    """Söhbət üçün provayder sırası: Claude (keyfiyyət) → Groq (fallback)."""
    return ["claude", "groq"]


# İstifadəçi 2026-08-04-də verdi — mövzu izahı istəyəndə AI-nin izlədiyi
# struktur (bölmələr, maraqlara bağlı nümunə, çətin sözün yanında AZ izah,
# son lüğət + yoxlama sualları). Sadə aydınlaşdırma suallarında (bax
# `build_chat_system`-in özündəki şərt) bu struktur MƏCBUR edilmir — hər
# mesajdan sonra 5-sözlük lüğət + 3 sual təkrarçı/yorucu olardı.
def _topic_explanation_instruction(lang: str) -> str:
    return (
        "MÖVZU İZAHI (istifadəçi bir mövzunu ətraflı öyrənmək istəyəndə, "
        'məs. "present perfect nədir?", "restoranda necə sifariş verim?"): '
        "aşağıdakı struktura əməl et. Sadə aydınlaşdırma sualında "
        '("bu söz nə deməkdir?" kimi qısa sual) isə təbii, qısa cavab ver — '
        "bu strukturu MƏCBUR ETMƏ:\n"
        "1. Mövzunu istifadəçinin səviyyəsinə uyğun sadə dildə, qısa "
        "bölmələrə bölərək izah et.\n"
        "2. Mümkün olduqda nümunələri istifadəçinin maraqlarına bağla.\n"
        "3. Çətin sözlərin yanında qısa Azərbaycanca izah ver.\n"
        f"4. Sonda \"{lang}–Azərbaycan\" formatında mövzu ilə bağlı ən vacib "
        "5 sözdən ibarət lüğət ver.\n"
        "5. Öyrəndiyini yoxlamaq üçün 3 sadə sual ver.\n"
        "6. İstifadəçinin səviyyəsindən mürəkkəb ifadə/qrammatika işlətmə."
    )


# Yaddaş markeri — 2026-08-04, spec: 2026-08-04-chat-memory-design.md.
# ƏLAVƏ AI ÇAĞIRIŞI YOXDUR: eyni tamamlanmanın sonuna AI özü görünməz bir
# marker sətri əlavə edir, server (`service.py` `run_chat`) onu regex ilə
# ayırıb istifadəçidən gizlədir və `MemoryStore`-a yazır. Groq gündəlik
# kvotası dar olduğu üçün ikinci bir "fakt çıxar" sorğusu qəbuledilməzdir.
_MEMORY_MARKER_INSTRUCTION = (
    "YADDAŞ: söhbətdə istifadəçi haqqında YENİ, UZUNMÜDDƏTLİ əhəmiyyətli "
    "fakt öyrənsən (ad, peşə, maraq, məqsəd, vərdiş və s. — keçici "
    "təfərrüat YOX), cavabının LAP SONUNA, YENİ SƏTİRDƏ bunu əlavə et: "
    "[[YADDA: fakt1 | fakt2]]. Heç bir yeni fakt yoxdursa bu sətri YAZMA. "
    "İstifadəçi bu sətri HEÇ VAXT görməməlidir — heç vaxt ona bu barədə "
    "danışma, sadəcə cavabının sonuna əlavə et."
)


def build_chat_system(
    profile: UserProfile,
    context: Context | None,
    known_facts: list[str] | None = None,
) -> str:
    """Söhbət üçün system prompt — Azərbaycanca dil müəllimi personası."""
    ctx = ""
    if context is not None:
        ctx = (
            f"\nİstifadəçi hazırda '{context.pack_id}' kontekstindədir "
            f"(saat {context.hour}) — cavablarını buna uyğunlaşdıra bilərsən."
        )
    lang = language_name(profile.target_lang)
    interests = ", ".join(profile.interests) if profile.interests else "yoxdur"
    facts_line = (
        f"\nBu istifadəçi haqqında bildiklərin: {'; '.join(known_facts)}. "
        "Bunları təbii şəkildə istifadə et (məs. adı ilə xitab et), amma "
        "hər cavabda təkrar sadalamaq MƏCBURİ deyil."
        if known_facts
        else ""
    )
    return (
        f"Sən DilDostu-san — Azərbaycanca danışan istifadəçiyə {lang} dili "
        "öyrədən dostcasına, səbirli, 25 illik təcrübəli AI dil müəllimisən. "
        "Həmişə AZƏRBAYCANCA cavab ver "
        f"({lang} söz/ifadələri nümunə kimi ver).{_script_note(profile.target_lang)} "
        "Cavabların qısa, praktik və "
        "cəsarətləndirici olsun. İstifadəçi soruşanda tələffüz, nümunə cümlə və "
        "sadə izah ver.\n"
        f"məqsəd: {profile.purpose}, maraqlar: {interests}.{ctx}{facts_line}\n"
        f"{level_instruction(profile.level)}\n\n"
        f"{_topic_explanation_instruction(lang)}\n\n"
        f"{_MEMORY_MARKER_INSTRUCTION}"
    )


def build_dayplan_prompt(
    profile: UserProfile,
    pack_ids: list[str],
    date: str,
) -> tuple[str, str]:
    """Günün mesaj dəsti üçün (system, user) prompt qur (batch)."""
    user = (
        f"{_intro_line(profile.target_lang)}\n{_profile_line(profile)}\n"
        f"Tarix: {date}. Aşağıdakı kontekstlərin HƏR BİRİ üçün bir söz/ifadə seç "
        f"(sıra ilə): {', '.join(pack_ids)}.\n\n"
        f"Hər element üçün sahələr:\n{_word_fields_desc(profile.target_lang)}\n"
        '- "pack_id": həmin kontekstin id-si\n\n'
        'Yalnız bu formada JSON qaytar: {"messages": [ {pack_id, word, '
        'translation_az, ipa, example, example_az, ai_line, level}, ... ]} '
        f"— dəqiq {len(pack_ids)} element, verilmiş sıra ilə."
    )
    return _SYSTEM, user
