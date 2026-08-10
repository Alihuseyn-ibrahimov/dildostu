import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/config.dart';
import 'src/l10n/app_locale_scope.dart';
import 'src/l10n/app_strings.dart';
import 'src/l10n/material_app_l10n.dart';
import 'src/models/ui_language.dart';
import 'src/data/app_update_client.dart';
import 'src/data/audiobook_client.dart';
import 'src/models/audiobook.dart';
import 'src/data/music_client.dart';
import 'src/models/song.dart';
import 'src/data/word_lookup_client.dart';
import 'src/data/auth_client.dart';
import 'src/data/auth_repository.dart';
import 'src/data/device_lock_repository.dart';
import 'src/data/chat_client.dart';
import 'src/data/day_plan_cache_repository.dart';
import 'src/data/device_id_repository.dart';
import 'src/data/essential_words_repository.dart';
import 'src/data/geofence_cooldown_repository.dart';
import 'src/data/live_content_client.dart';
import 'src/data/manual_context_repository.dart';
import 'src/data/pack_repository.dart';
import 'src/data/place_client.dart';
import 'src/data/profile_client.dart';
import 'src/data/review_repository.dart';
import 'src/data/routine_client.dart';
import 'src/data/settings_repository.dart';
import 'src/data/tts_telemetry_repository.dart';
import 'src/data/user_profile_repository.dart';
import 'src/engine/chat_nudge_fallback.dart';
import 'src/engine/chat_nudge_payload.dart';
import 'src/engine/context_engine.dart';
import 'src/engine/day_plan_picker.dart';
import 'src/engine/geofence_logic.dart';
import 'src/engine/level_content.dart';
import 'src/engine/location_quality.dart';
import 'src/engine/pack_titles.dart';
import 'src/models/app_version_info.dart';
import 'src/models/live_message.dart';
import 'src/models/user_profile.dart';
import 'src/services/audio_player_service.dart';
import 'src/services/audiobook_downloader.dart';
import 'src/services/battery_optimization_service.dart';
import 'src/services/browser_launcher_service.dart';
import 'src/services/build_flavor_service.dart';
import 'src/services/location_service.dart';
import 'src/services/notification_service.dart';
import 'src/services/routine_sampler.dart';
import 'src/services/speaker.dart';
import 'src/ui/accent_colors.dart';
import 'src/ui/bootstrap_loading_screen.dart';
import 'src/ui/audiobook_player_screen.dart';
import 'src/ui/audiobooks_screen.dart';
import 'src/ui/music_screen.dart';
import 'src/ui/chat_screen.dart';
import 'src/ui/essential_words_screen.dart';
import 'src/ui/home_tab.dart';
import 'src/ui/learned_places_screen.dart';
import 'src/ui/login_screen.dart';
import 'src/ui/main_shell.dart';
import 'src/ui/manual_mode_screen.dart';
import 'src/ui/onboarding_screen.dart';
import 'src/ui/profile_tab.dart';
import 'src/ui/progress_tab.dart';
import 'src/ui/routine_permission_screen.dart';
import 'src/ui/settings_screen.dart';
import 'src/ui/theme.dart';
import 'src/ui/unlock_screen.dart';
import 'src/ui/word_detail_screen.dart';
import 'src/ui/word_list_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Arxa fon rutin toplama plugin-i (periodik iş üçün). Xəta app-ı bloklamamalı.
  try {
    await RoutineSampler.initialize();
  } catch (_) {}
  runApp(const LachinGoApp());
}

class LachinGoApp extends StatefulWidget {
  const LachinGoApp({super.key});

  @override
  State<LachinGoApp> createState() => _LachinGoAppState();
}

class _LachinGoAppState extends State<LachinGoApp> {
  UiLanguage _uiLanguage = UiLanguage.az;
  bool _localeReady = false;

  @override
  void initState() {
    super.initState();
    _loadUiLanguage();
  }

  Future<void> _loadUiLanguage() async {
    try {
      final repo = await SettingsRepository.load();
      if (mounted) {
        setState(() {
          _uiLanguage = repo.current.uiLanguage;
          _localeReady = true;
        });
      }
    } catch (_) {
      // Korrupt prefs — defolt AZ ilə davam et, app çökməsin.
      if (mounted) {
        setState(() {
          _uiLanguage = UiLanguage.az;
          _localeReady = true;
        });
      }
    }
  }

  void _onUiLanguageChanged(UiLanguage lang) {
    setState(() => _uiLanguage = lang);
  }

  @override
  Widget build(BuildContext context) {
    if (!_localeReady) {
      return MaterialApp(
        localizationsDelegates: MaterialAppL10n.localizationsDelegates,
        supportedLocales: MaterialAppL10n.supportedLocales,
        locale: MaterialAppL10n.locale,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final strings = AppStrings(_uiLanguage);
    // AppLocaleScope MaterialApp-in XARİCİNDƏ olmalıdır — bütün route/overlay
    // onun altında qalsın. `locale: Locale('az')` MaterialApp-ə vermək OLMAZ:
    // Flutter `az` üçün MaterialLocalizations dəstəkləmir → qırmızı ekran.
    // Bizim interfeys dili yalnız AppStrings (`context.s`) ilə idarə olunur.
    return AppLocaleScope(
      language: _uiLanguage,
      strings: strings,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'LachinGo',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        localizationsDelegates: MaterialAppL10n.localizationsDelegates,
        supportedLocales: MaterialAppL10n.supportedLocales,
        locale: MaterialAppL10n.locale,
        home: _AuthGate(onUiLanguageChanged: _onUiLanguageChanged),
      ),
    );
  }
}

/// Giriş qapısı — token varsa əsas app-ı (`_Bootstrap`), yoxdursa
/// `LoginScreen`-i göstərir. Çıxış/401 halında `setState` ilə geri
/// `LoginScreen`-ə qayıdır (spec: Faza 3, "hər kəs öz kabinetini yaradıb
/// daxil olsun").
class _AuthGate extends StatefulWidget {
  const _AuthGate({this.onUiLanguageChanged});

