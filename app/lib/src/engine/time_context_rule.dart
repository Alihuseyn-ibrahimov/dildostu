/// Vaxt-əsaslı kontekst qaydası (spec §3.2, ContextEngine-in təməl qatı):
/// gündəki ilk bildiriş "morning" paketini, sonuncusu "evening" paketini
/// seçir; aradakılar qalan paketlər arasında fırlanır. Manual/məkan siqnalları
/// (Phase 4) bu qaydadan üstün olacaq.
///
/// [slotIndex] 0-based bildiriş sırası, [totalSlots] həmin günkü ümumi say.
String pickPackForSlot(
  int slotIndex,
  int totalSlots,
  List<String> availablePackIds,
) {
  if (availablePackIds.isEmpty) {
    throw ArgumentError('availablePackIds boş ola bilməz');
  }
  if (slotIndex == 0 && availablePackIds.contains('morning')) {
    return 'morning';
  }
  if (slotIndex == totalSlots - 1 && availablePackIds.contains('evening')) {
    return 'evening';
  }

  final rotating =
      availablePackIds.where((id) => id != 'morning' && id != 'evening').toList();
  if (rotating.isEmpty) {
    return availablePackIds[slotIndex % availablePackIds.length];
  }
  // slotIndex-1 çünki 0-cı slot artıq morning-ə ayrılıb (varsa).
  final rotationIndex = (slotIndex - 1).clamp(0, 1 << 30);
  return rotating[rotationIndex % rotating.length];
}
