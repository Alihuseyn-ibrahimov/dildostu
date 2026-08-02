import pytest

from dildostu_server.place_lookup import PlaceLookup, PlaceLookupError


class FakeResponse:
    def __init__(self, status_code, payload):
        self.status_code = status_code
        self._payload = payload

    def json(self):
        return self._payload


class FakeClient:
    """Foursquare cavabını təqlid edir; sorğunu yoxlamaq üçün onu saxlayır."""

    def __init__(self, response):
        self.response = response
        self.calls = []

    def get(self, url, *, headers, params):
        self.calls.append({"url": url, "headers": headers, "params": params})
        return self.response


_MALL = {
    "results": [
        {"name": "28 Mall", "categories": [{"name": "Shopping Mall"}]}
    ]
}


class TestPlaceLookup:
    def test_resolves_pack_id(self):
        client = FakeClient(FakeResponse(200, _MALL))
        lookup = PlaceLookup("key123", client=client)
        result = lookup.resolve(40.3785, 49.8492)
        assert result == {
            "name": "28 Mall",
            "category": "Shopping Mall",
            "pack_id": "market",
        }

    def test_sends_bearer_auth_and_version_header(self):
        client = FakeClient(FakeResponse(200, _MALL))
        PlaceLookup("key123", client=client).resolve(40.0, 49.0)
        headers = client.calls[0]["headers"]
        assert headers["Authorization"] == "Bearer key123"
        assert headers["X-Places-Api-Version"] == "2025-06-17"

    def test_sends_ll_and_sort_params(self):
        client = FakeClient(FakeResponse(200, _MALL))
        PlaceLookup("k", client=client).resolve(40.5, 49.5, radius=150)
        params = client.calls[0]["params"]
        assert params["ll"] == "40.5,49.5"
        assert params["radius"] == 150
        assert params["sort"] == "DISTANCE"

    def test_no_results_returns_none(self):
        client = FakeClient(FakeResponse(200, {"results": []}))
        assert PlaceLookup("k", client=client).resolve(0, 0) is None

    def test_unknown_category_pack_id_none(self):
        payload = {"results": [{"name": "City Hall",
                                "categories": [{"name": "Government Building"}]}]}
        client = FakeClient(FakeResponse(200, payload))
        result = PlaceLookup("k", client=client).resolve(0, 0)
        assert result["pack_id"] is None
        assert result["name"] == "City Hall"

    def test_http_error_raises(self):
        client = FakeClient(FakeResponse(401, {}))
        with pytest.raises(PlaceLookupError):
            PlaceLookup("k", client=client).resolve(0, 0)

    def test_missing_key_raises(self):
        with pytest.raises(PlaceLookupError):
            PlaceLookup("").resolve(0, 0)

    def test_configured_property(self):
        assert PlaceLookup("k").configured is True
        assert PlaceLookup("").configured is False
