"""Foursquare Places API ilə koordinatı yaxınlıqdakı yerə (və paketə) çevirir.

API açarı YALNIZ serverdə saxlanır (`.env`-də FOURSQUARE_API_KEY) — mobil app-a
düşmür. App server-ə `{lat,lng}` göndərir, server paket kimliyini qaytarır.

HTTP client inject olunur (test-də saxta cavabla əvəz olunur).
"""

from __future__ import annotations

import logging
import time
from typing import Any, Callable, Protocol

from .foursquare_mapping import pack_id_for_foursquare

logger = logging.getLogger("dildostu.place")

# Foursquare Places API (2025 versiyası — köhnə api.foursquare.com/v3 deyil).
_BASE_URL = "https://places-api.foursquare.com"
_API_VERSION = "2025-06-17"
_TIMEOUT_SECONDS = 6.0
# Neçə nəticə istənir. QƏSDƏN 1 DEYİL: ən yaxın POI tez-tez bizim paketə
# uyğun gəlməyən tipdir ("Office", "Park", "Government Building") — o halda
# əvvəllər 404 qaytarılırdı, halbuki 30 m-də kafe ola bilərdi. İndi məsafə
# sırası ilə gəzib paketə uyğunlaşan ilk yeri seçirik.
_RESULT_LIMIT = 12
# Kredit/kvota bitəndə Foursquare 429 qaytarır. Bu vəziyyət saatlarla (hətta
# günlərlə) davam edir — hər GPS sorğusunda yenidən cəhd etmək mənasızdır və
# istifadəçini 6 saniyə gözlədir. Bu müddət ərzində birbaşa imtina edilir ki,
# app dərhal OSM ehtiyatına keçsin.
_QUOTA_COOLDOWN_SECONDS = 15 * 60


class PlaceLookupError(Exception):
    """Foursquare açarı yoxdur və ya API xəta qaytardı."""


class PlaceQuotaExceeded(PlaceLookupError):
    """Foursquare krediti/kvotası bitib (HTTP 429).

    Digər xətalardan AYRILIR: bu, kod problemi deyil, hesab problemidir və
    yalnız insan müdaxiləsi (kredit almaq) ilə həll olunur. 2026-08-07-də
    production-da aşkarlandı — `x-ratelimit-remaining: 0`, hər sorğu 503
    verirdi və heç bir yerdə görünmürdü, ona görə loq əlavə edildi.
    """


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
        clock: Callable[[], float] | None = None,
    ) -> None:
        self._api_key = api_key
        self._base_url = base_url.rstrip("/")
        self._client = client
        self._clock = clock or time.monotonic
        # Kvota bitəndən sonra bu ana qədər sorğu edilmir (bax
        # _QUOTA_COOLDOWN_SECONDS).
        self._quota_blocked_until: float | None = None

    @property
    def quota_exhausted(self) -> bool:
        """Kvota bitib sayılırmı (soyuma müddəti hələ keçməmiş)."""
        until = self._quota_blocked_until
        return until is not None and self._clock() < until

    @property
    def configured(self) -> bool:
        return bool(self._api_key)

    def resolve(
        self, lat: float, lng: float, radius: int = 200
    ) -> dict[str, Any] | None:
        """Paketə uyğunlaşan ən yaxın yeri gətir.

        Açar yoxdursa/API xəta versə `PlaceLookupError`.

        Nəticə: `{"name", "category", "pack_id", "distance_m"}`.
        `pack_id` `None` ola bilər — radiusda yer var, amma heç birinin tipi
        paketlərimizə uyğun gəlmir (məs. "Park"). Bu halda ƏN YAXIN yerin adı
        qaytarılır ki, çağıran tərəf istifadəçiyə nə tapıldığını göstərə bilsin
        (əvvəllər bu hal tamamilə itirdi).

        Radiusda heç bir yer yoxdursa `None`.
        """
        if not self._api_key:
            raise PlaceLookupError("FOURSQUARE_API_KEY təyin olunmayıb")

        if self.quota_exhausted:
            # Şəbəkəyə heç çıxmırıq — app dərhal OSM ehtiyatına keçir.
            raise PlaceQuotaExceeded(
                "Foursquare krediti bitib (soyuma müddətindədir)"
            )

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
                "limit": _RESULT_LIMIT,
            },
        )
        if response.status_code == 429:
            self._quota_blocked_until = self._clock() + _QUOTA_COOLDOWN_SECONDS
            # ERROR səviyyəsi QƏSDƏN: bu, insan müdaxiləsi tələb edir (kredit
            # almaq) və əvvəllər tamamilə görünməz qalırdı.
            logger.error(
                "place_quota_exhausted Foursquare 429 — kredit bitdi, "
                "%d dəqiqə OSM ehtiyatı ilə davam edilir",
                _QUOTA_COOLDOWN_SECONDS // 60,
            )
            raise PlaceQuotaExceeded("Foursquare krediti bitib (HTTP 429)")
        if response.status_code != 200:
            logger.warning("place_http_error status=%s", response.status_code)
            raise PlaceLookupError(f"Foursquare HTTP {response.status_code}")

        # Uğurlu cavab — kvota bloku (varsa) götürülür.
        self._quota_blocked_until = None

        results = (response.json() or {}).get("results") or []
        if not results:
            return None

        # `sort=DISTANCE` sırasını qoruyaraq paketə uyğunlaşan ilk yeri seç.
        for place in results:
            categories = place.get("categories") or []
            pack_id = pack_id_for_foursquare(categories)
            if pack_id:
                return _place_dict(place, categories, pack_id)

        nearest = results[0]
        return _place_dict(nearest, nearest.get("categories") or [], None)

    def _http(self) -> _HttpClient:
        if self._client is not None:
            return self._client
        import httpx

        # Hər sorğuda qısa ömürlü client — sadəlik üçün (yer sorğusu seyrəkdir).
        self._client = httpx.Client(timeout=_TIMEOUT_SECONDS)
        return self._client


def _place_dict(
    place: dict, categories: list, pack_id: str | None
) -> dict[str, Any]:
    return {
        "name": place.get("name", ""),
        "category": _category_name(categories),
        "pack_id": pack_id,
        "distance_m": _distance_m(place),
    }


def _category_name(categories: list) -> str:
    for cat in categories:
        name = cat.get("name")
        if isinstance(name, str) and name:
            return name
    return ""


def _distance_m(place: dict) -> int | None:
    """Foursquare-in verdiyi metr məsafəsi. Yoxdursa/yanlışsa `None`.

    Bu, "yaxınlıqdadır" iddiasını yoxlamağa imkan verir — əvvəllər 195 m-dəki
    kafe 5 m-dəkindən fərqlənmirdi.
    """
    raw = place.get("distance")
    if isinstance(raw, bool) or not isinstance(raw, (int, float)):
        return None
    return int(raw) if raw >= 0 else None
