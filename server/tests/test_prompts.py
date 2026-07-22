from dildostu_server.models import Context, UserProfile
from dildostu_server.prompts import (
    build_dayplan_prompt,
    build_generate_prompt,
    preferred_providers,
)


def profile():
    return UserProfile(
        wake_hour=8, sleep_hour=23, purpose="travel", level="beginner",
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
