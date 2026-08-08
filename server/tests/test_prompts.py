import pytest
from pydantic import ValidationError

from dildostu_server.models import Context, UserProfile
from dildostu_server.prompts import (
    build_chat_system,
    build_dayplan_prompt,
    build_essential_words_prompt,
    build_generate_prompt,
    build_language_essential_words_prompt,
    build_pack_words_prompt,
    build_word_lookup_prompt,
    language_name,
    level_instruction,
    preferred_providers,
)


def profile(level="beginner", target_lang="en"):
    return UserProfile(
        wake_hour=8, sleep_hour=23, purpose="travel", level=level,
        interests=["yemək"], target_lang=target_lang,
    )


class TestGeneratePrompt:
    def test_includes_context_and_profile(self):
        system, user = build_generate_prompt(
            profile(), Context(pack_id="cafe", hour=9), mode="normal", recent_words=[]
        )
        assert "cafe" in user.lower()
        assert "beginner" in user.lower() or "başlanğıc" in user.lower()
        assert "travel" in user.lower() or "səyahət" in user.lower()

    def test_simpler_mode_asks_for_simpler(self):
        _, user = build_generate_prompt(
            profile(), Context(pack_id="cafe", hour=9), mode="simpler", recent_words=[]
        )
        assert "sad" in user.lower() or "simpl" in user.lower()

    def test_harder_mode_asks_for_harder(self):
        _, user = build_generate_prompt(
            profile(), Context(pack_id="cafe", hour=9), mode="harder", recent_words=[]
        )
        assert "çətin" in user.lower() or "advanc" in user.lower() or "hard" in user.lower()

    def test_recent_words_excluded(self):
        _, user = build_generate_prompt(
            profile(), Context(pack_id="cafe", hour=9), mode="normal",
            recent_words=["coffee", "tea"],
        )
        assert "coffee" in user and "tea" in user

    def test_asks_json_output(self):
        _, user = build_generate_prompt(
            profile(), Context(pack_id="cafe", hour=9), mode="normal", recent_words=[]
        )
        assert "json" in user.lower()

    def test_nudges_toward_essential_vocabulary(self):
        _, user = build_generate_prompt(
            profile(), Context(pack_id="cafe", hour=9), mode="normal", recent_words=[]
        )
        assert "504" in user
        assert "kontekstə uyğunluqdan vacib" in user


class TestLevelInstruction:
    """Spec §2 — hər səviyyə AI-ya konkret, fərqli təlimat verməlidir."""

    def test_all_three_levels_supported(self):
        for level in ("beginner", "intermediate", "advanced"):
            assert level_instruction(level)

    def test_levels_differ_from_each_other(self):
        texts = {
            level_instruction(lvl)
            for lvl in ("beginner", "intermediate", "advanced")
        }
        assert len(texts) == 3

    def test_beginner_mentions_present_tense_and_short_sentence(self):
        text = level_instruction("beginner").lower()
        assert "indiki zaman" in text
        assert "4-6" in text or "4–6" in text

    def test_intermediate_mentions_past_future(self):
        text = level_instruction("intermediate").lower()
        assert "keçmiş" in text and "gələcək" in text

    def test_advanced_mentions_idiom_and_phrasal(self):
        text = level_instruction("advanced").lower()
        assert "idiom" in text
        assert "phrasal" in text

    def test_each_level_states_target_word_level_number(self):
        assert "1" in level_instruction("beginner")
        assert "2" in level_instruction("intermediate")
        assert "3" in level_instruction("advanced")


class TestGeneratePromptCarriesLevel:
    def test_advanced_profile_puts_advanced_rules_in_prompt(self):
        _, user = build_generate_prompt(
            profile("advanced"), Context(pack_id="cafe", hour=9),
            mode="normal", recent_words=[],
        )
        assert "idiom" in user.lower()

    def test_beginner_profile_does_not_ask_for_idioms(self):
        _, user = build_generate_prompt(
            profile("beginner"), Context(pack_id="cafe", hour=9),
            mode="normal", recent_words=[],
        )
        assert "idiom" not in user.lower()

    def test_dayplan_prompt_also_carries_level(self):
        _, user = build_dayplan_prompt(profile("advanced"), ["cafe"], "2026-08-03")
        assert "idiom" in user.lower()


class TestAdvancedLevelAccepted:
    def test_profile_accepts_advanced(self):
        assert profile("advanced").level == "advanced"

    def test_unknown_level_rejected(self):
        with pytest.raises(ValidationError):
            profile("expert")


class TestEssentialWordsPrompt:
    def test_lists_the_exact_words(self):
        _, user = build_essential_words_prompt(profile(), ["abandon", "keen", "tact"])
        assert "abandon" in user
        assert "keen" in user
        assert "tact" in user

    def test_forbids_substitution(self):
        _, user = build_essential_words_prompt(profile(), ["abandon"])
        assert "ƏVƏZ" in user.upper() or "TƏKRAR ETMƏ" in user.upper() or "DƏYİŞ" in user.upper()

    def test_carries_level_rules(self):
        _, user = build_essential_words_prompt(profile("advanced"), ["abandon"])
        assert "idiom" in user.lower()

    def test_asks_for_exact_count_matching_words(self):
        words = ["abandon", "keen", "tact", "vacant"]
        _, user = build_essential_words_prompt(profile(), words)
        assert str(len(words)) in user

    def test_asks_json_messages_array(self):
        _, user = build_essential_words_prompt(profile(), ["abandon"])
        assert "messages" in user


