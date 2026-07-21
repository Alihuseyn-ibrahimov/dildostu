"""Paket sxem validatoru testləri (TDD — kod bundan sonra yazılır)."""

import copy

import pytest

from dildostu_content.schema import ValidationError, validate_pack


def valid_pack():
    """Hər testdə sıfırdan işlənən düzgün paket nümunəsi."""
    return {
        "pack_id": "cafe",
        "target_lang": "en",
        "ui_lang": "az",
        "title_az": "Kafedə",
        "words": [
            {
                "word": "receipt",
                "translation_az": "qəbz",
                "ipa": "/rɪˈsiːt/",
                "example": "Could I have the receipt, please?",
                "example_az": "Qəbzi verə bilərsiniz?",
                "level": 1,
            },
            {
                "word": "order",
                "translation_az": "sifariş",
                "ipa": "/ˈɔːrdər/",
                "example": "I would like to order a coffee.",
                "example_az": "Bir kofe sifariş etmək istəyirəm.",
                "level": 1,
            },
        ],
    }


def test_valid_pack_passes():
    validate_pack(valid_pack())  # istisna atmamalıdır


def test_missing_top_level_field_fails():
    pack = valid_pack()
    del pack["title_az"]
    with pytest.raises(ValidationError):
        validate_pack(pack)


def test_empty_words_fails():
    pack = valid_pack()
    pack["words"] = []
    with pytest.raises(ValidationError):
        validate_pack(pack)


def test_word_missing_field_fails():
    pack = valid_pack()
    del pack["words"][0]["ipa"]
    with pytest.raises(ValidationError):
        validate_pack(pack)


def test_level_out_of_range_fails():
    pack = valid_pack()
    pack["words"][0]["level"] = 9
    with pytest.raises(ValidationError):
        validate_pack(pack)


def test_level_below_range_fails():
    pack = valid_pack()
    pack["words"][0]["level"] = 0
    with pytest.raises(ValidationError):
        validate_pack(pack)


def test_empty_string_field_fails():
    pack = valid_pack()
    pack["words"][0]["translation_az"] = "   "
    with pytest.raises(ValidationError):
        validate_pack(pack)


def test_duplicate_words_fail():
    pack = valid_pack()
    pack["words"][1]["word"] = "receipt"  # birinci sözlə eyni
    with pytest.raises(ValidationError):
        validate_pack(pack)


def test_duplicate_words_case_insensitive():
    pack = valid_pack()
    pack["words"][1]["word"] = "Receipt"
    with pytest.raises(ValidationError):
        validate_pack(pack)


def test_wrong_type_fails():
    pack = valid_pack()
    pack["words"][0]["level"] = "birinci"  # int olmalıdır
    with pytest.raises(ValidationError):
        validate_pack(pack)


def test_error_message_names_pack_id():
    pack = valid_pack()
    pack["words"] = []
    with pytest.raises(ValidationError) as exc:
        validate_pack(pack)
    assert "cafe" in str(exc.value)


def test_unknown_top_level_field_fails():
    pack = valid_pack()
    pack["extra"] = "nə isə"
    with pytest.raises(ValidationError):
        validate_pack(pack)


def test_deep_copy_not_mutated():
    pack = valid_pack()
    before = copy.deepcopy(pack)
    try:
        validate_pack(pack)
    except ValidationError:
        pass
    assert pack == before
