"""Google Play üçün məcburi statik səhifələr (məxfilik siyasəti, hesab silmə)."""

from fastapi.testclient import TestClient

from dildostu_server.app import app


class TestPrivacyPolicy:
    def test_returns_200_html(self):
        client = TestClient(app)
        r = client.get("/privacy")
        assert r.status_code == 200
        assert "text/html" in r.headers["content-type"]

    def test_mentions_data_collected(self):
        client = TestClient(app)
        body = client.get("/privacy").text
        assert "Hesab məlumatı" in body
        assert "Məkan" in body

    def test_mentions_contact_email(self):
        client = TestClient(app)
        assert "dildostu@prdostu.com" in client.get("/privacy").text

    def test_links_to_delete_account(self):
        client = TestClient(app)
        assert "/delete-account" in client.get("/privacy").text


class TestDeleteAccountPage:
    def test_returns_200_html(self):
        client = TestClient(app)
        r = client.get("/delete-account")
        assert r.status_code == 200
        assert "text/html" in r.headers["content-type"]

    def test_mentions_in_app_flow(self):
        client = TestClient(app)
        body = client.get("/delete-account").text
        assert "Profil" in body
        assert "Hesabı sil" in body

    def test_mentions_contact_email_fallback(self):
        client = TestClient(app)
        assert "dildostu@prdostu.com" in client.get("/delete-account").text
