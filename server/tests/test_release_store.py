import json

from dildostu_server.release_store import ReleaseStore


class TestVersionInfo:
    def test_no_release_returns_none(self, tmp_path):
        store = ReleaseStore(str(tmp_path))
        assert store.version_info() is None

    def test_reads_version_json(self, tmp_path):
        (tmp_path / "version.json").write_text(
            json.dumps({"version_code": 3, "version_name": "1.0.0+3", "notes": "test"}),
            encoding="utf-8",
        )
        store = ReleaseStore(str(tmp_path))
        info = store.version_info()
        assert info["version_code"] == 3
        assert info["version_name"] == "1.0.0+3"

    def test_reads_version_json_with_bom(self, tmp_path):
        # Windows PowerShell `Set-Content -Encoding utf8` BOM əlavə edir.
        (tmp_path / "version.json").write_text(
            json.dumps({"version_code": 4, "version_name": "1.0.0+4"}),
            encoding="utf-8-sig",
        )
        store = ReleaseStore(str(tmp_path))
        assert store.version_info()["version_code"] == 4


class TestApkPath:
    def test_no_apk_returns_none(self, tmp_path):
        store = ReleaseStore(str(tmp_path))
        assert store.apk_path() is None

    def test_returns_path_when_present(self, tmp_path):
        (tmp_path / "latest.apk").write_bytes(b"fake-apk-bytes")
        store = ReleaseStore(str(tmp_path))
        path = store.apk_path()
        assert path is not None
        assert path.read_bytes() == b"fake-apk-bytes"
