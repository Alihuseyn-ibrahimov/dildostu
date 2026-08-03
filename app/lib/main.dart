import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'src/config.dart';
import 'src/data/app_update_client.dart';
import 'src/data/auth_client.dart';
import 'src/data/auth_repository.dart';
import 'src/data/chat_client.dart';
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
import 'src/data/user_profile_repository.dart';
import 'src/engine/context_engine.dart';
import 'src/engine/geofence_logic.dart';
import 'src/engine/pack_titles.dart';
import 'src/engine/update_logic.dart';
import 'src/models/app_version_info.dart';
import 'src/models/user_profile.dart';
import 'src/services/battery_optimization_service.dart';
import 'src/services/browser_launcher_service.dart';
import 'src/services/build_flavor_service.dart';
import 'src/services/location_service.dart';
import 'src/services/notification_service.dart';
import 'src/services/routine_sampler.dart';
import 'src/services/speaker.dart';
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
import 'src/ui/update_banner.dart';
import 'src/ui/word_detail_screen.dart';
import 'src/ui/word_list_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Arxa fon rutin toplama plugin-i (periodik iş üçün). Xəta app-ı bloklamamalı.
  try {
    await RoutineSampler.initialize();
  } catch (_) {}
  runApp(const DilDostuApp());
}

class DilDostuApp extends StatelessWidget {
  const DilDostuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'DilDostu',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AuthGate(),
    );
  }
}

/// Giriş qapısı — token varsa əsas app-ı (`_Bootstrap`), yoxdursa
/// `LoginScreen`-i göstərir. Çıxış/401 halında `setState` ilə geri
/// `LoginScreen`-ə qayıdır (spec: Faza 3, "hər kəs öz kabinetini yaradıb
/// daxil olsun").
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Future<AuthRepository> _future;
  final AuthClient _authClient = AuthClient(baseUrl: AppConfig.serverBaseUrl);

  @override
  void initState() {
    super.initState();
    _future = AuthRepository.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthRepository>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final auth = snapshot.data!;
        if (!auth.isLoggedIn) {
          return LoginScreen(
            register: _authClient.register,
            login: _authClient.login,
            onAuthenticated: (token, email) {
              auth.setSession(token: token, email: email).then((_) {
                if (mounted) setState(() {});
              });
            },
          );
        }
        // `key` — istifadəçi dəyişəndə (çıxış→başqa hesaba giriş) _Bootstrap
        // tam təzədən qurulsun, köhnə sessiyanın state-i sızmasın.
        return _Bootstrap(
          key: ValueKey(auth.token),
          auth: auth,
          authClient: _authClient,
          onLoggedOut: () {
            if (mounted) setState(() {});
          },
        );
      },
    );
  }
}

