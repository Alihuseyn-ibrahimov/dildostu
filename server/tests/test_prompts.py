import pytest
from pydantic import ValidationError

from dildostu_server.models import Context, UserProfile
from dildostu_server.prompts import (
    build_dayplan_prompt,
    build_essential_words_prompt,
    build_generate_prompt,
    level_instruction,
    preferred_providers,
)


def profile(level="beginner"):
    return UserProfile(
        wake_hour=8, sleep_hour=23, purpose="travel", level=level,
        interests=["yemək"],
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


class TestDayPlanPrompt:
    def test_includes_pack_ids_and_count(self):
        _, user = build_dayplan_prompt(profile(), ["morning", "cafe", "evening"], "2026-07-22")
        assert "morning" in user and "cafe" in user and "evening" in user


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
