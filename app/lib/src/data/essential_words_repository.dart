import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/pack.dart';

/// 504 sabit söz bankının offline (asset bundle) nüsxəsi — server əlçatmaz
/// olanda "Əsas lüğət" heç olmasa əvvəlcədən hazırlanmış AI məzmunu ilə işləsin.
///
/// Struktur canlı serverin cavabı ilə eynidir (word/translation_az/ipa/
/// example/example_az/level) — yalnız BİR DƏFƏ əvvəlcədən yaradılıb
/// (bax `essential_words.py` + tək dəfəlik generasiya skripti), runtime-da
/// AI-ya müraciət olunmur.
class EssentialWordsRepository {
  EssentialWordsRepository._(this.pack);

  final Pack pack;

  factory EssentialWordsRepository.fromJsonString(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return EssentialWordsRepository._(Pack.fromJson(decoded));
  }

  static Future<EssentialWordsRepository> loadFromAssets({
    AssetBundle? bundle,
  }) async {
    final assets = bundle ?? rootBundle;
    final raw = await assets.loadString('assets/essential/words.json');
    return EssentialWordsRepository.fromJsonString(raw);
  }
}
