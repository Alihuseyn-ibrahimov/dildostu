import '../models/ui_language.dart';

import '../models/user_profile.dart';

/// Proqram interfeysi mətnləri — öyrənilən dil məzmunundan ayrıdır.
class AppStrings {
  AppStrings(this.language);

  final UiLanguage language;

  String _t({required String az, required String en, required String ru}) {
    switch (language) {
      case UiLanguage.en:
        return en;
      case UiLanguage.ru:
        return ru;
      case UiLanguage.az:
        return az;
    }
  }

  // — Tablar —
  String get tabHome => _t(az: 'Ana səhifə', en: 'Home', ru: 'Главная');
  String get tabChat => _t(az: 'Söhbət', en: 'Chat', ru: 'Чат');
  String get tabProgress => _t(az: 'İrəliləyiş', en: 'Progress', ru: 'Прогресс');
  String get tabProfile => _t(az: 'Profil', en: 'Profile', ru: 'Профиль');

  // — Ayarlar —
  String get settingsTitle => _t(az: 'Ayarlar', en: 'Settings', ru: 'Настройки');
  String get appLanguage => _t(
        az: 'Proqram dili',
        en: 'App language',
        ru: 'Язык приложения',
      );
  String get appLanguageHint => _t(
        az: 'Menyu və düymələrin dili',
        en: 'Language of menus and buttons',
        ru: 'Язык меню и кнопок',
      );
  String get wakeTime => _t(az: 'Oyanma vaxtı', en: 'Wake time', ru: 'Время подъёма');
  String get sleepTime => _t(az: 'Yatma vaxtı', en: 'Sleep time', ru: 'Время сна');
  String get dailyNotifications => _t(
        az: 'Gündəlik bildiriş sayı',
        en: 'Daily notifications',
        ru: 'Уведомлений в день',
      );
  String notificationRange(int min, int max) => _t(
        az: '$min–$max aralığında',
        en: '$min–$max range',
        ru: 'диапазон $min–$max',
      );
  String get privacyPolicy =>
      _t(az: 'Məxfilik siyasəti', en: 'Privacy policy', ru: 'Политика конфиденциальности');
  String get releaseLabel => _t(az: 'Buraxılış', en: 'Release', ru: 'Сборка');
  String get updates => _t(az: 'Yeniləmələr', en: 'Updates', ru: 'Обновления');
  String get checkingUpdates =>
      _t(az: 'Yoxlanılır…', en: 'Checking…', ru: 'Проверка…');
  String get upToDate =>
      _t(az: 'Ən son versiyadasan', en: 'You are up to date', ru: 'У вас последняя версия');
  String updateCheckFailed(String error) => _t(
        az: 'Yoxlama alınmadı: $error',
        en: 'Check failed: $error',
        ru: 'Не удалось проверить: $error',
      );
  String get recheckUpdates =>
      _t(az: 'Yenidən yoxla', en: 'Check again', ru: 'Проверить снова');
  String get pickHour => _t(az: 'Saat seçin', en: 'Pick hour', ru: 'Выберите час');
  String get cancel => _t(az: 'Ləğv et', en: 'Cancel', ru: 'Отмена');
  String get save => _t(az: 'Yadda saxla', en: 'Save', ru: 'Сохранить');
  String get delete => _t(az: 'Sil', en: 'Delete', ru: 'Удалить');
  String get dismiss => _t(az: 'İmtina', en: 'Dismiss', ru: 'Отмена');

  // — Yeniləmə banneri —
  String get updateAvailable => _t(
        az: 'Yeni versiya var',
        en: 'New version available',
        ru: 'Доступна новая версия',
      );
  String get downloading => _t(az: 'Yüklənir…', en: 'Downloading…', ru: 'Загрузка…');
  String downloadingPercent(int percent) => _t(
        az: 'Yüklənir… $percent%',
        en: 'Downloading… $percent%',
        ru: 'Загрузка… $percent%',
      );
  String get downloadFailed => _t(
        az: 'Yüklənmədi — internetini yoxla',
        en: 'Download failed — check your connection',
        ru: 'Не удалось загрузить — проверьте интернет',
      );
  String get updateAction => _t(az: 'Yenilə', en: 'Update', ru: 'Обновить');
  String get retry => _t(az: 'Yenidən cəhd et', en: 'Retry', ru: 'Повторить');

