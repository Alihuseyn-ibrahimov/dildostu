import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../engine/osm_place_mapping.dart';

const _overpassUrl = 'https://overpass-api.de/api/interpreter';
const _searchRadiusMeters = 60;
const _requestTimeout = Duration(seconds: 3);

/// Cihazın GPS-i və OpenStreetMap Overpass API-si ilə yaxınlıqdakı yerin
/// tipini müəyyənləşdirir (spec §3.2/§4). Bütün xəta halları (icazə yoxdur,
/// internet yoxdur, timeout) sakitcə `null` qaytarır — ContextEngine bu halda
/// vaxt qaydasına düşür, app sınmır.
class LocationService {
  LocationService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  Future<String?> resolveNearbyPackId() async {
    try {
      if (!await _hasUsablePermission()) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: _requestTimeout,
        ),
      );

      final tags = await _queryNearbyTags(position.latitude, position.longitude)
          .timeout(_requestTimeout);
      if (tags == null) return null;

      return packIdForOsmTags(tags);
    } catch (_) {
      // GPS/şəbəkə xətası, timeout və s. — sakitcə imtina et.
      return null;
    }
  }

  Future<bool> _hasUsablePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Map<String, String>?> _queryNearbyTags(double lat, double lon) async {
    final query = '[out:json][timeout:3];'
        'node(around:$_searchRadiusMeters,$lat,$lon)'
        '[~"^(amenity|shop|tourism|aeroway|railway|public_transport)\$"~"."];'
        'out tags 1;';
    final response = await _http.post(
      Uri.parse(_overpassUrl),
      body: {'data': query},
    );
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = decoded['elements'] as List<dynamic>?;
    if (elements == null || elements.isEmpty) return null;

    final tags = (elements.first as Map<String, dynamic>)['tags'];
    if (tags is! Map) return null;
    return tags.map((key, value) => MapEntry(key.toString(), value.toString()));
  }
}
