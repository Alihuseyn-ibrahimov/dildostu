"""Foursquare kredit/kvota bitmə halı (2026-08-07-də production-da aşkarlandı).

O gün `x-ratelimit-remaining: 0` idi və HƏR `/place/resolve` 503 verirdi;
heç bir loq/metrik olmadığı üçün bu, uzun müddət görünməz qalmışdı.
"""

from dildostu_server.place_lookup import (
    PlaceLookup,
    PlaceLookupError,
    PlaceQuotaExceeded,
)


class FakeResponse:
    def __init__(self, status_code, payload=None):
        self.status_code = status_code
        self._payload = payload or {}

    def json(self):
        return self._payload


class CountingClient:
    """Sorğu sayını sayır — soyuma müddətinin işlədiyini yoxlamaq üçün."""

    def __init__(self, *responses):
        self._responses = list(responses)
        self.calls = 0

    def get(self, url, *, headers, params):
        self.calls += 1
        if len(self._responses) > 1:
            return self._responses.pop(0)
        return self._responses[0]


_CAFE = {"results": [{"name": "Kafe", "categories": [{"name": "Café"}],
                      "distance": 10}]}


class FakeClock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now

    def advance(self, seconds):
        self.now += seconds


class TestQuotaExceeded:
    def test_429_raises_quota_error_not_generic(self):
        client = CountingClient(FakeResponse(429))
        lookup = PlaceLookup("k", client=client)
        try:
            lookup.resolve(0, 0)
        except PlaceQuotaExceeded:
            pass
        else:
            raise AssertionError("PlaceQuotaExceeded gözlənilirdi")

    def test_quota_error_is_a_place_lookup_error(self):
        """Köhnə `except PlaceLookupError` blokları sınmamalıdır."""
        assert issubclass(PlaceQuotaExceeded, PlaceLookupError)

    def test_quota_flag_set_after_429(self):
        lookup = PlaceLookup("k", client=CountingClient(FakeResponse(429)))
        assert lookup.quota_exhausted is False
        try:
            lookup.resolve(0, 0)
        except PlaceQuotaExceeded:
            pass
        assert lookup.quota_exhausted is True

    def test_no_network_call_during_cooldown(self):
        """Kvota bitibsə hər GPS sorğusunda API-yə çıxmaq mənasızdır."""
        client = CountingClient(FakeResponse(429))
        lookup = PlaceLookup("k", client=client)
        for _ in range(5):
            try:
                lookup.resolve(0, 0)
            except PlaceQuotaExceeded:
                pass
        assert client.calls == 1, "soyuma müddətində yalnız bir sorğu olmalı"

    def test_retries_after_cooldown_expires(self):
        clock = FakeClock()
        client = CountingClient(FakeResponse(429), FakeResponse(200, _CAFE))
        lookup = PlaceLookup("k", client=client, clock=clock)

        try:
            lookup.resolve(0, 0)
        except PlaceQuotaExceeded:
            pass
        clock.advance(16 * 60)

        assert lookup.quota_exhausted is False
        assert lookup.resolve(0, 0)["pack_id"] == "cafe"
        assert client.calls == 2

    def test_success_clears_quota_block(self):
        clock = FakeClock()
        client = CountingClient(FakeResponse(429), FakeResponse(200, _CAFE))
        lookup = PlaceLookup("k", client=client, clock=clock)
        try:
            lookup.resolve(0, 0)
        except PlaceQuotaExceeded:
            pass
        clock.advance(16 * 60)
        lookup.resolve(0, 0)
        assert lookup.quota_exhausted is False

    def test_other_http_errors_do_not_trigger_cooldown(self):
        # 500 keçici ola bilər — onu 15 dəqiqə bloklamaq düzgün deyil.
        client = CountingClient(FakeResponse(500))
        lookup = PlaceLookup("k", client=client)
        for _ in range(3):
            try:
                lookup.resolve(0, 0)
            except PlaceLookupError:
                pass
        assert lookup.quota_exhausted is False
        assert client.calls == 3
