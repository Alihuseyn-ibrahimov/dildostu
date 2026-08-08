import '../models/chat_nudge.dart';
import '../models/user_profile.dart';

typedef _Template = ({String body, String prompt});

const _morningTemplates = <_Template>[
  (
    body:
        'Sabahın xeyir! ☀️ Gəl 5 dəqiqəni ayır — bu günü {lang} ilə faydalı başlayaq.',
    prompt: 'Bu gün üçün 3 faydalı söz',
  ),
  (
    body: 'Günaydın! 🌅 5 dəqiqəlik mini dərs — günə enerjili başla.',
    prompt: 'Sabah salamlaşması necə deyilir?',
  ),
  (
    body:
        'Sabahın xeyir! LachinGo burada — 5 dəqiqə ayır, {lang} sözləri ilə günə start ver.',
    prompt: 'Günə enerjili başlamaq üçün 3 ifadə',
  ),
  (
    body:
        'Yeni gün, yeni sözlər! ☀️ 5 dəqiqəni ayır — birlikdə faydalı başlayaq.',
    prompt: 'Bu gün üçün 3 faydalı söz',
  ),
  (
    body:
        'Sabahın xeyir! Günün ilk 5 dəqiqəsini {lang} öyrənməyə ayırmaq istəyirsən?',
    prompt: 'Sabah rutini üçün 3 ifadə',
  ),
  (
    body: 'Günaydın! ☕ 5 dəqiqə kifayətdir — bu günü {lang} ilə güclü başlat.',
    prompt: 'Bu gün üçün 3 faydalı söz',
  ),
  (
    body:
        'Sabahın xeyir! ✈️ Səyahətə hazırlaş — 5 dəqiqəlik {lang} ilə günə başla.',
    prompt: 'Aeroportda check-in necə deyilir?',
  ),
];

const _lunchTemplates = <_Template>[
  (
    body:
        'Nahar fasiləsindəsən? 🍽️ Gəl bu vaxtı dəyərləndirək — 5 dəqiqəlik {lang} sual-cavab.',
    prompt: 'Restoranda sifariş necə verilir?',
  ),
  (
    body: 'Fasilə vaxtı! ☕ 5 dəqiqəni ayır — nahar arasında {lang} öyrən.',
    prompt: 'Nahar menyusunda nə demək olar?',
  ),
  (
    body:
        'Nahar fasiləsi ideal vaxtdır! Gəl birlikdə 5 dəqiqə {lang} danışaq.',
    prompt: 'Bu gün üçün 3 faydalı söz',
  ),
  (
    body: 'Fasilədəsən? 🥗 Bu 5 dəqiqəni boş keçirmə — gəl praktik edək.',
    prompt: 'Kafedə çay sifarişi necə deyilir?',
  ),
  (
    body: 'Nahar vaxtı! 🍽️ Gəl sual-cavab edək — fasiləni faydalı keçir.',
    prompt: 'Bu gün üçün 3 faydalı söz',
  ),
  (
    body: '{place} qalmışdıq — nahar fasiləsində davam edək! 5 dəqiqə kifayətdir.',
    prompt: '{place} üçün praktik ifadələr',
  ),
  (
    body:
        'Gün ortası! 🌤️ Nahar fasiləsində {lang} sözləri ilə özünü yüngülləşdir.',
    prompt: 'Restoranda hesab necə istənilir?',
  ),
];

const _eveningTemplates = <_Template>[
  (
    body: 'Yatmamış — gəl bu gün öyrəndiklərimizi təkrar edək 🌙',
    prompt: 'Bu gün öyrəndiklərimi təkrar et',
  ),
  (
    body: 'Günün sonu! 🌙 Yatmadan əvvəl 5 dəqiqəlik {lang} təkrarı edək.',
    prompt: 'Axşam üçün 3 faydalı söz',
  ),
  (
    body: 'Axşam saatı — öyrəndiklərimizi birlikdə xatırlayaq? 📚',
    prompt: 'Bu günün qısa xülasəsi',
  ),
  (
    body: 'Yatmadan əvvəl qısa təkrar — bu gün nə öyrənmişik? 🌙',
    prompt: 'Bu gün öyrəndiklərimi təkrar et',
  ),
  (
    body: 'Günü yaxşı bitirək! 🌙 5 dəqiqəlik {lang} təkrarı — yatmadan əvvəl.',
    prompt: 'Axşam üçün 3 faydalı söz',
  ),
  (
    body: 'Axşamın xeyir! 🌙 Gəl bu gün öyrəndiklərimizi bir daha təkrar edək.',
    prompt: 'Bu gün öyrəndiklərimi təkrar et',
  ),
  (
    body: 'Yatma vaxtı yaxındır — 5 dəqiqə ayır, {lang} sözlərini möhkəmləndir.',
    prompt: 'Bu günün qısa xülasəsi',
  ),
];

ChatNudge _pick(List<_Template> templates, int day, String lang) {
  final t = templates[day % templates.length];
  final place = 'Son dəfə öyrəndiyimiz yerdə';
  return ChatNudge(
    body: t.body.replaceAll('{lang}', lang).replaceAll('{place}', place),
    quickPrompt:
        t.prompt.replaceAll('{lang}', lang).replaceAll('{place}', place),
  );
}

/// Server əlçatan olmadıqda — eyni 3 slot, günə görə fərqli şablon.
List<ChatNudge> buildLocalChatNudges(UserProfile profile, {DateTime? onDay}) {
  final day = (onDay ?? DateTime.now());
  final ordinal = DateTime(day.year, day.month, day.day)
      .difference(DateTime(1970))
      .inDays;
  final lang = profile.targetLang.labelAz;

  var morning = _pick(_morningTemplates, ordinal, lang);
  if (profile.purpose == LearningPurpose.travel && ordinal % 3 == 0) {
    morning = ChatNudge(
      body:
          'Sabahın xeyir! ✈️ Səyahətə hazırlaş — 5 dəqiqəlik $lang ilə günə faydalı başla.',
      quickPrompt: 'Aeroportda check-in necə deyilir?',
    );
  }

  return [
    morning,
    _pick(_lunchTemplates, ordinal + 1, lang),
    _pick(_eveningTemplates, ordinal + 2, lang),
  ];
}
