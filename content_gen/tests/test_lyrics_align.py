from dildostu_content.lyrics_align import align_lines, normalize


def _asr(*pairs):
    return [
        {"word": w, "start": s, "end": s + 0.4}
        for w, s in pairs
    ]


def test_normalize_strips_case_accents_and_punctuation():
    assert normalize("¡Bamba,") == "bamba"
    assert normalize("fuí") == "fui"
    assert normalize("You're") == "youre"


def test_exact_match_uses_real_asr_times():
    lines = ["Para bailar la bamba", "Se necesita gracia"]
    asr = _asr(
        ("Para", 5.6), ("bailar", 6.6), ("la", 7.4), ("bamba", 7.9),
        ("Se", 11.2), ("necesita", 11.7), ("gracia", 14.1),
    )
    out = align_lines(lines, asr)
    assert out[0]["matched"] is True
    assert out[0]["start_ms"] == 5600
    assert len(out[0]["word_ms"]) == 4
    assert out[1]["matched"] is True
    assert out[1]["start_ms"] == 11200


def test_repeated_lines_map_to_sequential_occurrences():
    lines = ["Para bailar la bamba", "Para bailar la bamba"]
    asr = _asr(
        ("Para", 5.6), ("bailar", 6.6), ("la", 7.4), ("bamba", 7.9),
        ("Para", 9.8), ("bailar", 10.2), ("la", 10.5), ("bamba", 11.0),
    )
    out = align_lines(lines, asr)
    assert out[0]["start_ms"] == 5600
    assert out[1]["start_ms"] == 9800


def test_unmatched_line_has_no_timing():
    lines = ["Yo no fui yo no fui"]
    asr = _asr(("Para", 5.0), ("bailar", 6.0))
    out = align_lines(lines, asr)
    assert out[0]["matched"] is False
    assert out[0]["start_ms"] is None
    assert out[0]["word_ms"] is None


def test_misheard_words_interpolated_within_line_only():
    lines = ["Para bailar la bamba"]
    asr = _asr(("Para", 10.0), ("xxx", 10.5), ("yyy", 11.0), ("bamba", 12.0))
    out = align_lines(lines, asr)
    word_ms = out[0]["word_ms"]
    assert word_ms[0] == 10000
    assert word_ms[-1] == 12000
    assert 10000 < word_ms[1] < word_ms[2] < 12000
