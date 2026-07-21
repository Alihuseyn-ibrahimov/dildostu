import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/review_engine.dart';

const _prefsKey = 'dildostu.review.v1';

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Hər sözün (wordKey = "packId:word") ReviewState-ini və son review
/// tarixini saxlayır. Axşam quiz-i üçün "bu gün toxunulan sözlər" siyahısı
/// buradan çıxarılır.
class ReviewRepository {
  ReviewRepository._(this._prefs, this._entries);

  final SharedPreferences _prefs;
  final Map<String, _Entry> _entries;

  static Future<ReviewRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final entries = <String, _Entry>{};
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        entries[entry.key] = _Entry.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    return ReviewRepository._(prefs, entries);
  }

  ReviewState stateFor(String wordKey) =>
      _entries[wordKey]?.state ?? ReviewState.initial();

  Future<void> recordReview(
    String wordKey,
    ReviewOutcome outcome, {
    required DateTime now,
  }) async {
    final current = stateFor(wordKey);
    final next = current.apply(outcome, now: now);
    _entries[wordKey] = _Entry(state: next, reviewedDateKey: _dateKey(now));
    await _persist();
  }

  /// Verilmiş tarixdə (gün dəqiqliyi ilə) review olunan wordKey-lər.
  List<String> reviewedOn(DateTime day) {
    final key = _dateKey(day);
    return _entries.entries
        .where((e) => e.value.reviewedDateKey == key)
        .map((e) => e.key)
        .toList(growable: false);
  }

  Future<void> _persist() async {
    final encoded = {
      for (final e in _entries.entries) e.key: e.value.toJson(),
    };
    await _prefs.setString(_prefsKey, jsonEncode(encoded));
  }
}

class _Entry {
  const _Entry({required this.state, required this.reviewedDateKey});

  final ReviewState state;
  final String reviewedDateKey;

  factory _Entry.fromJson(Map<String, dynamic> json) => _Entry(
        state: ReviewState.fromJson(json['state'] as Map<String, dynamic>),
        reviewedDateKey: json['reviewed_date'] as String,
      );

  Map<String, dynamic> toJson() => {
        'state': state.toJson(),
        'reviewed_date': reviewedDateKey,
      };
}