  // — Profil —
  String get profileTitle => _t(az: 'Profil', en: 'Profile', ru: 'Профиль');
  String get settingsMenu => _t(az: 'Ayarlar', en: 'Settings', ru: 'Настройки');
  String get settingsMenuSubtitle => _t(
        az: 'Oyanma/yatma vaxtı, bildiriş sayı',
        en: 'Wake/sleep times, notifications',
        ru: 'Время сна, уведомления',
      );
  String get aiLearnedTitle =>
      _t(az: 'AI nəyi öyrənib', en: 'What AI learned', ru: 'Что AI запомнил');
  String get aiLearnedSubtitle => _t(
        az: 'Tez-tez getdiyin yerlər',
        en: 'Places you visit often',
        ru: 'Частые места',
      );
  String get routineLearning => _t(
        az: 'Rutin öyrənmə',
        en: 'Routine learning',
        ru: 'Рутинное обучение',
      );
  String get routineSubtitle => _t(
        az: 'Arxa fon məkan icazəsi',
        en: 'Background location permission',
        ru: 'Фоновая геолокация',
      );
  String get accountSection => _t(az: 'Hesab', en: 'Account', ru: 'Аккаунт');
  String get accountCabinet =>
      _t(az: 'Kabinetin', en: 'Your account', ru: 'Ваш аккаунт');
  String get logoutSubtitle => _t(
        az: 'Yenidən giriş edə bilərsən',
        en: 'You can log in again',
        ru: 'Можно войти снова',
      );
  String get deleteAccountSubtitle => _t(
        az: 'Bütün datanı həmişəlik sil',
        en: 'Permanently delete all data',
        ru: 'Удалить все данные навсегда',
      );
  String get testNotifTitle =>
      _t(az: 'Test bildirişi', en: 'Test notification', ru: 'Тест уведомления');
  String get testNotifSubtitle => _t(
        az: 'Bildiriş→kart axınını yoxla',
        en: 'Test notification flow',
        ru: 'Проверить уведомления',
      );
  String get logout => _t(az: 'Çıxış', en: 'Log out', ru: 'Выйти');
  String get deleteAccount =>
      _t(az: 'Hesabı sil', en: 'Delete account', ru: 'Удалить аккаунт');
  String get deleteAccountTitle => _t(
        az: 'Hesabı silmək istəyirsən?',
        en: 'Delete your account?',
        ru: 'Удалить аккаунт?',
      );
  String get deleteAccountBody => _t(
        az: 'Bu əməliyyat geri qaytarıla bilməz — hesabın və bütün rutin/məkan '
            'datan həmişəlik silinəcək.',
        en: 'This cannot be undone — your account and all routine/location '
            'data will be permanently deleted.',
        ru: 'Это необратимо — ваш аккаунт и все данные о местах будут '
            'удалены навсегда.',
      );
  String get developerSection =>
      _t(az: 'Developer', en: 'Developer', ru: 'Developer');

  // — Giriş —
  String get loginAction => _t(az: 'Giriş', en: 'Log in', ru: 'Войти');
  String get registerAction =>
      _t(az: 'Qeydiyyatdan keç', en: 'Sign up', ru: 'Регистрация');
  String get emailHint => _t(az: 'E-poçt', en: 'Email', ru: 'Эл. почта');
  String get passwordHint => _t(az: 'Şifrə', en: 'Password', ru: 'Пароль');
  String get emailPasswordRequired => _t(
        az: 'E-poçt və şifrəni daxil et.',
        en: 'Enter email and password.',
        ru: 'Введите email и пароль.',
      );
  String get haveAccountQuestion => _t(
        az: 'Artıq hesabın var?',
        en: 'Already have an account?',
        ru: 'Уже есть аккаунт?',
      );
  String get noAccountQuestion => _t(
        az: 'Hesabın yoxdur?',
        en: "Don't have an account?",
        ru: 'Нет аккаунта?',
      );
  String get loginTagline => _t(
        az: 'Səyahət yoldaşın — harada olursan ol, dil öyrən',
        en: 'Your travel companion — learn wherever you are',
        ru: 'Твой спутник в путешествии — учи язык где угодно',
      );
  String get loginRegisterHeadline => _t(
        az: 'Səyahətə get, dili öyrən',
        en: 'Travel and learn the language',
        ru: 'Путешествуй и учи язык',
      );
  String get loginSignInHeadline => _t(
        az: 'Kabinetinə daxil ol',
        en: 'Sign in to your account',
        ru: 'Войдите в аккаунт',
      );
  String get switchToLogin => _t(
        az: 'Artıq hesabın var? Giriş et',
        en: 'Already have an account? Log in',
        ru: 'Уже есть аккаунт? Войти',
      );
  String get switchToRegister => _t(
        az: 'Hesabın yoxdur? Qeydiyyatdan keç',
        en: "Don't have an account? Sign up",
        ru: 'Нет аккаунта? Зарегистрироваться',
      );

