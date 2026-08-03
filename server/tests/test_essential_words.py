from collections import Counter

from dildostu_server.essential_words import WORD_LESSON, words_for_level


class TestWordLessonData:
    """Kitabın öz indeksindən çıxarılmış 504 sözün struktur doğrulaması."""

    def test_exactly_504_words(self):
        assert len(WORD_LESSON) == 504

    def test_lesson_numbers_1_to_42(self):
        assert set(WORD_LESSON.values()) == set(range(1, 43))

    def test_each_lesson_has_exactly_12_words(self):
        counts = Counter(WORD_LESSON.values())
        assert all(counts[lesson] == 12 for lesson in range(1, 43))

    def test_no_empty_words(self):
        assert all(w.strip() for w in WORD_LESSON)

    def test_words_are_lowercase(self):
        assert all(w == w.lower() for w in WORD_LESSON)


class TestWordsForLevel:
    def test_beginner_is_lessons_1_to_14(self):
        words = words_for_level("beginner")
        assert len(words) == 168
        assert all(WORD_LESSON[w] <= 14 for w in words)
        assert any(WORD_LESSON[w] == 1 for w in words)
        assert any(WORD_LESSON[w] == 14 for w in words)

    def test_intermediate_is_lessons_15_to_28(self):
        words = words_for_level("intermediate")
        assert len(words) == 168
        assert all(15 <= WORD_LESSON[w] <= 28 for w in words)

    def test_advanced_is_lessons_29_to_42(self):
        words = words_for_level("advanced")
        assert len(words) == 168
        assert all(29 <= WORD_LESSON[w] <= 42 for w in words)

    def test_levels_do_not_overlap(self):
        b, i, a = (
            set(words_for_level("beginner")),
            set(words_for_level("intermediate")),
            set(words_for_level("advanced")),
        )
        assert not (b & i)
        assert not (i & a)
        assert not (b & a)
        assert len(b | i | a) == 504

    def test_stable_order(self):
        assert words_for_level("beginner") == words_for_level("beginner")

    def test_unknown_level_returns_empty(self):
        assert words_for_level("expert") == []
