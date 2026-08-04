import json

import pytest

from dildostu_server.generator import (
    parse_dayplan_response,
    parse_generate_response,
    parse_word_lookup_response,
)
from dildostu_server.models import Context


def _word_obj(word="coffee"):
    return {
        "word": word,
        "translation_az": "qəhvə",
        "ipa": "/ˈkɒfi/",
        "example": "I would like a coffee.",
        "example_az": "Mən qəhvə istəyirəm.",
        "ai_line": "İndi kafedəsən!",
        "level": 1,
    }


class TestParseGenerate:
    def test_plain_object(self):
        msg = parse_generate_response(json.dumps(_word_obj()), Context(pack_id="cafe", hour=9))
        assert msg.word == "coffee"
        assert msg.pack_id == "cafe"  # kontekstdən doldurulur

    def test_code_fence(self):
        text = "```json\n" + json.dumps(_word_obj()) + "\n```"
        msg = parse_generate_response(text, Context(pack_id="cafe", hour=9))
        assert msg.translation_az == "qəhvə"

    def test_surrounding_prose(self):
        text = "Budur:\n" + json.dumps(_word_obj()) + "\nUğurlar!"
        msg = parse_generate_response(text, Context(pack_id="hotel", hour=20))
        assert msg.pack_id == "hotel"

    def test_invalid_json_raises(self):
        with pytest.raises(ValueError):
            parse_generate_response("json deyil", Context(pack_id="cafe", hour=9))

    def test_bad_schema_raises(self):
        bad = _word_obj()
        bad["level"] = 99
        with pytest.raises(ValueError):
            parse_generate_response(json.dumps(bad), Context(pack_id="cafe", hour=9))


class TestParseDayPlan:
    def test_messages_array(self):
        payload = {"messages": [
            {**_word_obj("good morning"), "pack_id": "morning"},
            {**_word_obj("coffee"), "pack_id": "cafe"},
        ]}
        msgs = parse_dayplan_response(json.dumps(payload), ["morning", "cafe"])
        assert len(msgs) == 2
        assert msgs[0].pack_id == "morning"

    def test_fills_pack_id_by_order_if_missing(self):
        # pack_id verilməyibsə, sıraya görə doldurulur
        payload = {"messages": [_word_obj("a"), _word_obj("b")]}
        msgs = parse_dayplan_response(json.dumps(payload), ["morning", "cafe"])
        assert [m.pack_id for m in msgs] == ["morning", "cafe"]

    def test_bad_dayplan_raises(self):
        with pytest.raises(ValueError):
            parse_dayplan_response("{}", ["morning"])


class TestParseWordLookup:
    def test_parses_translation_and_ipa(self):
        payload = {"translation_az": "sahil", "ipa": "/bæŋk/"}
        result = parse_word_lookup_response(json.dumps(payload), "bank")
        assert result.word == "bank"
        assert result.translation_az == "sahil"
        assert result.ipa == "/bæŋk/"

    def test_word_comes_from_query_not_ai(self):
        # AI cavabında "word" olsa da, sorğudakı orijinal söz istifadə olunur.
        payload = {"word": "BANK", "translation_az": "sahil", "ipa": "/bæŋk/"}
        result = parse_word_lookup_response(json.dumps(payload), "bank")
        assert result.word == "bank"

    def test_missing_translation_raises(self):
        with pytest.raises(ValueError):
            parse_word_lookup_response(json.dumps({"ipa": "/bæŋk/"}), "bank")

    def test_bad_json_raises(self):
        with pytest.raises(ValueError):
            parse_word_lookup_response("not json", "bank")
