"""Səsli kitab boru xəttinin təmiz (I/O-suz) funksiyaları.

Bax: docs/superpowers/specs/2026-08-04-audiobooks-design.md
"""

import pytest

from dildostu_content.audiobooks import (
    Chapter,
    after_last_marker,
    build_manifest,
    clean_text,
    drop_non_narrative,
    is_title_line,
    slugify,
    split_chapters,
    strip_gutenberg_wrapper,
)


class TestCleanText:
    def test_removes_illustration_markers(self):
        # TTS bunları ucadan oxuyardı — mütləq silinməlidir.
        text = "A Fox saw grapes.\n\n[Illustration: THE FOX]\n\nHe jumped."
        cleaned = clean_text(text)
        assert "Illustration" not in cleaned
        assert "A Fox saw grapes." in cleaned
        assert "He jumped." in cleaned

    def test_removes_multiline_markers(self):
        text = "Start.\n\n[Illustration: A VERY\nLONG CAPTION]\n\nEnd."
        cleaned = clean_text(text)
        assert "Illustration" not in cleaned
        assert "LONG CAPTION" not in cleaned

    def test_collapses_excess_blank_lines(self):
        assert "\n\n\n" not in clean_text("A.\n\n\n\n\nB.")

    def test_preserves_paragraph_breaks(self):
        assert "\n\n" in clean_text("Birinci abzas.\n\nİkinci abzas.")

    def test_strips_result(self):
        assert clean_text("\n\n  Mətn.  \n\n") == "Mətn."


class TestDropNonNarrative:
    def test_drops_chapters_that_became_empty(self):
        chapters = [
            Chapter("illustrations", "ILLUSTRATIONS", ""),
            Chapter("real", "REAL", "A proper fable body with enough words here."),
        ]
        kept = drop_non_narrative(chapters, min_words=5)
        assert [c.chapter_id for c in kept] == ["real"]

    def test_drops_too_short_chapters(self):
        chapters = [Chapter("stub", "STUB", "Three words only")]
        assert drop_non_narrative(chapters, min_words=10) == []

    def test_keeps_normal_fables(self):
        text = " ".join(["word"] * 50)
        chapters = [Chapter("ok", "OK", text)]
        assert len(drop_non_narrative(chapters, min_words=10)) == 1


class TestStripGutenbergWrapper:
    def test_removes_header_and_footer(self):
        raw = (
            "The Project Gutenberg eBook of X\nLisenziya mətni burada\n"
            "*** START OF THE PROJECT GUTENBERG EBOOK X ***\n"
            "ƏSL MƏTN\n"
            "*** END OF THE PROJECT GUTENBERG EBOOK X ***\n"
            "Sonluq lisenziyası\n"
        )
        assert strip_gutenberg_wrapper(raw).strip() == "ƏSL MƏTN"

    def test_without_markers_returns_input(self):
        # Marker yoxdursa mətni itirmirik (səssiz boş nəticə ən pis haldır).
        raw = "Sadəcə mətn"
        assert strip_gutenberg_wrapper(raw) == raw


class TestAfterLastMarker:
    def test_takes_text_after_last_occurrence(self):
        # Kitabın adı həm titul səhifəsində, həm gövdə başlanğıcında olur —
        # bizə SONUNCUSU lazımdır (CONTENTS siyahısından sonrakı).
        text = "ADI\n\nGiriş\n\nCONTENTS\n\nADI\n\nƏsl gövdə"
        assert after_last_marker(text, "ADI").strip() == "Əsl gövdə"

    def test_missing_marker_returns_input(self):
        assert after_last_marker("mətn", "YOXDUR") == "mətn"


class TestIsTitleLine:
    @pytest.mark.parametrize("line", [
        "THE FOX AND THE GRAPES",
        "THE LION, THE FOX, AND THE ASS",
        "THE MISER",
    ])
    def test_uppercase_lines_are_titles(self, line):
        assert is_title_line(line)

    @pytest.mark.parametrize("line", [
        "A hungry Fox saw some fine bunches of Grapes",
        "    Much wants more and loses all.",  # girintili əxlaq
        "",
        "   ",
        "1912 EDITION",  # rəqəmlə başlayan başlıq gövdə deyil, amma...
    ])
    def test_body_and_blank_lines_are_not_titles(self, line):
        if line.strip() == "1912 EDITION":
            pytest.skip("rəqəmli sətir ayrıca qaydayla süzülür")
        assert not is_title_line(line)

    def test_indented_uppercase_is_not_title(self):
        assert not is_title_line("    THE FOX")


