import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../engine/review_engine.dart';

const _prefsKey = 'dildostu.review.v1';
const _activeDaysKey = 'dildostu.review.active_days.v1';

/// "Mənimsənilmiş" sayılmaq üçün minimum ardıcıl "bilirəm" addımı.
const masteredStepThreshold = 3;

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Hər sözün (wordKey = "packId:word") ReviewState-ini və son review
/// tarixini saxlayır. Axşam quiz-i üçün "bu gün toxunulan sözlər" siyahısı,
/// statistika ekranı üçün söz sayı/streak buradan çıxarılır.
class ReviewRepository {
  ReviewRepository._(this._prefs, this._entries, this._activeDayKeys);

  final SharedPreferences _prefs;
  final Map<String, _Entry> _entries;
  final Set<String> _activeDayKeys;

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
    final activeDays = (prefs.getStringList(_activeDaysKey) ?? []).toSet();
    return ReviewRepository._(prefs, entries, activeDays);
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
    _activeDayKeys.add(_dateKey(now));
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

  /// Ən azı bir dəfə review olunan sözlərin ümumi sayı.
  int get wordCount => _entries.length;

  /// `masteredStepThreshold`-a çatmış (yaxşı bilinən) sözlərin sayı.
  int get masteredCount =>
      _entries.values.where((e) => e.state.step >= masteredStepThreshold).length;

  /// `today`-dən geriyə ardıcıl neçə gün istifadəçi ən azı bir söz review
  /// edib (gün buraxılanda kəsilir).
  int currentStreak({required DateTime today}) {
    var streak = 0;
    var day = today;
    while (_activeDayKeys.contains(_dateKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> _persist() async {
    final encoded = {
      for (final e in _entries.entries) e.key: e.value.toJson(),
    };
    await _prefs.setString(_prefsKey, jsonEncode(encoded));
    await _prefs.setStringList(_activeDaysKey, _activeDayKeys.toList());
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