class _AppData {
  const _AppData(
    this.packs,
    this.reviews,
    this.settings,
    this.manualContext,
    this.profileRepo,
    this.deviceId,
    this.isPlayBuild,
  );
  final PackRepository packs;
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
    required this.onLoggedOut,
  });

  final AuthRepository auth;
  final AuthClient authClient;

  /// Çıxış/hesab silmə/401 sonrası çağırılır — `_AuthGate`-i yenidən qurur.
  final VoidCallback onLoggedOut;

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  late final Future<_AppData> _future;
  final Speaker _speaker = TtsSpeaker();
  final NotificationService _notifications = NotificationService();
  final BatteryOptimizationService _battery = BatteryOptimizationService();
  final BuildFlavorService _buildFlavor = BuildFlavorService();
  final BrowserLauncherService _browserLauncher = BrowserLauncherService();
  late final Future<bool> _isPlayBuildFuture;
  late final LocationService _location;
  late final LiveContentClient _live;
  final ChatClient _chat = ChatClient(baseUrl: AppConfig.serverBaseUrl);
  late final RoutineClient _routine;
  final ProfileClient _profileClient = ProfileClient(baseUrl: AppConfig.serverBaseUrl);
  final AppUpdateClient _updateClient =
      AppUpdateClient(baseUrl: AppConfig.serverBaseUrl);
  AppVersionInfo? _availableUpdate;
  UpdateStage _updateStage = UpdateStage.available;
  double? _updateProgress;
  String? _buildLabel;
  bool _loggingOut = false;

  String get _token => widget.auth.token!;

  @override
  void initState() {
    super.initState();
    _isPlayBuildFuture = _buildFlavor.isPlayBuild();
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
    _checkForUpdate(); // fire-and-forget — açılışı bloklamır
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

  /// Serverdə yeni versiya varmı — YALNIZ yoxlayır (kiçik JSON sorğusu) və
  /// tapılsa "Yenilə" zolağını DƏRHAL göstərir. Yükləmə istifadəçi zolağa
  /// toxunanda başlayır (`_startUpdate`).
  ///
  /// Google Play buraxılışında tamamilə söndürülür — Play siyasəti tətbiqin
  /// özünü yeniləməsini qadağan edir, yeniləmə yalnız Play-in öz mexanizmi
  /// ilə olmalıdır.
  Future<void> _checkForUpdate() async {
    if (await _isPlayBuildFuture) return;
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.parse(packageInfo.buildNumber);
      if (mounted) {
        setState(() =>
            _buildLabel = '${packageInfo.version}+${packageInfo.buildNumber}');
      }
      final info = await checkForUpdate(
        currentVersionCode: currentVersionCode,
        fetchVersion: _updateClient.fetchVersionInfo,
      );
      if (info == null || !mounted) return;
      setState(() {
        _availableUpdate = info;
        _updateStage = UpdateStage.available;
        _updateProgress = null;
      });
    } catch (_) {
      // Yeniləmə yoxlaması istifadəçini bloklamamalı.
    }
  }

  /// "Yenilə" toxunuşu: APK-nı faiz göstərərək yükləyir, sonra sistem
  /// quraşdırıcısını açır. Uğursuz olsa zolaq "Yenidən cəhd et"-ə keçir —
  /// səssiz uğursuzluq olmamalıdır (əvvəl məhz bu, problemi gizlədirdi).
  Future<void> _startUpdate() async {
    if (_updateStage == UpdateStage.downloading) return;
    setState(() {
      _updateStage = UpdateStage.downloading;
      _updateProgress = null;
    });

    final destPath = '${Directory.systemTemp.path}/dildostu-update.apk';
    var lastPercent = -1;
    final path = await _updateClient.downloadApk(
      destPath,
      onProgress: (received, total) {
        if (!mounted || total == null || total <= 0) return;
        // Hər çanaqda setState çağırmaq UI-ı boğur — yalnız faiz dəyişəndə.
        final percent = (received * 100 ~/ total);
        if (percent == lastPercent) return;
        lastPercent = percent;
        setState(() => _updateProgress = received / total);
      },
    );
    if (!mounted) return;

    if (path == null) {
      setState(() {
        _updateStage = UpdateStage.failed;
        _updateProgress = null;
      });
      return;
    }
    setState(() {
      _updateStage = UpdateStage.available;
      _updateProgress = null;
    });

    // APK-nı explicit .apk MIME ilə aç (bəzi cihazlarda ümumi tip quraşdırıcını
    // açmır); xəta olsa istifadəçiyə göstər ki, diaqnoz mümkün olsun.
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

  Future<_AppData> _bootstrap() async {
    final packs = await PackRepository.loadFromAssets();
    // "Əsas lüğət" offline nüsxəsi — asset korlanıbsa/yoxdursa səssiz keçir,
    // sadəcə offline halda bu paket boş qalır (server yenə işləyir).
    EssentialWordsRepository? essentialFallback;
    try {
      essentialFallback = await EssentialWordsRepository.loadFromAssets();
    } catch (_) {}
    _live = LiveContentClient(
      baseUrl: AppConfig.serverBaseUrl,
      fallbackRepo: packs,
      essentialFallback: essentialFallback,
    );
    final reviews = await ReviewRepository.load();
    final settings = await SettingsRepository.load();
    final manualContext = await ManualContextRepository.load();
    final profileRepo = await UserProfileRepository.load();
    final deviceId = (await DeviceIdRepository.load()).deviceId;

    // Server profili tək mənbədir (spec: hər istifadəçi üçün ayrıca AI
    // yanaşması) — hər girişdə yenidən çəkilir ki, eyni cihazda fərqli
    // istifadəçi daxil olanda əvvəlki istifadəçinin profili sızmasın.
    final serverProfile = await _profileClient.fetch(_token);
    if (serverProfile != null) {
      await profileRepo.save(serverProfile);
    } else {
      await profileRepo.clear();
    }

    // Bu cihazda giriş edilmədən (köhnə buraxılışda) toplanmış anonim
    // nümunələr varsa hesaba bağla.
    await _routine.claimDevice(deviceId);

    final isPlayBuild = await _isPlayBuildFuture;

    await _notifications.init(onTap: _openLive);

    final now = DateTime.now();
    final manualSignal = manualContext.currentSignal(now: now);
    String? contextOverride = manualSignal?.packId;
    if (contextOverride == null) {
      final nearbyPackId = await _location.resolveNearbyPackId();
      if (nearbyPackId != null && packs.byId(nearbyPackId) != null) {
        contextOverride = resolveContextPack(
          now: now,
          timeBasedPackId: nearbyPackId,
          manualSignal: null,
          locationSignal: LocationSignal(packId: nearbyPackId, resolvedAt: now),
        );
      }
    }

    await _notifications.scheduleToday(
      settings.current,
      packs.packIds,
      (packId) => packs.byId(packId)?.titleAz ?? packId,
      firstSlotOverride: contextOverride,
    );

    final launchPackId = await _notifications.initialLaunchPayload();
    if (launchPackId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openLive(launchPackId));
    }

    // İcazə varsa: periodik tapşırığı yenidən qeyd et (app yeniləməsindən sonra
    // itə bilər) + dərhal ön-plan nümunəsi götür (WorkManager-ə güvənmə).
    // Play buraxılışında arxa fon məkan yoxdur (manifestdə icazə silinib) —
    // heç cəhd etmə (Play siyasəti, V1.1-də ayrıca müraciətlə əlavə olunacaq).
    if (!isPlayBuild) _startRoutineSampling(deviceId, packs);

    return _AppData(packs, reviews, settings, manualContext, profileRepo,
        deviceId, isPlayBuild);
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

  /// Ana səhifədəki canlı məkan kartı üçün: GPS→server ilə cari yeri tapır,
  /// paket başlığı ilə birlikdə qaytarır və ön-plan nümunəsini serverə göndərir.
  /// Tapılmasa `null` (kart manual rejimə keçir).
  Future<({String packId, String title, String placeName})?> _resolveLivePlace(
      _AppData data) async {
    final sample = await _location.resolveNearbySample();
    if (sample == null) return null;
    final title = data.packs.byId(sample.packId)?.titleAz ?? sample.packId;
    // Ön-plan nümunəsini rutin datasına da yaz (fon icazəsi olmasa belə).
    _routine.postSample(
      deviceId: data.deviceId,
      lat: sample.lat,
      lng: sample.lng,
      placeType: sample.packId,
      packId: sample.packId,
    );
    return (packId: sample.packId, title: title, placeName: sample.place);
  }

  /// Bildiriş/geofence tıklamasında həmin paketin söz siyahısını açır.
  void _openLive(String? packId) {
    if (packId == null) return;
    _future.then((data) {
      final profile = data.profileRepo.current;
      final pack = data.packs.byId(packId);
      if (profile == null || pack == null) return;
      navigatorKey.currentState
          ?.push(_wordListRoute(pack.packId, pack.titleAz, profile));
    });
  }

  /// Paket → söz siyahısı ekranı. Siyahıdan sözə toxunanda ətraflı ekran açılır
  /// (indeks ötürülür ki, orada "Əvvəlki/Növbəti" işləsin).
  MaterialPageRoute _wordListRoute(
      String packId, String title, UserProfile profile) {
    return MaterialPageRoute(
      builder: (_) => WordListScreen(
        title: title,
        loader: () => _live.packWords(packId: packId, profile: profile),
        onOpenWord: (words, index) =>
            navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => WordDetailScreen(
            title: title,
            words: words,
            initialIndex: index,
            speaker: _speaker,
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
  void _openEssentialWords(UserProfile profile) {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => EssentialWordsScreen(
        loader: (offset) =>
            _live.essentialWords(profile: profile, offset: offset),
        onOpenWord: (words, index) =>
            navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => WordDetailScreen(
            title: 'Əsas lüğət',
            words: words,
            initialIndex: index,
            speaker: _speaker,
            onAskQuestion: () => _openChat(
              profile,
              greeting: 'Bu sözlər haqda nə soruşmaq istəyirsən? 🤖',
            ),
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

  void _openSettings(_AppData data) {
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => SettingsScreen(
        repository: data.settings,
        buildLabel: _buildLabel,
        onOpenPrivacyPolicy: () =>
            _browserLauncher.openUrl('${AppConfig.serverBaseUrl}/privacy'),
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
    _speaker.dispose();
    super.dispose();
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!;

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
        return MainShell(
          home: HomeTab(
            repository: data.packs,
            profile: profile,
            openLive: (packId, title, p) =>
                navigatorKey.currentState?.push(_wordListRoute(packId, title, p)),
            onManualPlace: () => _openManualPlace(data),
            onLevelChanged: (level) => _changeLevel(data, level),
            resolveLivePlace: () => _resolveLivePlace(data),
            onOpenEssentialWords: () => _openEssentialWords(profile),
            availableUpdate: _availableUpdate,
            onInstallUpdate: _availableUpdate == null ? null : _startUpdate,
            updateStage: _updateStage,
            updateProgress: _updateProgress,
          ),
          chat: ChatScreen(
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
