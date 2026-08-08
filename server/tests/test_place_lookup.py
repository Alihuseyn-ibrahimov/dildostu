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
        {"name": "28 Mall", "categories": [{"name": "Shopping Mall"}],
         "distance": 42}
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
            "distance_m": 42,
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


class TestNearestMappableSelection:
    """2026-08-07 — əvvəllər YALNIZ ən yaxın nəticə götürülürdü (`limit=1`).

    Ən yaxın POI tez-tez paketə uyğun gəlmirdi (ofis/park) və istifadəçi
    30 m-dəki kafeni itirirdi. İndi məsafə sırası ilə uyğunlaşan ilk yer seçilir.
    """

    def test_asks_for_more_than_one_result(self):
        client = FakeClient(FakeResponse(200, _MALL))
        PlaceLookup("k", client=client).resolve(40.0, 49.0)
        assert client.calls[0]["params"]["limit"] > 1

    def test_skips_unmappable_nearest_and_picks_next(self):
        payload = {"results": [
            {"name": "Nazirlik", "categories": [{"name": "Government Building"}],
             "distance": 8},
            {"name": "Parkda skamya", "categories": [{"name": "Park"}],
             "distance": 15},
            {"name": "Kofe Evi", "categories": [{"name": "Coffee Shop"}],
             "distance": 34},
        ]}
        client = FakeClient(FakeResponse(200, payload))
        result = PlaceLookup("k", client=client).resolve(0, 0)
        assert result["pack_id"] == "cafe"
        assert result["name"] == "Kofe Evi"
        assert result["distance_m"] == 34

    def test_prefers_nearest_when_several_map(self):
        payload = {"results": [
            {"name": "Yaxın kafe", "categories": [{"name": "Café"}],
             "distance": 12},
            {"name": "Uzaq market", "categories": [{"name": "Supermarket"}],
             "distance": 90},
        ]}
        client = FakeClient(FakeResponse(200, payload))
        result = PlaceLookup("k", client=client).resolve(0, 0)
        assert result["name"] == "Yaxın kafe"

    def test_all_unmappable_returns_nearest_with_none_pack(self):
        payload = {"results": [
            {"name": "Nazirlik", "categories": [{"name": "Government Building"}],
             "distance": 8},
            {"name": "Xəstəxana", "categories": [{"name": "Hospital"}],
             "distance": 20},
        ]}
        client = FakeClient(FakeResponse(200, payload))
        result = PlaceLookup("k", client=client).resolve(0, 0)
        assert result["pack_id"] is None
        assert result["name"] == "Nazirlik"
        assert result["distance_m"] == 8

    def test_missing_distance_is_none_not_crash(self):
        payload = {"results": [
            {"name": "Kafe", "categories": [{"name": "Café"}]},
        ]}
        client = FakeClient(FakeResponse(200, payload))
        assert PlaceLookup("k", client=client).resolve(0, 0)["distance_m"] is None

    def test_invalid_distance_ignored(self):
        payload = {"results": [
            {"name": "Kafe", "categories": [{"name": "Café"}], "distance": "yaxın"},
        ]}
        client = FakeClient(FakeResponse(200, payload))
        assert PlaceLookup("k", client=client).resolve(0, 0)["distance_m"] is None

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
