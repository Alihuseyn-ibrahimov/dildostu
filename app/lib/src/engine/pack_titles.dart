/// Paket başlıqlarının statik AZ xəritəsi (assets/packs/*.json `title_az`
/// dəyərləri ilə uzlaşır). Fon izolatında (WorkManager) `rootBundle` asset
/// yükləməsi etibarsız ola bilər — bu, ona ehtiyacı aradan qaldırır.
const Map<String, String> kPackTitlesAz = {
  'morning': 'Səhər',
  'greetings': 'Salamlaşma',
  'cafe': 'Kafedə',
  'restaurant': 'Restoranda',
  'market': 'Marketdə',
  'airport': 'Aeroportda',
  'hotel': 'Oteldə',
  'transport': 'Nəqliyyatda',
  'pharmacy': 'Aptekdə',
  'evening': 'Axşam',
};

String packTitleAz(String packId) => kPackTitlesAz[packId] ?? packId;
