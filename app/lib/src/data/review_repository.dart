import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/review_engine.dart';
import '../models/live_message.dart';
import '../models/word.dart';

const _prefsKey = 'dildostu.review.v1';
const _activeDaysKey = 'dildostu.review.active_days.v1';

/// "Mənimsənilmiş" sayılmaq üçün minimum ardıcıl "bilirəm" addımı.
const masteredStepThreshold = 3;

String reviewWordKey(LiveMessage message) => '${message.packId}:${message.word}';

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// UI üçün son öyrənilən sözün qısa məlumatı.
class WordProgressItem {
  const WordProgressItem({
    required this.wordKey,
    required this.word,
    required this.packId,
    required this.step,
    this.translationAz,
    this.lastSeenAt,
  });

  final String wordKey;
  final String word;
  final String packId;
  final String? translationAz;
  final int step;
  final DateTime? lastSeenAt;

  bool get isMastered => step >= masteredStepThreshold;
  bool get isLearning => step >= 1 && step < masteredStepThreshold;
}

/// Paket üzrə qısa statistika.
class PackProgressStats {
  const PackProgressStats({
    required this.packId,
    required this.touched,
    required this.learning,
    required this.mastered,
  });

  final String packId;
  final int touched;
  final int learning;
  final int mastered;
}

/// Hər sözün (wordKey = "packId:word") ReviewState-ini və son review
/// tarixini saxlayır. Axşam quiz-i üçün "bu gün toxunulan sözlər" siyahısı,
/// statistika ekranı üçün söz sayı/streak buradan çıxarılır.
class ReviewRepository extends ChangeNotifier {
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

  /// Söz detalları açılanda çağırılır — streak və "toxunulan" sayını yeniləyir.
  Future<void> recordExposure(
    String wordKey, {
    required DateTime now,
    LiveMessage? hint,
  }) async {
    final existing = _entries[wordKey];
    final hints = _hintsFromMessage(hint);
    if (existing == null) {
      _entries[wordKey] = _Entry(
        state: ReviewState(
          step: 1,
          dueAt: now.add(const Duration(days: 1)),
        ),
        reviewedDateKey: _dateKey(now),
        lastSeenAt: now,
        seenCount: 1,
        translationAz: hints.translationAz,
        ipa: hints.ipa,
        example: hints.example,
        exampleAz: hints.exampleAz,
        level: hints.level,
      );
    } else {
      final bumpedState = existing.state.step == 0
          ? ReviewState(step: 1, dueAt: now.add(const Duration(days: 1)))
          : existing.state;
      _entries[wordKey] = existing.copyWith(
        state: bumpedState,
        reviewedDateKey: _dateKey(now),
        lastSeenAt: now,
        seenCount: existing.seenCount + 1,
        translationAz: hints.translationAz ?? existing.translationAz,
        ipa: hints.ipa ?? existing.ipa,
        example: hints.example ?? existing.example,
        exampleAz: hints.exampleAz ?? existing.exampleAz,
        level: hints.level ?? existing.level,
      );
    }
    _activeDayKeys.add(_dateKey(now));
    await _persist();
    notifyListeners();
  }

  Future<void> recordReview(
    String wordKey,
    ReviewOutcome outcome, {
    required DateTime now,
    LiveMessage? hint,
  }) async {
    final existing = _entries[wordKey];
    final current = existing?.state ?? ReviewState.initial();
    final next = current.apply(outcome, now: now);
    final hints = _hintsFromMessage(hint);
    _entries[wordKey] = (existing ??
            _Entry(
              state: next,
              reviewedDateKey: _dateKey(now),
            ))
        .copyWith(
      state: next,
      reviewedDateKey: _dateKey(now),
      lastSeenAt: now,
      seenCount: (existing?.seenCount ?? 0) + 1,
      translationAz: hints.translationAz ?? existing?.translationAz,
      ipa: hints.ipa ?? existing?.ipa,
      example: hints.example ?? existing?.example,
      exampleAz: hints.exampleAz ?? existing?.exampleAz,
      level: hints.level ?? existing?.level,
    );
    _activeDayKeys.add(_dateKey(now));
    await _persist();
    notifyListeners();
  }

  /// Verilmiş tarixdə (gün dəqiqliyi ilə) review olunan wordKey-lər.
  List<String> reviewedOn(DateTime day) {
    final key = _dateKey(day);
    return _entries.entries
        .where((e) => e.value.reviewedDateKey == key)
        .map((e) => e.key)
        .toList(growable: false);
  }

  /// Ən azı bir dəfə toxunulan sözlərin ümumi sayı.
  int get wordCount => _entries.length;

  /// `masteredStepThreshold`-a çatmış (yaxşı bilinən) sözlərin sayı.
  int get masteredCount =>
      _entries.values.where((e) => e.state.step >= masteredStepThreshold).length;

  /// Addım 1–2 arasında olan (aktiv öyrənilən) sözlər.
  int get learningCount => _entries.values
      .where((e) =>
          e.state.step >= 1 && e.state.step < masteredStepThreshold)
      .length;

  /// Bu gün toxunulan söz sayı.
  int todayCount({DateTime? today}) =>
      reviewedOn(today ?? DateTime.now()).length;

  /// Son N gün üçün gündəlik toxunulan söz sayı (köhnədən yeniyə).
  List<int> wordsPerDay({required DateTime today, int days = 7}) {
    final result = <int>[];
    for (var i = days - 1; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      result.add(reviewedOn(day).length);
    }
    return result;
  }

