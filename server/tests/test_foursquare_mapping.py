from dildostu_server.foursquare_mapping import pack_id_for_foursquare


def _cats(*names):
    return [{"name": n} for n in names]


class TestFoursquareMapping:
    def test_shopping_mall_to_market(self):
        assert pack_id_for_foursquare(_cats("Shopping Mall")) == "market"

    def test_supermarket_to_market(self):
        assert pack_id_for_foursquare(_cats("Supermarket")) == "market"

    def test_coffee_shop_prefers_cafe_over_market(self):
        # "Coffee Shop" həm coffee (cafe) həm shop (market) daşıyır — cafe qalib.
        assert pack_id_for_foursquare(_cats("Coffee Shop")) == "cafe"

    def test_restaurant(self):
        assert pack_id_for_foursquare(_cats("Italian Restaurant")) == "restaurant"

    def test_pharmacy(self):
        assert pack_id_for_foursquare(_cats("Pharmacy")) == "pharmacy"

    def test_airport_beats_transport(self):
        assert pack_id_for_foursquare(_cats("Airport Terminal")) == "airport"

    def test_metro_station_to_transport(self):
        assert pack_id_for_foursquare(_cats("Metro Station")) == "transport"

    def test_hotel(self):
        assert pack_id_for_foursquare(_cats("Hotel")) == "hotel"

    def test_case_insensitive(self):
        assert pack_id_for_foursquare(_cats("SUPERMARKET")) == "market"

    def test_uses_short_name_field(self):
        assert pack_id_for_foursquare([{"short_name": "Café"}]) == "cafe"

    def test_unknown_returns_none(self):
        assert pack_id_for_foursquare(_cats("Government Building")) is None

    def test_empty_returns_none(self):
        assert pack_id_for_foursquare([]) is None

    def test_first_matching_rule_wins_across_categories(self):
        # Bir yer "Park" + "Café" — cafe qaydası tapılır (park paketimizdə yoxdur).
        assert pack_id_for_foursquare(_cats("Park", "Café")) == "cafe"
