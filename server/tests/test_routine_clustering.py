from dildostu_server.routine_clustering import cluster_places, haversine_distance_m


def _sample(lat, lng, place_type="cafe", pack_id="cafe", ts="2026-08-02T09:00:00+00:00"):
    return {"lat": lat, "lng": lng, "place_type": place_type, "pack_id": pack_id, "ts": ts}


class TestHaversine:
    def test_same_point_zero(self):
        assert haversine_distance_m(40.37, 49.83, 40.37, 49.83) == 0

    def test_known_short_distance(self):
        # ~0.001 dərəcə enlik fərqi ≈ 111m
        d = haversine_distance_m(40.370, 49.830, 40.371, 49.830)
        assert 100 < d < 120


class TestClusterPlaces:
    def test_repeated_same_place_forms_cluster(self):
        samples = [_sample(40.370, 49.830) for _ in range(5)]
        clusters = cluster_places(samples)
        assert len(clusters) == 1
        assert clusters[0]["count"] == 5
        assert clusters[0]["pack_id"] == "cafe"

    def test_below_threshold_no_cluster(self):
        samples = [_sample(40.370, 49.830) for _ in range(2)]
        assert cluster_places(samples, min_count=3) == []

    def test_exact_threshold_forms_cluster(self):
        samples = [_sample(40.370, 49.830) for _ in range(3)]
        clusters = cluster_places(samples, min_count=3)
        assert len(clusters) == 1

    def test_scattered_points_no_cluster(self):
        # Hər biri fərqli, bir-birindən uzaq (>100m) — heç biri təkrarlanmır.
        samples = [
            _sample(40.30 + i * 0.01, 49.80 + i * 0.01) for i in range(5)
        ]
        assert cluster_places(samples) == []

    def test_multiple_distinct_clusters(self):
        home = [_sample(40.370, 49.830, "home", "cafe") for _ in range(4)]
        work = [_sample(40.400, 49.870, "work", "restaurant") for _ in range(6)]
        clusters = cluster_places(home + work)
        assert len(clusters) == 2
        # say azalan sırada — iş (6) əvvəl gəlir
        assert clusters[0]["count"] == 6
        assert clusters[1]["count"] == 4

    def test_missing_pack_id_falls_back_to_place_type(self):
        samples = [_sample(40.370, 49.830, "airport", None) for _ in range(3)]
        clusters = cluster_places(samples)
        assert clusters[0]["pack_id"] == "airport"

    def test_points_within_radius_merge(self):
        # 3 nöqtə bir-birindən < 100m aralıda — eyni klasterə düşməlidir.
        samples = [
            _sample(40.3700, 49.8300),
            _sample(40.3703, 49.8300),  # ~33m
            _sample(40.3706, 49.8300),  # ~66m
        ]
        clusters = cluster_places(samples)
        assert len(clusters) == 1
        assert clusters[0]["count"] == 3

    def test_cluster_has_required_fields(self):
        samples = [_sample(40.370, 49.830) for _ in range(3)]
        cluster = cluster_places(samples)[0]
        for key in ("center_lat", "center_lng", "radius", "pack_id", "label",
                    "hour_window", "count"):
            assert key in cluster

    def test_hour_window_morning(self):
        samples = [
            _sample(40.370, 49.830, ts="2026-08-02T08:00:00+00:00")
            for _ in range(3)
        ]
        assert cluster_places(samples)[0]["hour_window"] == "morning"
