/// İstifadəçinin bir sözə verdiyi cavab.
enum ReviewOutcome { known, later }

/// Sadələşdirilmiş SM-2 (spaced repetition) vəziyyəti — bir söz üçün.
///
/// `step` ardıcıl "bilirəm" sayını göstərir; hər addımda növbəti göstərilmə
/// vaxtı (dueAt) daha da uzaqlaşır. "Sonra" cavabı addımı sıfırlayır və
/// sözü tezliklə (10 dəq sonra) yenidən göstərir.
class ReviewState {
  const ReviewState({required this.step, required this.dueAt});

  final int step;
  final DateTime dueAt;

  static const int maxStep = 5;

  /// step-ə görə "bilirəm" sonrası gözləmə müddəti (indeks = yeni step).
  static const List<Duration> _intervals = [
    Duration.zero, // istifadə olunmur (step 0-a çatılmır "known" ilə)
    Duration(days: 1),
    Duration(days: 3),
    Duration(days: 7),
    Duration(days: 14),
    Duration(days: 30),
  ];

  static const Duration _laterDelay = Duration(minutes: 10);

  /// Yeni söz — dərhal due (heç vaxt review olunmayıb).
  factory ReviewState.initial() =>
      ReviewState(step: 0, dueAt: DateTime.fromMillisecondsSinceEpoch(0));

  bool isDue(DateTime now) => !now.isBefore(dueAt);

  ReviewState apply(ReviewOutcome outcome, {required DateTime now}) {
    if (outcome == ReviewOutcome.later) {
      return ReviewState(step: 0, dueAt: now.add(_laterDelay));
    }
    final nextStep = (step + 1).clamp(1, maxStep);
    final interval = _intervals[nextStep];
    return ReviewState(step: nextStep, dueAt: now.add(interval));
  }

  Map<String, dynamic> toJson() => {
        'step': step,
        'due_at': dueAt.toIso8601String(),
      };

  factory ReviewState.fromJson(Map<String, dynamic> json) => ReviewState(
        step: json['step'] as int,
        dueAt: DateTime.parse(json['due_at'] as String),
      );
}
