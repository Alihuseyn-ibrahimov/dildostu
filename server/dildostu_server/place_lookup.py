"""Foursquare Places API ilə koordinatı yaxınlıqdakı yerə (və paketə) çevirir.

API açarı YALNIZ serverdə saxlanır (`.env`-də FOURSQUARE_API_KEY) — mobil app-a
düşmür. App server-ə `{lat,lng}` göndərir, server paket kimliyini qaytarır.

HTTP client inject olunur (test-də saxta cavabla əvəz olunur).
"""

from __future__ import annotations

from typing import Any, Protocol

from .foursquare_mapping import pack_id_for_foursquare

# Foursquare Places API (2025 versiyası — köhnə api.foursquare.com/v3 deyil).
_BASE_URL = "https://places-api.foursquare.com"
_API_VERSION = "2025-06-17"
_TIMEOUT_SECONDS = 6.0


class PlaceLookupError(Exception):
    """Foursquare açarı yoxdur və ya API xəta qaytardı."""


class _Response(Protocol):
    status_code: int

    def json(self) -> Any:  # pragma: no cover - protokol
        ...


class _HttpClient(Protocol):
    def get(
        self, url: str, *, headers: dict, params: dict
    ) -> _Response:  # pragma: no cover - protokol
        ...


class PlaceLookup:
    """Koordinatı → {name, category, pack_id}. Yer tapılmasa None."""

    def __init__(
        self,
        api_key: str,
        client: _HttpClient | None = None,
        base_url: str = _BASE_URL,
    ) -> None:
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        self._client = client

    @property
    def configured(self) -> bool:
        return bool(self._api_key)

    def resolve(
        self, lat: float, lng: float, radius: int = 200
    ) -> dict[str, Any] | None:
        """Ən yaxın yeri gətir. Açar yoxdursa/API xəta versə PlaceLookupError.

        Nəticə: `{"name": str, "category": str, "pack_id": str | None}`.
        Radiusda heç bir yer yoxdursa `None`.
        """
        if not self._api_key:
            raise PlaceLookupError("FOURSQUARE_API_KEY təyin olunmayıb")

        response = self._http().get(
            f"{self._base_url}/places/search",
            headers={
                "Authorization": f"Bearer {self._api_key}",
                "X-Places-Api-Version": _API_VERSION,
                "accept": "application/json",
            },
            params={
                "ll": f"{lat},{lng}",
                "radius": radius,
                "sort": "DISTANCE",
                "limit": 1,
            },
        )
        if response.status_code != 200:
            raise PlaceLookupError(f"Foursquare HTTP {response.status_code}")

        results = (response.json() or {}).get("results") or []
        if not results:
            return None

        top = results[0]
        categories = top.get("categories") or []
        category_name = ""
        for cat in categories:
            name = cat.get("name")
            if isinstance(name, str) and name:
                category_name = name
                break
        return {
            "name": top.get("name", ""),
            "category": category_name,
            "pack_id": pack_id_for_foursquare(categories),
        }

    def _http(self) -> _HttpClient:
        if self._client is not None:
            return self._client
        import httpx

        # Hər sorğuda qısa ömürlü client — sadəlik üçün (yer sorğusu seyrəkdir).
        self._client = httpx.Client(timeout=_TIMEOUT_SECONDS)
        return self._client
