"""Musiqi bölməsi — MusicStore + /music endpoint."""

import json

import pytest
from fastapi.testclient import TestClient

from dildostu_server.app import app, get_music_store
from dildostu_server.music_store import MusicStore


@pytest.fixture
def store_dir(tmp_path):
    """Kiçik, real quruluşlu musiqi manifest qovluğu (mp3 yoxdur — YouTube-dan gəlir)."""
    manifest = {
        "version": 1,
        "songs": [
            {
                "song_id": "jane-taylor-twinkle-twinkle-little-star",
                "title": "Twinkle Twinkle Little Star",
                "artist": "Jane Taylor",
                "youtube_id": "yCjJyiqpAuU",
                "level": "beginner",
                "lang": "en",
                "lines": [
                    {
                        "line_id": "l1",
                        "text": "Twinkle, twinkle, little star",
                        "translation_az": "Bərq vur, bərq vur, kiçik ulduz",
                    }
                ],
            }
        ],
    }
    (tmp_path / "songs.json").write_text(
        json.dumps(manifest, ensure_ascii=False), encoding="utf-8"
    )
    return tmp_path


class TestMusicStore:
    def test_manifest_read(self, store_dir):
        store = MusicStore(str(store_dir))
        manifest = store.manifest()
        assert manifest["songs"][0]["song_id"] == "jane-taylor-twinkle-twinkle-little-star"

    def test_manifest_missing_returns_none(self, tmp_path):
        assert MusicStore(str(tmp_path)).manifest() is None


class TestMusicEndpoint:
    def _client(self, store_dir):
        app.dependency_overrides[get_music_store] = lambda: MusicStore(str(store_dir))
        return TestClient(app)

    def teardown_method(self):
        app.dependency_overrides.clear()

    def test_manifest_endpoint(self, store_dir):
        r = self._client(store_dir).get("/music")
        assert r.status_code == 200
        body = r.json()
        assert body["songs"][0]["title"] == "Twinkle Twinkle Little Star"
        assert body["songs"][0]["youtube_id"] == "yCjJyiqpAuU"
        assert body["songs"][0]["lines"][0]["translation_az"] == "Bərq vur, bərq vur, kiçik ulduz"

    def test_manifest_missing_404(self, tmp_path):
        r = self._client(tmp_path).get("/music")
        assert r.status_code == 404


class TestMusicEmbed:
    def test_valid_id_returns_iframe_html(self):
        r = TestClient(app).get("/music/embed/yCjJyiqpAuU")
        assert r.status_code == 200
        assert "text/html" in r.headers["content-type"]
        assert "https://www.youtube.com/embed/yCjJyiqpAuU" in r.text
        assert "<iframe" in r.text

    @pytest.mark.parametrize("bad_id", [
        "../../etc/passwd",
        "<script>alert(1)</script>",
        "tooshort",
        "waytoolongforavalididxx",
        "",
    ])
    def test_invalid_id_rejected(self, bad_id):
        r = TestClient(app).get(f"/music/embed/{bad_id}")
        assert r.status_code in (400, 404)
        assert "<script>" not in r.text