  final ValueChanged<UiLanguage>? onUiLanguageChanged;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final AuthClient _authClient = AuthClient(baseUrl: AppConfig.serverBaseUrl);

  AuthRepository? _auth;
  DeviceLockRepository? _lockRepo;
  bool _initializing = true;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final auth = await AuthRepository.load();
    final lockRepo = await DeviceLockRepository.load();

    if (auth.isLoggedIn) {
      final valid = await _authClient.validateSession(auth.token!);
      if (!valid) await auth.logout();
    }

    final lockEnabled = await lockRepo.isEnabled();
    if (!mounted) return;
    setState(() {
      _auth = auth;
      _lockRepo = lockRepo;
      _initializing = false;
      _unlocked = !lockEnabled || !auth.isLoggedIn;
    });
  }

  Future<void> _onAuthenticated(String token, String email) async {
    await _auth!.setSession(token: token, email: email);
    final lockEnabled = await _lockRepo!.isEnabled();
    if (!mounted) return;
    setState(() => _unlocked = !lockEnabled);
  }

  Future<void> _requireFullLogin() async {
    await _auth?.logout();
    await _lockRepo?.clear();
    if (!mounted) return;
    setState(() => _unlocked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing || _auth == null || _lockRepo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final auth = _auth!;
    final lockRepo = _lockRepo!;

    if (!auth.isLoggedIn) {
      return LoginScreen(
        register: _authClient.register,
        login: _authClient.login,
        onAuthenticated: _onAuthenticated,
      );
    }

    if (!_unlocked) {
      return UnlockScreen(
        lockRepo: lockRepo,
        onUnlocked: () => setState(() => _unlocked = true),
        onRequireFullLogin: _requireFullLogin,
      );
    }

    return _Bootstrap(
      key: ValueKey(auth.token),
      auth: auth,
      authClient: _authClient,
      lockRepo: lockRepo,
      onLoggedOut: () {
        setState(() {
          _unlocked = false;
        });
        _initialize();
      },
      onUiLanguageChanged: widget.onUiLanguageChanged,
    );
  }
}

class _AppData {
  _AppData(
    this.packs,
    this.reviews,
    this.settings,
    this.manualContext,
    this.profileRepo,
    this.deviceId,
    this.isPlayBuild,
  );
  // Dil dəyişəndə (bax `_reloadForLanguage`) yeni dilin paketləri ilə əvəz
  // olunur — `profileRepo` kimi artıq mutable referanslar bundle edən
  // mövcud naxışın davamı (final DEYİL, qəsdən).
  PackRepository packs;
  final ReviewRepository reviews;
  final SettingsRepository settings;
  final ManualContextRepository manualContext;
  final UserProfileRepository profileRepo;
  final String deviceId;

  /// Google Play buraxılışıdırmı (bax `BuildFlavorService`) — `true`-dursa
  /// self-update/arxa-fon-məkan UI-ları gizlədilir (Play siyasəti).
  final bool isPlayBuild;
}

/// Repository-ləri yükləyir, profil yoxdursa onboarding göstərir, bildirişləri
/// planlaşdırır. Paket/bildiriş tıklaması canlı AI kartı açır (offline fallback).
class _Bootstrap extends StatefulWidget {
  const _Bootstrap({
    super.key,
    required this.auth,
    required this.authClient,
    required this.lockRepo,
    required this.onLoggedOut,
    this.onUiLanguageChanged,
  });

  final AuthRepository auth;
  final AuthClient authClient;
  final DeviceLockRepository lockRepo;

  /// Çıxış/hesab silmə/401 sonrası çağırılır — `_AuthGate`-i yenidən qurur.
  final VoidCallback onLoggedOut;

  /// Ayarlardan proqram dili dəyişəndə `MaterialApp`-ı yeniləyir.
  final ValueChanged<UiLanguage>? onUiLanguageChanged;

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> with WidgetsBindingObserver {
  late final Future<_AppData> _future;
  final TtsSpeaker _speaker = TtsSpeaker();
  final NotificationService _notifications = NotificationService();
  final GlobalKey<MainShellState> _shellKey = GlobalKey<MainShellState>();
  final GlobalKey<ChatScreenState> _chatKey = GlobalKey<ChatScreenState>();
  final BatteryOptimizationService _battery = BatteryOptimizationService();
  final BuildFlavorService _buildFlavor = BuildFlavorService();
  final BrowserLauncherService _browserLauncher = BrowserLauncherService();
  late final Future<bool> _isPlayBuildFuture;
  late final LocationService _location;
  late LiveContentClient _live;
  late final ChatClient _chat;
  final AudiobookClient _audiobooks =
      AudiobookClient(baseUrl: AppConfig.serverBaseUrl);
  final AudiobookDownloader _audiobookDownloader = AudiobookDownloader();
  bool _offlinePromptScheduled = false;
  final MusicClient _music = MusicClient(baseUrl: AppConfig.serverBaseUrl);
  final WordLookupClient _wordLookup =
      WordLookupClient(baseUrl: AppConfig.serverBaseUrl);
  final AudioPlayer _audioPlayer = const NativeAudioPlayer();
  late final RoutineClient _routine;
  final ProfileClient _profileClient = ProfileClient(baseUrl: AppConfig.serverBaseUrl);
  final AppUpdateClient _updateClient =
      AppUpdateClient(baseUrl: AppConfig.serverBaseUrl);
  String? _buildLabel;
  bool _loggingOut = false;
  _AppData? _cachedData;

  String get _token => widget.auth.token!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isPlayBuildFuture = _buildFlavor.isPlayBuild();
    _chat = ChatClient(baseUrl: AppConfig.serverBaseUrl, token: _token);
    _routine = RoutineClient(
      baseUrl: AppConfig.serverBaseUrl,
      token: _token,
      onUnauthorized: _forceLogout,
    );
    _location = LocationService(
      placeClient: PlaceClient(
        baseUrl: AppConfig.serverBaseUrl,
        token: _token,
        onUnauthorized: _forceLogout,
      ),
    );
    _future = _bootstrap();
    _loadBuildLabel(); // fire-and-forget — açılışı bloklamır
    _autoCheckForUpdate(); // fire-and-forget — istifadəçi Ayarlara getmədən
    // Faza 0 (ElevenLabs planı) baseline ölçüsü — `flutter_tts` uğursuzluq
    // faizini toplayır. Konstruktor sinxrondur (dispose() həmişə işləsin
    // deyə), ona görə repository sonradan bağlanır.
    TtsTelemetryRepository.load().then((t) => _speaker.telemetry = t);
  }