  // — Ana səhifə —
  String greetingForHour(int hour) {
    if (hour < 6) {
      return _t(az: 'Gecən xeyrə', en: 'Good night', ru: 'Доброй ночи');
    }
    if (hour < 12) {
      return _t(az: 'Sabahın xeyir', en: 'Good morning', ru: 'Доброе утро');
    }
    if (hour < 18) {
      return _t(az: 'Günortan xeyir', en: 'Good afternoon', ru: 'Добрый день');
    }
    return _t(az: 'Axşamın xeyir', en: 'Good evening', ru: 'Добрый вечер');
  }

  String get homeHeroHeadline => _t(
        az: 'Bu gün hara uçuruq?',
        en: 'Where are we flying today?',
        ru: 'Куда летим сегодня?',
      );
  String get missionsSection =>
      _t(az: 'Missiyalar', en: 'Missions', ru: 'Миссии');
  String get missionsSubtitle => _t(
        az: 'Kontekstdən asılı olmayan bölmələr',
        en: 'Sections independent of context',
        ru: 'Разделы без привязки к месту',
      );
  String get essentialWords =>
      _t(az: 'Əsas lüğət', en: 'Essential words', ru: 'Основной словарь');
  String get audiobooks => _t(az: 'Səsli kitablar', en: 'Audiobooks', ru: 'Аудиокниги');
  String get audiobooksSubtitle => _t(
        az: 'Dinlə və eyni vaxtda mətni oxu',
        en: 'Listen and read along',
        ru: 'Слушай и читай текст',
      );
  String get music => _t(az: 'Musiqi', en: 'Music', ru: 'Музыка');
  String get wordPacks => _t(az: 'Söz paketləri', en: 'Word packs', ru: 'Наборы слов');
  String wordPacksSubtitle(int count) => _t(
        az: '$count məkan · pasport möhürləri',
        en: '$count places · passport stamps',
        ru: '$count мест · штампы',
      );
  String wordsAtLevel(int count, String level) => _t(
        az: '$count söz · $level',
        en: '$count words · $level',
        ru: '$count слов · $level',
      );
  String essentialWordsSubtitle(String level) => _t(
        az: '504 söz · $level səviyyə',
        en: '504 words · $level level',
        ru: '504 слова · уровень $level',
      );
  String musicSubtitle(String level) => _t(
        az: '$level səviyyəyə uyğun mahnılar',
        en: 'Songs for $level level',
        ru: 'Песни для уровня $level',
      );

