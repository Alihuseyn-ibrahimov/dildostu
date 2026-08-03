"""Səsli kitablar — AudiobookStore + /audiobooks endpoint-ləri."""

import json

import pytest
from fastapi.testclient import TestClient

from dildostu_server.app import app, get_audiobook_store
from dildostu_server.audiobook_store import AudiobookStore


@pytest.fixture
def store_dir(tmp_path):
    """Kiçik, real quruluşlu səsli kitab qovluğu."""
    (tmp_path / "aesop").mkdir()
    (tmp_path / "aesop" / "the-fox-and-the-grapes.mp3").write_bytes(b"ID3fake-mp3")
    manifest = {
        "version": 1,
        "books": [
            {
                "book_id": "aesop",
                "title_en": "Aesop's Fables",
                "title_az": "Ezop Təmsilləri",
                "author": "Aesop",
                "source": "Project Gutenberg #11339 — ictimai domen",
                "level": "beginner",
                "chapters": [
                    {
                        "chapter_id": "the-fox-and-the-grapes",
                        "title_en": "The Fox and the Grapes",
                        "duration_sec": 24.0,
                        "size_bytes": 11,
                        "text": "A hungry Fox saw grapes.",
                    }
                ],
            }
        ],
    }
    (tmp_path / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False), encoding="utf-8"
    )
    return tmp_path


class TestAudiobookStore:
    def test_manifest_read(self, store_dir):
        store = AudiobookStore(str(store_dir))
        manifest = store.manifest()
        assert manifest["books"][0]["book_id"] == "aesop"

    def test_manifest_missing_returns_none(self, tmp_path):
        assert AudiobookStore(str(tmp_path)).manifest() is None

    def test_chapter_path_found(self, store_dir):
        store = AudiobookStore(str(store_dir))
        path = store.chapter_path("aesop", "the-fox-and-the-grapes")
        assert path is not None and path.exists()

    def test_unknown_chapter_returns_none(self, store_dir):
        store = AudiobookStore(str(store_dir))
        assert store.chapter_path("aesop", "yoxdur") is None
        assert store.chapter_path("yoxdur", "the-fox-and-the-grapes") is None

    @pytest.mark.parametrize("evil", [
        "../../etc/passwd",
        "..",
        "aesop/../../secret",
        "a/b",
        "with space",
        "UPPER",
        "semicolon;rm",
    ])
    def test_rejects_unsafe_ids(self, store_dir, evil):
        # Yalnız [a-z0-9-] qəbul olunur — path traversal bağlıdır.
        store = AudiobookStore(str(store_dir))
        assert store.chapter_path(evil, "the-fox-and-the-grapes") is None
        assert store.chapter_path("aesop", evil) is None


class TestAudiobookEndpoints:
    def _client(self, store_dir):
        app.dependency_overrides[get_audiobook_store] = lambda: AudiobookStore(
            str(store_dir)
        )
        return TestClient(app)

    def teardown_method(self):
        app.dependency_overrides.clear()

    def test_manifest_endpoint(self, store_dir):
        r = self._client(store_dir).get("/audiobooks")
        assert r.status_code == 200
        body = r.json()
        assert body["books"][0]["title_az"] == "Ezop Təmsilləri"
        assert body["books"][0]["chapters"][0]["duration_sec"] == 24.0

    def test_manifest_missing_404(self, tmp_path):
        r = self._client(tmp_path).get("/audiobooks")
        assert r.status_code == 404

    def test_chapter_mp3_served(self, store_dir):
        r = self._client(store_dir).get("/audiobooks/aesop/the-fox-and-the-grapes.mp3")
        assert r.status_code == 200
        assert r.headers["content-type"] == "audio/mpeg"
        assert r.content == b"ID3fake-mp3"

    def test_chapter_is_cached_long(self, store_dir):
        # Audio DƏYİŞMƏZ — APK-dan (no-store) fərqli olaraq uzun keşlənməlidir,
        # yoxsa hər dinləmə serverə gedər (trafik + gecikmə).
        r = self._client(store_dir).get("/audiobooks/aesop/the-fox-and-the-grapes.mp3")
        cache = r.headers["cache-control"]
        assert "public" in cache
        assert "immutable" in cache
        assert "max-age=" in cache

    def test_unknown_chapter_404(self, store_dir):
        r = self._client(store_dir).get("/audiobooks/aesop/yoxdur.mp3")
        assert r.status_code == 404

    def test_path_traversal_blocked(self, store_dir):
        # Kodlanmış "../" ilə də çıxmaq olmamalıdır.
        r = self._client(store_dir).get("/audiobooks/aesop/%2e%2e%2f%2e%2e%2fsecret.mp3")
        assert r.status_code == 404
