"""Generatorun təmiz (şəbəkəsiz) funksiyaları üçün testlər."""

import json

import pytest

from dildostu_content.categories import by_id
from dildostu_content.generate import build_prompt, parse_response
from dildostu_content.schema import ValidationError


def _words_json(n=2):
    words = [
        {
            "word": f"word{i}",
            "translation_az": f"söz{i}",
            "ipa": f"/w{i}/",
            "example": f"This is example {i}.",
            "example_az": f"Bu {i} nömrəli nümunədir.",
            "level": 1,
        }
        for i in range(n)
    ]
    return words


def test_build_prompt_mentions_category_and_langs():
    prompt = build_prompt(by_id("cafe"), n_words=10)
    assert "cafe" in prompt.lower() or "café" in prompt.lower()
    assert "Azerbaijani" in prompt or "az" in prompt
    assert "10" in prompt


def test_parse_response_plain_object():
    payload = json.dumps({"words": _words_json(2)})
    pack = parse_response(payload, by_id("cafe"))
    assert pack["pack_id"] == "cafe"
    assert pack["target_lang"] == "en"
    assert pack["ui_lang"] == "az"
    assert pack["title_az"] == "Kafedə"
    assert len(pack["words"]) == 2


def test_parse_response_strips_code_fences():
    payload = "```json\n" + json.dumps({"words": _words_json(2)}) + "\n```"
    pack = parse_response(payload, by_id("cafe"))
    assert len(pack["words"]) == 2


def test_parse_response_accepts_bare_array():
    payload = json.dumps(_words_json(3))
    pack = parse_response(payload, by_id("hotel"))
    assert pack["pack_id"] == "hotel"
    assert len(pack["words"]) == 3


def test_parse_response_with_surrounding_prose():
    payload = "Here is your pack:\n" + json.dumps({"words": _words_json(2)}) + "\nHope it helps!"
    pack = parse_response(payload, by_id("cafe"))
    assert len(pack["words"]) == 2


def test_parse_response_invalid_json_raises():
    with pytest.raises(ValueError):
        parse_response("not json at all", by_id("cafe"))


def test_parse_response_runs_schema_validation():
    bad = _words_json(1)
    bad[0]["level"] = 99  # sxemə uyğun deyil
    payload = json.dumps({"words": bad})
    with pytest.raises(ValidationError):
        parse_response(payload, by_id("cafe"))


def test_parse_response_empty_words_raises():
    payload = json.dumps({"words": []})
    with pytest.raises(ValidationError):
        parse_response(payload, by_id("cafe"))