class TestWordLookupPrompt:
    def test_includes_word_and_context(self):
        _, user = build_word_lookup_prompt("bank", "He sat by the river bank.")
        assert "bank" in user
        assert "river bank" in user

    def test_context_optional(self):
        _, user = build_word_lookup_prompt("bank", "")
        assert "bank" in user
        assert "Cümlə:" not in user

    def test_asks_json_translation_and_ipa(self):
        _, user = build_word_lookup_prompt("gallant", "He was a gallant man.")
        assert "translation_az" in user
        assert "ipa" in user

    def test_does_not_ask_for_example(self):
        # Sözün öz cümləsi artıq ekranda görünür — təkrar yaratmağa ehtiyac
        # yoxdur (token qənaəti).
        _, user = build_word_lookup_prompt("gallant", "He was a gallant man.")
        assert "example" not in user


class TestDayPlanPrompt:
    def test_includes_pack_ids_and_count(self):
        _, user = build_dayplan_prompt(profile(), ["morning", "cafe", "evening"], "2026-07-22")
        assert "morning" in user and "cafe" in user and "evening" in user


class TestLanguageName:
    def test_known_languages(self):
        assert language_name("en") == "İngilis"
        assert language_name("ru") == "Rus"
        assert language_name("es") == "İspan"
        assert language_name("it") == "İtalyan"

    def test_unknown_falls_back_to_english(self):
        assert language_name("fr") == "İngilis"


class TestGeneratePromptCarriesLanguage:
    def test_default_english_mentions_ingilis(self):
        _, user = build_generate_prompt(
            profile(), Context(pack_id="cafe", hour=9), mode="normal", recent_words=[]
        )
        assert "İngilis dili öyrədən" in user

    def test_russian_profile_mentions_rus(self):
        _, user = build_generate_prompt(
            profile(target_lang="ru"), Context(pack_id="cafe", hour=9),
            mode="normal", recent_words=[],
        )
        assert "Rus dili öyrədən" in user
        assert "İngilis" not in user


class TestEssentialNudgeOnlyForEnglish:
    def test_english_gets_barrons_nudge(self):
        _, user = build_generate_prompt(
            profile(target_lang="en"), Context(pack_id="cafe", hour=9),
            mode="normal", recent_words=[],
        )
        assert "504" in user

    def test_russian_does_not_get_barrons_nudge(self):
        _, user = build_generate_prompt(
            profile(target_lang="ru"), Context(pack_id="cafe", hour=9),
            mode="normal", recent_words=[],
        )
        assert "504" not in user
        assert "Barron" not in user


class TestChatSystemCarriesLanguage:
    def test_default_english(self):
        system = build_chat_system(profile(), None)
        assert "İngilis dili" in system

    def test_russian(self):
        system = build_chat_system(profile(target_lang="ru"), None)
        assert "Rus dili" in system

    def test_includes_expert_tone_instruction(self):
        system = build_chat_system(profile(), None)
        assert "Ekspert kimi danış" in system
        assert "LachinGo brendi" in system


class TestChatSystemPersona:
    """2026-08-06 — ekspert + zarafatlı səyahət bələdçisi personası."""

    def test_travel_purpose_in_azerbaijani(self):
        system = build_chat_system(profile(), None)
        assert "məqsəd: səyahət üçün" in system

    def test_topic_explanation_includes_travel_hook(self):
        system = build_chat_system(profile(), None)
        assert "səyahət analogiyası" in system
        assert "yüngül zarafatla başla" in system


class TestChatSystemMemory:
    """2026-08-04 — yaddaş markeri həmişə mövcuddur; faktlar verilsə prompta düşür."""

    def test_marker_instruction_always_present(self):
        system = build_chat_system(profile(), None)
        assert "[[YADDA:" in system

    def test_no_facts_shows_empty_portrait(self):
        system = build_chat_system(profile(), None, known_facts=None)
        assert "İSTİFADƏÇİ PORTRETİ hələ boşdur" in system

    def test_empty_facts_list_shows_empty_portrait(self):
        system = build_chat_system(profile(), None, known_facts=[])
        assert "İSTİFADƏÇİ PORTRETİ hələ boşdur" in system

    def test_facts_included_when_given(self):
        system = build_chat_system(
            profile(), None, known_facts=["Ad: Elvin", "Hobbi: foto"]
        )
        assert "Ad: Elvin" in system
        assert "Hobbi: foto" in system
        assert "İSTİFADƏÇİ PORTRETİ" in system

    def test_marker_instruction_present_even_with_facts(self):
        system = build_chat_system(profile(), None, known_facts=["Adı Elvin"])
        assert "[[YADDA:" in system

    def test_portrait_speech_instruction_present(self):
        system = build_chat_system(profile(), None)
        assert "ÖZÜM HAQQINDA ÇIXIŞ" in system
        assert "hekayə kimi" in system

    def test_memory_categories_listed(self):
        system = build_chat_system(profile(), None)
        assert "Hobbi" in system and "Xarakter" in system
        assert "PORTRET TOPLAMA" in system


