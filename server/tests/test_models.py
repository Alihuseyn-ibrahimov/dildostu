"""Pydantic model/sxem testləri (TDD — modellər bundan sonra yazılır)."""

import pytest
from pydantic import ValidationError

from dildostu_server.models import (
    Context,
    DayPlanRequest,
    GenerateRequest,
    LiveMessage,
    UserProfile,
)


def valid_profile():
    return UserProfile(
        wake_hour=8,
        sleep_hour=23,
        purpose="travel",
        level="beginner",
        interests=["yemək", "səyahət"],
    )


def valid_message():
    return LiveMessage(
        pack_id="cafe",
        word="coffee",
        translation_az="qəhvə",
        ipa="/ˈkɒfi/",
        example="I would like a coffee.",
        example_az="Mən qəhvə istəyirəm.",
        ai_line="İndi kafedəsən — kofe sifarişini məşq edək!",
        level=1,
    )


class TestUserProfile:
    def test_valid(self):
        p = valid_profile()
        assert p.purpose == "travel"
        assert p.level == "beginner"

    def test_invalid_purpose_rejected(self):
        with pytest.raises(ValidationError):
            UserProfile(wake_hour=8, sleep_hour=23, purpose="oyun", level="beginner")

    def test_invalid_level_rejected(self):
        with pytest.raises(ValidationError):
            UserProfile(wake_hour=8, sleep_hour=23, purpose="work", level="expert")

    def test_interests_default_empty(self):
        p = UserProfile(wake_hour=7, sleep_hour=22, purpose="general", level="intermediate")
        assert p.interests == []

    def test_target_lang_defaults_to_en(self):
        p = valid_profile()
        assert p.target_lang == "en"

    def test_target_lang_accepts_four_languages(self):
        for lang in ("en", "ru", "es", "it"):
            p = UserProfile(
                wake_hour=8, sleep_hour=23, purpose="travel", level="beginner",
                target_lang=lang,
            )
            assert p.target_lang == lang

    def test_unknown_target_lang_rejected(self):
        with pytest.raises(ValidationError):
            UserProfile(
                wake_hour=8, sleep_hour=23, purpose="travel", level="beginner",
                target_lang="fr",
            )


class TestLiveMessage:
    def test_valid(self):
        m = valid_message()
        assert m.word == "coffee"
        assert m.ai_line

    def test_level_out_of_range_rejected(self):
        with pytest.raises(ValidationError):
            LiveMessage(
                pack_id="cafe", word="x", translation_az="y", ipa="/x/",
                example="X.", example_az="X.", ai_line="line", level=9,
            )

    def test_empty_word_rejected(self):
        with pytest.raises(ValidationError):
            LiveMessage(
                pack_id="cafe", word="", translation_az="y", ipa="/x/",
                example="X.", example_az="X.", ai_line="line", level=1,
            )


class TestRequests:
    def test_generate_request_defaults(self):
        req = GenerateRequest(
            profile=valid_profile(),
            context=Context(pack_id="cafe", hour=9),
        )
        assert req.mode == "normal"
        assert req.recent_words == []

    def test_generate_invalid_mode_rejected(self):
        with pytest.raises(ValidationError):
            GenerateRequest(
                profile=valid_profile(),
                context=Context(pack_id="cafe", hour=9),
                mode="reverse",
            )

    def test_dayplan_request(self):
        req = DayPlanRequest(
            profile=valid_profile(),
            date="2026-07-22",
            pack_ids=["morning", "cafe", "evening"],
        )
        assert len(req.pack_ids) == 3