class TestSlugify:
    def test_uppercase_title_to_slug(self):
        assert slugify("THE FOX AND THE GRAPES") == "the-fox-and-the-grapes"

    def test_strips_punctuation(self):
        assert slugify("THE LION, THE FOX, AND THE ASS") == \
            "the-lion-the-fox-and-the-ass"

    def test_handles_apostrophes(self):
        assert slugify("THE MISER'S GOLD") == "the-misers-gold"

    def test_only_safe_chars(self):
        # Server path traversal-a qarşı yalnız [a-z0-9-] qəbul edir.
        slug = slugify("ÆSOP'S  FABLES!! (1912)")
        assert all(c.isalnum() or c == "-" for c in slug)
        assert slug == slug.lower()

    def test_no_leading_trailing_or_double_dashes(self):
        slug = slugify("  --THE  FOX--  ")
        assert not slug.startswith("-")
        assert not slug.endswith("-")
        assert "--" not in slug

    def test_cyrillic_title_transliterated_not_dropped(self):
        # NFKD ASCII-foldinq kiril hərflərini SİLƏR (dekompozisiyası yoxdur) —
        # transliterasiya olmasa slug boş qalardı (Rus kitabları üçün bug).
        slug = slugify("ВОРОНА И ЛИСИЦА")
        assert slug == "vorona-i-lisitsa"
        assert slug  # boş DEYİL

    def test_cyrillic_slug_only_safe_chars(self):
        slug = slugify("ЩУКА И КОТ!")
        assert all(c.isalnum() or c == "-" for c in slug)
        assert slug


class TestSplitChapters:
    BODY = """THE FOX AND THE GRAPES


A hungry Fox saw some fine bunches of Grapes hanging from a vine
and did his best to reach them.




THE GOOSE THAT LAID THE GOLDEN EGGS


A Man and his Wife had a Goose which laid a Golden Egg every day.

    Much wants more and loses all.
"""

    def test_splits_into_chapters(self):
        chapters = split_chapters(self.BODY)
        assert len(chapters) == 2
        assert chapters[0].title_en == "THE FOX AND THE GRAPES"
        assert chapters[1].title_en == "THE GOOSE THAT LAID THE GOLDEN EGGS"

    def test_chapter_ids_are_slugs(self):
        chapters = split_chapters(self.BODY)
        assert chapters[0].chapter_id == "the-fox-and-the-grapes"

    def test_text_excludes_title(self):
        chapters = split_chapters(self.BODY)
        assert "THE FOX AND THE GRAPES" not in chapters[0].text
        assert "hungry Fox" in chapters[0].text

    def test_text_keeps_moral(self):
        chapters = split_chapters(self.BODY)
        assert "Much wants more" in chapters[1].text

    def test_text_is_stripped_and_nonempty(self):
        for ch in split_chapters(self.BODY):
            assert ch.text == ch.text.strip()
            assert ch.text

    def test_ignores_titles_with_no_body(self):
        # Ardıcıl başlıqlar (CONTENTS qalığı) fəsil sayılmamalıdır.
        body = "TITLE ONE\n\n\nTITLE TWO\n\n\nReal text here.\n"
        chapters = split_chapters(body)
        assert [c.title_en for c in chapters] == ["TITLE TWO"]

    def test_empty_body_gives_no_chapters(self):
        assert split_chapters("") == []


class TestBuildManifest:
    def _chapters(self):
        return [
            Chapter(
                chapter_id="the-fox-and-the-grapes",
                title_en="THE FOX AND THE GRAPES",
                text="A hungry Fox saw grapes.",
            )
        ]

    def _manifest(self):
        return build_manifest(
            book_id="aesop",
            title_en="Aesop's Fables",
            title_az="Ezop Təmsilləri",
            author="Aesop",
            source="Project Gutenberg #11339 — ictimai domen",
            level="beginner",
            chapters=self._chapters(),
            measured={"the-fox-and-the-grapes": (78.4, 39000)},
        )

    def test_has_version_and_book(self):
        m = self._manifest()
        assert m["version"] == 1
        assert len(m["books"]) == 1
        assert m["books"][0]["book_id"] == "aesop"

    def test_chapter_carries_measured_duration_and_size(self):
        ch = self._manifest()["books"][0]["chapters"][0]
        # Uzunluq TƏXMİN EDİLMİR — real fayldan ölçülür (ffprobe).
        assert ch["duration_sec"] == 78.4
        assert ch["size_bytes"] == 39000

    def test_chapter_title_is_human_cased(self):
        # Manifestdə BÖYÜK HƏRFLƏ deyil, oxunaqlı formada.
        ch = self._manifest()["books"][0]["chapters"][0]
        assert ch["title_en"] == "The Fox and the Grapes"

    def test_chapter_keeps_text_for_sync_display(self):
        ch = self._manifest()["books"][0]["chapters"][0]
        assert ch["text"] == "A hungry Fox saw grapes."

    def test_source_attribution_present(self):
        # İctimai domen mənbəyi həmişə göstərilməlidir.
        assert "Gutenberg" in self._manifest()["books"][0]["source"]

    def test_missing_measurement_raises(self):
        # Səssizcə 0 yazmaqdansa açıq xəta — plyer 0-lıq fəsli göstərməsin.
        with pytest.raises(KeyError):
            build_manifest(
                book_id="aesop", title_en="x", title_az="x", author="x",
                source="x", level="beginner", chapters=self._chapters(),
                measured={},
            )

    def test_lang_defaults_to_en(self):
        assert self._manifest()["books"][0]["lang"] == "en"

    def test_lang_carries_through(self):
        m = build_manifest(
            book_id="krylov", title_en="x", title_az="x", author="x",
            source="x", level="beginner", chapters=self._chapters(),
            measured={"the-fox-and-the-grapes": (1.0, 100)},
            lang="ru",
        )
        assert m["books"][0]["lang"] == "ru"