class TestChatSystemTopicExplanation:
    """2026-08-04 — istifadəçinin verdiyi mövzu-izahı promptu inteqrasiyası:
    yalnız mövzu izahında tam struktur, sadə aydınlaşdırmada məcbur deyil."""

    def test_mentions_interests(self):
        system = build_chat_system(profile(), None)
        assert "yemək" in system

    def test_no_interests_shows_yoxdur(self):
        p = UserProfile(
            wake_hour=8, sleep_hour=23, purpose="travel", level="beginner",
            interests=[],
        )
        system = build_chat_system(p, None)
        assert "maraqlar: yoxdur" in system

    def test_includes_vocabulary_list_instruction(self):
        system = build_chat_system(profile(), None)
        assert "5 sözdən ibarət lüğət" in system

    def test_includes_three_check_questions_instruction(self):
        system = build_chat_system(profile(), None)
        assert "3 sadə sual" in system

    def test_includes_hard_word_az_gloss_instruction(self):
        system = build_chat_system(profile(), None)
        assert "Çətin sözlərin yanında qısa Azərbaycanca izah" in system

    def test_structure_not_forced_for_simple_clarifications(self):
        system = build_chat_system(profile(), None)
        assert "MƏCBUR ETMƏ" in system

    def test_vocabulary_list_uses_target_language_name(self):
        system = build_chat_system(profile(target_lang="ru"), None)
        assert "Rus–Azərbaycan" in system


class TestLanguageEssentialWordsPrompt:
    def test_asks_for_exact_count(self):
        _, user = build_language_essential_words_prompt(
            profile(target_lang="ru"), 12, []
        )
        assert "12" in user

    def test_mentions_target_language(self):
        _, user = build_language_essential_words_prompt(
            profile(target_lang="ru"), 12, []
        )
        assert "Rus" in user

    def test_exclude_words_listed(self):
        _, user = build_language_essential_words_prompt(
            profile(target_lang="ru"), 12, ["привет", "спасибо"]
        )
        assert "привет" in user
        assert "спасибо" in user

    def test_no_exclude_line_when_empty(self):
        _, user = build_language_essential_words_prompt(
            profile(target_lang="ru"), 12, []
        )
        assert "TƏKRAR ETMƏ" not in user

    def test_carries_level_rules(self):
        _, user = build_language_essential_words_prompt(
            profile(level="advanced", target_lang="ru"), 12, []
        )
        assert "idiom" in user.lower()

    def test_asks_json_messages_array(self):
        _, user = build_language_essential_words_prompt(
            profile(target_lang="ru"), 12, []
        )
        assert "messages" in user


class TestScriptNote:
    """2026-08-04-də real generasiyada tutuldu: model dil adı verilsə də
    latın hərflərinə transliterasiya edir (məs. "kofe" — "кофе" yerinə).
    Açıq skript təlimatı olmadan bu, prompt-a qayıdır."""

    def test_russian_prompt_demands_cyrillic(self):
        _, user = build_generate_prompt(
            profile(target_lang="ru"), Context(pack_id="cafe", hour=9),
            mode="normal", recent_words=[],
        )
        assert "KİRİL" in user

    def test_english_prompt_has_no_script_note_noise(self):
        _, user = build_generate_prompt(
            profile(target_lang="en"), Context(pack_id="cafe", hour=9),
            mode="normal", recent_words=[],
        )
        assert "KİRİL" not in user

    def test_pack_words_prompt_carries_script_note(self):
        _, user = build_pack_words_prompt(profile(target_lang="ru"), "cafe", 8)
        assert "KİRİL" in user

    def test_essential_words_prompt_carries_script_note(self):
        _, user = build_essential_words_prompt(profile(target_lang="ru"), ["abandon"])
        assert "KİRİL" in user

    def test_language_essential_words_prompt_carries_script_note(self):
        _, user = build_language_essential_words_prompt(
            profile(target_lang="ru"), 12, []
        )
        assert "KİRİL" in user

    def test_dayplan_prompt_carries_script_note(self):
        _, user = build_dayplan_prompt(profile(target_lang="ru"), ["cafe"], "2026-08-04")
        assert "KİRİL" in user

    def test_chat_system_carries_script_note(self):
        system = build_chat_system(profile(target_lang="ru"), None)
        assert "KİRİL" in system


class TestProviderRouting:
    def test_normal_mode_prefers_groq(self):
        assert preferred_providers("normal")[0] == "groq"

    def test_personal_modes_prefer_claude(self):
        assert preferred_providers("simpler")[0] == "claude"
        assert preferred_providers("harder")[0] == "claude"
        assert preferred_providers("another_example")[0] == "claude"

    def test_always_has_fallback(self):
        for mode in ("normal", "simpler", "harder", "another_example"):
            assert len(preferred_providers(mode)) >= 2