  /// App açılışında arxa fonda: yeni versiya varsa dərhal yükləyib sistem
  /// quraşdırıcısını açır — istifadəçi Ayarlar ekranına girib "Yenilə"yə
  /// toxunmalı olmasın. Ana səhifənin widget ağacına toxunmur (bax
  /// `_loadBuildLabel` yanındakı izah — HomeTab-a dinamik UI əlavə etmək
  /// riskli olub), sadəcə şəbəkə/fayl əməliyyatıdır və sonda `OpenFilex.open`
  /// sistemin öz quraşdırma dialoqunu açır (Android buna görə hələ də bir
  /// toxunuş tələb edir — tam səssiz quraşdırma mümkün deyil).
  Future<void> _autoCheckForUpdate() async {
    try {
      final status = await _fetchUpdateStatus();
      if (status.info == null) return;
      final destPath = '${Directory.systemTemp.path}/dildostu-update.apk';
      final path = await _updateClient.downloadApk(destPath);
      if (path == null) return;
      await _installApk(path);
    } catch (_) {
      // Arxa fon yoxlaması — istifadəçini bloklamamalı; Ayarlar ekranı
      // hələ də əl ilə yoxlama/yükləmə təklif edir.
    }
  }

  /// Buraxılış etiketini yükləyir (Ayarlarda "Buraxılış" sətri üçün).
  ///
  /// Yeniləmə YOXLAMASI burada YOXDUR — bax Ayarlar ekranındaki izah:
  /// "Yenilə" zolağının Ana səhifədə dinamik göstərilməsi Samsung
  /// S926B-də tabı əbədi boş qoyurdu. Yeniləmə indi tamamilə Ayarlar
  /// ekranının öz məsuliyyətidir (`SettingsScreen.fetchUpdate`).
  Future<void> _loadBuildLabel() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() =>
            _buildLabel = '${packageInfo.version}+${packageInfo.buildNumber}');
      }
    } catch (_) {
      // Etiket göstərilməsə də app işləməlidir.
    }
  }

  /// Token vaxtı keçib/hesab silinibsə (server 401 versə) sessiyanı bağlayıb
  /// giriş ekranına qaytarır. Bir neçə client eyni anda 401 alsa belə
  /// təhlükəsizdir (logout/onLoggedOut idempotentdir).
  void _forceLogout() {
    if (_loggingOut) return;
    _loggingOut = true;
    widget.auth.logout().then((_) => widget.onLoggedOut());
  }

  Future<void> _logout() async {
    await widget.auth.logout();
    widget.onLoggedOut();
  }

  Future<void> _deleteAccount() async {
    try {
      await widget.authClient.deleteAccount(_token);
    } on AuthException catch (e) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    await widget.auth.logout();
    widget.onLoggedOut();
  }

  /// Serverdə yeni versiya varmı yoxlayır — Ayarlar ekranı özü çağırır
  /// (açılışda avtomatik + "yenidən yoxla" düyməsi ilə əl ilə). Google Play
  /// buraxılışında `info: null, error: null` qaytarır (bölmə boş görünər) —
  /// Play siyasəti app-daxili yeniləməni qadağan edir.
  Future<({AppVersionInfo? info, String? error})> _fetchUpdateStatus() async {
    if (await _isPlayBuildFuture) return (info: null, error: null);
    int currentCode;
    try {
      final info = await PackageInfo.fromPlatform();
      currentCode = int.parse(info.buildNumber);
    } catch (e) {
      return (info: null, error: 'Cari versiya oxunmadı: $e');
    }
    final result = await _updateClient.fetchVersionInfoDetailed();
    if (result.error != null) return (info: null, error: result.error);
    final server = result.info!;
    if (server.versionCode <= currentCode) return (info: null, error: null);
    return (info: server, error: null);
  }

  /// APK-nı yükləyir (Ayarlar ekranı gedişatı öz vəziyyətində göstərir).
  Future<String?> _downloadUpdate(
    void Function(int received, int? total) onProgress,
  ) {
    final destPath = '${Directory.systemTemp.path}/dildostu-update.apk';
    return _updateClient.downloadApk(destPath, onProgress: onProgress);
  }

  /// Yüklənmiş APK-nı sistem quraşdırıcısına açır. Uğursuz olsa göstərir —
  /// səssiz uğursuzluq olmamalıdır (əvvəl məhz bu, problemi gizlədirdi).
  Future<void> _installApk(String path) async {
    final result = await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Quraşdırma açılmadı: ${result.message}')),
        );
      }
    }
  }

  /// Verilmiş dilin statik paketlərini yükləyib `_live`/`_speaker`-i bu dilə
  /// bağlayır. Bootstrap-da VƏ Ayarlardan dil dəyişəndə (bax
  /// `_reloadForLanguage`) eyni məntiq işlədilir — təkrarlanmasın deyə ayrıca.
  Future<PackRepository> _loadPacksAndWireLive(TargetLanguage lang) async {
    final packs = await PackRepository.loadFromAssets(lang: lang.wire);
    // "Əsas lüğət" offline nüsxəsi yalnız İngilis üçün var (Barron's 504
    // bankı) — digər dillərdə server canlı AI ilə cavab verir, offline
    // fallback yoxdur (spec: 2026-08-04-multilanguage-russian-design.md).
    EssentialWordsRepository? essentialFallback;
    if (lang == TargetLanguage.english) {
      try {
        essentialFallback = await EssentialWordsRepository.loadFromAssets();
      } catch (_) {}
    }
    _live = LiveContentClient(
      baseUrl: AppConfig.serverBaseUrl,
      fallbackRepo: packs,
      essentialFallback: essentialFallback,
    );
    _speaker.ttsLocale = lang.ttsLocale;
    return packs;
  }

  Future<_AppData> _bootstrap() async {
    // Lokal keşlənmiş profil (şəbəkə tələb etmir) ƏVVƏLCƏ oxunur ki, düzgün
    // dilin paketləri yüklənsin. Server profili aşağıda paralel gələcək —
    // fərqli dil göstərsə (nadir: yeni cihazda giriş) paketlər növbəti
    // restart-da düzəlir, bu, mövcud "server profili tək mənbədir" prinsipi
    // ilə uyğundur, əlavə mürəkkəblik gətirmir.
    final profileRepo = await UserProfileRepository.load();
    final initialLang = profileRepo.current?.targetLang ?? TargetLanguage.english;
    final packs = await _loadPacksAndWireLive(initialLang);
    // Yerli fayl skani sürətlidir (millisaniyələr) — açılışı bloklamağa
    // dəyər ki, `sourceFor` ilk render-dən artıq yerli fayllara düzgün
    // yönləndirsin (bax `_openAudiobooks`).
    await _audiobookDownloader.init();
    final reviews = await ReviewRepository.load();
    final settings = await SettingsRepository.load();
    final manualContext = await ManualContextRepository.load();
    final deviceId = (await DeviceIdRepository.load()).deviceId;

    final now = DateTime.now();
    final manualSignal = manualContext.currentSignal(now: now);

    // Bir-birindən ASILI OLMAYAN şəbəkə çağırışları PARALEL göndərilir.
    // Əvvəllər ardıcıl idi (profil 8s + cihaz bağlama 15s + məkan GPS+server
    // +OSM ~25s = ən pis halda ~48s) — istifadəçi bunu "ağ ekran" kimi qəbul
    // edirdi, halbuki proqram donmurdu, sadəcə növbə ilə gözləyirdi.
    // Fütürlər burada BAŞLADILIR (await olmadan) ki, hamısı eyni anda getsin.
    final profileFuture = _profileClient.fetchOutcome(_token);
    final claimFuture = _routine.claimDevice(deviceId);
    final locationFuture = manualSignal == null
        ? _location.resolveNearbyPackId()
        : Future<String?>.value(null);
    final notifInitFuture = _notifications.init(onTap: _onNotificationTap);

    // Server profili tək mənbədir (spec: hər istifadəçi üçün ayrıca AI
    // yanaşması) — hər girişdə yenidən çəkilir ki, eyni cihazda fərqli
    // istifadəçi daxil olanda əvvəlki istifadəçinin profili sızmasın.
    final profileOutcome = await profileFuture;
    if (profileOutcome.reachedServer) {
      if (profileOutcome.profile != null) {
        await profileRepo.save(profileOutcome.profile!);
      } else {
        await profileRepo.clear();
      }
    }
    // Şəbəkə xətasında lokal profil saxlanır — chat/söz bildirişləri itmir.

    // Bu cihazda giriş edilmədən (köhnə buraxılışda) toplanmış anonim
    // nümunələr varsa hesaba bağla.
    await claimFuture;

    final isPlayBuild = await _isPlayBuildFuture;

    await notifInitFuture;

    String? contextOverride = manualSignal?.packId;
    final nearbyPackId = await locationFuture;
    if (contextOverride == null &&
        nearbyPackId != null &&
        packs.byId(nearbyPackId) != null) {
      contextOverride = resolveContextPack(
        now: now,
        timeBasedPackId: nearbyPackId,
        manualSignal: null,
        locationSignal: LocationSignal(packId: nearbyPackId, resolvedAt: now),
      );
    }

    final appData = _AppData(packs, reviews, settings, manualContext, profileRepo,
        deviceId, isPlayBuild);

    await _scheduleAllNotifications(
      appData,
      contextOverride: contextOverride,
    );

    final launchPayload = await _notifications.initialLaunchPayload();
    if (launchPayload != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleNotificationPayload(launchPayload),
      );
    }

    // İcazə varsa: periodik tapşırığı yenidən qeyd et (app yeniləməsindən sonra
    // itə bilər) + dərhal ön-plan nümunəsi götür (WorkManager-ə güvənmə).
    // Play buraxılışında arxa fon məkan yoxdur (manifestdə icazə silinib) —
    // heç cəhd etmə (Play siyasəti, V1.1-də ayrıca müraciətlə əlavə olunacaq).
    if (!isPlayBuild) _startRoutineSampling(deviceId, packs);

    return appData;
  }

  /// Söz + chat bildirişlərini planlaşdırır (açılış, resume, ayar dəyişikliyi).
  Future<void> _scheduleAllNotifications(
    _AppData data, {
    String? contextOverride,
  }) async {
    await _notifications.scheduleToday(
      data.settings.current,
      data.packs.packIds,
      (packId) => data.packs.byId(packId)?.titleAz ?? packId,
      firstSlotOverride: contextOverride,
    );

    final profile = data.profileRepo.current;
    if (profile == null) return;

    final serverNudges = await _chat.fetchNudges();
    final nudges = serverNudges.isNotEmpty
        ? serverNudges
        : buildLocalChatNudges(profile);
    await _notifications.scheduleChatNudges(nudges);
  }

  /// App açılışda rutin toplamanı təmin edir: icazə varsa periodik tapşırığı
  /// yenidən qeyd edir, dərhal bir ön-plan nümunəsi göndərir və eyni koordinatla
  /// geofence yoxlaması edir (tez-tez gedilən yerdəsənsə dərhal bildiriş).
  /// Səssiz keçir.
  Future<void> _startRoutineSampling(
      String deviceId, PackRepository packs) async {
    try {
      if (!await _location.hasBackgroundPermission()) return;
      await RoutineSampler.registerPeriodic();
      final sample = await _location.resolveNearbySample();
      if (sample == null) return;
      await _routine.postSample(
        deviceId: deviceId,
        lat: sample.lat,
        lng: sample.lng,
        placeType: sample.packId,
        packId: sample.packId,
      );
      final cooldown = await GeofenceCooldownRepository.load();
      await checkGeofenceArrival(
        lat: sample.lat,
        lng: sample.lng,
        fetchGeofences: _routine.fetchGeofences,
        getLastNotified: cooldown.lastNotifiedAt,
        markNotified: cooldown.markNotified,
        notify: (packId, label) =>
            _notifications.showArrival(packId, packTitleAz(label)),
      );
    } catch (_) {
      // Fon işi — istifadəçini bloklamamalı.
    }
  }

  /// "İndi yoxla" — nümunə tapılsa göndərir; tapılmasa detallı diaqnostika
  /// göstərir (koordinat + server/OSM nəticəsi) ki, problem harada olduğu görünsün.
  Future<String> _sampleNow(_AppData data) async {
    final sample = await _location.resolveNearbySample();
    if (sample == null) {
      return _location.diagnose();
    }
    await _routine.postSample(
      deviceId: data.deviceId,
      lat: sample.lat,
      lng: sample.lng,
      placeType: sample.packId,
      packId: sample.packId,
    );
    final label = data.packs.byId(sample.packId)?.titleAz ?? sample.packId;
    final where = sample.place.isNotEmpty ? '${sample.place} → ' : '';
    return 'Tapıldı: $where$label — serverə göndərildi ✅';
  }

  /// Ana səhifədəki canlı məkan kartı üçün: GPS→server ilə cari yeri tapır və
  /// ön-plan nümunəsini serverə göndərir. Nəticə uğursuzluq halında da qaytarılır
  /// (səbəb daşıyır) — kart istifadəçiyə niyə alınmadığını göstərir.
  Future<LivePlaceState> _resolveLivePlace(_AppData data,
      {bool forceRefresh = false}) async {
    if (forceRefresh) _location.invalidateCache();
    final outcome = await _location.resolve();

    if (!outcome.isSuccess) {
      return LivePlaceState.failed(describeFailure(outcome.failure!));
    }

    // Paketi olmayan yer (məs. "Park") — yeri göstəririk, amma açılmır.
    final pack = outcome.hasPack ? data.packs.byId(outcome.packId!) : null;
    if (outcome.hasPack && pack != null && !outcome.fromCache) {
      // Ön-plan nümunəsini rutin datasına da yaz (fon icazəsi olmasa belə).
      _routine.postSample(
        deviceId: data.deviceId,
        lat: outcome.lat!,
        lng: outcome.lng!,
        placeType: outcome.packId!,
        packId: outcome.packId!,
      );
    }

    return LivePlaceState.resolved(
      packId: pack != null ? outcome.packId : null,
      title: pack?.titleAz ?? '',
      placeName: outcome.label,
      distanceM: outcome.distanceM,
      approximate: outcome.quality == FixQuality.approximate,
    );
  }

  /// Bildiriş/geofence tıklamasında paket və ya chat tab açır.
  void _onNotificationTap(String? payload) {
    if (payload == null) return;
    _handleNotificationPayload(payload);
  }

  void _handleNotificationPayload(String payload) {
    if (isChatNudgePayload(payload)) {
      _openChatFromNotification(decodeChatNudgePrompt(payload));
      return;
    }
    _openLive(payload);
  }

  /// Chat bildirişindən — Söhbət tabına keçir, sualı input-a yazır.
  void _openChatFromNotification(String? quickPrompt) {
    _future.then((_) {
      _shellKey.currentState?.openChatTab();
      if (quickPrompt != null && quickPrompt.isNotEmpty) {
        _chatKey.currentState?.applyDraftPrompt(quickPrompt);
      }
    });
  }

  /// Bildiriş/geofence tıklamasında həmin paketin söz siyahısını açır.
  void _openLive(String? packId) {
    if (packId == null) return;
    _future.then((data) {
      final profile = data.profileRepo.current;
      final pack = data.packs.byId(packId);
      if (profile == null || pack == null) return;
      navigatorKey.currentState?.push(
          _wordListRoute(pack.packId, pack.titleAz, profile, data.reviews));
    });
  }

  /// Gündəlik AI missiya (`/day-plan`) — gündə bir dəfə şəbəkə, sonra keş.
  Future<({List<LiveMessage> messages, bool isLive})> _loadDayPlan(
    _AppData data, {
    bool forceRefresh = false,
  }) async {
    final profile = data.profileRepo.current!;
    final today = dayPlanDateKey(DateTime.now());
    final cacheRepo = await DayPlanCacheRepository.load();
    if (!forceRefresh) {
      final cached = cacheRepo.read(today);
      if (cached != null && cached.messages.isNotEmpty) {
        final allLive = cached.messages.every((m) => m.isLive);
        return (messages: cached.messages, isLive: allLive);
      }
    }
    final packIds = pickDayPlanPackIds(data.packs.packIds, DateTime.now());
    final result = await _live.dayPlan(
      profile: profile,
      date: today,
      packIds: packIds,
    );
    if (result.messages.isNotEmpty) {
      await cacheRepo.save(today, result.messages);
    }
    return result;
  }

  void _openDayPlanWords(
    List<LiveMessage> words,
    int index,
    UserProfile profile,
    ReviewRepository reviews,
  ) {
    if (words.isEmpty) return;
    final safeIndex = index.clamp(0, words.length - 1);
    final accent = accentFor(words[safeIndex].packId);
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => WordDetailScreen(
        title: 'Bu günün missiyası',
        words: words,
        initialIndex: safeIndex,
        speaker: _speaker,
        accent: accent,
        reviewRepository: reviews,
        onAiWord: ({
          required String packId,
          required String mode,
          required List<String> recentWords,
        }) =>
            _live.generate(
          packId: packId,
          hour: DateTime.now().hour,
          profile: profile,
          mode: mode,
          recentWords: recentWords,
        ),
        onAskQuestion: () => _openChat(
          profile,
          greeting: 'Bu günün missiyası haqda nə soruşmaq istəyirsən? 🤖',
        ),
      ),
    ));
  }

  /// Paket → söz siyahısı ekranı. Siyahıdan sözə toxunanda ətraflı ekran açılır
  /// (indeks ötürülür ki, orada "Əvvəlki/Növbəti" işləsin).
  MaterialPageRoute _wordListRoute(String packId, String title,
      UserProfile profile, ReviewRepository reviews) {
    final accent = accentFor(packId);
    return MaterialPageRoute(
      builder: (_) => WordListScreen(
        title: title,
        loader: () => _live.packWords(packId: packId, profile: profile),
        accent: accent,
        onOpenWord: (words, index) =>
            navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => WordDetailScreen(
            title: title,
            words: words,
            initialIndex: index,
            speaker: _speaker,
            accent: accent,
            reviewRepository: reviews,
            onAiWord: ({
              required String packId,
              required String mode,
              required List<String> recentWords,
            }) =>
                _live.generate(
              packId: packId,
              hour: DateTime.now().hour,
              profile: profile,
              mode: mode,
              recentWords: recentWords,
            ),
            onAskQuestion: () => _openChat(
              profile,
              packId: packId,
              greeting: '"$title" haqda nə soruşmaq istəyirsən? 🤖',
            ),
          ),
        )),
      ),
    );
  }

  /// "Əsas lüğət" (504 sabit söz bankı) ekranını açır — kontekstdən
  /// (məkan/paket) asılı deyil, birbaşa istifadəçinin cari səviyyəsindən.
  void _openEssentialWords(
      UserProfile profile, ReviewRepository reviews) {
    final accent = accentFor('essential');
    final levelLabel = profile.level.labelAz;
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => EssentialWordsScreen(
        levelLabel: levelLabel,
        loader: (offset) =>
            _live.essentialWords(profile: profile, offset: offset),
        accent: accent,
        onOpenWord: (words, index) =>
            navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => WordDetailScreen(
            title: 'Əsas lüğət',
            words: words,
            initialIndex: index,
            speaker: _speaker,
            accent: accent,
            reviewRepository: reviews,
            onAiWord: ({
              required String packId,
              required String mode,
              required List<String> recentWords,
            }) =>
                _live.generate(
              packId: packId,
              hour: DateTime.now().hour,
              profile: profile,
              mode: mode,
              recentWords: recentWords,
            ),
            onAskQuestion: () => _openChat(
              profile,
              greeting: 'Bu sözlər haqda nə soruşmaq istəyirsən? 🤖',
            ),
          ),
        )),
      ),
    ));
  }

  /// Kitabxana manifestini serverdən alır, uğurlu olsa yerli keşi yeniləyir
  /// (bax `AudiobookDownloader.cacheLibraryRaw`); server/internet əlçatmaz
  /// olsa əvvəlki uğurlu cavabın keşinə düşür — kitab siyahısı offline da
  /// görünür (yalnız endirilmiş fəsillər ÇALINA bilər, amma siyahı özü
  /// heç vaxt "internet yoxdur" səbəbindən boş qalmır, əgər bir dəfə
  /// uğurla yüklənibsə).
  Future<List<Audiobook>> _fetchAudiobookLibrary() async {
    try {
      final raw = await _audiobooks.fetchLibraryRaw();
      unawaited(_audiobookDownloader.cacheLibraryRaw(raw));
      return AudiobookClient.parseLibrary(raw);
    } catch (_) {
      final cached = await _audiobookDownloader.cachedLibraryRaw();
      if (cached != null) return AudiobookClient.parseLibrary(cached);
      rethrow;
    }
  }

  Future<List<Audiobook>> _audiobooksForProfile(UserProfile profile) async {
    final books = await _fetchAudiobookLibrary();
    final byLang =
        books.where((b) => b.lang == profile.targetLang.wire).toList();
    return audiobooksForLevel(byLang, profile.level);
  }

  /// Səsli kitablar: kitabxana → hekayə siyahısı → plyer. Kitabxana
  /// istifadəçinin öyrəndiyi dilə görə süzülür (bax
  /// 2026-08-04-multilanguage-russian-design.md) — server manifesti bütün
  /// dillərin kitablarını qaytarır, süzgəc client-dədir (kiçik kataloq).
  void _openAudiobooks(UserProfile profile) {
    final accent = accentFor('audiobooks');

    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => AudiobooksScreen(
        loader: () => _audiobooksForProfile(profile),
        accent: accent,
        onOpenBook: (book) =>
            navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => AudiobookChaptersScreen(
            book: book,
            accent: accent,
            onOpenChapter: (index) =>
                navigatorKey.currentState?.push(MaterialPageRoute(
              builder: (_) => AudiobookPlayerScreen(
                book: book,
                initialIndex: index,
                player: _audioPlayer,
                // Yerli faylı üstün tutur (endirilibsə) — offline dinləmə
                // buna görə işləyir; endirilməyibsə axın URL-inə düşür.
                sourceFor: (b, c) =>
                    _audiobookDownloader.localPath(b.bookId, c.chapterId) ??
                    _audiobooks.chapterUrl(b.bookId, c.chapterId),
                lookupWord: (word, sentence) =>
                    _wordLookup.lookup(word, context: sentence),
                accent: accent,
              ),
            )),
          ),
        )),
      ),
    ));
  }

  /// Bir dəfə (hər istifadəçi üçün) — açılışda offline endirmə təklif edir.
  /// Ana səhifənin widget ağacına TOXUNMUR (dialog overlay-dir, Column-a
  /// dinamik widget əlavə edilmir) — `home_tab.dart`/`SettingsScreen`-dəki
  /// "dinamik UI = layout donması" dərsinə görə qəsdən bu formada.
  Future<void> _maybePromptOfflineDownload(UserProfile profile) async {
    if (_offlinePromptScheduled) return;
    _offlinePromptScheduled = true;
    final prefs = await SharedPreferences.getInstance();
    const flagKey = 'offline_audiobooks_prompted_v1';
    if (prefs.getBool(flagKey) == true) return;
    List<Audiobook> books;
    try {
      books = await _audiobooksForProfile(profile);
    } catch (_) {
      // İlk girişdə internet yoxdursa soruşmağa dəyməz — sonra Ayarlardan
      // əl ilə cəhd edə bilər. Bayrağı BURADA qeyd etmirik ki, internet
      // gələndə növbəti açılışda yenə soruşulsun.
      return;
    }
    await prefs.setBool(flagKey, true);
    final pendingMb = _audiobookDownloader.pendingBytes(books) / (1024 * 1024);
    if (pendingMb < 1) return; // artıq yüklənib və ya heç kitab yoxdur
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final accepted = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Offline üçün endirilsin?'),
        content: Text(
          'Səyahət zamanı internet olmasa belə dinləyə bilmək üçün səsli '
          'kitablar (~${pendingMb.toStringAsFixed(0)} MB) telefona '
          'yüklənsin? Wi-Fi ilə etmək tövsiyə olunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Sonra'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Bəli, yüklə'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      unawaited(_audiobookDownloader.downloadAll(
        books,
        urlFor: (b, c) => _audiobooks.chapterUrl(b, c),
      ));
    }
  }

  /// Musiqi: kataloq → mahnı seçimi → pleyer (video + sətir-sətir tərcümə).
  /// Audiobook-dakı eyni prinsip: kataloq istifadəçinin öyrəndiyi dilə görə
  /// client-də süzülür (bax `_openAudiobooks`).
  void _openMusic(UserProfile profile) {
    final accent = accentFor('music');
    final levelLabel = profile.level.labelAz;
    Future<List<Song>> loadForLanguageAndLevel() async {
      final songs = await _music.fetchLibrary();
      final byLang =
          songs.where((s) => s.lang == profile.targetLang.wire).toList();
      return songsForLevel(byLang, profile.level);
    }

    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => MusicScreen(
        loader: loadForLanguageAndLevel,
        levelLabel: levelLabel,
        accent: accent,
        onOpenSong: (song) => navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => SongPlayerScreen(
            song: song,
            lookupWord: (word, line) =>
                _wordLookup.lookup(word, context: line),
            embedUrlFor: (videoId) =>
                '${AppConfig.serverBaseUrl}/music/embed/$videoId',
            accent: accent,
          ),
        )),
      ),
    ));
  }

  /// "AI nəyi öyrənib" ekranını açır (serverdəki rutin aqreqatı).
  void _openLearnedPlaces(_AppData data) {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => LearnedPlacesScreen(
        loader: _routine.fetchSummary,
        labelFor: (id) => data.packs.byId(id)?.titleAz ?? id,
        onOpenPermission: () => _openRoutinePermission(data),
      ),
    ));
  }

  /// Arxa fon icazə ekranını açır; icazə verilsə periodik toplamanı qeyd edir.
  void _openRoutinePermission(_AppData data) {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => RoutinePermissionScreen(
        requestAlways: _location.ensureBackgroundPermission,
        openSettings: _location.openSettings,
        onGranted: () {
          // Xəta app-ı bloklamamalı — səssiz udulur.
          RoutineSampler.registerPeriodic().catchError((_) {});
        },
        onSampleNow: () => _sampleNow(data),
        checkBatteryOptimization: _battery.isIgnoringOptimizations,
        openBatterySettings: _battery.openSettings,
      ),
    ));
  }

  /// AI söhbət ekranını açır (home-dan ümumi, kartdan kontekstli).
  void _openChat(UserProfile profile, {String? packId, String? greeting}) {
    final hour = DateTime.now().hour;
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => ChatScreen(
        greeting: greeting,
        // Chat sabit öz rənginə malikdir (paketdən açılsa belə) — dizayn
        // sənədinin qərarı: kontekstsiz xüsusiyyətlər öz kimliyini saxlayır.
        accent: accentFor('chat'),
        historyLoader: _chat.fetchHistory,
        quotaLoader: _chat.fetchQuota,
        speaker: _speaker,
        sender: (history) => _chat.send(
          profile: profile,
          history: history,
          packId: packId,
          hour: packId != null ? hour : null,
        ),
      ),
    ));
  }

  /// "İndi haradayam?" — manual məkan/kontekst ekranı.
  void _openManualPlace(_AppData data) {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => ManualModeScreen(
        packRepository: data.packs,
        reviewRepository: data.reviews,
        manualContextRepository: data.manualContext,
        speaker: _speaker,
      ),
    ));
  }

  /// Ana səhifədəki çətinlik seçicisi — profilə saxlanır (lokal keş + server)
  /// və dərhal tətbiq olunur (növbəti AI sorğusu yeni səviyyə ilə gedir,
  /// spec §1).
  Future<void> _changeLevel(_AppData data, ProficiencyLevel level) async {
    final current = data.profileRepo.current;
    if (current == null || current.level == level) return;
    final updated = current.copyWith(level: level);
    await data.profileRepo.save(updated);
    await _profileClient.save(_token, updated);
    if (mounted) setState(() {});
  }

  /// Ayarlardan öyrənilən dili canlı dəyişir (bax spec:
  /// 2026-08-04-multilanguage-russian-design.md §6) — `_changeLevel`-in
  /// qardaşı, fərqi: paketlər/TTS/canlı client də yeni dil üçün yenidən
  /// qurulmalıdır (yalnız profil sahəsi kifayət etmir).
  Future<void> _changeLanguage(_AppData data, TargetLanguage lang) async {
    final current = data.profileRepo.current;
    if (current == null || current.targetLang == lang) return;
    final updated = current.copyWith(targetLang: lang);
    await data.profileRepo.save(updated);
    await _profileClient.save(_token, updated);
    data.packs = await _loadPacksAndWireLive(lang);
    if (mounted) setState(() {});
  }

  void _openSettings(_AppData data) {
    final profile = data.profileRepo.current!;
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => SettingsScreen(
        repository: data.settings,
        buildLabel: _buildLabel,
        onOpenPrivacyPolicy: () =>
            _browserLauncher.openUrl('${AppConfig.serverBaseUrl}/privacy'),
        fetchUpdate: _fetchUpdateStatus,
        downloadUpdate: _downloadUpdate,
        onInstallApk: _installApk,
        ttsTelemetry: _speaker.telemetrySnapshot,
        audiobookDownloader: _audiobookDownloader,
        loadAudiobookLibrary: () => _audiobooksForProfile(profile),
        onDownloadAudiobooks: (books) => _audiobookDownloader.downloadAll(
          books,
          urlFor: (b, c) => _audiobooks.chapterUrl(b, c),
        ),
        loadChatPortrait: _chat.fetchPortrait,
        loadChatQuota: _chat.fetchQuota,
        lockRepo: widget.lockRepo,
        onRescheduleNotifications: () => _scheduleAllNotifications(data),
        diagnoseNotifications: _notifications.diagnose,
        onSendTestNotification: _notifications.showTestNow,
        onClearChatHistory: _chat.clearHistory,
        onClearChatPortrait: _chat.clearPortrait,
        onUiLanguageChanged: (lang) async {
          await data.settings.save(
            data.settings.current.copyWith(uiLanguage: lang),
          );
          widget.onUiLanguageChanged?.call(lang);
        },
      ),
    ));
  }

  /// Demo: dərhal "kafe" bildirişi göstərir (bildiriş→toxunma→kart axını).
  Future<void> _testNotification(_AppData data) async {
    const demoPack = 'cafe';
    final title = data.packs.byId(demoPack)?.titleAz ?? demoPack;
    await _notifications.showNow(demoPack, title);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speaker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _cachedData != null) {
      _scheduleAllNotifications(_cachedData!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Yüklənmə xətası:\n${snapshot.error}'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const BootstrapLoadingScreen();
        }
        final data = snapshot.data!;
        _cachedData = data;

        // Profil yoxdursa onboarding göstər.
        if (!data.profileRepo.isOnboarded) {
          return OnboardingScreen(
            onComplete: (profile) async {
              await data.profileRepo.save(profile);
              await _profileClient.save(_token, profile);
              if (mounted) setState(() {});
            },
          );
        }

        final profile = data.profileRepo.current!;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _maybePromptOfflineDownload(profile),
        );
        return MainShell(
          key: _shellKey,
          home: HomeTab(
            repository: data.packs,
            profile: profile,
            openLive: (packId, title, p) => navigatorKey.currentState?.push(
                _wordListRoute(packId, title, p, data.reviews)),
            onManualPlace: () => _openManualPlace(data),
            onLevelChanged: (level) => _changeLevel(data, level),
            currentLanguage: profile.targetLang,
            onLanguageChanged: (lang) => _changeLanguage(data, lang),
            resolveLivePlace: ({bool forceRefresh = false}) =>
                _resolveLivePlace(data, forceRefresh: forceRefresh),
            onOpenEssentialWords: () =>
                _openEssentialWords(profile, data.reviews),
            onOpenAudiobooks: () => _openAudiobooks(profile),
            // Musiqi Play buraxılışında GİZLİDİR: mahnı sözləri lisenziyasız
            // göstərilir, bu isə Play-in əqli mülkiyyət siyasətinə görə rədd/
            // silinmə riski yaradır (bax .planning/2026-08-03-dildostu-playstore).
            // Kod tam qalır — təsdiqdən sonra lisenziya və ya ictimai domen
            // məzmunla açılacaq (geofence ilə eyni yanaşma).
            onOpenMusic:
                data.isPlayBuild ? null : () => _openMusic(profile),
            loadDayPlan: ({forceRefresh = false}) =>
                _loadDayPlan(data, forceRefresh: forceRefresh),
            onOpenDayPlanWord: (words, index) =>
                _openDayPlanWords(words, index, profile, data.reviews),
          ),
          chat: ChatScreen(
            key: _chatKey,
            greeting:
                'Salam! Mən LachinGo-yam — səyahət yoldaşın və dil bələdçin. ✈️\n'
                'Səni tanıdıqca hobbi və xarakterini yadda saxlayıram — '
                'istəsən sənin haqqında gözəl çıxış da yazaram! 😄',
            accent: accentFor('chat'),
            historyLoader: _chat.fetchHistory,
            quotaLoader: _chat.fetchQuota,
            speaker: _speaker,
            quickPrompts: const [
              'Mənim haqqımda maraqlı çıxış yaz',
              'Aeroportda check-in necə deyilir?',
              'Bu gün üçün 3 faydalı söz',
            ],
            sender: (history) =>
                _chat.send(profile: profile, history: history),
          ),
          progress: ProgressTab(
            reviewRepository: data.reviews,
            packRepository: data.packs,
            speaker: _speaker,
          ),
          profile: ProfileTab(
            onOpenSettings: () => _openSettings(data),
            onOpenLearned: () => _openLearnedPlaces(data),
            // Play buraxılışında bu funksiya yoxdur (manifestdə icazə silinib) —
            // giriş nöqtəsi göstərilmir.
            onOpenRoutine:
                data.isPlayBuild ? null : () => _openRoutinePermission(data),
            onTestNotification: () => _testNotification(data),
            email: widget.auth.email ?? '',
            onLogout: _logout,
            onDeleteAccount: _deleteAccount,
          ),
        );
      },
    );
  }
}
