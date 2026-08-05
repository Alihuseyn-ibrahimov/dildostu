"""Musiqi boru xəttinin təmiz (şəbəkəsiz) funksiyaları üçün testlər."""

import json

import pytest

from dildostu_content.songs import (
    SongCandidate,
    build_lyrics_prompt,
    build_suggest_prompt,
    parse_lyrics_response,
    parse_suggest_response,
    validate_confirmed_songs,
)


def _candidates_json(levels=("beginner", "intermediate", "advanced")):
    return [
        {"title": f"Song {i}", "artist": f"Artist {i}", "level": level}
        for i, level in enumerate(levels)
    ]


class TestBuildSuggestPrompt:
    def test_mentions_language_and_levels(self):
        prompt = build_suggest_prompt("English", per_level=3)
        assert "English" in prompt
        assert "beginner" in prompt
        assert "intermediate" in prompt
        assert "advanced" in prompt
        assert "3" in prompt

    def test_forbids_inventing_youtube_id(self):
        prompt = build_suggest_prompt("English")
        assert "YouTube video ID" in prompt or "video ID" in prompt


class TestParseSuggestResponse:
    def test_plain_object(self):
        payload = json.dumps({"songs": _candidates_json()})
        candidates = parse_suggest_response(payload)
        assert len(candidates) == 3
        assert candidates[0] == SongCandidate(
            title="Song 0", artist="Artist 0", level="beginner"
        )

    def test_strips_code_fences(self):
        payload = "```json\n" + json.dumps({"songs": _candidates_json()}) + "\n```"
        candidates = parse_suggest_response(payload)
        assert len(candidates) == 3

    def test_accepts_bare_array(self):
        payload = json.dumps(_candidates_json())
        candidates = parse_suggest_response(payload)
        assert len(candidates) == 3

    def test_missing_title_raises(self):
        bad = [{"artist": "X", "level": "beginner"}]
        with pytest.raises(ValueError):
            parse_suggest_response(json.dumps({"songs": bad}))

    def test_unknown_level_raises(self):
        bad = [{"title": "X", "artist": "Y", "level": "expert"}]
        with pytest.raises(ValueError):
            parse_suggest_response(json.dumps({"songs": bad}))

    def test_invalid_json_raises(self):
        with pytest.raises(ValueError):
            parse_suggest_response("not json at all")


class TestBuildLyricsPrompt:
    def test_mentions_title_artist_language(self):
        prompt = build_lyrics_prompt("Yesterday", "The Beatles", "English")
        assert "Yesterday" in prompt
        assert "The Beatles" in prompt
        assert "English" in prompt

    def test_mentions_ui_language_for_translation(self):
        prompt = build_lyrics_prompt("Yesterday", "The Beatles", "English", "Azerbaijani")
        assert "Azerbaijani" in prompt

    def test_warns_against_padding_uncertain_lyrics(self):
        prompt = build_lyrics_prompt("Yesterday", "The Beatles", "English")
        assert "not fully certain" in prompt or "best" in prompt.lower()


def _lines_json(n=3):
    return [{"text": f"Line {i}", "translation_az": f"Sətir {i}"} for i in range(n)]


class TestParseLyricsResponse:
    def _kwargs(self, **overrides):
        base = dict(
            song_id="beatles-yesterday",
            title="Yesterday",
            artist="The Beatles",
            youtube_id="abcdefghijk",
            level="intermediate",
            lang="en",
        )
        base.update(overrides)
        return base

    def test_builds_song_with_ordered_lines(self):
        payload = json.dumps({"lines": _lines_json(3)})
        song = parse_lyrics_response(payload, **self._kwargs())
        assert song.song_id == "beatles-yesterday"
        assert song.youtube_id == "abcdefghijk"
        assert song.level == "intermediate"
        assert song.lang == "en"
        assert len(song.lines) == 3
        assert song.lines[0].line_id == "l1"
        assert song.lines[0].text == "Line 0"
        assert song.lines[0].translation_az == "Sətir 0"

    def test_strips_code_fences(self):
        payload = "```json\n" + json.dumps({"lines": _lines_json(2)}) + "\n```"
        song = parse_lyrics_response(payload, **self._kwargs())
        assert len(song.lines) == 2

    def test_accepts_bare_array(self):
        payload = json.dumps(_lines_json(2))
        song = parse_lyrics_response(payload, **self._kwargs())
        assert len(song.lines) == 2

    def test_empty_lines_raises(self):
        payload = json.dumps({"lines": []})
        with pytest.raises(ValueError):
            parse_lyrics_response(payload, **self._kwargs())

    def test_missing_translation_raises(self):
        bad = [{"text": "Line 0"}]
        payload = json.dumps({"lines": bad})
        with pytest.raises(ValueError):
            parse_lyrics_response(payload, **self._kwargs())

    def test_unknown_level_raises(self):
        payload = json.dumps({"lines": _lines_json(1)})
        with pytest.raises(ValueError):
            parse_lyrics_response(payload, **self._kwargs(level="expert"))

    def test_invalid_json_raises(self):
        with pytest.raises(ValueError):
            parse_lyrics_response("not json at all", **self._kwargs())


class TestValidateConfirmedSongs:
    def test_valid_youtube_ids_pass(self):
        items = [{"title": "X", "youtube_id": "dQw4w9WgXcQ"}]
        validate_confirmed_songs(items)  # doesn't raise

    def test_empty_youtube_id_raises(self):
        items = [{"title": "X", "youtube_id": ""}]
        with pytest.raises(ValueError):
            validate_confirmed_songs(items)

    def test_missing_youtube_id_raises(self):
        items = [{"title": "X"}]
        with pytest.raises(ValueError):
            validate_confirmed_songs(items)

    def test_wrong_length_youtube_id_raises(self):
        items = [{"title": "X", "youtube_id": "tooshort"}]
        with pytest.raises(ValueError):
            validate_confirmed_songs(items)

    def test_url_instead_of_id_raises(self):
        items = [{"title": "X", "youtube_id": "https://youtu.be/dQw4w9WgXcQ"}]
        with pytest.raises(ValueError):
            validate_confirmed_songs(items)