  String proficiencyLabel(ProficiencyLevel level) {
    switch (level) {
      case ProficiencyLevel.beginner:
        return levelEasy;
      case ProficiencyLevel.intermediate:
        return levelMedium;
      case ProficiencyLevel.advanced:
        return levelHard;
    }
  }
  String get changeLearningLanguage => _t(
        az: 'Öyrənilən dili dəyiş',
        en: 'Change learning language',
        ru: 'Сменить изучаемый язык',
      );
  String get difficultyLevel => _t(
        az: 'Çətinlik səviyyəsi',
        en: 'Difficulty level',
        ru: 'Уровень сложности',
      );
  String get levelEasy => _t(az: 'Asan', en: 'Easy', ru: 'Лёгкий');
  String get levelMedium => _t(az: 'Orta', en: 'Medium', ru: 'Средний');
  String get levelHard => _t(az: 'Çətin', en: 'Hard', ru: 'Сложный');
  String get locatingTitle => _t(
        az: 'Yerini müəyyən edirəm…',
        en: 'Finding your location…',
        ru: 'Определяю местоположение…',
      );
  String get locatingSubtitle => _t(
        az: 'GPS radar işləyir',
        en: 'GPS radar active',
        ru: 'Работает GPS',
      );
  String get refreshLocation =>
      _t(az: 'Yenilə', en: 'Refresh', ru: 'Обновить');
  String get whereAmI =>
      _t(az: 'İndi haradayam?', en: 'Where am I now?', ru: 'Где я сейчас?');
  String get whereAmISubtitle => _t(
        az: 'Olduğun yerə uyğun sözlər',
        en: 'Words for where you are',
        ru: 'Слова для вашего места',
      );
  String get locationFailed => _t(
        az: 'Yerini tapa bilmədim',
        en: "Couldn't find your location",
        ru: 'Не удалось определить место',
      );
  String get liveBadge => _t(az: 'CANLI', en: 'LIVE', ru: 'LIVE');
  String get approximateLabel =>
      _t(az: 'təxmini', en: 'approx.', ru: 'прибл.');
  String get noWordPack => _t(
        az: 'söz paketi yoxdur',
        en: 'no word pack',
        ru: 'нет набора слов',
      );
  String levelSuffix(String level) => _t(
        az: '$level səviyyə',
        en: '$level level',
        ru: 'уровень $level',
      );
  String get refreshLocationTooltip => _t(
        az: 'Yeri yenilə',
        en: 'Refresh location',
        ru: 'Обновить место',
      );

  // — Gündəlik missiya (day-plan) —
  String get dailyMissionTitle => _t(
        az: 'Bu günün missiyası',
        en: "Today's mission",
        ru: 'Миссия дня',
      );
  String dailyMissionSubtitle(int count) => _t(
        az: '$count söz · AI ilə seçildi',
        en: '$count words · picked by AI',
        ru: '$count слов · выбрано AI',
      );
  String get dailyMissionLoading => _t(
        az: 'Missiya hazırlanır…',
        en: 'Preparing mission…',
        ru: 'Готовим миссию…',
      );
  String get dailyMissionOffline => _t(
        az: 'Offline — statik sözlər',
        en: 'Offline — static words',
        ru: 'Офлайн — статичные слова',
      );
  String get dailyMissionRefresh => _t(
        az: 'Yenilə',
        en: 'Refresh',
        ru: 'Обновить',
      );
  String dailyMissionFailed(String error) => _t(
        az: 'Missiya alınmadı: $error',
        en: 'Mission failed: $error',
        ru: 'Не удалось: $error',
      );
  String get dailyMissionRetry => _t(
        az: 'Yenidən cəhd et',
        en: 'Try again',
        ru: 'Повторить',
      );

  // — AI yaddaşı (Ayarlar) —
  String get aiMemory => _t(az: 'AI yaddaşı', en: 'AI memory', ru: 'Память AI');
  String get clearChat =>
      _t(az: 'Söhbəti təmizlə', en: 'Clear chat', ru: 'Очистить чат');
  String get clearChatSubtitle => _t(
        az: 'Yazışma silinir, AI səni yenə tanıyır',
        en: 'Messages deleted, AI still remembers you',
        ru: 'Переписка удалится, AI вас помнит',
      );
  String get resetAiMemory => _t(
        az: 'AI yaddaşını sıfırla',
        en: 'Reset AI memory',
        ru: 'Сбросить память AI',
      );
  String get resetAiMemorySubtitle => _t(
        az: 'AI səni sıfırdan tanımağa başlayır',
        en: 'AI will learn about you from scratch',
        ru: 'AI начнёт узнавать вас заново',
      );
  String get noAiFactsYet => _t(
        az: 'Hələ heç nə yadda saxlamayıb',
        en: 'Nothing saved yet',
        ru: 'Пока ничего не сохранено',
      );

