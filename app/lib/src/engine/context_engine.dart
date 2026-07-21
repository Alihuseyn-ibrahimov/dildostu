/// İstifadəçinin özünün seçdiyi kontekst ("İndi haradayam?").
class ManualSignal {
  const ManualSignal({required this.packId});
  final String packId;
}

/// OSM-dən həll olunmuş məkan konteksti — köhnəlmə üçün `resolvedAt` saxlanır.
class LocationSignal {
  const LocationSignal({required this.packId, required this.resolvedAt});
  final String packId;
  final DateTime resolvedAt;
}

const _locationFreshness = Duration(minutes: 30);

/// Spec §3.2 ContextEngine prioriteti: manual > məkan (təzədirsə) > vaxt.
///
/// Pure funksiyadır — hər üç siqnal artıq hesablanmış vəziyyətdə ötürülür;
/// GPS/OSM sorğusu, manual seçim saxlanması ayrı (yan-təsirli) qatlardadır.
String resolveContextPack({
  required DateTime now,
  required String timeBasedPackId,
  required ManualSignal? manualSignal,
  required LocationSignal? locationSignal,
}) {
  if (manualSignal != null) return manualSignal.packId;

  if (locationSignal != null) {
    final age = now.difference(locationSignal.resolvedAt);
    if (age <= _locationFreshness) {
      return locationSignal.packId;
    }
  }

  return timeBasedPackId;
}
