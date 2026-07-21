import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/pack.dart';

/// MVP kateqoriyalarının sabit siyahısı — asset fayllarının adları
/// (`assets/packs/<id>.json`). content_gen/categories.py ilə uzlaşır.
const List<String> kPackIds = [
  'morning',
  'greetings',
  'cafe',
  'restaurant',
  'market',
  'airport',
  'hotel',
  'transport',
  'pharmacy',
  'evening',
];

/// Söz paketlərini asset JSON-larından yükləyib yaddaşda saxlayır.
///
/// Parsing (təmiz, testlənə bilən) asset oxumasından ayrıdır: `fromJsonStrings`
/// unit testlərdə birbaşa işlədilir; `loadFromAssets` isə cihazda rootBundle-dan
/// oxuyur.
class PackRepository {
  PackRepository._(this._byId);

  final Map<String, Pack> _byId;

  /// Paketlər pack_id-yə görə əlifba sırasında (deterministik UI üçün).
  List<Pack> get packs {
    final list = _byId.values.toList()
      ..sort((a, b) => a.packId.compareTo(b.packId));
    return List.unmodifiable(list);
  }

  List<String> get packIds => packs.map((p) => p.packId).toList();

  Pack? byId(String id) => _byId[id];

  /// Xam JSON sətirlərindən repozitoriya qur. Xarab JSON → FormatException.
  factory PackRepository.fromJsonStrings(Iterable<String> jsonStrings) {
    final byId = <String, Pack>{};
    for (final raw in jsonStrings) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final pack = Pack.fromJson(decoded);
      byId[pack.packId] = pack;
    }
    return PackRepository._(byId);
  }

  /// Cihazda `assets/packs/<id>.json` fayllarını yüklə.
  static Future<PackRepository> loadFromAssets({
    AssetBundle? bundle,
    List<String> ids = kPackIds,
  }) async {
    final assets = bundle ?? rootBundle;
    final jsonStrings = <String>[];
    for (final id in ids) {
      jsonStrings.add(await assets.loadString('assets/packs/$id.json'));
    }
    return PackRepository.fromJsonStrings(jsonStrings);
  }
}
