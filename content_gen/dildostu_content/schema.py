"""DilDostu söz paketi sxemi və validatoru.

Spec §3.1-dəki formata uyğun paketləri doğrulayır. Həm struktur (jsonschema),
həm də semantik qaydalar (boş sətir, təkrarlanan söz) yoxlanır. App bu formatı
olduğu kimi oxuyacağı üçün generasiya mərhələsində sərt doğrulama vacibdir.
"""

from __future__ import annotations

from jsonschema import Draft202012Validator

LEVEL_MIN = 1
LEVEL_MAX = 3

_WORD_FIELDS = ("word", "translation_az", "ipa", "example", "example_az")

PACK_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "required": ["pack_id", "target_lang", "ui_lang", "title_az", "words"],
    "properties": {
        "pack_id": {"type": "string", "minLength": 1},
        "target_lang": {"type": "string", "minLength": 2},
        "ui_lang": {"type": "string", "minLength": 2},
        "title_az": {"type": "string", "minLength": 1},
        "words": {
            "type": "array",
            "minItems": 1,
            "items": {
                "type": "object",
                "additionalProperties": False,
                "required": list(_WORD_FIELDS) + ["level"],
                "properties": {
                    "word": {"type": "string", "minLength": 1},
                    "translation_az": {"type": "string", "minLength": 1},
                    "ipa": {"type": "string", "minLength": 1},
                    "example": {"type": "string", "minLength": 1},
                    "example_az": {"type": "string", "minLength": 1},
                    "level": {
                        "type": "integer",
                        "minimum": LEVEL_MIN,
                        "maximum": LEVEL_MAX,
                    },
                },
            },
        },
    },
}

_VALIDATOR = Draft202012Validator(PACK_SCHEMA)


class ValidationError(Exception):
    """Paket sxemə və ya semantik qaydalara uyğun deyil."""


def validate_pack(pack: dict) -> None:
    """Paketi doğrula; problem varsa ValidationError at.

    Xəta mesajı hansı paketdə (pack_id) problem olduğunu göstərir ki,
    toplu generasiyada təqsirkar fayl tez tapılsın.
    """
    pack_id = pack.get("pack_id", "<pack_id yoxdur>")

    structural = sorted(_VALIDATOR.iter_errors(pack), key=lambda e: list(e.path))
    if structural:
        first = structural[0]
        location = "/".join(str(p) for p in first.path) or "(kök)"
        raise ValidationError(
            f"[{pack_id}] sxem xətası ({location}): {first.message}"
        )

    # Semantik yoxlamalar — jsonschema-nın tutmadıqları.
    _check_no_blank_strings(pack, pack_id)
    _check_no_duplicate_words(pack, pack_id)


def _check_no_blank_strings(pack: dict, pack_id: str) -> None:
    """Yalnız boşluqdan ibarət sətirlər (minLength keçir, amma mənasız) rədd edilir."""
    for field in ("title_az",):
        if not pack[field].strip():
            raise ValidationError(f"[{pack_id}] '{field}' boşdur")
    for i, word in enumerate(pack["words"]):
        for field in _WORD_FIELDS:
            if not word[field].strip():
                raise ValidationError(
                    f"[{pack_id}] söz #{i} '{field}' boşdur"
                )


def _check_no_duplicate_words(pack: dict, pack_id: str) -> None:
    seen: set[str] = set()
    for word in pack["words"]:
        key = word["word"].strip().casefold()
        if key in seen:
            raise ValidationError(
                f"[{pack_id}] təkrarlanan söz: {word['word']!r}"
            )
        seen.add(key)