  /// Son görülən sözlər (ən yeni birinci).
  List<WordProgressItem> recentWords({int limit = 8}) {
    final items = _entries.entries.map((e) {
      final packId = _packIdFromKey(e.key);
      final word = _wordFromKey(e.key);
      return WordProgressItem(
        wordKey: e.key,
        word: word,
        packId: packId,
        translationAz: e.value.translationAz,
        step: e.value.state.step,
        lastSeenAt: e.value.lastSeenAt,
      );
    }).toList()
      ..sort((a, b) {
        final aT = a.lastSeenAt?.millisecondsSinceEpoch ?? 0;
        final bT = b.lastSeenAt?.millisecondsSinceEpoch ?? 0;
        return bT.compareTo(aT);
      });
    if (items.length <= limit) return items;
    return items.sublist(0, limit);
  }

  /// Paket üzrə toxunulan/öyrənilən/mənimsənilmiş say.
  List<PackProgressStats> packBreakdown() {
    final touched = <String, int>{};
    final learning = <String, int>{};
    final mastered = <String, int>{};
    for (final e in _entries.entries) {
      final packId = _packIdFromKey(e.key);
      touched[packId] = (touched[packId] ?? 0) + 1;
      if (e.value.state.step >= masteredStepThreshold) {
        mastered[packId] = (mastered[packId] ?? 0) + 1;
      } else if (e.value.state.step >= 1) {
        learning[packId] = (learning[packId] ?? 0) + 1;
      }
    }
    final packIds = touched.keys.toList()..sort();
    return packIds
        .map((id) => PackProgressStats(
              packId: id,
              touched: touched[id] ?? 0,
              learning: learning[id] ?? 0,
              mastered: mastered[id] ?? 0,
            ))
        .toList(growable: false);
  }

  /// Axşam təkrarı üçün saxlanmış ipucundan Word qur (essential/canlı sözlər).
  Word? wordForKey(String wordKey) {
    final entry = _entries[wordKey];
    if (entry == null) return null;
    final translationAz = entry.translationAz;
    if (translationAz == null) return null;
    return Word(
      word: _wordFromKey(wordKey),
      translationAz: translationAz,
      ipa: entry.ipa ?? '',
      example: entry.example ?? '',
      exampleAz: entry.exampleAz ?? '',
      level: entry.level ?? 1,
    );
  }

  /// `today`-dən geriyə ardıcıl neçə gün istifadəçi ən azı bir söz review
  /// edib (gün buraxılanda kəsilir).
  int currentStreak({required DateTime today}) {
    var streak = 0;
    var day = DateTime(today.year, today.month, today.day);
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

  static _WordHints _hintsFromMessage(LiveMessage? hint) {
    if (hint == null) {
      return const _WordHints(
        translationAz: null,
        ipa: null,
        example: null,
        exampleAz: null,
        level: null,
      );
    }
    return _WordHints(
      translationAz: hint.translationAz,
      ipa: hint.ipa,
      example: hint.example,
      exampleAz: hint.exampleAz,
      level: hint.level,
    );
  }
}

String _packIdFromKey(String wordKey) {
  final separator = wordKey.indexOf(':');
  if (separator < 0) return wordKey;
  return wordKey.substring(0, separator);
}

String _wordFromKey(String wordKey) {
  final separator = wordKey.indexOf(':');
  if (separator < 0) return wordKey;
  return wordKey.substring(separator + 1);
}

class _WordHints {
  const _WordHints({
    required this.translationAz,
    required this.ipa,
    required this.example,
    required this.exampleAz,
    required this.level,
  });

  final String? translationAz;
  final String? ipa;
  final String? example;
  final String? exampleAz;
  final int? level;
}

class _Entry {
  const _Entry({
    required this.state,
    required this.reviewedDateKey,
    this.lastSeenAt,
    this.seenCount = 0,
    this.translationAz,
    this.ipa,
    this.example,
    this.exampleAz,
    this.level,
  });

  final ReviewState state;
  final String reviewedDateKey;
  final DateTime? lastSeenAt;
  final int seenCount;
  final String? translationAz;
  final String? ipa;
  final String? example;
  final String? exampleAz;
  final int? level;

  _Entry copyWith({
    ReviewState? state,
    String? reviewedDateKey,
    DateTime? lastSeenAt,
    int? seenCount,
    String? translationAz,
    String? ipa,
    String? example,
    String? exampleAz,
    int? level,
  }) =>
      _Entry(
        state: state ?? this.state,
        reviewedDateKey: reviewedDateKey ?? this.reviewedDateKey,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        seenCount: seenCount ?? this.seenCount,
        translationAz: translationAz ?? this.translationAz,
        ipa: ipa ?? this.ipa,
        example: example ?? this.example,
        exampleAz: exampleAz ?? this.exampleAz,
        level: level ?? this.level,
      );

  factory _Entry.fromJson(Map<String, dynamic> json) => _Entry(
        state: ReviewState.fromJson(json['state'] as Map<String, dynamic>),
        reviewedDateKey: json['reviewed_date'] as String,
        lastSeenAt: json['last_seen_at'] != null
            ? DateTime.parse(json['last_seen_at'] as String)
            : null,
        seenCount: json['seen_count'] as int? ?? 0,
        translationAz: json['translation_az'] as String?,
        ipa: json['ipa'] as String?,
        example: json['example'] as String?,
        exampleAz: json['example_az'] as String?,
        level: json['level'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'state': state.toJson(),
        'reviewed_date': reviewedDateKey,
        if (lastSeenAt != null) 'last_seen_at': lastSeenAt!.toIso8601String(),
        if (seenCount > 0) 'seen_count': seenCount,
        if (translationAz != null) 'translation_az': translationAz,
        if (ipa != null) 'ipa': ipa,
        if (example != null) 'example': example,
        if (exampleAz != null) 'example_az': exampleAz,
        if (level != null) 'level': level,
      };
}