  // — Söhbət kvotası —
  String get chatQuotaTitle => _t(
        az: 'Gündəlik söhbət limiti',
        en: 'Daily chat limit',
        ru: 'Дневной лимит чата',
      );
  String chatQuotaSummary(int used, int limit) => _t(
        az: 'Bu gün: $used/$limit mesaj',
        en: 'Today: $used/$limit messages',
        ru: 'Сегодня: $used/$limit сообщений',
      );
  String chatQuotaRemaining(int remaining) => _t(
        az: 'Qalıb $remaining',
        en: '$remaining left',
        ru: 'Осталось $remaining',
      );
  String get chatQuotaExhausted => _t(
        az: 'Bu gün üçün limit doldu — sabah davam edək',
        en: 'Daily limit reached — try again tomorrow',
        ru: 'Дневной лимит исчерпан — продолжим завтра',
      );

  // — Cihaz kilidi —
  String get deviceLockTitle =>
      _t(az: 'Cihaz kilidi', en: 'Device lock', ru: 'Блокировка устройства');
  String get setPinTitle =>
      _t(az: 'PIN təyin et', en: 'Set PIN', ru: 'Установить PIN');
  String get changePin =>
      _t(az: 'PIN-i dəyiş', en: 'Change PIN', ru: 'Сменить PIN');
  String get pinHint => _t(az: '4 rəqəmli PIN', en: '4-digit PIN', ru: 'PIN из 4 цифр');
  String get pinConfirmHint =>
      _t(az: 'PIN-i təkrarla', en: 'Confirm PIN', ru: 'Повторите PIN');
  String get pinMustBeFourDigits => _t(
        az: 'PIN 4 rəqəm olmalıdır',
        en: 'PIN must be 4 digits',
        ru: 'PIN должен быть из 4 цифр',
      );
  String get pinMismatch => _t(
        az: 'PIN-lər uyğun gəlmir',
        en: 'PINs do not match',
        ru: 'PIN не совпадает',
      );
  String get pinSetSuccess => _t(
        az: 'PIN təyin olundu',
        en: 'PIN set',
        ru: 'PIN установлен',
      );
  String get deviceLockSubtitle => _t(
        az: 'App açılanda PIN və ya barmaq izi',
        en: 'PIN or fingerprint when opening the app',
        ru: 'PIN или отпечаток при открытии',
      );
  String get biometricUnlock => _t(
        az: 'Barmaq izi ilə aç',
        en: 'Unlock with fingerprint',
        ru: 'Открыть отпечатком',
      );
  String get disableDeviceLock => _t(
        az: 'Kilidi söndür',
        en: 'Turn off lock',
        ru: 'Отключить блокировку',
      );
  String get unlockTitle =>
      _t(az: 'LachinGo kilidlidir', en: 'LachinGo is locked', ru: 'LachinGo заблокирован');
  String get unlockSubtitle => _t(
        az: 'Davam etmək üçün PIN daxil et',
        en: 'Enter PIN to continue',
        ru: 'Введите PIN для продолжения',
      );
  String get unlockWrongPin => _t(
        az: 'PIN səhvdir',
        en: 'Wrong PIN',
        ru: 'Неверный PIN',
      );
  String get unlockUseBiometric => _t(
        az: 'Barmaq izi ilə aç',
        en: 'Use fingerprint',
        ru: 'Отпечаток пальца',
      );
  String get unlockFullLogin => _t(
        az: 'Tam giriş (email/şifrə)',
        en: 'Full sign-in (email/password)',
        ru: 'Полный вход (email/пароль)',
      );
  String get unlockBiometricReason => _t(
        az: 'LachinGo-nu açmaq üçün barmaq izini təsdiqlə',
        en: 'Confirm fingerprint to open LachinGo',
        ru: 'Подтвердите отпечаток для входа в LachinGo',
      );

  // — Ümumi —
  String get progressTitle => _t(az: 'İrəliləyiş', en: 'Progress', ru: 'Прогресс');
  String get loadError => _t(
        az: 'Yüklənmə xətası',
        en: 'Load error',
        ru: 'Ошибка загрузки',
      );
}
